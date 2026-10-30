//
//  GaussianSplat.metal
//  Quick3D
//
//  3D Gaussian splats (.gsx) drawn by GaussianSplatRenderer inside SceneKit's render pass.
//  Port of the web engine's splat.vert/splat.frag (EWA projection, vmin clamp, AA
//  compensation). The pipeline tests depth against the scene's depth buffer, so the point
//  cloud, the IFC model and the occlusion mesh hide the splats behind them.
//
//  gsxProject (compute) projects the draw list once per frame; gsxVertex expands each result
//  into a quad. Kernel bindings: buffer(0) splats, (1) sorted order, (2) projected, (3)
//  GsxUniforms, (4) count. Vertex: buffer(1) projected, buffer(3) GsxUniforms.
//

#include <metal_stdlib>
using namespace metal;

// Must match GsxDecoder.splatStride (40 bytes).
struct GsxSplat {
    packed_float3 position;   // data space
    uint color;               // RGBA8: sRGB colour, alpha = opacity
    packed_float3 covA;       // Σ00 Σ01 Σ02 (data space)
    packed_float3 covB;       // Σ11 Σ12 Σ22
};

// Must match GsxUniforms in GaussianSplatRenderer.swift.
struct GsxUniforms {
    float4x4 viewModel;       // data → view
    float4x4 proj;            // scene projection
    float2 viewport;          // render target size in pixels
    float2 focal;             // fx, fy in pixels
    uint srgbTarget;          // 1: target encodes sRGB on write, so output linear colour
    float4 limits;            // x: near cull distance (m), y: max splat radius as a fraction of vmin
};

// Kept small: a tile-based GPU writes every vertex's varyings to memory and reads them back
// to shade, and with millions of quads that traffic, not the shading, sets the frame time.
struct GsxVaryings {
    float4 position [[position]];
    half2 uv;                 // position in the quad in standard deviations (±kSigma at its edges)
    half4 color;              // rgb, a = opacity
};

// One splat projected to the screen by gsxProject, in draw order (48 bytes with padding).
struct GsxProjected {
    float4 clip;              // clip-space centre; w == 0 for a culled splat
    half4 axes;               // quad half-axes in pixels: xy first, zw second
    half4 color;              // rgb (linear when the target is sRGB), a = opacity
    half kSigma;              // standard deviations from the centre to the quad's edge
};

static inline float3 gsxSrgbToLinear(float3 c)
{
    return select(pow((c + 0.055) / 1.055, 2.4), c / 12.92, c <= 0.04045);
}

static inline GsxProjected gsxCulledProjection()
{
    GsxProjected p;
    p.clip = float4(0.0);
    p.axes = half4(0.0h);
    p.color = half4(0.0h);
    p.kSigma = 0.0h;
    return p;
}

