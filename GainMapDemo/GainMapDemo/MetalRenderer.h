//
//  MetalRenderer.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/16.
//

#ifndef MetalRenderer_h
#define MetalRenderer_h

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/CAMetalLayer.h>

#include "Utils.h"

class MetalRenderer {
public:
    MetalRenderer(id<MTLDevice> device);
    ~MetalRenderer();
    void uploadCIImageToTexture(CIImage *image, MTLPixelFormat mtlPixFmt, NSUInteger width, NSUInteger height, id<MTLTexture>* outTexture);
    void uploadBufferToTexture(void* buffer, MTLPixelFormat mtlPixFmt, NSUInteger width, NSUInteger height, NSUInteger bytesPerRow, id<MTLTexture>* outTexture);
    void renderGainTextureToLayer(id<MTLTexture> texture, id<MTLTexture> gainTexture, FragUniforms fragUniformData, CAMetalLayer* layer);
    //void renderTextureToLayer(id<MTLTexture> texture, FragUniforms fragUniformData, CAMetalLayer* layer);
    void renderTextureToLayer(id<MTLTexture> texture, FragUniforms fragUniformData, MTKView *view, CAMetalLayer* layer);
    
    id<MTLDevice> getDevice() { return m_device; }
    
private:
    id<MTLDevice> m_device;
    id<MTLCommandQueue> m_commandQueue;
    id<MTLLibrary> m_defaultLibrary;
    id<MTLFunction> m_vertexFunction;
    id<MTLFunction> m_fragmentFunction;
    id<MTLFunction> m_gainFragmentFunction;
    id<MTLBuffer> m_vertexBuffer;
    id<MTLSamplerState> m_samplerState;
    
    void setupMetal();
    void setupPipeline();
    void calculateAspectRatio(const CGSize &srcSize, const CGSize &dstSize, float *scaleX, float *scaleY);
    
    static const float s_vertexData[];
};

#endif /* MetalRenderer_h */
