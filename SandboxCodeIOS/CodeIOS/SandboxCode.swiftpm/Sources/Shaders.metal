//
//  Shaders.metal
//  Quick3DDemo
//
//  Tầng ⑥ (shader) — gần như GLSL đổi cú pháp.
//  Trong project thật: Camera/Metal/Shaders.metal → scnVertex / pointFragment
//
//  SceneKit tự nạp 2 buffer theo TÊN tham số:
//    scn_frame : SCNSceneBuffer (view/projection… của frame)   ← từ <SceneKit/scn_metal>
//    scn_node  : struct per-node (modelTransform…)               ← phải tự khai layout
//  Các buffer còn lại (pointCount/pointSize/opacity) đến từ handleBinding(ofBufferNamed:).
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;            // PHẢI đứng trước scn_metal: header đó dùng float4x4 không prefix
#include <SceneKit/scn_metal>

// Layout chuẩn Apple cho buffer "scn_node" (giống project)
typedef struct {
    float4x4 modelTransform;
    float4x4 inverseModelTransform;
    float4x4 modelViewTransform;
    float4x4 inverseModelViewTransform;
    float4x4 normalTransform;
    float4x4 modelViewProjectionTransform;
    float4x4 inverseModelViewProjectionTransform;
    float2x3 boundingBox;
    float2x3 worldBoundingBox;
} DemoNodeBuffer;

// = attribute position / color (khớp semantic .vertex / .color trong SCNBuilder)
typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float3 color    [[ attribute(SCNVertexSemanticColor) ]];
} DemoVertexIn;

// = varying + gl_Position + gl_PointSize
typedef struct {
    float4 position  [[ position ]];
    float  pointSize [[ point_size ]];
    float  clip      [[ clip_distance ]];   // < 0 → vertex bị bỏ (thay cho gl_Position = vec4(2,2,2,1))
    float3 color;
    float  opacity;
} DemoVertexOut;

vertex DemoVertexOut demoVertex(
    uint vid                                [[ vertex_id ]],
    DemoVertexIn in                         [[ stage_in ]],
    constant SCNSceneBuffer& scn_frame      [[ buffer(0) ]],
    constant DemoNodeBuffer& scn_node       [[ buffer(1) ]],
    constant int&   pointCount              [[ buffer(2) ]],
    constant float& pointSize               [[ buffer(3) ]],
    constant float& opacity                 [[ buffer(4) ]])
{
    DemoVertexOut out;

    if (pointCount >= 0 && (int)vid >= pointCount) {
        out.position  = float4(0.0);
        out.pointSize = 0.0;
        out.clip      = -1.0;
        out.color     = float3(0.0);
        out.opacity   = 0.0;
        return out;
    }

    // local → world (arNode dời model = modelTransform đổi)
    float4 worldPos = scn_node.modelTransform * float4(in.position, 1.0);

    // Cỡ điểm giảm theo khoảng cách tới camera, kẹp trong [1, pointSize]
    float3 cameraPos = scn_frame.inverseViewTransform[3].xyz;
    float  dist      = max(length(worldPos.xyz - cameraPos), 0.05);

    out.position  = scn_frame.viewProjectionTransform * worldPos;   // = proj * view * world
    out.pointSize = clamp(2.0 * pointSize / dist, 1.0, pointSize);
    out.clip      = 1.0;
    out.color     = in.color;
    out.opacity   = opacity;
    return out;
}

fragment float4 demoFragment(DemoVertexOut in [[ stage_in ]],
                             float2 pointCoord  [[ point_coord ]])   // = gl_PointCoord
{
    float2 c = pointCoord - 0.5;
    if (length(c) > 0.5) {
        discard_fragment();                                           // = discard → chấm tròn
    }
    // Mềm rìa một chút cho đỡ răng cưa
    float edge = 1.0 - smoothstep(0.42, 0.5, length(c));
    return float4(in.color, in.opacity * edge);                      // blendMode .alpha ở material
}

