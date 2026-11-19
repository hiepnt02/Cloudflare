//
//  Shaders.metal
//  Quick3D
//
//  Created by HaNST on 13/11/24.
//

#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"
using namespace metal;
#include <SceneKit/scn_metal>

constexpr sampler colorSampler(mip_filter::linear, mag_filter::linear, min_filter::linear);

constant auto yCbCrToRGB = float4x4(float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
                                    float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
                                    float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
                                    float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f));


static simd_float4 worldPoint(simd_float2 cameraPoint, float depth, matrix_float3x3 cameraIntrinsicsInversed, matrix_float4x4 localToWorld) {
    const auto localPoint = cameraIntrinsicsInversed * simd_float3(cameraPoint, 1) * depth;
    const auto worldPoint = localToWorld * simd_float4(localPoint, 1);
    
    return worldPoint / worldPoint.w;
}

static float2 calculateGridPoint(uint id, FrameConfiguration configuration) {
    const uint deltaX = uint(configuration.grid.x);
    const uint spacing = uint(configuration.spacing);
    const uint gridX = id % deltaX;
    const uint gridY = id / deltaX;

    const float alternatingOffsetX = float(gridY & 1u) * (spacing * 0.5);
    const float x = alternatingOffsetX + (float(gridX) + 0.5) * spacing;
    const float y = (float(gridY) + 0.5) * spacing;
    return float2(x, y);
}

static void detectVertex(uint id,
                         uint numElements,
                         FrameConfiguration configuration,
                         device float3 *tempPositionsBuffer,
                         device float3 *tempColorsBuffer,
                         device float  *tempConfidenceBuffer,
                         texture2d<float, access::sample> capturedImageTextureY,
                         texture2d<float, access::sample> capturedImageTextureCbCr,
                         texture2d<float, access::sample> depthTexture,
                         texture2d<unsigned int, access::sample> confidenceTexture) {
    
    if (id >= numElements) {
        tempConfidenceBuffer[id] = 0;
        return;
    }
    
    const float2 gridPoint = calculateGridPoint(id, configuration);
    
    const auto texCoord = gridPoint / configuration.cameraResolution;
    const auto depth = depthTexture.sample(colorSampler, texCoord).r;
    
    if (depth > 4) {
        tempConfidenceBuffer[id] = 0;
        return;
    }
    
    const auto position = worldPoint(gridPoint, depth, configuration.cameraIntrinsicsInversed, configuration.localToWorld);
    
    float y = capturedImageTextureY.sample(colorSampler, texCoord).r;
    float2 cbcr = capturedImageTextureCbCr.sample(colorSampler, texCoord).rg;
    const auto ycbcr = float4(y, cbcr, 1);
    const auto sampledColor = (yCbCrToRGB * ycbcr).rgb;
    const auto confidence = confidenceTexture.sample(colorSampler, texCoord).r;
    
    tempPositionsBuffer[id] = position.xyz;
    tempColorsBuffer[id] = sampledColor;
    tempConfidenceBuffer[id] = confidence;
}

