//
//  Shaders.metal
//  Runner
//
//  Created by Pedro Tacla Yamada on 15/11/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} VertexInOut;

typedef struct
{
    float tick;
} Uniform;

vertex VertexInOut vertexShader(
  uint vertexID [[ vertex_id ]],
  const device VertexInOut* in [[buffer(0)]]
) {
  return in[vertexID];
}

fragment float4 fragmentShader(
  VertexInOut in [[stage_in]],
  const device Uniform& uniform [[buffer(1)]]
) {
  return {tan(uniform.tick * in.position.x), sin(uniform.tick), cos(uniform.tick), 1.0};
}
