/////////////////////////////////////////////////////////////////////////
// $Id: nogui.cc,v 1.23 2006/02/21 21:35:08 vruppert Exp $
/////////////////////////////////////////////////////////////////////////
//
//  Copyright (C) 2001  MandrakeSoft S.A.
//
//    MandrakeSoft S.A.
//    43, rue d'Aboukir
//    75002 Paris - France
//    http://www.linux-mandrake.com/
//    http://www.mandrakesoft.com/
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA



// Define BX_PLUGGABLE in files that can be compiled into plugins.  For
// platforms that require a special tag on exported symbols, BX_PLUGGABLE 
// is used to know when we are exporting symbols and when we are importing.

#define BX_PLUGGABLE

#include "bochs.h"
#if BX_WITH_NOGUI
#include "icon_bochs.h"
#include "iodev.h"

#import <UIKit/UIKit.h>

class bx_nogui_gui_c : public bx_gui_c 
{
public:
	bx_nogui_gui_c (void) {}
	void show_ips(Bit32u ips_count);
	void statusbar_setitem(int element, bx_bool active);

	DECLARE_GUI_VIRTUAL_METHODS()
};

// declare one instance of the gui object and call macro to insert the
// plugin code
static bx_nogui_gui_c *theGui = NULL;


IMPLEMENT_GUI_PLUGIN_CODE(nogui)

#define LOG_THIS theGui->
#define BX_GUI_THIS theGui->

#define MAX_EVENTS 100

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

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

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////

typedef struct _EventStruct
{
	int isMouse;
	int x;
	int y;
	int button;
} EventStruct;

static RenderView* renderView;
static int tsx, tsy;
static bool isTextMode;
static unsigned short textBuffer[80*26];
static int currentResX, currentResY, currentBpp;
static EventStruct eventBuffer[MAX_EVENTS];
static int eventBufferPos;
static unsigned indexed_colors[256][3];
static int touchX, touchY;
static int touchCount;

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////


@implementation RenderView

+ (id)sharedInstance
{
	return renderView;
}

- (id)init:(UIWindow*)window
{
//	[[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:YES];
//	[[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleBlackTranslucent animated:YES];
	
    CGRect bounds = [[UIScreen mainScreen] bounds];
    
	self = [super initWithFrame:CGRectMake(0, 0, bounds.size.height, bounds.size.width)];
//	self.transform = CGAffineTransformMakeRotation(M_PI_2);
//	self.transform = CGAffineTransformTranslate(self.transform, 80, 80);
	self.multipleTouchEnabled = YES;

	renderView = self;
	
	imageData = nil;
	imageContext = nil;
	
	self.backgroundColor = [UIColor blackColor];
	
	isTextMode = YES;
	
	[self recreateImageContextWithX:640 y:480 bpp:16];
	
	[self addToWindow:window];
	
	return self;
}

- (void)addToWindow:(UIWindow*)window
{
	[window.rootViewController.view addSubview:self];
    self.transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation(M_PI_2), 17.f, 17.f);
}

- (void)recreateImageContextWithX:(int)x y:(int)y bpp:(int)bpp
{	
	sz.width = x;
	sz.height = y;
	
	currentResX = sz.width;
	currentResY = sz.height;

	@synchronized(self)
	{
		if (imageContext)
		{
			CGContextRelease(imageContext);
			imageContext = nil;
		}
	 
		if (imageData)
		{
			free(imageData);
			imageData = nil;
		}
	 
		imageData = (int*)malloc(sz.width * sz.height * 4);
		imageContext = CGBitmapContextCreate(imageData, sz.width, sz.height, 8, sz.width*4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaNoneSkipLast);
	}
	
	CGContextSetRGBFillColor(imageContext, 0.5f, 0.5f, 0.5f, 1.0f);
	CGContextFillRect(imageContext, CGRectMake(0, 0, sz.width, sz.height));
	
}

- (void)doRedraw
{
	if (self.superview)
	{
		[self setNeedsDisplay];
	}
}

