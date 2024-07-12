//
//  MetalRenderer.mm
//  GainMapDemo
//
//  Created by Chang on 2024/2/16.
//

#import "MetalRenderer.h"
#import <simd/simd.h>

const float MetalRenderer::s_vertexData[] = {
   // Positions  // Texture Coordinates
   -1.0f, -1.0f,  0.0f, 1.0f,
    1.0f, -1.0f,  1.0f, 1.0f,
   -1.0f,  1.0f,  0.0f, 0.0f,
    1.0f,  1.0f,  1.0f, 0.0f,
};

MetalRenderer::MetalRenderer(id<MTLDevice> device) {
    m_device = device;
    setupMetal();
    setupPipeline();
}

MetalRenderer::~MetalRenderer() {
    // Cleanup Metal objects if needed
}

void MetalRenderer::setupMetal() {
    m_commandQueue = [m_device newCommandQueue];
    m_defaultLibrary = [m_device newDefaultLibrary];
}

void MetalRenderer::setupPipeline() {
    m_vertexFunction = [m_defaultLibrary newFunctionWithName:@"basic_vertex"];
    //m_fragmentFunction = [m_defaultLibrary newFunctionWithName:@"basic_fragment"];
    m_fragmentFunction = [m_defaultLibrary newFunctionWithName:@"basic_fragment_two"];
    m_gainFragmentFunction = [m_defaultLibrary newFunctionWithName:@"gain_map_fragment"];
    m_vertexBuffer = [m_device newBufferWithBytes:s_vertexData length:sizeof(s_vertexData) options:MTLResourceStorageModeShared];
    
    MTLSamplerDescriptor *samplerDescriptor = [[MTLSamplerDescriptor alloc] init];
    samplerDescriptor.minFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.magFilter = MTLSamplerMinMagFilterNearest;
    samplerDescriptor.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDescriptor.tAddressMode = MTLSamplerAddressModeRepeat;
    m_samplerState = [m_device newSamplerStateWithDescriptor:samplerDescriptor];
}

void MetalRenderer::uploadCIImageToTexture(CIImage *image, MTLPixelFormat mtlPixFmt, NSUInteger width, NSUInteger height, id<MTLTexture>* outTexture) {
    // Create a CIContext with Metal device
    CIContext *context = [CIContext contextWithMTLDevice:m_device];

    // Prepare the texture descriptor
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlPixFmt width:width height:height mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    textureDescriptor.storageMode = MTLStorageModePrivate;
    *outTexture = [m_device newTextureWithDescriptor:textureDescriptor];

    // Render CIImage to MTLTexture
    [context render:image toMTLTexture:*outTexture commandBuffer:nil bounds:image.extent colorSpace:[image colorSpace]];
}

void MetalRenderer::uploadBufferToTexture(void* buffer, MTLPixelFormat mtlPixFmt, NSUInteger width, NSUInteger height, NSUInteger bytesPerRow, id<MTLTexture>* outTexture) {
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:mtlPixFmt width:width height:height mipmapped:NO];
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    *outTexture = [m_device newTextureWithDescriptor:textureDescriptor];
    
    MTLRegion region = MTLRegionMake2D(0, 0, width, height);
    [*outTexture replaceRegion:region mipmapLevel:0 withBytes:buffer bytesPerRow: bytesPerRow];
}

void MetalRenderer::calculateAspectRatio(const CGSize &srcSize, const CGSize &dstSize, float *scaleX, float *scaleY) {
    CGFloat srcAspectRatio = (CGFloat)srcSize.width / (CGFloat)srcSize.height;
    CGFloat dstAspectRatio = (CGFloat)dstSize.width / (CGFloat)dstSize.height;
    *scaleX = 1.0;
    *scaleY = 1.0;
    if (srcAspectRatio > dstAspectRatio) {
        // Texture is wider than the layer
        *scaleY = dstAspectRatio / srcAspectRatio;
    } else {
        // Texture is taller than the layer or has the same aspect ratio
        *scaleX = srcAspectRatio / dstAspectRatio;
    }
}

