//
//  ViewController.m
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#import "ViewController.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <AVFoundation/AVFoundation.h>

#include "Utils.h"
#include "RenderCommon.h"

@interface ViewController () {
    PHPickerResult *m_currentPickedImage;
    float m_slider_value;
}

- (void)updateImageView;
- (void)updateMetalView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self setupImageView];
    [self setupMetalView];
    [self setupSlider];
    [self setupRendererControl];
    [self setupDynamicRangeControl];
    [self setupMetalRenderModeControl];
    [self setupGainMapModeControl];
    
    self.dynamicRangeSegmentedControl.enabled = NO;
    self.metalModeSegmentedControl.enabled = YES;
    m_currentPickedImage = nil;
    
    [self setupButton];
}

- (void)setupMetalView {
    self.metalView = [[MetalView alloc] initWithFrame:CGRectMake(20, 60, self.view.frame.size.width - 40, self.view.frame.size.width - 40)];
    self.metalView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    [self.metalView setupMetal];
    [self.view addSubview:self.metalView];
}

- (void)setupImageView {
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(20, 60, self.view.frame.size.width - 40, self.view.frame.size.width - 40)];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    self.imageView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    self.imageView.preferredImageDynamicRange = UIImageDynamicRangeStandard;
    [self.view addSubview:self.imageView];
}

- (void)setupSlider {
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.metalView.frame) + 20, self.view.frame.size.width - 40, 20)];
    self.slider.minimumValue = 0.0;
    self.slider.maximumValue = 1.0;
    self.slider.value = 0.0;
    self.slider.enabled = NO;
    
    [self.slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.slider];
}

- (void)setupRendererControl {
    UILabel *rendererLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.slider.frame) + 15, self.view.frame.size.width - 40, 20)];
    rendererLabel.text = @"Renderer";
    rendererLabel.textAlignment = NSTextAlignmentLeft;
    rendererLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.view addSubview:rendererLabel];
    
    NSArray *rendererOptions = @[@"UIImageView", @"Metal"];
    self.rendererSegmentedControl = [[UISegmentedControl alloc] initWithItems:rendererOptions];
    self.rendererSegmentedControl.frame = CGRectMake(20, CGRectGetMaxY(rendererLabel.frame) + 10, self.view.frame.size.width - 40, 30);
    
    // Set the default selected segment (e.g., Standard)
    self.rendererSegmentedControl.selectedSegmentIndex = 1;
    self.imageView.hidden = YES;
    self.metalView.hidden = NO;
    
    // Add target-action mechanism
    [self.rendererSegmentedControl addTarget:self action:@selector(rendererChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.rendererSegmentedControl];
}

- (void)setupDynamicRangeControl {
    UILabel *dynamicRangeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.rendererSegmentedControl.frame) + 15, self.view.frame.size.width - 40, 20)];
    dynamicRangeLabel.text = @"Dynamic Range";
    dynamicRangeLabel.textAlignment = NSTextAlignmentLeft;
    dynamicRangeLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.view addSubview:dynamicRangeLabel];
    
    NSArray *dynamicRangeOptions = @[@"Standard", @"Constrained", @"High"];
    self.dynamicRangeSegmentedControl = [[UISegmentedControl alloc] initWithItems:dynamicRangeOptions];
    self.dynamicRangeSegmentedControl.frame = CGRectMake(20, CGRectGetMaxY(dynamicRangeLabel.frame) + 10, self.view.frame.size.width - 40, 30);
    
    // Set the default selected segment (e.g., Standard)
    self.dynamicRangeSegmentedControl.selectedSegmentIndex = 2;
    self.imageView.preferredImageDynamicRange = UIImageDynamicRangeHigh;
    
    // Add target-action mechanism
    [self.dynamicRangeSegmentedControl addTarget:self action:@selector(dynamicRangeChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.dynamicRangeSegmentedControl];
}

- (void)setupMetalRenderModeControl {
    UILabel *metalRenderModeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.dynamicRangeSegmentedControl.frame) + 15, self.view.frame.size.width - 40, 20)];
    metalRenderModeLabel.text = @"Metal Render Mode";
    metalRenderModeLabel.textAlignment = NSTextAlignmentLeft;
    metalRenderModeLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.view addSubview:metalRenderModeLabel];
    
    NSArray *metalOptions = @[@"SystemTrc", @"EDR"];
    self.metalModeSegmentedControl = [[UISegmentedControl alloc] initWithItems:metalOptions];
    self.metalModeSegmentedControl.frame = CGRectMake(20, CGRectGetMaxY(metalRenderModeLabel.frame) + 10, self.view.frame.size.width - 40, 30);
    
    // Set the default selected segment (e.g., Standard)
    self.metalModeSegmentedControl.selectedSegmentIndex = 1;
    self.metalMode = EDR;
    
    // Add target-action mechanism
    [self.metalModeSegmentedControl addTarget:self action:@selector(metalModeChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.metalModeSegmentedControl];
}

