#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

typedef struct {
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct {
    float4 position [[position]];
    float2 texCoord;
    float3 worldPos;
} ColorInOut;

// Hash function to generate pseudo-random values
float hash(float2 p) {
    p = fract(p * 0.6180339887);
    p *= 25.0;
    return fract(p.x * p.y * (p.x + p.y));
}

// Noise function for generating smooth random noise
float noise(float2 x) {
    float2 p = floor(x);
    float2 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(p + float2(0.0, 0.0));
    float b = hash(p + float2(1.0, 0.0));
    float c = hash(p + float2(0.0, 1.0));
    float d = hash(p + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion (FBM) with 4 octaves
float fbm4(float2 p) {
    float f = 0.0;
    float amplitude = 3.0;
    float2 mtx = float2(0.80, 0.60);

    for (int i = 0; i < 4; i++) {
        f += amplitude * (-1.0 + 2.0 * noise(p));
        p = float2(mtx.x, -mtx.y) * p * 2.02;
        amplitude *= 0.5;
    }
    return f / 0.9375;
}

// Fractal Brownian Motion (FBM) with 6 octaves
float fbm6(float2 p) {
    float f = 0.0;
    float amplitude = 0.5;
    float2 mtx = float2(0.80, 0.60);

    for (int i = 0; i < 6; i++) {
        f += amplitude * noise(p);
        p = float2(mtx.x, -mtx.y) * p * 2.02;
        amplitude *= 0.5;
    }
    return f / 0.96875;
}

// Composite FBM functions
float2 fbm4_2(float2 p) {
    return float2(fbm4(p + float2(1.0)), fbm4(p + float2(6.2)));
}

float2 fbm6_2(float2 p) {
    return float2(fbm6(p + float2(9.2)), fbm6(p + float2(5.7)));
}

// Main fluid function
float fluid_func(float2 q, thread float2 &o, thread float2 &n, float time) {
    q += 0.05 * sin(float2(0.11, 0.13) * time + length(q) * 4.0);
    q *= 0.7 + 0.2 * cos(0.05 * time);

    o = 0.5 + 0.5 * fbm4_2(q);
    o += 0.02 * sin(float2(0.13, 0.11) * time * length(o));

    n = fbm6_2(4.0 * o);

    float2 p = q + 2.0 * n + 1.0;
    float f = 0.5 + 0.5 * fbm4(2.0 * p);

    f = mix(f, f * f * f * 3.5, f * abs(n.x));
    f *= 1.0 - 0.5 * pow(0.5 + 0.5 * sin(8.0 * p.x) * sin(8.0 * p.y), 8.0);

    return f;
}

float calculateEdgeFade(float3 worldPos, float time) {
    // Bottom edge with liquid cut-ins
    float baseHeight = (worldPos.y + 1.0) * 0.5;
    float bottomFadeStart = 0.3;
    float bottomFadeWidth = 0.2;
    
    float2 noiseCoord = float2(worldPos.x + time * 0.1, worldPos.z + time * 0.1);
    float noiseValue = fbm4(noiseCoord * 2.0) * 0.15;
    
    float bottomFade = smoothstep(
        bottomFadeStart + noiseValue,
        bottomFadeStart + bottomFadeWidth + noiseValue,
        baseHeight
    );
    
    // Top fade out
    float3 normalizedPos = worldPos / 10.0;
    float distFromCenter = length(float2(normalizedPos.x, normalizedPos.z));
    float topFadeStart = 0.8;
    float topFadeWidth = 0.2;
    
    float topFade = smoothstep(
        topFadeStart,
        topFadeStart + topFadeWidth,
        distFromCenter
    );
    
    // Combine both effects
    // Using multiplication to ensure both fades are applied
    return bottomFade * (1.0 - topFade);
}

vertex ColorInOut vertexShader(Vertex in [[stage_in]],
                             ushort amp_id [[amplification_id]],
                             constant UniformsArray & uniformsArray [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    Uniforms uniforms = uniformsArray.uniforms[amp_id];
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord;
    out.worldPos = in.position;
    return out;
}

fragment half4 fragmentShader(ColorInOut in [[stage_in]],
                            constant UniformsArray & uniformsArray [[ buffer(BufferIndexUniforms) ]],
                            ushort amp_id [[amplification_id]])
{
    Uniforms uniforms = uniformsArray.uniforms[amp_id];
    float2 uv = in.texCoord * 2.0 - 1.0;
    uv *= 2.0;
    
    float2 o, n;
    float f = fluid_func(uv, o, n, uniforms.time);
    
    float3 col = mix(float3(0.2, 0.1, 0.4), float3(0.3, 0.05, 0.05), f);
    col = mix(col, float3(0.1, 0.9, 0.9), dot(n, n));
    col = mix(col, float3(0.5, 0.2, 0.2), 0.5 * o.y * o.y);
    col = mix(col, float3(0.0, 0.2, 0.4), 0.5 * smoothstep(1.2, 1.3, abs(n.y) + abs(n.x)));
    
    col *= f * 2.0;
    
    // Calculate and apply the fade
    float fadeAlpha = calculateEdgeFade(in.worldPos, uniforms.time);
    
    return half4(half3(col), half(fadeAlpha));
}
