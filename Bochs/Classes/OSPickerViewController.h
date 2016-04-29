//
//  OSPickerViewController.h
//  bochs
//
//  Created by WERT on 19.07.09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol OSPickerViewControllerDelegate;


@interface OSPickerViewController : UITableViewController<UIAlertViewDelegate>
{
	NSMutableArray* osArray;
	id<OSPickerViewControllerDelegate> delegate;
}

- (void)setDelegate:(id<OSPickerViewControllerDelegate>)delegate;

@end

@protocol OSPickerViewControllerDelegate

- (void)selectedOsInPickerView:(OSPickerViewController*)viewController withConfigFile:(NSString*)path;

@end
