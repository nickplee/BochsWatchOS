//
//  main.m
//  WatchTest
//
//  Created by Nick on 9/14/15.
//  Copyright © 2015 Nicholas Lee Designs, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

void __attribute__((constructor)) injected_main()
{
    @autoreleasepool {
        UIApplicationMain(0, nil, @"UIApplication", @"AppDelegate");
    }
}