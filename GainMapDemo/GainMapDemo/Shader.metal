//
//  SimpleShader.metal
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#include <metal_stdlib>
#include "ShaderCommon.h"
using namespace metal;

// Vertex data structure
struct VertexIn {
    float2 position;
    float2 texCoord;
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct Uniforms {
    float4x4 scalingMatrix;
};

float pqEOTF(float color) {                                                         
    float m1 = 0.1593017578125;                                                     
    float m2 = 78.84375;                                                            
    float c2 = 18.8515625;                                                          
    float c3 = 18.6875;                                                             
    float c1 = c3 - c2 + 1.0;                                                       
                                                                                    
    float denColor = max(pow(color, 1.0 / m2) - c1, 0.0);                           
    float moColor = c2 - c3 * pow(color, 1.0 / m2);                                 
                                                                                    
    float targetColor = pow(denColor / moColor, 1.0 / m1);                          
    targetColor = clamp(targetColor, 0.0, 1.0);                                     
                                                                                    
    return targetColor;
}

float hlgEOTF(float color) {
    float hlgA = 0.17883277;
    float hlgB = 1.0 - 4.0 * hlgA;
    float hlgC = 0.5 - hlgA * log(4.0 * hlgA);
    float sceneLightComponent = 0.0;
    if (color <= 0.5) {
        sceneLightComponent = pow(color, 2.0) / 3.0;
    } else {
        sceneLightComponent = (exp((color - hlgC) / hlgA) + hlgB) / 12.0;
    }
                                                                                    
    return clamp(sceneLightComponent, 0.0, 1.0) * 12.0;
}

// Vertex shader
vertex VertexOut basic_vertex(const device VertexIn* vertexArray [[ buffer(0) ]],
                              constant Uniforms& uniforms [[buffer(1)]],
                              unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = uniforms.scalingMatrix * float4(vertexArray[vid].position, 0.0, 1.0);
    out.texCoord = vertexArray[vid].texCoord;
    return out;
}

fragment half4 basic_fragment_two(VertexOut in [[stage_in]],
                              texture2d<half> texture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]],
                              constant FragUniforms& uniforms [[buffer(0)]]) {
    half4 color = texture.sample(textureSampler, in.texCoord);
    return color;
}

// Fragment shader
fragment half4 basic_fragment(VertexOut in [[stage_in]],
                              texture2d<half> texture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]],
                              constant FragUniforms& uniforms [[buffer(0)]]) {
    half4 color = texture.sample(textureSampler, in.texCoord);
    half outR = color.r;
    half outG = color.g;
    half outB = color.b;
    half outA = color.a;
    
    if (uniforms.metalMode == EDR) {
        if (uniforms.colorTrc == PQ) {
            outR = pqEOTF(color.r);
            outG = pqEOTF(color.g);
            outB = pqEOTF(color.b);
        } else if (uniforms.colorTrc == HLG) {
            outR = hlgEOTF(color.r);
            outG = hlgEOTF(color.g);
            outB = hlgEOTF(color.b);
        } else {
            outR = color.r;
            outG = color.g;
            outB = color.b;
        }
    } else {
        outR = color.r;
        outG = color.g;
        outB = color.b;
    }
    
    return half4(outR, outG, outB, outA);

}

fragment half4 gain_map_fragment(VertexOut in [[stage_in]],
                                 texture2d<half> texture [[texture(0)]],
                                 texture2d<half> auxTexture [[texture(1)]],
                                 sampler textureSampler [[sampler(0)]],
                                 constant FragUniforms& uniforms [[buffer(0)]]) {
    half4 color = texture.sample(textureSampler, in.texCoord);
    half4 color2 = auxTexture.sample(textureSampler, in.texCoord);
    
    half gamma = 2.2;
    half scale = 0.02;
    half headroom = uniforms.headroom;
    half outR = pow(color.r, gamma) * scale;
    half outG = pow(color.g, gamma) * scale;
    half outB = pow(color.b, gamma) * scale;
    half outA = color.a;
    
    half gmG = pow(color2.g, 2.2h);
    outR = outR * (1.0 + (headroom - 1.0) * gmG);
    outG = outG * (1.0 + (headroom - 1.0) * gmG);
    outB = outB * (1.0 + (headroom - 1.0) * gmG);
    
    return half4(outR, outG, outB, outA);
}