// MARK: - Gaussian splatting
//
// Mỗi splat vẫn là MỘT điểm (primitive .point) nhưng:
//   vertex   : covariance 3D (6 số, đối xứng) → covariance 2D trên màn hình (công thức EWA trong paper 3DGS:
//              Σ' = J·W·Σ·Wᵀ·Jᵀ, J = Jacobian phép chiếu), point_size = đường kính 3σ lớn nhất.
//   fragment : alpha = opacity · exp(−½·dᵀ·Σ'⁻¹·d) với d = khoảng cách pixel tới tâm → ellipse mờ có hướng.
// Thứ tự vẽ (xa → gần) do SplatCloud sắp xếp lại index buffer trên CPU; material blend alpha, không ghi depth.

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float4 color    [[ attribute(SCNVertexSemanticColor) ]];        // rgb + opacity (đã sigmoid)
    float3 cov0     [[ attribute(SCNVertexSemanticTexcoord0) ]];    // Σxx Σxy Σxz
    float3 cov1     [[ attribute(SCNVertexSemanticTexcoord1) ]];    // Σyy Σyz Σzz
} SplatVertexIn;

typedef struct {
    float4 position  [[ position ]];
    float  pointSize [[ point_size ]];
    float  clip      [[ clip_distance ]];
    float4 color;
    float3 conic;      // (A, B, C) = Σ'⁻¹ theo pixel: A·dx² + 2B·dx·dy + C·dy²
    float  size;       // point_size (px) để fragment đổi point_coord → pixel
} SplatVertexOut;

vertex SplatVertexOut splatVertex(
    SplatVertexIn in                        [[ stage_in ]],
    constant SCNSceneBuffer& scn_frame      [[ buffer(0) ]],
    constant DemoNodeBuffer& scn_node       [[ buffer(1) ]],
    constant float& splatScale              [[ buffer(2) ]],      // nhân σ (slider Point size / 14)
    constant float& opacity                 [[ buffer(3) ]])
{
    SplatVertexOut out;
    out.position  = float4(0.0);
    out.pointSize = 0.0;
    out.clip      = -1.0;
    out.color     = float4(0.0);
    out.conic     = float3(0.0);
    out.size      = 0.0;

    float4 viewPos = scn_node.modelViewTransform * float4(in.position, 1.0);
    float3 t  = viewPos.xyz;
    float  zz = -t.z;                                   // SceneKit nhìn theo −Z → độ sâu dương
    if (zz < 0.02) { return out; }

    float2 res = 1.0 / scn_frame.inverseResolution;     // kích thước viewport (px)
    float  fx  = scn_frame.projectionTransform[0][0] * res.x * 0.5;   // tiêu cự theo pixel
    float  fy  = scn_frame.projectionTransform[1][1] * res.y * 0.5;

    // Kẹp tâm vào trong frustum ×1.3 để Jacobian ở mép màn không nổ số (giống code gốc 3DGS)
    float limx = 1.3 * res.x * 0.5 / fx;
    float limy = 1.3 * res.y * 0.5 / fy;
    float tx = clamp(t.x / zz, -limx, limx) * zz;
    float ty = clamp(t.y / zz, -limy, limy) * zz;

    float k = splatScale * splatScale;                  // scale σ → covariance nhân k
    float3x3 S = float3x3(float3(in.cov0.x, in.cov0.y, in.cov0.z),
                          float3(in.cov0.y, in.cov1.x, in.cov1.y),
                          float3(in.cov0.z, in.cov1.y, in.cov1.z)) * k;
    // Σ local → view (gồm cả scale của node, nên slider "Cỡ cloud" tự đúng)
    float3x3 T = float3x3(scn_node.modelViewTransform[0].xyz,
                          scn_node.modelViewTransform[1].xyz,
                          scn_node.modelViewTransform[2].xyz);
    // Jacobian của phép chiếu phối cảnh tại t (cột = cột của ma trận)
    float3x3 J = float3x3(float3(fx / zz, 0.0, 0.0),
                          float3(0.0, fy / zz, 0.0),
                          float3(-fx * tx / (zz * zz), -fy * ty / (zz * zz), 0.0));
    float3x3 W = J * T;
    float3x3 C = W * S * transpose(W);

    float a = C[0][0] + 0.3;                            // +0.3 px²: lọc thông thấp, tránh splat < 1 px lấp lánh
    float b = C[1][0];
    float d = C[1][1] + 0.3;
    float det = a * d - b * b;
    if (det <= 0.0) { return out; }

    float mid = 0.5 * (a + d);
    float lam = mid + sqrt(max(0.0, mid * mid - det)); // trị riêng lớn nhất = σ² theo trục dài
    float size = min(2.0 * ceil(3.0 * sqrt(lam)), 1024.0);

    out.position  = scn_frame.projectionTransform * viewPos;
    out.pointSize = size;
    out.size      = size;
    out.clip      = 1.0;
    out.conic     = float3(d, -b, a) / det;
    out.color     = float4(in.color.rgb, in.color.a * opacity);
    return out;
}