// EWA projection of one splat.
static inline GsxProjected gsxProjectSplat(GsxSplat s, constant GsxUniforms& u)
{
    float4 vp = u.viewModel * float4(float3(s.position), 1.0);
    // Behind or right at the camera (view space looks down -Z): splats the camera is inside
    // would cover the whole screen.
    if (vp.z >= -u.limits.x) return gsxCulledProjection();

    float3 a3 = float3(s.covA);
    float3 b3 = float3(s.covB);
    float3x3 sigma = float3x3(float3(a3.x, a3.y, a3.z),
                              float3(a3.y, b3.x, b3.y),
                              float3(a3.z, b3.y, b3.z));
    float3x3 W = float3x3(u.viewModel[0].xyz, u.viewModel[1].xyz, u.viewModel[2].xyz);
    float3x3 T = W * sigma * transpose(W);

    // EWA Jacobian (camera → pixels).
    float zinv = 1.0 / vp.z;
    float zinv2 = zinv * zinv;
    float3x3 J = float3x3(float3(u.focal.x * zinv, 0.0, 0.0),
                          float3(0.0, u.focal.y * zinv, 0.0),
                          float3(-u.focal.x * vp.x * zinv2, -u.focal.y * vp.y * zinv2, 0.0));
    float3x3 cov2 = J * T * transpose(J);

    // Anti-aliasing low-pass + energy compensation (PlayCanvas GSPLAT_AA).
    const float aaFloor = 0.3;
    float detOrig = cov2[0][0] * cov2[1][1] - cov2[0][1] * cov2[0][1];
    float a = cov2[0][0] + aaFloor;
    float b = cov2[0][1];
    float c = cov2[1][1] + aaFloor;
    float det = a * c - b * b;
    if (det <= 0.0) return gsxCulledProjection();
    float aaFactor = sqrt(max(detOrig / det, 0.0));

    float mid = 0.5 * (a + c);
    float disc = sqrt(max(0.1, mid * mid - det));
    float lam1 = mid + disc;
    float lam2 = max(mid - disc, 0.1);
    float r1 = sqrt(lam1);
    float r2 = sqrt(lam2);
    float2 axisRaw = float2(b, lam1 - a);
    float2 axis1 = length(axisRaw) < 1e-6 ? float2(1.0, 0.0) : normalize(axisRaw);
    float2 axis2 = float2(-axis1.y, axis1.x);

    // Quad extent: where opacity·(exp(-d²/2) − e⁻⁴)·1.0187 drops below 1/255, so faint
    // splats get smaller quads (2.83σ for opaque ones) and invisible ones none at all.
    float4 rgba = unpack_unorm4x8_to_float(s.color);
    float opacity = rgba.a * aaFactor;
    float cutoff = 1.0 / (255.0 * 1.0186512 * opacity) + 0.01831564;
    if (cutoff >= 1.0) return gsxCulledProjection();
    float kSigma = sqrt(-2.0 * log(cutoff));
    // Clamp oversized splats instead of discarding them; the Gaussian shrinks with the quad, as
    // it is evaluated in the quad's own coordinates (matches PlayCanvas).
    float vmin = min(1024.0, min(u.viewport.x, u.viewport.y)) * u.limits.y;
    float cap = vmin / kSigma;
    r1 = min(r1, cap);
    r2 = min(r2, cap);

    GsxProjected p;
    p.clip = u.proj * vp;
    p.axes = half4(half2(kSigma * r1 * axis1), half2(kSigma * r2 * axis2));
    p.color = half4(half3(u.srgbTarget != 0 ? gsxSrgbToLinear(rgba.rgb) : rgba.rgb), half(opacity));
    p.kSigma = half(kSigma);
    return p;
}

// Projects every splat of the draw list once (instead of once per quad corner), so the vertex
// shader only reads the results, in order.
kernel void gsxProject(const device GsxSplat* splats [[buffer(0)]],
                       const device uint* order [[buffer(1)]],
                       device GsxProjected* projected [[buffer(2)]],
                       constant GsxUniforms& u [[buffer(3)]],
                       constant uint& count [[buffer(4)]],
                       uint i [[thread_position_in_grid]])
{
    if (i >= count) return;
    projected[i] = gsxProjectSplat(splats[order[i]], u);
}

static inline GsxVaryings gsxCulled()
{
    GsxVaryings out;
    out.position = float4(0.0, 0.0, -2.0, 1.0);
    out.uv = half2(0.0h);
    out.color = half4(0.0h);
    return out;
}

vertex GsxVaryings gsxVertex(uint vid [[vertex_id]],
                             uint iid [[instance_id]],
                             const device GsxProjected* projected [[buffer(1)]],
                             constant GsxUniforms& u [[buffer(3)]])
{
    const float2 corners[4] = { float2(-1, -1), float2(1, -1), float2(-1, 1), float2(1, 1) };
    GsxProjected p = projected[iid];
    if (p.clip.w == 0.0) return gsxCulled();
    float2 corner = corners[vid];
    float2 offsetPix = corner.x * float2(p.axes.xy) + corner.y * float2(p.axes.zw);

    GsxVaryings out;
    out.position = p.clip;
    out.position.xy += (offsetPix / u.viewport) * 2.0 * p.clip.w;
    out.uv = half2(corner) * p.kSigma;
    out.color = p.color;
    return out;
}

// opacity·(exp(-d²/2) − e⁻⁴)·1.0187, d in standard deviations: 0 at the quad's edge.
static inline float gsxAlpha(GsxVaryings in)
{
    float d2 = dot(float2(in.uv), float2(in.uv));
    return float(in.color.a) * max(exp(-0.5 * d2) - 0.01831564, 0.0) * 1.0186512;
}

// Straight into SceneKit's pass: back-to-front, premultiplied.
fragment float4 gsxFragment(GsxVaryings in [[stage_in]])
{
    float alpha = gsxAlpha(in);
    if (alpha < 1.0 / 255.0) discard_fragment();
    return float4(float3(in.color.rgb) * alpha, alpha);
}