void addToEventBuffer(int isMouse, int x, int y, int button)
{
	if (eventBufferPos >= MAX_EVENTS-1)
		return;

	int oldX = 0;
	int oldY = 0;
	
	if (eventBufferPos)
	{
		eventBufferPos = 0;
		oldX = eventBuffer[0].x;
		oldY = eventBuffer[0].y;
	}
	
	eventBuffer[eventBufferPos].isMouse = isMouse;
	eventBuffer[eventBufferPos].x = oldX + x;//(int)(x*1.5f);
	eventBuffer[eventBufferPos].y = oldY - y;//-(int)(y*1.5f);
	eventBuffer[eventBufferPos].button = button;
	eventBufferPos++;
}



- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
{
	int count = 0;
	
	for (UITouch* touch in touches)
	{
		if (count == 0)
		{
			CGPoint p = [touch locationInView:self];

			touchX = p.x;
			touchY = p.y;
		}
		
		count++;
		touchCount++;
	}
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{

	for (UITouch* touch in touches)
	{
		CGPoint p = [touch locationInView:self];
		CGPoint pOld = [touch previousLocationInView:self];
		
		addToEventBuffer(1, p.x - pOld.x, p.y - pOld.y, 0);
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch* touch in touches)
	{
		CGPoint p = [touch locationInView:self];
		CGPoint pOld = [touch previousLocationInView:self];
		
		int isTap = 0;
		
		if ((abs(p.x - touchX) < 5) && (abs(p.y-touchY) < 5))
			isTap = 1;
		
		if (touchCount > 1)
			isTap = 2;
		
	
		addToEventBuffer(1, 0, 0, isTap);
		
		touchCount--;
	}
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
	for (UITouch* touch in touches)
	{
		touchCount--;
	}
}

- (void)drawRect:(CGRect)rect 
{
	@synchronized(self)
	{
        @autoreleasepool {
            if (!isTextMode)
            {
                CGContextRef c = UIGraphicsGetCurrentContext();
                CGContextSaveGState(c);
                
                CGContextTranslateCTM(c, 0.0f, self.bounds.size.height);
                
                CGContextScaleCTM(c, self.bounds.size.width/currentResX, -self.bounds.size.height/currentResY);
                
                CGImageRef image = CGBitmapContextCreateImage(imageContext);
                if (image)
                {
                    CGContextDrawImage(c, CGRectMake(0, 0, currentResX,  currentResY), image);
                    CGImageRelease(image);
                }
                
                CGContextRestoreGState(c);
                
            }else
            {
                CGContextRef c = UIGraphicsGetCurrentContext();
                CGContextSaveGState(c);
                
                CGContextScaleCTM(c, self.bounds.size.width/currentResX, self.bounds.size.height/currentResY);
                
                UIFont* font = [UIFont fontWithName:@"Courier" size:15];
                
                [[UIColor whiteColor] set];
                
                for (int y = 0; y < 25; y++)
                {
                    for (int x = 0; x < 80; x++)
                    {
                        unichar ch = textBuffer[x + y*80] & 0xff;
                        
                        NSString * s = [[NSString alloc] initWithCharacters:&ch length:1];
                        [s drawAtPoint:CGPointMake(x * 8, 20 + y * 16) withFont:font];
                    }
                }
                
                CGContextRestoreGState(c);
            }
        }
	}
}

- (int*)imageData
{
	return imageData;
}

- (CGContextRef)imageContext
{
	return imageContext;
}

@end

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////


void bx_nogui_gui_c::specific_init(int argc, char **argv, unsigned tilewidth, unsigned tileheight, unsigned headerbar_y)
{
	BX_GUI_THIS new_gfx_api = 0;
	BX_GUI_THIS host_xres = 800;
	BX_GUI_THIS host_yres = 600;
	BX_GUI_THIS host_bpp = 32;
	
	tsx = tilewidth;
	tsy = tileheight;
}

void bx_nogui_gui_c::handle_events(void)
{
	while(eventBufferPos)
	{
		eventBufferPos--;
		
		if (eventBuffer[eventBufferPos].isMouse)
		{
			DEV_mouse_motion(eventBuffer[eventBufferPos].x, eventBuffer[eventBufferPos].y, eventBuffer[eventBufferPos].button);
			
			if (eventBuffer[eventBufferPos].button)
			{
				DEV_mouse_motion(0, 0, 0);
			}
			
			static int is_first;
			if (!is_first)
			{
				is_first = YES;
				//if (eventBuffer[eventBufferPos].button)
				//	DEV_kbd_gen_scancode(BX_KEY_SPACE);
			}
		}
	}
}

void bx_nogui_gui_c::text_update(Bit8u *old_text, Bit8u *new_text,
                      unsigned long cursor_x, unsigned long cursor_y,
                      bx_vga_tminfo_t tm_info, unsigned nrows)
{

	memcpy(textBuffer, new_text, 4000);	
	isTextMode = YES;
}

void bx_nogui_gui_c::flush(void)
{
}

void bx_nogui_gui_c::clear_screen(void)
{
}

int bx_nogui_gui_c::get_clipboard_text(Bit8u **bytes, Bit32s *nbytes)
{
	return 0;
}

int bx_nogui_gui_c::set_clipboard_text(char *text_snapshot, Bit32u len)
{
	return 0;
}

bx_bool bx_nogui_gui_c::palette_change(unsigned index, unsigned red, unsigned green, unsigned blue)
{
	if (index > 255) return 0;
	
	indexed_colors[index][0] = red;
	indexed_colors[index][1] = green;
	indexed_colors[index][2] = blue;
	
	return 1;
}

void bx_nogui_gui_c::graphics_tile_update(Bit8u *tile, unsigned x0, unsigned y0)
{
	isTextMode = NO;
	int* imageData = [renderView imageData];
	
	if (currentBpp == 32) // not tested yet
	{
		for (int y = 0; y < tsy; y++)
		{
			int py = y + y0;
			memcpy(&imageData[x0 + py*currentResX], &tile[y*tsx*4], tsy * 4);
		}
	}else if (currentBpp == 16)
	{
		for (int y = 0; y < tsy; y++)
		{
			int py = y + y0;
			py = MIN(py, currentResY-1);
			
			for (int x = 0; x < tsx; x++)
			{
				int px = x + x0;
				px = MIN(px, currentResX-1);
				
				unsigned int c = ((unsigned int*)tile)[x + y*tsx];
				
				c = ((c & 0xff) << 16) | (c & 0xff00) | ((c & 0xff0000) >> 16);
				
				imageData[px + py*currentResX] = c;
			}
		}
	}else // 8
	{
		for (int y = 0; y < tsy; y++)
		{
			int py = y + y0;
			py = MIN(py, currentResY-1);
			
			for (int x = 0; x < tsx; x++)
			{
				int px = x + x0;
				px = MIN(px, currentResX-1);
				
				unsigned int c = tile[x + y*tsx];
				c = indexed_colors[c][0] | (indexed_colors[c][1] << 8) | (indexed_colors[c][2] << 16);
				imageData[px + py*currentResX] = c;
			}
		}
	}
}

void bx_nogui_gui_c::dimension_update(unsigned x, unsigned y, unsigned fheight, unsigned fwidth, unsigned bpp)
{
	currentResX = x;
	currentResX = y;
	currentBpp = bpp;
	
	if (bpp >= 8)
	{
		[renderView recreateImageContextWithX:x y:y bpp:bpp];
	}
}

void bx_nogui_gui_c::show_ips(Bit32u ips_count)
{
    NSLog(@"ips = %u", ips_count);
}

void bx_nogui_gui_c::statusbar_setitem(int element, bx_bool active)
{
}

unsigned bx_nogui_gui_c::create_bitmap(const unsigned char *bmap, unsigned xdim, unsigned ydim)
{
	return 0;
}

unsigned bx_nogui_gui_c::headerbar_bitmap(unsigned bmap_id, unsigned alignment, void (*f)(void))
{
	return 0;
}

void bx_nogui_gui_c::show_headerbar(void)
{
}

void bx_nogui_gui_c::replace_bitmap(unsigned hbar_id, unsigned bmap_id)
{
}

void bx_nogui_gui_c::exit(void)
{
}

void bx_nogui_gui_c::mouse_enabled_changed_specific (bx_bool val)
{
}

#endif /* if BX_WITH_NOGUI */
