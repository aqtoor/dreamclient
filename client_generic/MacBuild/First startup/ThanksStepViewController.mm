//
//  ThanksStepViewController.m
//  infinidream
//
//  Created by Guillaume Louel on 17/06/2025.
//

#import "ThanksStepViewController.h"
#import "ESScreensaver.h"

@interface ThanksStepViewController ()
@property (weak) IBOutlet NSButton *installAndEnableScreensaver;

@end

@implementation ThanksStepViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
}

- (IBAction)openRemote:(id)sender {
#ifdef STAGE
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://stage.infinidream.ai/rc"]];
#else
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://alpha.infinidream.ai/rc"]];
#endif
}

- (IBAction)openPlaylistBrowser:(id)sender {
#ifdef STAGE
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://stage.infinidream.ai/playlists"]];
#else
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://alpha.infinidream.ai/playlists"]];
#endif
}

- (IBAction)closeModal:(id)sender {
    // Save the screensaver installation preference
    BOOL installScreensaver = (self.installAndEnableScreensaver.state == NSControlStateValueOn);
    ESScreensaver_SetBoolSetting("settings.app.auto_install_screensaver", installScreensaver);
    
    // End the sheet with OK response
    [self.view.window.sheetParent endSheet:self.view.window returnCode:NSModalResponseOK];
}

@end
