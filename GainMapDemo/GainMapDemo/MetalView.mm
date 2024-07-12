//
//  MetalView.m
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#import "MetalView.h"

#include "MetalRenderer.h"
#include <memory>

@interface MetalView () <MTKViewDelegate>  {
    std::unique_ptr<MetalRenderer> m_metalRenderer;
    id<MTLDevice> m_device;
    NSData *m_ambientViewingEnvironmentData;
    MTKView *_view;
    id<MTLTexture> mSrcTexture;
    FragUniforms mFragUniform;
    dispatch_queue_t renderThread;
}
@end

@implementation MetalView

//+ (Class)layerClass {
//    return [CAMetalLayer class];
//}

- (void)setupMetal {
    if (!m_device) {
        m_device = MTLCreateSystemDefaultDevice();
        _view = [[MTKView alloc] initWithFrame:self.bounds device:m_device];
        m_metalRenderer = std::make_unique<MetalRenderer>(m_device);
        _view.autoResizeDrawable = NO;
        if (_view.frame.size.width < 1 || _view.frame.size.height < 1) {
            _view.frame = CGRectMake(0, 0, 1, 1);
        }
        _view.paused = YES;
        _view.delegate = self;
        [self addSubview:_view];
        m_ambientViewingEnvironmentData = [NSData dataWithBytes:"\x00\x2f\xe9\xa0\x3d\x13\x40\x42" length:8];
        
        self.contentScaleFactor = [[UIScreen mainScreen] scale];
        //self.m_metalLayer = (CAMetalLayer *)self.layer;
        self.m_metalLayer = (CAMetalLayer *)_view.layer;
        self.m_metalLayer.device = m_device;
        self.m_metalLayer.opaque = NO;
    }
}

- (void)showCIImage: (CIImage*) image auxImage: (CIImage*) auxImage renderConfig: (struct RenderConfig) renderConfig {
    if (image == nil || auxImage == nil) {
        return;
    }
    
    ColorTrc mainColorTrc = [self determineColorTrcFromImage: image];
    ColorTrc auxColorTrc = [self determineColorTrcFromImage: auxImage];
    
    CGColorSpaceRef pqColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearDisplayP3);
//    CGColorSpaceRef pqColorSpace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);
    self.m_metalLayer.pixelFormat = MTLPixelFormatRGBA16Float;
    [self configMetalLayerEDR: renderConfig.metalMode colorTrc: ColorTrc::PQ];
    self.m_metalLayer.colorspace = pqColorSpace;
    CGColorSpaceRelease(pqColorSpace);
    
    double exif_headroom = 1.0;
    NSDictionary *metadata = [image properties];
    NSDictionary *makerAppleDictionary = [metadata objectForKey:(NSString *)kCGImagePropertyMakerAppleDictionary];
    id maker33 = [makerAppleDictionary objectForKey:@"33"];
    id maker48 = [makerAppleDictionary objectForKey:@"48"];
    if ([maker33 isKindOfClass:[NSNumber class]] || [maker48 isKindOfClass:[NSNumber class]]) {
        double d33 = [maker33 doubleValue];
        double d48 = [maker48 doubleValue];
        double stops;
        if (d33 < 1.0) {
            if (d48 <= 0.01) {
                stops = -20.0 * d48 + 1.8;
            } else {
                stops = -0.101 * d48 + 1.601;
            }
        } else {
            if (d48 <= 0.01) {
                stops = -70.0 * d48 + 3.0;
            } else {
                stops = -0.303 * d48 + 2.303;
            }
        }
        exif_headroom = pow(2.0, fmax(stops, 0.0));
    }
    
    FragUniforms fragUniformData {
        .colorTrc = ColorTrc::PQ,
        .metalMode = renderConfig.metalMode,
        .headroom = (float)exif_headroom
    };
    
    // Create and upload Metal texture
    id<MTLTexture> srcTexture = nil;
    id<MTLTexture> auxTexture = nil;
    m_metalRenderer->uploadCIImageToTexture(image, MTLPixelFormatRGBA8Unorm, image.extent.size.width, image.extent.size.height, &srcTexture);
    m_metalRenderer->uploadCIImageToTexture(auxImage, MTLPixelFormatRGBA8Unorm, auxImage.extent.size.width, auxImage.extent.size.height, &auxTexture);
    m_metalRenderer->renderGainTextureToLayer(srcTexture, auxTexture, fragUniformData, self.m_metalLayer);
}

