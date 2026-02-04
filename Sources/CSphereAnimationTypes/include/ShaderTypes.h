#ifndef ShaderTypes_h
#define ShaderTypes_h

#include <simd/simd.h>

// MARK: - Shared Structures (Swift + Metal)

// Vertex input structure
typedef struct {
    simd_float3 position;
    simd_float3 normal;
} VertexIn;

// Vertex shader uniforms
typedef struct {
    simd_float4x4 modelMatrix;
    simd_float4x4 viewProjectionMatrix;
    simd_float3 cameraPosition;
    simd_float2 spherePosition;
    float sphereScale;
} VertexUniforms;

// Fragment shader uniforms
typedef struct {
    simd_float3 colors[10];
    int colorCount;
    float time;
    simd_float3 lightPosition;
    float colorCycleDuration;
    float glowIntensity;
} FragmentUniforms;

// MARK: - Metal-only Structures

#ifdef __METAL_VERSION__

// Vertex output structure (passed to fragment shader)
// Contains Metal-specific attributes, not needed in Swift
struct VertexOut {
    simd_float4 position [[position]];
    simd_float3 worldPosition;
    simd_float3 worldNormal;
    simd_float3 viewDirection;
};

#endif /* __METAL_VERSION__ */

#endif /* ShaderTypes_h */