void MetalRenderer::renderGainTextureToLayer(id<MTLTexture> texture, id<MTLTexture> gainTexture, FragUniforms fragUniformData, CAMetalLayer* layer) {
    // Prepare pipeline
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = m_vertexFunction;
    pipelineDescriptor.fragmentFunction = m_gainFragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
    
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [m_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    
    // Prepare uniform buffer
    const CGSize srcSize = CGSizeMake(texture.width, texture.height);
    const CGSize dstSize = layer.bounds.size;
    float scaleX = 1.0;
    float scaleY = 1.0;
    calculateAspectRatio(srcSize, dstSize, &scaleX, &scaleY);
    matrix_float4x4 scalingMatrix = (matrix_float4x4){
        .columns[0] = {scaleX, 0, 0, 0},
        .columns[1] = {0, -scaleY, 0, 0},
        .columns[2] = {0, 0, 1, 0},
        .columns[3] = {0, 0, 0, 1}
    };
    
    id<MTLBuffer> uniformBuffer = [m_device newBufferWithBytes:&scalingMatrix length:sizeof(matrix_float4x4) options:MTLResourceStorageModeShared];
    
    id<MTLBuffer> fragUniform = [m_device newBufferWithBytes:&fragUniformData length:sizeof(fragUniformData) options:MTLResourceStorageModeShared];

    // Do draw command
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    id<MTLTexture> framebufferTexture = drawable.texture;
    
    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = framebufferTexture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id<MTLCommandBuffer> commandBuffer = [m_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    // Configure encoder settings, like setting the pipeline state and vertex buffer
    [commandEncoder setRenderPipelineState:pipelineState];
    [commandEncoder setVertexBuffer:m_vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:uniformBuffer offset:0 atIndex:1];
    [commandEncoder setFragmentBuffer:fragUniform offset:0 atIndex:0];
    [commandEncoder setFragmentTexture:texture atIndex:0];
    [commandEncoder setFragmentTexture:gainTexture atIndex:1];
    [commandEncoder setFragmentSamplerState:m_samplerState atIndex:0];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [commandEncoder endEncoding];

    [commandBuffer presentDrawable:drawable];
    
    [commandBuffer commit];
}

//void MetalRenderer::renderTextureToLayer(id<MTLTexture> texture, FragUniforms fragUniformData, CAMetalLayer* layer) {
void MetalRenderer::renderTextureToLayer(id<MTLTexture> texture, FragUniforms fragUniformData, MTKView *view, CAMetalLayer* layer) {
    // Prepare pipeline
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = m_vertexFunction;
    pipelineDescriptor.fragmentFunction = m_fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = layer.pixelFormat;
    
    NSError *error = nil;
    id<MTLRenderPipelineState> pipelineState = [m_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!pipelineState) {
        NSLog(@"Error occurred when creating render pipeline state: %@", error);
    }
    
    // Prepare uniform buffer
    const CGSize srcSize = CGSizeMake(texture.width, texture.height);
    const CGSize dstSize = layer.bounds.size;
    float scaleX = 1.0;
    float scaleY = 1.0;
    calculateAspectRatio(srcSize, dstSize, &scaleX, &scaleY);
    matrix_float4x4 scalingMatrix = (matrix_float4x4){
        .columns[0] = {scaleX, 0, 0, 0},
        .columns[1] = {0, -scaleY, 0, 0},
        .columns[2] = {0, 0, 1, 0},
        .columns[3] = {0, 0, 0, 1}
    };
    
    id<MTLBuffer> uniformBuffer = [m_device newBufferWithBytes:&scalingMatrix length:sizeof(matrix_float4x4) options:MTLResourceStorageModeShared];
    
    id<MTLBuffer> fragUniform = [m_device newBufferWithBytes:&fragUniformData length:sizeof(fragUniformData) options:MTLResourceStorageModeShared];

    // Do draw command
//    id<CAMetalDrawable> drawable = [layer nextDrawable];
//    id<MTLTexture> framebufferTexture = drawable.texture;
    
//    MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
//    passDescriptor.colorAttachments[0].texture = framebufferTexture;
//    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
//    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);
//    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    MTLRenderPassDescriptor *passDescriptor = [view currentRenderPassDescriptor];
    
    id<MTLCommandBuffer> commandBuffer = [m_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> commandEncoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    // Configure encoder settings, like setting the pipeline state and vertex buffer
    [commandEncoder setRenderPipelineState:pipelineState];
    [commandEncoder setVertexBuffer:m_vertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBuffer:uniformBuffer offset:0 atIndex:1];
    [commandEncoder setFragmentBuffer:fragUniform offset:0 atIndex:0];
    [commandEncoder setFragmentTexture:texture atIndex:0];
    [commandEncoder setFragmentSamplerState:m_samplerState atIndex:0];
    [commandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    [commandEncoder endEncoding];

    [commandBuffer presentDrawable:[view currentDrawable]];
    
    [commandBuffer commit];
}
