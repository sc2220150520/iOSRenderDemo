//
//  ShaderCommon.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/21.
//

#ifndef ShaderCommon_h
#define ShaderCommon_h

typedef enum { sRGB, PQ, HLG } ColorTrc;
typedef enum { sysTrc, EDR } MetalRenderMode;

struct FragUniforms {
    ColorTrc colorTrc;
    MetalRenderMode metalMode;
    float headroom;
};


#endif /* ShaderCommon_h */