- (void)setupGainMapModeControl {
    UILabel *gainMapModeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, CGRectGetMaxY(self.metalModeSegmentedControl.frame) + 15, self.view.frame.size.width - 40, 20)];
    gainMapModeLabel.text = @"Gain Map Mode";
    gainMapModeLabel.textAlignment = NSTextAlignmentLeft;
    gainMapModeLabel.font = [UIFont boldSystemFontOfSize:17];
    [self.view addSubview:gainMapModeLabel];
    
    NSArray *gainMapOptions = @[@"HDR", @"HDR Custom", @"SDR", @"GainMap"];
    self.gainMapSegmentedControl = [[UISegmentedControl alloc] initWithItems:gainMapOptions];
    self.gainMapSegmentedControl.frame = CGRectMake(20, CGRectGetMaxY(gainMapModeLabel.frame) + 10, self.view.frame.size.width - 40, 30);
    
    // Set the default selected segment (e.g., Standard)
    self.gainMapSegmentedControl.selectedSegmentIndex = 0;
    self.gainMapMode = hdr;
    
    // Add target-action mechanism
    [self.gainMapSegmentedControl addTarget:self action:@selector(gainMapModeChanged:) forControlEvents:UIControlEventValueChanged];
    
    [self.view addSubview:self.gainMapSegmentedControl];
}

- (void)setupButton {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.frame = CGRectMake(20, CGRectGetMaxY(self.gainMapSegmentedControl.frame) + 20, self.view.frame.size.width - 40, 40);
    [button setTitle:@"Pick Image" forState:UIControlStateNormal];
    [button setBackgroundColor:[UIColor colorWithRed:0.0 green:0.3 blue:1.0 alpha:1.0]];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(pickImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
}

- (void)pickImage {
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = 1; // Set the selection limit to 1 if you only want one image
    config.filter = [PHPickerFilter imagesFilter]; // Show only images
    
    PHPickerViewController *pickerViewController = [[PHPickerViewController alloc] initWithConfiguration:config];
    pickerViewController.delegate = self;
    [self presentViewController:pickerViewController animated:YES completion:nil];
}

// PHPickerViewControllerDelegate
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (results.count == 0) {
        return;
    }
    
    PHPickerResult *result = results.firstObject;
    if ([result.itemProvider canLoadObjectOfClass:UIImage.class]) {
        m_currentPickedImage = result;
        [self updateImageView];
        [self updateMetalView];
    }
}

- (void)dynamicRangeChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    
    // Here you would adjust your UIImageView's dynamic range based on the selection
    // Since UIImageDynamicRange isn't a standard feature, let's just print the selection
    switch (selectedSegment) {
        case 0:
            self.imageView.preferredImageDynamicRange = UIImageDynamicRangeStandard;
            break;
        case 1:
            self.imageView.preferredImageDynamicRange = UIImageDynamicRangeConstrainedHigh;
            break;
        case 2:
            self.imageView.preferredImageDynamicRange = UIImageDynamicRangeHigh;
            break;
        default:
            break;
    }
}

- (void)rendererChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    
    // Here you would adjust your UIImageView's dynamic range based on the selection
    // Since UIImageDynamicRange isn't a standard feature, let's just print the selection
    switch (selectedSegment) {
        case 0:
            self.imageView.hidden = NO;
            self.metalView.hidden = YES;
            self.dynamicRangeSegmentedControl.enabled = YES;
            self.metalModeSegmentedControl.enabled = NO;
            break;
        case 1:
            self.imageView.hidden = YES;
            self.metalView.hidden = NO;
            self.dynamicRangeSegmentedControl.enabled = NO;
            self.metalModeSegmentedControl.enabled = YES;
            break;
        default:
            break;
    }
}

- (void)metalModeChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    
    // Here you would adjust your UIImageView's dynamic range based on the selection
    // Since UIImageDynamicRange isn't a standard feature, let's just print the selection
    switch (selectedSegment) {
        case 0:
            self.metalMode = sysTrc;
            [self updateMetalView];
            break;
        case 1:
            self.metalMode = EDR;
            [self updateMetalView];
            break;
        default:
            break;
    }
}

- (void)gainMapModeChanged:(UISegmentedControl *)segmentedControl {
    NSInteger selectedSegment = segmentedControl.selectedSegmentIndex;
    
    switch (selectedSegment) {
        case 0:
            self.gainMapMode = hdr;
            self.metalModeSegmentedControl.enabled = YES;
            [self updateMetalView];
            break;
        case 1:
            self.gainMapMode = hdrc;
            self.metalModeSegmentedControl.selectedSegmentIndex = 1;
            self.metalModeSegmentedControl.enabled = NO;
            self.metalMode = EDR;
            [self updateMetalView];
            break;
        case 2:
            self.gainMapMode = sdr;
            self.metalModeSegmentedControl.enabled = YES;
            [self updateMetalView];
            break;
        case 3:
            self.gainMapMode = gainmap;
            self.metalModeSegmentedControl.enabled = YES;
            [self updateMetalView];
            break;
        default:
            break;
    }
    
}

- (void)sliderValueChanged:(UISlider *)sender {
    NSLog(@"Slider value changed to: %f", sender.value);
    m_slider_value = sender.value;
}

- (void)updateImageView {
    if (m_currentPickedImage != nil) {
        [m_currentPickedImage.itemProvider loadObjectOfClass:UIImage.class completionHandler:^(UIImage *image, NSError *error) {
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.imageView.image = image;
                });
            }
        }];
    }
}

- (void)updateMetalView {
    if (m_currentPickedImage != nil) {
        [m_currentPickedImage.itemProvider loadFileRepresentationForTypeIdentifier:UTTypeImage.identifier
                                                                 completionHandler:^(NSURL * _Nullable url, NSError * _Nullable error) {
            if (url) {
                struct RenderConfig renderConfig = {
                    .metalMode = self.metalMode,
                    .gainMapMode = self.gainMapMode
                };
                [self.metalView showImageURL: url renderConfig: renderConfig];
            }
        }];
    }
}

@end