static void prefixSum(uint id,
                      uint tid,
                      uint gid,
                      uint threadgroup_size,
                      uint numElements,
                      FrameConfiguration configuration,
                      device float3 *tempPositionsBuffer,
                      device float3 *tempColorsBuffer,
                      device float  *tempConfidenceBuffer,
                      device uint *threadsIndexBuffer,
                      device uint *threadgroupsIndexBuffer,
                      threadgroup uint *sharedData) {
    
    // ---- PREFIX SUM ----
    if (id >= numElements || tempConfidenceBuffer[id] < 1) {
        sharedData[tid] = 0;
    } else {
        sharedData[tid] = 1;
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // ---- PHASE 1: UPSWEEP ----
    for (uint offset = 1; offset < threadgroup_size; offset <<= 1) {
        uint i = (tid + 1) * offset * 2 - 1;
        if (i < threadgroup_size)
            sharedData[i] += sharedData[i - offset];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // ---- PHASE 2: DOWNSWEEP ----
    if (tid == threadgroup_size - 1) sharedData[threadgroup_size - 1] = 0;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint offset = threadgroup_size >> 1; offset > 0; offset >>= 1) {
        uint i = (tid + 1) * offset * 2 - 1;
        if (i < threadgroup_size) {
            uint t = sharedData[i - offset];
            sharedData[i - offset] = sharedData[i];
            sharedData[i] += t;
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    threadsIndexBuffer[id] = sharedData[tid];
    if (tid == threadgroup_size - 1) {
        if (tempConfidenceBuffer[id] >= 1) {
            threadgroupsIndexBuffer[gid] = sharedData[tid] + 1;
        } else {
            threadgroupsIndexBuffer[gid] = sharedData[tid];
        }
    }
    
}

kernel void unprojectVertexWithoutPrefixSum(uint id                                     [[ thread_position_in_grid ]],
                                            uint tid                                    [[ thread_position_in_threadgroup ]],
                                            uint gid                                    [[ threadgroup_position_in_grid ]],
                                            uint threadgroup_size                       [[ threads_per_threadgroup]],
                                            uint threadgroup_count                      [[ threadgroups_per_grid ]],
                                            uint thread_count                           [[ threads_per_grid ]],
                                            constant uint &numElements                  [[ buffer(0) ]],
                                            constant FrameConfiguration &configuration  [[ buffer(1) ]],
                                            device float3 *tempPositionsBuffer          [[ buffer(2) ]],
                                            device float3 *tempColorsBuffer             [[ buffer(3) ]],
                                            device float  *tempConfidenceBuffer         [[ buffer(4) ]],
                                            texture2d<float, access::sample> capturedImageTextureY      [[texture(0)]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr   [[texture(1)]],
                                            texture2d<float, access::sample> depthTexture               [[texture(2)]],
                                            texture2d<unsigned int, access::sample> confidenceTexture   [[texture(3)]]) {
    detectVertex(id, numElements, configuration, tempPositionsBuffer, tempColorsBuffer, tempConfidenceBuffer, capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture);
}

kernel void unprojectVertex(uint id                                     [[ thread_position_in_grid ]],
                            uint tid                                    [[ thread_position_in_threadgroup ]],
                            uint gid                                    [[ threadgroup_position_in_grid ]],
                            uint threadgroup_size                       [[ threads_per_threadgroup]],
                            uint threadgroup_count                      [[ threadgroups_per_grid ]],
                            uint thread_count                           [[ threads_per_grid ]],
                            constant uint &numElements                  [[ buffer(0) ]],
                            constant FrameConfiguration &configuration  [[ buffer(1) ]],
                            device uint *threadsIndexBuffer             [[ buffer(2) ]],
                            device uint *threadgroupsIndexBuffer        [[ buffer(3) ]],
                            device float3 *tempPositionsBuffer          [[ buffer(4) ]],
                            device float3 *tempColorsBuffer             [[ buffer(5) ]],
                            device float  *tempConfidenceBuffer         [[ buffer(6) ]],
                            texture2d<float, access::sample> capturedImageTextureY      [[texture(0)]],
                            texture2d<float, access::sample> capturedImageTextureCbCr   [[texture(1)]],
                            texture2d<float, access::sample> depthTexture               [[texture(2)]],
                            texture2d<unsigned int, access::sample> confidenceTexture   [[texture(3)]],
                            threadgroup uint *sharedData                [[ threadgroup(0) ]]) {
    detectVertex(id, numElements, configuration, tempPositionsBuffer, tempColorsBuffer, tempConfidenceBuffer, capturedImageTextureY, capturedImageTextureCbCr, depthTexture, confidenceTexture);
    prefixSum(id, tid, gid, threadgroup_size, numElements, configuration, tempPositionsBuffer, tempColorsBuffer, tempConfidenceBuffer, threadsIndexBuffer, threadgroupsIndexBuffer, sharedData);
}

kernel void merge(
    uint id                             [[ thread_position_in_grid ]],
    uint tid                            [[ thread_position_in_threadgroup ]],
    uint gid                            [[ threadgroup_position_in_grid ]],
    uint threadgroup_size               [[ threads_per_threadgroup]],
    uint threadgroup_count              [[ threadgroups_per_grid ]],
    uint thread_count                   [[ threads_per_grid ]],
    constant uint &numElements                    [[ buffer(0) ]],
    constant uint *threadsIndexBuffer             [[ buffer(1) ]],
    constant uint *threadgroupsIndexBuffer        [[ buffer(2) ]],
    constant float3 *tempPositionsBuffer          [[ buffer(3) ]],
    constant float3 *tempColorsBuffer             [[ buffer(4) ]],
    constant float  *tempConfidenceBuffer         [[ buffer(5) ]],
    device ArrayInfo &infoBuffer                  [[ buffer(6) ]],
    device float3 *positionsBuffer                [[ buffer(7) ]],
    device float3 *colorsBuffer                   [[ buffer(8) ]],
    device uint *indicesBuffer                    [[ buffer(9) ]]
)
{
    if (id >= numElements) {
        return;
    }
    
    uint currentIndex = infoBuffer.index;
    
    for (uint i = 0; i < gid; i++) {
        currentIndex = currentIndex + threadgroupsIndexBuffer[i];
    }
    
    if (tempConfidenceBuffer[id] >= 1) {
        uint index = currentIndex + threadsIndexBuffer[id];
        positionsBuffer[index] = tempPositionsBuffer[id];
        colorsBuffer[index] = tempColorsBuffer[id];
        indicesBuffer[index] = index;
    }
    
    if (id == numElements - 1) {
        uint index = 0;
        for (uint i = 0; i < threadgroup_count; i++) {
            index = index + threadgroupsIndexBuffer[i];
        }
        infoBuffer.index += index;
    }
    
}

kernel void fillIndices(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device uint *indicesBuffer          [[ buffer(1) ]]
) {
    if (id >= numElements) {
        return;
    }
    indicesBuffer[id] = id;
}

kernel void fillValue(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device uint *indicesBuffer          [[ buffer(1) ]],
    constant uint &value                [[ buffer(2) ]]
) {
    if (id >= numElements) {
        return;
    }
    indicesBuffer[id] = value;
}

kernel void fillSubValue
(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device uint *indicesBuffer          [[ buffer(1) ]],
    constant uint &offset               [[ buffer(2) ]],
    constant uint &value                [[ buffer(3) ]]
) {
    if (id >= numElements) {
        return;
    }
    const uint index = offset + id;
    indicesBuffer[index] = value;
}


fragment float4 ycbcrToRGBFragment(VertexOut in [[stage_in]],
                                   texture2d<float, access::sample> yTexture    [[texture(0)]],
                                   texture2d<float, access::sample> cbcrTexture [[texture(1)]]) {
    float y = yTexture.sample(colorSampler, in.texCoord).r;
    float2 cbcr = cbcrTexture.sample(colorSampler, in.texCoord).rg;
    const auto ycbcr = float4(y, cbcr, 1);
    const auto sampledColor = (yCbCrToRGB * ycbcr).rgb;
    return float4(sampledColor, 1.0);
}

vertex VertexOut vertexPassthrough(uint vid [[vertex_id]]) {
    float2 pos[4] = { {-1.0, -1.0}, {1.0, -1.0}, {-1.0, 1.0}, {1.0, 1.0} };
    float2 uv[4]  = { {0.0, 1.0}, {1.0, 1.0}, {0.0, 0.0}, {1.0, 0.0} };
    VertexOut out;
    out.position = float4(pos[vid], 0.0, 1.0);
    out.texCoord = uv[vid];
    return out;
}

typedef struct {
    float3 position [[ attribute(SCNVertexSemanticPosition) ]];
    float3 color    [[ attribute(SCNVertexSemanticColor) ]];
} PointVertexIn;

typedef struct {
    float4 position [[position]];
    float3 color;
    float pointSize [[point_size]];
    float clip [[clip_distance]];
} PointVertexOut;

vertex PointVertexOut pointVertex
(
    uint vid [[vertex_id]],
    PointVertexIn in [[stage_in]],
    constant SCNSceneBuffer& scn_frame  [[ buffer(0) ]],
    constant uint& pointCount           [[ buffer(1) ]],
    constant float& pointSize           [[ buffer(2) ]]
 ) {
    
    PointVertexOut out;
    
    if (vid >= pointCount) {
        out.clip = -1.0;
        return out;
    }
    
    float4 worldPos = float4(in.position, 1.0);
    out.position = scn_frame.viewProjectionTransform * worldPos;
    out.pointSize = pointSize;
    out.color = in.color;
    out.clip = 1.0;
    
    return out;
}

fragment float4 pointFragment(PointVertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
    float2 coord = pointCoord - 0.5;
    float r = length(coord);
    if (r > 0.5) {
        discard_fragment();
    }
    return float4(in.color.rgb, 1.0);
}

kernel void appendMeshVertices(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device packed_float3 *sourceBuffer  [[ buffer(1) ]],
    constant uint &destinationCount     [[ buffer(2) ]],
    device float3 *destinationBuffer    [[ buffer(3) ]],
    constant float4x4 &modelMatrix      [[ buffer(4) ]]
) {
    if (id >= numElements) {
        return;
    }
    
    const uint index = destinationCount + id;
    
    const auto sourceVertex = sourceBuffer[id];
    
    const float4 localVertex = float4(sourceVertex.x, sourceVertex.y, sourceVertex.z, 1.0);
    
    const float4 worldVertex = modelMatrix * localVertex;
    
    destinationBuffer[index] = worldVertex.xyz;
}

kernel void appendMeshFaces(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device uint *sourceBuffer           [[ buffer(1) ]],
    constant uint &destinationCount     [[ buffer(2) ]],
    device uint *destinationBuffer      [[ buffer(3) ]],
    constant uint &baseIndex            [[ buffer(4) ]]
) {
    if (id >= numElements) {
        return;
    }
    
    const uint index = destinationCount + id;
    
    destinationBuffer[index] = baseIndex + sourceBuffer[id];
}

kernel void fillColorAlpha
(
    uint id                             [[ thread_position_in_grid ]],
    constant uint &numElements          [[ buffer(0) ]],
    device float4 *colorsBuffer         [[ buffer(1) ]],
    constant float &alpha               [[ buffer(2) ]]
) {
    if (id >= numElements) {
        return;
    }
    const float4 color = float4(colorsBuffer[id].xyz, alpha);
    colorsBuffer[id] = color;
}

typedef struct {
    float4 position [[position]];
    float3 color;
    float pointSize [[point_size]];
    float opacity;
    float belowGroundFactor; // 1 = trên mặt sàn, giữ nguyên alpha; belowGroundAlphaScale = dưới sàn
} ARPointVertexOut;

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
} SCNNode;

vertex ARPointVertexOut arPointVertex
(
    uint vid [[vertex_id]],
    PointVertexIn in [[stage_in]],
    constant SCNSceneBuffer& scn_frame        [[ buffer(0) ]],
    constant SCNNode& scn_node                [[ buffer(1) ]],
    constant float& baseSize                  [[ buffer(2) ]],
    constant float& opacity                   [[ buffer(3) ]],
    constant float& groundPlaneY              [[ buffer(4) ]],
    constant float& hasGroundPlane            [[ buffer(5) ]],
    constant float& belowGroundAlphaScale     [[ buffer(6) ]],
    constant float& belowGroundTransitionBand [[ buffer(7) ]]
 ) {

    ARPointVertexOut out;

    float4 worldPos = scn_node.modelTransform * float4(in.position, 1.0);
    float3 cameraPos = scn_frame.inverseViewTransform[3].xyz;

    float dist = length(worldPos.xyz - cameraPos);
    float size = clamp(2.0 * baseSize / dist, 1.0, baseSize);

    out.position = scn_frame.viewProjectionTransform * worldPos;
    out.pointSize = size;
    out.color = in.color;
    out.opacity = opacity;

    // delta > 0: ở trên/ngang mặt sàn. delta < 0: nằm dưới mặt sàn.
    // smoothstep tạo dải chuyển tiếp mềm quanh mặt sàn thay vì cắt cứng, để
    // điểm không giật hình khi ARKit rung nhẹ ước lượng plane giữa các frame.
    //
    // Đúng công thức của BelowGroundFade (model design USDZ/IFC) và đọc chung
    // hai hằng số với nó, nên point cloud và model nhạt bằng nhau ở cùng độ sâu.
    float delta = worldPos.y - groundPlaneY;
    float aboveness = smoothstep(-belowGroundTransitionBand, 0.0, delta);
    float factor = mix(belowGroundAlphaScale, 1.0, aboveness);
    out.belowGroundFactor = mix(1.0, factor, hasGroundPlane);

    return out;
}

fragment float4 arPointFragment(ARPointVertexOut in [[stage_in]], float2 pointCoord [[point_coord]]) {
//    float2 coord = pointCoord - 0.5;
//    float r = length(coord);
//    if (r > 0.5) {
//        discard_fragment();
//    }
    // Màu trả về là premultiplied, nên nhân cả RGBA cho cùng một hệ số chính
    // là giảm alpha đúng nghĩa — giống cách BelowGroundFade làm với material
    // của model design. Cần MetalViewARProgram.isOpaque = false, không thì
    // SceneKit bỏ qua alpha này và phần dưới sàn chỉ tối đi chứ không mờ.
    float alpha = in.opacity * in.belowGroundFactor;
    return float4(in.color * alpha, alpha);
}

kernel void copyPointCloud(
   uint id                                       [[ thread_position_in_grid ]],
   uint tid                                      [[ thread_position_in_threadgroup ]],
   uint gid                                      [[ threadgroup_position_in_grid ]],
   uint threadgroup_size                         [[ threads_per_threadgroup]],
   uint threadgroup_count                        [[ threadgroups_per_grid ]],
   uint thread_count                             [[ threads_per_grid ]],
   constant uint &numElements                    [[ buffer(0) ]],
   constant float3 *sourcePositionsBuffer        [[ buffer(1) ]],
   constant float3 *sourceColorsBuffer           [[ buffer(2) ]],
   constant ArrayInfo &sourceInfoBuffer          [[ buffer(3) ]],
   constant uint &destinationCount               [[ buffer(4) ]],
   device float3 *destinationPositionsBuffer     [[ buffer(5) ]],
   device float3 *destinationColorsBuffer        [[ buffer(6) ]],
   device ArrayInfo &destinationInfoBuffer       [[ buffer(7) ]]) {
 
    if (id >= numElements || sourceInfoBuffer.index == 0) {
        return;
    }
    
    const uint index = destinationCount + id;
    
    destinationPositionsBuffer[index] = sourcePositionsBuffer[id];
    destinationColorsBuffer[index] = sourceColorsBuffer[id];
 
    if (id == numElements - 1) {
        destinationInfoBuffer.index += sourceInfoBuffer.index;
    }
}
