//
//  MetalView.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <AVFoundation/AVFoundation.h>

#include "RenderCommon.h"
#include "Utils.h"

NS_ASSUME_NONNULL_BEGIN

@interface MetalView : UIView

@property (nonatomic, strong) CAMetalLayer *m_metalLayer;

- (void)setupMetal;
- (void)showImageURL: (NSURL*)imageURL renderConfig: (struct RenderConfig) renderConfig;
- (void)showCIImage: (CIImage*) image renderConfig: (struct RenderConfig) renderConfig;

@end

NS_ASSUME_NONNULL_END