- (void)showCIImage: (CIImage*) image renderConfig: (struct RenderConfig) renderConfig {
    if (image == nil) {
        return;
    }
    
    CGFloat width = image.extent.size.width;
    CGFloat height = image.extent.size.height;
    CGColorSpaceRef imageColorSpace = [image colorSpace];
    ColorTrc colorTrc = [self determineColorTrcFromImage:image];
    
    MTLPixelFormat metalTextureFormat = MTLPixelFormatRGBA8Unorm;
    if (colorTrc != sRGB) {
        metalTextureFormat = MTLPixelFormatRGBA16Float;
    }
    
    // Config Metal layer
    self.m_metalLayer.colorspace = imageColorSpace;
    self.m_metalLayer.pixelFormat = metalTextureFormat;
    [self configMetalLayerEDR: renderConfig.metalMode colorTrc: colorTrc];
    
    // Prepare frag uniform
    FragUniforms fragUniformData {
        .colorTrc = colorTrc,
        .metalMode = renderConfig.metalMode
    };
    mFragUniform = fragUniformData;
    
    // Create and upload Metal texture
    id<MTLTexture> srcTexture = nil;
    m_metalRenderer->uploadCIImageToTexture(image, metalTextureFormat, width, height, &srcTexture);
    mSrcTexture = srcTexture;
    if (renderThread == nil) {
        renderThread = dispatch_queue_create("vclould.videoprocessor.nnsr.initvpeffect.queue", DISPATCH_QUEUE_SERIAL);
    }
    
    //[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(render) userInfo:nil repeats:YES];
    dispatch_async(dispatch_get_main_queue(), ^{
     NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:(33.f/1000.f) repeats:YES block:^(NSTimer * _Nonnull timer) {
        [self render];
    }];
    });
}

- (void)render {
     dispatch_async(renderThread, ^{
        [_view draw];
    });
   
}

- (void)drawInMTKView:(MTKView *)view {
    [self configMetalLayerEDR:mFragUniform.metalMode  colorTrc: mFragUniform.colorTrc];
    m_metalRenderer->renderTextureToLayer(mSrcTexture, mFragUniform, _view,self.m_metalLayer);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _view.frame = self.bounds;
    if (_view.frame.size.width < 1 || _view.frame.size.height < 1) {// MTKView size must not be zero
        _view.frame = CGRectMake(0, 0, 1, 1);
    }
}

- (void)showImageURL: (NSURL*)imageURL renderConfig: (RenderConfig) renderConfig {
    // Create CIImage from image URL
    if (!imageURL) return;
    NSDictionary *optHDR = @{kCIImageApplyOrientationProperty: @YES, kCIImageExpandToHDR: @YES};
    CIImage* hdrImage = [CIImage imageWithContentsOfURL:imageURL options: optHDR];
    
    NSDictionary *optAux = @{kCIImageApplyOrientationProperty: @YES, kCIImageAuxiliaryHDRGainMap: @YES};
    CIImage* auxImage = [CIImage imageWithContentsOfURL:imageURL options: optAux];
    
    NSDictionary *optSDR = @{kCIImageApplyOrientationProperty: @YES};
    CIImage* sdrImage = [CIImage imageWithContentsOfURL:imageURL options: optSDR];
    
    if (renderConfig.gainMapMode == GainMapMode::hdr) {
        [self showCIImage:hdrImage renderConfig: renderConfig];
    } else if (renderConfig.gainMapMode == GainMapMode::hdrc) {
        [self showCIImage:sdrImage auxImage:auxImage renderConfig: renderConfig];
    } else if (renderConfig.gainMapMode == GainMapMode::gainmap) {
        [self showCIImage:auxImage renderConfig: renderConfig];
    } else {
        [self showCIImage:sdrImage renderConfig: renderConfig];
    }
}

