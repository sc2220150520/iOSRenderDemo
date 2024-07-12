//
//  AppDelegate.m
//  GainMapDemo
//
//  Created by Chang on 2024/2/15.
//

#import "AppDelegate.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor whiteColor];

    // Set your custom ViewController as the root view controller
    ViewController *viewController = [[ViewController alloc] init];
    [self.window setRootViewController: viewController];
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
