//
//  ShaderTypes.h
//  Quick3D
//
//  Created by HaNST on 13/11/24.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

enum TextureIndices {
    kTextureY = 0,
    kTextureCbCr = 1,
    kTextureDepth = 2,
    kTextureConfidence = 3,
    kTextureImage = 4
};

enum BufferIndices {
    kPointCloudUniforms = 0,
    kParticleUniforms = 1,
    kGridPoints = 2,
    kGridDelta = 3,
    kGridSpacing = 4
};

struct RGBUniforms {
    matrix_float3x3 viewToCamera;
    float viewRatio;
    float radius;
};

struct PointCloudUniforms {
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 localToWorld;
    matrix_float3x3 cameraIntrinsicsInversed;
    simd_float2 cameraResolution;
};

struct ParticleUniforms {
    simd_float3 position;
    simd_float3 color;
    float confidence;
};

struct ArrayInfo {
    uint32_t index;
};

struct FrameConfiguration {
    matrix_float4x4 viewProjectionMatrix;
    matrix_float4x4 localToWorld;
    matrix_float3x3 cameraIntrinsicsInversed;
    simd_float2     cameraResolution;
    float           spacing;
    simd_int2       grid;
    int             count;
};

struct VertexOut {
    simd_float4 position [[position]];
    simd_float2 texCoord;
};

#endif /* ShaderTypes_h */