- (ColorTrc) determineColorTrcFromImage: (CIImage*)image {
    CGColorSpaceRef imageColorSpace = [image colorSpace];
    
    // Print colorspace name
    CFStringRef imageColorSpaceName = CGColorSpaceGetName(imageColorSpace);
    if (imageColorSpaceName) {
        CFIndex length = CFStringGetLength(imageColorSpaceName);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
        std::unique_ptr<char[]> buffer(new char[maxSize]);
        CFStringGetCString(imageColorSpaceName, buffer.get(), maxSize, kCFStringEncodingUTF8);
        Nlog("Image colorspace = %s", buffer.get());
        CFRelease(imageColorSpaceName);
    }
    
    ColorTrc colorTrc = sRGB;
//    if (CGColorSpaceIsPQBased(imageColorSpace)) {
//        colorTrc = PQ;
//    } else if (CGColorSpaceIsHLGBased(imageColorSpace)) {
        colorTrc = HLG;
    //}
    
    return colorTrc;
}

- (void) configMetalLayerEDR: (MetalRenderMode)metalMode colorTrc: (ColorTrc)colorTrc {
    if (colorTrc != sRGB) {
        if ([[NSThread currentThread] isMainThread]) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _m_metalLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);;
            [CATransaction commit];
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                if (_m_metalLayer) {
                    _m_metalLayer.colorspace = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);;
                }
                [CATransaction commit];
            });
        }
        
        
        if (metalMode == sysTrc) {
            // why still need edrmetadata?
            CAEDRMetadata *edrMetadata;
            if (colorTrc == PQ) {
                edrMetadata = [CAEDRMetadata HDR10MetadataWithMinLuminance:0.1 maxLuminance:1000 opticalOutputScale:10000];
            } else { // HLG
                edrMetadata = [CAEDRMetadata HLGMetadataWithAmbientViewingEnvironment: m_ambientViewingEnvironmentData];
            }
            
            self.m_metalLayer.wantsExtendedDynamicRangeContent = YES;
//            self.m_metalLayer.EDRMetadata = edrMetadata;
            
        } else { // EDR
        
            
            CAEDRMetadata *edrMetadata;
            
//            if (colorTrc == PQ) {
//                edrMetadata = [CAEDRMetadata HDR10MetadataWithMinLuminance:0.1 maxLuminance:1000 opticalOutputScale:10000];
//            } else { // HLG
            self.m_metalLayer.wantsExtendedDynamicRangeContent = YES;
            if (@available(iOS 17.0, *)) {
                NSData *ambientViewingEnvironmentData = [NSData dataWithBytes:"\x00\x2f\xe9\xa0\x3d\x13\x40\x42" length:8];
                self.m_metalLayer.EDRMetadata = [CAEDRMetadata HLGMetadataWithAmbientViewingEnvironment: ambientViewingEnvironmentData];
//                self.m_metalLayer.EDRMetadata = [CAEDRMetadata HLGMetadataWithAmbientViewingEnvironment: m_ambientViewingEnvironmentData];
                
            } else {
            }
            //}
            
           
            
            // Override colorspace to EDR
            //CGColorSpaceRef colorSpaceEDR2020 = CGColorSpaceCreateWithName(kCGColorSpaceExtendedLinearITUR_2020);
            
//            CGColorSpaceRef colorSpaceEDR2020 = CGColorSpaceCreateWithName(kCGColorSpaceITUR_2100_HLG);
//            self.m_metalLayer.colorspace = colorSpaceEDR2020;
//            CGColorSpaceRelease(colorSpaceEDR2020);
        }
    }
}

@end
