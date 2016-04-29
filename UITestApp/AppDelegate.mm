//
//  AppDelegate.m
//  WatchTest
//
//  Created by Nick on 9/14/15.
//  Copyright © 2015 Nicholas Lee Designs, LLC. All rights reserved.
//

#include "bochs.h"
#import "AppDelegate.h"
#import "RootViewController.h"

@interface RenderView : UIView
{
    CGSize sz;
    int* imageData;
    CGContextRef imageContext;
}

+ (id)sharedInstance;

- (void)addToWindow:(UIWindow*)window;

- (int*)imageData;
- (CGContextRef)imageContext;
- (void)recreateImageContextWithX:(int)x y:(int)y bpp:(int)bpp;

@end


@interface AppDelegate ()

@end

int bochs_main (const char *);

@implementation AppDelegate

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    
    
    
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
    RootViewController *first = [[RootViewController alloc] init];
    
    self.window = [[UIWindow alloc] initWithFrame:bounds];
    
    self.window.rootViewController = first;
    
    self.window.backgroundColor = [UIColor redColor];
    
    [self.window makeKeyAndVisible];
    
    
    UILabel *label = [[UILabel alloc] initWithFrame:bounds];
    [first.view addSubview:label];
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.text = @"MAKE WATCH\nGREAT AGAIN";
    label.font = [UIFont fontWithName:@"TimesNewRomanPSMT" size:[UIFont systemFontSize]];
    label.textAlignment = NSTextAlignmentCenter;
    
    NSLog(@"%@", [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[NSBundle mainBundle] bundlePath] error:nil]);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self start];
    });
    
    
    [self disableTimer];
    
    
    return YES;
}

- (void)disableTimer
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self disableTimer];
    });
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - Bochs stuff

- (void)start
{
    NSString *path = [self generateConfig];
    Class RenderViewClass = NSClassFromString(@"RenderView");
    [[RenderViewClass alloc] performSelector:@selector(init:) withObject:self.window]; // eww
    [NSThread detachNewThreadSelector:@selector(refreshThread) toTarget:self withObject:nil];
    [NSThread detachNewThreadSelector:@selector(runBochs:) toTarget:self withObject:path];
}

- (void)refreshThread
{
    NSTimer* t = [NSTimer timerWithTimeInterval:0.1f target:[RenderView sharedInstance] selector:@selector(doRedraw) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
    [[NSRunLoop currentRunLoop] run];
}

- (NSString *)generateConfig
{
    NSString *tempPath = NSTemporaryDirectory();
    NSString *filename = [[tempPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d", arc4random()]] stringByAppendingPathExtension:@"conf"];
    
    NSURL *templateURL = [[NSBundle mainBundle] URLForResource:@"bochs" withExtension:@"conf"];
    NSString *templateContents = [NSString stringWithContentsOfURL:templateURL encoding:NSUTF8StringEncoding error:nil];
    NSMutableString *contents = [templateContents mutableCopy];
    
    NSRange(^stringRange)() = ^NSRange{
        return NSMakeRange(0, contents.length);
    };
    
    [contents replaceOccurrencesOfString:@"BIOS_ROM_IMAGE"
                              withString:[[NSBundle mainBundle] pathForResource:@"BIOS-bochs-latest"
                                                                         ofType:nil]
                                 options:kNilOptions
                                   range:stringRange()];
    
    [contents replaceOccurrencesOfString:@"VGA_ROM_IMAGE"
                              withString:[[NSBundle mainBundle] pathForResource:@"VGABIOS-lgpl-latest"
                                                                         ofType:nil]
                                 options:kNilOptions
                                   range:stringRange()];
    
    
    NSString *HDD_PATH = [[NSBundle mainBundle] pathForResource:@"win95"
                                                         ofType:@"img"];
    
    
    NSLog(@"%@", HDD_PATH);
    NSLog(@"%@", [[NSFileManager defaultManager] attributesOfItemAtPath:HDD_PATH error:nil]);
    
    NSString *NEW_HDD_PATH = [tempPath stringByAppendingPathComponent:@"boot.img"];
    
    [[NSFileManager defaultManager] removeItemAtPath:NEW_HDD_PATH error:nil];
    
    NSLog(@"COPY? %d", [[NSFileManager defaultManager] copyItemAtPath:HDD_PATH toPath:NEW_HDD_PATH error:nil]);
    
    [contents replaceOccurrencesOfString:@"HDD_IMAGE"
                              withString:NEW_HDD_PATH
                                 options:kNilOptions
                                   range:stringRange()];
    
    
    NSLog(@"%@", contents);
    
    BOOL result = [contents writeToFile:filename atomically:NO encoding:NSUTF8StringEncoding error:nil];
    NSLog(@"Wrote successfully: %d", result);
    
    return filename;
}

- (void)runBochs:(NSString *)configPath
{
    @autoreleasepool {
        bochs_main([configPath UTF8String]);
    }
}

#pragma mark - Helpers

- (NSString *)applicationDocumentsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = paths.firstObject;
    return basePath;
}

- (NSString *)pathForDocument:(NSString *)doc withExtension:(NSString *)ext
{
    return [[[self applicationDocumentsDirectory] stringByAppendingPathComponent:doc] stringByAppendingPathExtension:ext];
}

@end
