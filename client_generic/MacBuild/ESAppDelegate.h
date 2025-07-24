#import <Cocoa/Cocoa.h>

@class ESWindow;

@interface ESAppDelegate : NSObject <NSApplicationDelegate>

@property (weak, nonatomic) ESWindow *mainWindow;

@end