//
//  ViewController.h
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import "MetalView.h"

@interface ViewController : UIViewController <PHPickerViewControllerDelegate>

@property (strong, nonatomic) MetalView *metalView;

@property (strong, nonatomic) UIImageView *imageView;
@property (strong, nonatomic) UISegmentedControl *rendererSegmentedControl;
@property (strong, nonatomic) UISegmentedControl *dynamicRangeSegmentedControl;
@property (strong, nonatomic) UISegmentedControl *metalModeSegmentedControl;
@property (strong, nonatomic) UISegmentedControl *gainMapSegmentedControl;
@property (strong, nonatomic) UISlider *slider;

//@property (strong, nonatomic) NSURL *mediaURL;
@property (strong, nonatomic) NSString *mediaType;

@property (nonatomic) MetalRenderMode metalMode;
@property (nonatomic) GainMapMode gainMapMode;

@end

