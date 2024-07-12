//
//  RenderCommon.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/28.
//

#ifndef RenderCommon_h
#define RenderCommon_h

#include "ShaderCommon.h"
#include "Utils.h"

typedef enum { sdr, gainmap, hdr, hdrc } GainMapMode;

struct RenderConfig {
    GainMapMode gainMapMode;
    MetalRenderMode metalMode;
};



#endif /* RenderCommon_h */
