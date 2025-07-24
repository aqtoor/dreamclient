#import "ESAppDelegate.h"
#import "ESWindow.h"

@implementation ESAppDelegate

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)__unused theApplication
{
    return YES;
}

@end