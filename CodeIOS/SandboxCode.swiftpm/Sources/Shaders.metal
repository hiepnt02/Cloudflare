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