fragment float4 splatFragment(SplatVertexOut in [[ stage_in ]],
                              float2 pointCoord  [[ point_coord ]])
{
    float2 d = (pointCoord - 0.5) * in.size;           // pixel tính từ tâm
    d.y = -d.y;                                         // point_coord y đi xuống, covariance tính với y đi lên
    float power = -0.5 * (in.conic.x * d.x * d.x + 2.0 * in.conic.y * d.x * d.y + in.conic.z * d.y * d.y);
    float alpha = min(0.99, in.color.a * exp(power));
    if (alpha < 1.0 / 255.0) {
        discard_fragment();
    }
    // SceneKit blend theo premultiplied alpha (src + dst·(1−α)): phải nhân màu với alpha,
    // nếu không viền (α→0) vẫn cộng nguyên màu vào nền → vành sáng cứng, chồng nhiều splat thành trắng loá.
    return float4(in.color.rgb * alpha, alpha);
}

// MARK: - Gaussian splatting kiểu web (SplatRenderer.swift) — port nguyên văn splatVertSrc/splatFragSrc
//
// Khác splatVertex ở trên: mỗi splat là một QUAD instanced (4 đỉnh) xoay theo trục ellipse, cỡ 2√2σ,
// kẹp theo viewport, có bù antialias (aaFactor) khi cộng 0.3 px², cắt Gauss ở e⁻⁴ và không depth test.
// Σ 3D lấy sẵn từ cov0/cov1 (đã gồm lật trục) thay vì tính lại từ scale/rot như web.

typedef struct {
    float4x4 modelView;
    float4x4 projection;
    float2   viewport;
    float    focal;        // = h · proj[1][1] / 2
    float    splatScale;
    float    opacity;
    float    gamma;        // 2.2 nếu attachment sRGB (SceneKit iOS), 1 nếu thường
    float2   pad;
} GSplatUniforms;

typedef struct {
    float4 position [[ position ]];
    float2 offset;         // pixel tính từ tâm (v_offset)
    float3 color;
    float  opacity;
    float3 conic;
} GSplatVertexOut;

