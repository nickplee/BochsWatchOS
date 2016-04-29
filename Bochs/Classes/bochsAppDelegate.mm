//
//  bochsAppDelegate.m
//  bochs
//
//  Created by WERT on 25.10.08.
//  Copyright __MyCompanyName__ 2008. All rights reserved.
//

#import "bochsAppDelegate.h"

@implementation bochsAppDelegate

@synthesize window;

int bochs_main (const char*);

- (void)doBochs:(NSString*)configPath
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	bochs_main([configPath UTF8String]);
	
	[pool release];
}

- (void)refreshThread
{
	NSTimer* t = [NSTimer timerWithTimeInterval:0.1f target:[NSClassFromString(@"RenderView") sharedInstance] selector:@selector(doRedraw) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:t forMode:NSRunLoopCommonModes];
	
	[[NSRunLoop currentRunLoop] run];
}

- (void)selectedOsInPickerView:(OSPickerViewController*)viewController withConfigFile:(NSString*)path
{
	[[NSClassFromString(@"RenderView") alloc] performSelector:@selector(init:) withObject:window];
	[NSThread detachNewThreadSelector:@selector(refreshThread) toTarget:self withObject:nil];
	[NSThread detachNewThreadSelector:@selector(doBochs:) toTarget:self withObject:path];
	
	[UIView beginAnimations:nil context:nil];
	[UIView setAnimationDuration:1.0f];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromLeft forView:window cache:NO];
	
	[viewController.navigationController.view removeFromSuperview];
	
	[UIView commitAnimations];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application
{	
	[window makeKeyAndVisible];

	OSPickerViewController* viewController = [[[OSPickerViewController alloc] init] autorelease];
	UINavigationController* navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
	
	[viewController setDelegate:self];
	
	[window addSubview:navigationController.view];
 }


- (void)dealloc {
	[window release];
	[super dealloc];
}


@end

