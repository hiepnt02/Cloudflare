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
#include <SceneKit/scn_metal>
using namespace metal;

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
