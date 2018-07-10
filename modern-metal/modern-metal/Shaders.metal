
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position  [[attribute(0)]];
    float3 normal    [[attribute(1)]];
    float2 texCoords [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 eyeNormal;
    float4 eyePosition;
    float2 texCoords;
};

struct Uniforms {
    float4x4 modelViewMatrix;
    float4x4 projectionMatrix;
};

vertex VertexOut vertex_main(VertexIn vertexIn [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]])
{
    VertexOut vertexOut;
    vertexOut.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * float4(vertexIn.position, 1);
    vertexOut.eyeNormal = uniforms.modelViewMatrix * float4(vertexIn.normal, 0);
    vertexOut.eyePosition = uniforms.modelViewMatrix * float4(vertexIn.position, 1);
    vertexOut.texCoords = vertexIn.texCoords;
    return vertexOut;
}

fragment float4 fragment_main(VertexOut fragmentIn [[stage_in]]) {
    return float4(1, 0, 0, 1);
}
