#include <metal_stdlib>
#include "ShaderTypes.h"

using namespace metal;

// Vertex shader - transforms sphere vertices and prepares data for fragment shader
vertex VertexOut sphereVertexShader(const device VertexIn* vertices [[buffer(0)]],
                                     constant VertexUniforms& uniforms [[buffer(1)]],
                                     uint vid [[vertex_id]])
{
    VertexOut out;

    VertexIn in = vertices[vid];

    // Transform vertex position to world space
    float4 worldPosition = uniforms.modelMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPosition.xyz;

    // Transform to clip space
    out.position = uniforms.viewProjectionMatrix * worldPosition;

    // Transform normal to world space (assumes uniform scaling)
    out.worldNormal = normalize((uniforms.modelMatrix * float4(in.normal, 0.0)).xyz);

    // Calculate view direction
    out.viewDirection = normalize(uniforms.cameraPosition - worldPosition.xyz);

    return out;
}

// Helper function for smooth color interpolation
float smootherstep(float edge0, float edge1, float x) {
    float t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// Fragment shader - implements Phong lighting and color interpolation
fragment float4 sphereFragmentShader(VertexOut in [[stage_in]],
                                      constant FragmentUniforms& uniforms [[buffer(0)]])
{
    // Normalize interpolated normal
    float3 N = normalize(in.worldNormal);

    // Light direction (from fragment to light)
    float3 L = normalize(uniforms.lightPosition - in.worldPosition);

    // View direction (already normalized from vertex shader)
    float3 V = in.viewDirection;

    // Reflection vector for specular
    float3 R = reflect(-L, N);

    // === Color Interpolation ===
    // Calculate which colors to interpolate between based on time
    float cycleTime = fmod(uniforms.time, uniforms.colorCycleDuration);
    float segmentDuration = uniforms.colorCycleDuration / float(uniforms.colorCount);

    int currentIdx = int(cycleTime / segmentDuration) % uniforms.colorCount;
    int nextIdx = (currentIdx + 1) % uniforms.colorCount;

    // Calculate interpolation factor with smooth easing
    float t = fmod(cycleTime, segmentDuration) / segmentDuration;
    t = smootherstep(0.0, 1.0, t);

    // Interpolate between current and next color
    float3 baseColor = mix(uniforms.colors[currentIdx], uniforms.colors[nextIdx], t);

    // === Phong Lighting Model ===

    // Ambient component
    float ambientStrength = 0.3;
    float3 ambient = ambientStrength * baseColor;

    // Diffuse component
    float diff = max(dot(N, L), 0.0);
    float3 diffuse = diff * baseColor;

    // Specular component
    float specularStrength = 0.6;
    float shininess = 32.0;
    float spec = pow(max(dot(R, V), 0.0), shininess);
    float3 specular = specularStrength * spec * float3(1.0, 1.0, 1.0);  // White specular highlights

    // Combine all components
    float3 finalColor = ambient + diffuse + specular;

    // Enhanced rim lighting based on glow intensity
    float rim = 1.0 - max(dot(N, V), 0.0);
    rim = smoothstep(0.0, 1.0, rim);
    finalColor += rim * uniforms.glowIntensity * 0.3 * baseColor;

    // Emission effect for high glow values (adds brightness to the whole sphere)
    if (uniforms.glowIntensity > 1.0) {
        float emissionStrength = (uniforms.glowIntensity - 1.0) * 0.2;
        finalColor += baseColor * emissionStrength;
    }

    return float4(finalColor, 1.0);
}
