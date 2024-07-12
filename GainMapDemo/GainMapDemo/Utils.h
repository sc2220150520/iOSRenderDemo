//
//  Utils.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#ifndef Utils_h
#define Utils_h

#include <stdio.h>
#include "ShaderCommon.h"

#define Nlog(fmt, ...) NLogImpl(__FILE__, __LINE__, fmt, ##__VA_ARGS__)

#ifdef __cplusplus
extern "C" {
#endif

void NLogImpl(const char* file, int line, const char* fmt, ...);

#ifdef __cplusplus
};
#endif

#endif /* Utils_h */
