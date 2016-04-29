//
//  bochsAppDelegate.h
//  bochs
//
//  Created by WERT on 25.10.08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSPickerViewController.h"

@class bochsViewController;

@interface bochsAppDelegate : NSObject <UIApplicationDelegate, OSPickerViewControllerDelegate>
{
	IBOutlet UIWindow *window;
}

@property (nonatomic, retain) UIWindow *window;

@end