vertex GSplatVertexOut gsplatVertex(
    uint vid                              [[ vertex_id ]],
    uint iid                              [[ instance_id ]],
    const device float3*  positions       [[ buffer(0) ]],
    const device float4*  colors          [[ buffer(1) ]],
    const device float3*  cov0s           [[ buffer(2) ]],
    const device float3*  cov1s           [[ buffer(3) ]],
    const device uint*    order           [[ buffer(4) ]],   // index buffer đã sắp xa → gần (SplatCloud)
    constant GSplatUniforms& u            [[ buffer(5) ]])
{
    GSplatVertexOut out;
    out.position = float4(2.0, 2.0, 2.0, 1.0);          // = gl_Position = vec4(2,2,2,1) → bị clip
    out.offset = float2(0.0); out.color = float3(0.0); out.opacity = 0.0; out.conic = float3(0.0);

    // a_corner: (-1,-1) (1,-1) (-1,1) (1,1) theo triangle strip
    float2 corner = float2((vid & 1u) ? 1.0 : -1.0, (vid & 2u) ? 1.0 : -1.0);
    uint   si   = order[iid];
    float3 pos  = positions[si];
    float4 col  = colors[si];
    float3 c0   = cov0s[si], c1 = cov1s[si];
    float  k    = u.splatScale * u.splatScale;
    float3x3 Sigma = float3x3(float3(c0.x, c0.y, c0.z),
                              float3(c0.y, c1.x, c1.y),
                              float3(c0.z, c1.y, c1.z)) * k;

    float4 vp = u.modelView * float4(pos, 1.0);
    if (vp.z >= 0.0) { return out; }                    // sau camera

    float3x3 W = float3x3(u.modelView[0].xyz, u.modelView[1].xyz, u.modelView[2].xyz);
    float3x3 T = W * Sigma * transpose(W);
    float zinv = 1.0 / vp.z; float zinv2 = zinv * zinv;
    float fx = u.focal, fy = u.focal;
    float3x3 J = float3x3(float3(fx * zinv, 0.0, 0.0),
                          float3(0.0, fy * zinv, 0.0),
                          float3(-fx * vp.x * zinv2, -fy * vp.y * zinv2, 0.0));
    float3x3 cov2 = J * T * transpose(J);
    float detOrig = cov2[0][0] * cov2[1][1] - cov2[0][1] * cov2[0][1];
    float a = cov2[0][0] + 0.3; float b = cov2[0][1]; float c = cov2[1][1] + 0.3;
    float detBlur = a * c - b * b;
    float aaFactor = detBlur > 0.0 ? sqrt(max(detOrig / detBlur, 0.0)) : 1.0;
    float det = a * c - b * b;
    if (det <= 0.0) { return out; }
    float invDet = 1.0 / det;
    float3 conic = float3(c * invDet, -b * invDet, a * invDet);
    float mid = 0.5 * (a + c); float disc = sqrt(max(0.1, mid * mid - det));
    float lam1 = mid + disc; float lam2 = max(mid - disc, 0.1);
    float r1 = sqrt(lam1); float r2 = sqrt(lam2);
    float2 ax = float2(b, lam1 - a);
    float2 axis1 = length(ax) < 1e-6 ? float2(1.0, 0.0) : normalize(ax);
    float2 axis2 = float2(-axis1.y, axis1.x);
    float kSigma = 2.8284271;
    float vmin = min(1024.0, min(u.viewport.x, u.viewport.y)); float cap = vmin / kSigma;
    r1 = min(r1, cap); r2 = min(r2, cap);
    float2 offsetPix = corner.x * (kSigma * r1) * axis1 + corner.y * (kSigma * r2) * axis2;
    float4 clip = u.projection * vp;
    float2 ndcOffset = (offsetPix / u.viewport) * 2.0 * clip.w;
    clip.xy += ndcOffset;

    out.position = clip;
    out.offset = offsetPix;
    // Màu 3DGS là sRGB (như web). Attachment sRGB sẽ mã hoá lại khi ghi → giải về tuyến tính trước.
    out.color = u.gamma > 1.0 ? pow(max(col.rgb, 0.0), u.gamma) : col.rgb;
    out.opacity = col.a * aaFactor * u.opacity;
    out.conic = conic;
    return out;
}

fragment float4 gsplatFragment(GSplatVertexOut in [[ stage_in ]])
{
    float x = in.offset.x, y = in.offset.y;
    float power = -0.5 * (in.conic.x * x * x + in.conic.z * y * y) - in.conic.y * x * y;
    if (power > 0.0) { discard_fragment(); }
    float alpha = in.opacity * max(exp(power) - 0.01831564, 0.0) * 1.0186512;   // cắt ở 2√2σ (e⁻⁴), chuẩn hoá lại
    if (alpha < 1.0 / 255.0) { discard_fragment(); }
    return float4(in.color * alpha, alpha);             // premultiplied, blend ONE / ONE_MINUS_SRC_ALPHA
}
