//
//  AppController.m
//  SelfControl
//
//  Created by Charlie Stigler on 1/29/09.
//  Copyright 2009 Eyebeam.

// This file is part of SelfControl.
//
// SelfControl is free software:  you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "AppController.h"
#import "SCDurationSlider.h"
#import <LetsMove/PFMoveApplication.h>
#import "SCSettings.h"
#import <ServiceManagement/ServiceManagement.h>
#import "SCXPCClient.h"
#import "SCBlockFileReaderWriter.h"
#import "SCUIUtilities.h"
#import "SelfControl-Swift.h"
#import <UserNotifications/UserNotifications.h>

@interface AppController () {}

@property (atomic, strong, readwrite) SCXPCClient* xpc;

@end

@implementation AppController

@synthesize addingBlock;

- (AppController*) init {
	if(self = [super init]) {

		defaults_ = [NSUserDefaults standardUserDefaults];
		[defaults_ registerDefaults: SCConstants.defaultUserDefaults];

		self.addingBlock = false;
	}

	return self;
}

- (IBAction)addBlock:(id)sender {
    if ([SCUIUtilities blockIsRunning]) {
		// This method shouldn't be getting called, a block is on so the Start button should be disabled.
        NSError* err = [SCErr errorWithCode: 104];
        [SCSentry captureError: err];
        [SCUIUtilities presentError: err];
		return;
	}
	if (([[defaults_ arrayForKey: @"Blocklist"] count] == 0) && ![defaults_ boolForKey: @"BlockAsWhitelist"]) {
		// Since the Start button should be disabled when the blocklist has no entries (and it's not an allowlist)
		// this should definitely not be happening.  Exit.

        NSError* err = [SCErr errorWithCode: 100];
        [SCSentry captureError: err];
        [SCUIUtilities presentError: err];

		return;
	}

	if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![SCUIUtilities networkConnectionIsAvailable]) {
		NSAlert* networkUnavailableAlert = [[NSAlert alloc] init];
		[networkUnavailableAlert setMessageText: NSLocalizedString(@"No network connection detected", "No network connection detected message")];
		[networkUnavailableAlert setInformativeText:NSLocalizedString(@"A block cannot be started without a working network connection.  You can override this setting in Preferences.", @"Message when network connection is unavailable")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"OK", "OK button")];
        [networkUnavailableAlert runModal];
		return;
	}

    // cancel if we pop up a warning about the super long block, and the user decides to cancel
    if (![self showLongBlockWarningsIfNecessary]) {
        return;
    }

	[NSThread detachNewThreadSelector: @selector(installBlock) toTarget: self withObject: nil];
}

// returns YES if we should continue with the block, NO if we should cancel it
- (BOOL)showLongBlockWarningsIfNecessary {
    // all UI stuff MUST be done on the main thread
    if (![NSThread isMainThread]) {
        __block BOOL retVal = NO;
        dispatch_sync(dispatch_get_main_queue(), ^{
            retVal = [self showLongBlockWarningsIfNecessary];
        });
        return retVal;
    }
    
    NSString* LONG_BLOCK_SUPPRESSION_KEY = @"SuppressLongBlockWarning";
    int LONG_BLOCK_THRESHOLD_MINS = 2880; // 2 days
    int FIRST_TIME_LONG_BLOCK_THRESHOLD_MINS = 480; // 8 hours

    BOOL isFirstBlock = ![defaults_ boolForKey: @"FirstBlockStarted"];
    int blockDuration = [[self->defaults_ valueForKey: @"BlockDuration"] intValue];

    BOOL showLongBlockWarning = blockDuration >= LONG_BLOCK_THRESHOLD_MINS || (isFirstBlock && blockDuration >= FIRST_TIME_LONG_BLOCK_THRESHOLD_MINS);
    if (!showLongBlockWarning) return YES;

    // if they don't want warnings, they don't get warnings. their funeral 💀
    if ([self->defaults_ boolForKey: LONG_BLOCK_SUPPRESSION_KEY]) {
        return YES;
    }

    NSAlert* alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"That's a long block!", "Long block warning title");
    alert.informativeText = [NSString stringWithFormat: NSLocalizedString(@"Remember that once you start the block, you can't turn it back off until the timer expires in %@ - even if you accidentally blocked a site you need. Consider starting a shorter block first, to test your list and make sure everything's working properly.", @"Long block warning message"), [SCDurationSlider timeSliderDisplayStringFromNumberOfMinutes: blockDuration]];
    [alert addButtonWithTitle: NSLocalizedString(@"Cancel", @"Button to cancel a long block")];
    [alert addButtonWithTitle: NSLocalizedString(@"Start Block Anyway", "Button to start a long block despite warnings")];
    alert.showsSuppressionButton = YES;

    NSModalResponse modalResponse = [alert runModal];
    if (alert.suppressionButton.state == NSControlStateValueOn) {
        // no more warnings, they say
        [self->defaults_ setBool: YES forKey: LONG_BLOCK_SUPPRESSION_KEY];
    }
    if (modalResponse == NSAlertFirstButtonReturn) {
        return NO;
    }
    
    return YES;
}


- (void)refreshUserInterface {
    // UI updates are for the main thread only!
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self refreshUserInterface];
        });
        return;
    }

	BOOL blockWasOn = blockIsOn;
	blockIsOn = [SCUIUtilities blockIsRunning];

	if(blockIsOn) { // block is on
		if(!blockWasOn) { // if we just switched states to on...
			// SwiftUI MenuBarContentView handles the setup→timer transition
			// via state observation. No window swapping needed.
			[self closeDomainList];

            // apparently, a block is running, so make sure FirstBlockStarted is true
            [defaults_ setBool: YES forKey: @"FirstBlockStarted"];
		}
    } else { // block is off
		if(blockWasOn) { // if we just switched states to off...
			// SwiftUI TimerView stays visible until user clicks DONE.
			// No window management needed.

			// Makes sure the domain list will refresh when it comes back
			[self closeDomainList];

            // Send system notification
            UNMutableNotificationContent *noteContent = [UNMutableNotificationContent new];
            noteContent.title = @"Your SelfControl block has ended!";
            noteContent.body = @"All sites are now accessible.";
            UNNotificationRequest *noteRequest = [UNNotificationRequest requestWithIdentifier:@"blockEnded"
                                                                                      content:noteContent
                                                                                      trigger:nil];
            [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:noteRequest
                                                                   withCompletionHandler:nil];
		}
	}

    // finally: if the helper tool marked that it detected tampering, make sure
    // we follow through and set the cheater wallpaper (helper tool can't do it itself)
    if ([settings_ boolForKey: @"TamperingDetected"]) {
        NSURL* cheaterBackgroundURL = [[NSBundle mainBundle] URLForResource: @"cheater-background" withExtension: @"png"];
            NSArray<NSScreen *>* screens = [NSScreen screens];
        for (NSScreen* screen in screens) {
            NSError* err;
            [[NSWorkspace sharedWorkspace] setDesktopImageURL: cheaterBackgroundURL
                                                    forScreen: screen
                                                      options: @{}
                                                        error: &err];
        }
        [settings_ setValue: @NO forKey: @"TamperingDetected"];
    }
    
    // Display "blocklist" or "allowlist" as appropriate in menu items
    NSString* listType = [defaults_ boolForKey: @"BlockAsWhitelist"] ? @"Allowlist" : @"Blocklist";
    NSString* editListString = NSLocalizedString(([NSString stringWithFormat: @"Edit %@", listType]), @"Edit list button / menu item");

    editBlocklistMenuItem_.title = editListString;
}

- (void)handleConfigurationChangedNotification {
    [SCSentry addBreadcrumb: @"Received configuration changed notification" category: @"app"];
    // if our configuration changed, we should assume the settings may have changed
    [[SCSettings sharedSettings] reloadSettings];
    
    // clean out empty strings from the defaults blocklist (they can end up there occasionally due to UI glitches etc)
    // note we don't screw with the actively running blocklist - that should've been cleaned before it started anyway
    NSArray<NSString*>* cleanedBlocklist = [SCMiscUtilities cleanBlocklist: [defaults_ arrayForKey: @"Blocklist"]];
    [defaults_ setObject: cleanedBlocklist forKey: @"Blocklist"];

    // let the domain list know!
    if (domainListWindowController_ != nil) {
        domainListWindowController_.readOnly = [SCUIUtilities blockIsRunning];
        [domainListWindowController_ refreshDomainList];
    }
    
    // and our interface may need to change to match!
    [self refreshUserInterface];
}

- (IBAction)openPreferences:(id)sender {
    // Open the popover to show settings
    [self togglePopover: nil];
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    // For test runs, we don't want to pop up the dialog to move to the Applications folder, as it breaks the tests
    if (NSProcessInfo.processInfo.environment[@"XCTestConfigurationFilePath"] == nil) {
        PFMoveToApplicationsFolderIfNecessary();
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	[NSApplication sharedApplication].delegate = self;
    
    [SCSentry startSentry: @"org.eyebeam.SelfControl"];

    settings_ = [SCSettings sharedSettings];
    // go copy over any preferences from legacy setting locations
    // (we won't clear any old data yet - we leave that to the daemon)
    if ([SCMigrationUtilities legacySettingsFoundForCurrentUser]) {
        [SCMigrationUtilities copyLegacySettingsToDefaults];
    }

    // start up our daemon XPC
    self.xpc = [SCXPCClient new];

    SMAppService *service = [self daemonService];
    if (service.status == SMAppServiceStatusEnabled) {
        // Daemon is registered and running, connect XPC
        [self.xpc connectToHelperTool];

        // Check daemon version (update if app version is newer)
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
            [self.xpc getVersion:^(NSString * _Nonnull daemonVersion, NSError * _Nonnull error) {
                if (error == nil) {
                    if ([SELFCONTROL_VERSION_STRING compare:daemonVersion options:NSNumericSearch] == NSOrderedDescending) {
                        NSLog(@"Daemon version %@ is out of date (current: %@), re-registering...", daemonVersion, SELFCONTROL_VERSION_STRING);
                        [SCSentry addBreadcrumb:@"Detected out-of-date daemon" category:@"app"];
                        [service unregisterWithCompletionHandler:^(NSError * _Nullable unregError) {
                            if (unregError) {
                                NSLog(@"WARNING: Unregister failed: %@", unregError);
                            }
                            NSError *regError = nil;
                            [service registerAndReturnError:&regError];
                            if (regError) {
                                NSLog(@"WARNING: Re-register failed: %@", regError);
                            } else {
                                NSLog(@"Daemon re-registered successfully after version update.");
                            }
                        }];
                    } else {
                        [SCSentry addBreadcrumb:@"Detected up-to-date daemon" category:@"app"];
                        NSLog(@"Daemon version %@ is up-to-date!", daemonVersion);
                    }
                } else {
                    NSLog(@"WARNING: Failed to get daemon version: %@", error);
                }
            }];
        }];
    } else {
        NSLog(@"Daemon not registered yet (status=%ld). Will register on first block start.", (long)service.status);
    }

    // Register observers on both distributed and normal notification centers
	// to receive notifications from the helper tool and the other parts of the
	// main SelfControl app.  Note that they are divided thusly because distributed
	// notifications are very expensive and should be minimized.
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self
														selector: @selector(handleConfigurationChangedNotification)
															name: @"SCConfigurationChangedNotification"
														  object: nil
                                              suspensionBehavior: NSNotificationSuspensionBehaviorDeliverImmediately];
	[[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(handleConfigurationChangedNotification)
												 name: @"SCConfigurationChangedNotification"
											   object: nil];

    // Listen for pill click to toggle popover
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(togglePopoverFromNotification)
                                                 name: @"SelfControlTogglePopover"
                                               object: nil];

    // Set up menu bar status item + popover (replaces main window)
    [self setupStatusItem];

    // Run as accessory app (no Dock icon, no Cmd+Tab entry)
    [NSApp setActivationPolicy: NSApplicationActivationPolicyAccessory];

	// We'll set blockIsOn to whatever is NOT right, so that in refreshUserInterface
	// it'll fix it and properly refresh the user interface.
	blockIsOn = ![SCUIUtilities blockIsRunning];

	[self refreshUserInterface];
    
    NSOperatingSystemVersion minRequiredVersion = (NSOperatingSystemVersion){16,0,0};
    NSString* minRequiredVersionString = @"16.0";
	if (![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion: minRequiredVersion]) {
		NSLog(@"ERROR: Unsupported version for SelfControl");
        [SCSentry captureMessage: @"Unsupported operating system version"];
		NSAlert* unsupportedVersionAlert = [[NSAlert alloc] init];
		[unsupportedVersionAlert setMessageText: NSLocalizedString(@"Unsupported version", nil)];
        [unsupportedVersionAlert setInformativeText: [NSString stringWithFormat: NSLocalizedString(@"This version of SelfControl only supports Mac OS X version %@ or higher. To download a version for older operating systems, please go to www.selfcontrolapp.com", nil), minRequiredVersionString]];
		[unsupportedVersionAlert addButtonWithTitle: NSLocalizedString(@"OK", nil)];
		[unsupportedVersionAlert runModal];
	}
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [settings_ synchronizeSettings];
}

- (SMAppService *)daemonService {
    return [SMAppService daemonServiceWithPlistName:@"org.eyebeam.selfcontrold.plist"];
}

- (void)registerDaemonAndStartBlock {
    SMAppService *service = [self daemonService];
    NSError *error = nil;

    BOOL registered = [service registerAndReturnError:&error];

    if (!registered) {
        NSLog(@"ERROR: Failed to register daemon: %@", error);

        dispatch_async(dispatch_get_main_queue(), ^{
            if (service.status == SMAppServiceStatusRequiresApproval) {
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:NSLocalizedString(@"Background Service Required",
                    @"Alert title when daemon needs approval")];
                [alert setInformativeText:NSLocalizedString(
                    @"SelfControl needs a background service to enforce blocks. "
                    @"Please enable it in System Settings > General > Login Items & Extensions.",
                    @"Alert message when daemon needs approval")];
                [alert addButtonWithTitle:NSLocalizedString(@"Open System Settings", nil)];
                [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];

                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    [SMAppService openSystemSettingsLoginItems];
                }
            } else {
                [SCUIUtilities presentError:error ?: [SCErr errorWithCode:500]];
            }

            self.addingBlock = false;
            [self refreshUserInterface];
        });
        return;
    }

    NSLog(@"Daemon registered successfully via SMAppService!");
    [SCSentry addBreadcrumb:@"Daemon registered via SMAppService" category:@"app"];

    // Give the daemon a moment to start, then connect
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self.xpc performSelectorOnMainThread:@selector(connectToHelperTool) withObject:nil waitUntilDone:YES];
        [self proceedWithBlockStart];
    });
}

- (IBAction)showDomainList:(id)sender {
    [SCSentry addBreadcrumb: @"Showing domain list" category:@"app"];
    // Open the popover to show settings/blocklist
    [self togglePopover: nil];
}

- (void)closeDomainList {
	[domainListWindowController_ close];
	domainListWindowController_ = nil;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    // Menu bar app should always persist. Cancel termination.
    return NSTerminateCancel;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed: (NSApplication*) theApplication {
    // Menu bar app has no main window — never quit on window close.
    return NO;
}

// MARK: - Status Item & Popover

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];

    if (self.statusItem.button) {
        // Monoline icon: SF Symbol as placeholder (timer icon)
        NSImage *icon = [NSImage imageWithSystemSymbolName:@"timer"
                                 accessibilityDescription:@"SelfControl"];
        icon.size = NSMakeSize(18, 18);
        self.statusItem.button.image = icon;
        self.statusItem.button.action = @selector(togglePopover:);
        self.statusItem.button.target = self;
    }
}

- (void)togglePopover:(id)sender {
    if (self.menuPanel != nil && self.menuPanel.isVisible) {
        [self dismissMenuPanel];
        return;
    }

    [self showMenuPanel];
}

- (void)showMenuPanel {
    if (self.menuPanel == nil) {
        SCKeyablePanel *panel = [[SCKeyablePanel alloc]
            initWithContentRect:NSMakeRect(0, 0, 450, 380)
                      styleMask:NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel
                        backing:NSBackingStoreBuffered
                          defer:NO];
        panel.level = NSStatusWindowLevel;
        panel.backgroundColor = [NSColor clearColor];
        [panel setOpaque:NO];
        panel.hasShadow = YES;
        panel.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces |
                                   NSWindowCollectionBehaviorFullScreenAuxiliary;

        // Create a rounded visual effect container
        NSVisualEffectView *effectView = [[NSVisualEffectView alloc]
            initWithFrame:NSMakeRect(0, 0, 450, 380)];
        effectView.material = NSVisualEffectMaterialHUDWindow;
        effectView.state = NSVisualEffectStateActive;
        effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        effectView.wantsLayer = YES;
        effectView.layer.cornerRadius = 16;
        effectView.layer.masksToBounds = YES;
        effectView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        panel.contentView.wantsLayer = YES;
        [panel.contentView addSubview:effectView];

        NSView *hostingView = [SelfControlBridge.shared makeMenuBarContentView];
        hostingView.frame = effectView.bounds;
        hostingView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [effectView addSubview:hostingView];

        self.menuPanel = panel;
    }

    // Position below the status item button
    if (self.statusItem.button) {
        NSRect buttonFrame = [self.statusItem.button.window convertRectToScreen:
            [self.statusItem.button convertRect:self.statusItem.button.bounds toView:nil]];
        CGFloat panelWidth = self.menuPanel.frame.size.width;
        CGFloat panelHeight = self.menuPanel.frame.size.height;
        CGFloat x = NSMidX(buttonFrame) - panelWidth / 2;
        CGFloat y = NSMinY(buttonFrame) - panelHeight - 4;
        [self.menuPanel setFrameOrigin:NSMakePoint(x, y)];
    }

    [NSApp activate];
    [self.menuPanel makeKeyAndOrderFront:nil];

    // Monitor for clicks outside to dismiss
    self.clickMonitor = [NSEvent addGlobalMonitorForEventsMatchingMask:
        (NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown)
        handler:^(NSEvent *event) {
            [self dismissMenuPanel];
        }];

    self.localClickMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:
        (NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown)
        handler:^NSEvent *(NSEvent *event) {
            if (event.window != self.menuPanel) {
                [self dismissMenuPanel];
            }
            return event;
        }];
}

- (void)dismissMenuPanel {
    [self.menuPanel orderOut:nil];
    [NSApp deactivate];
    if (self.clickMonitor) {
        [NSEvent removeMonitor:self.clickMonitor];
        self.clickMonitor = nil;
    }
    if (self.localClickMonitor) {
        [NSEvent removeMonitor:self.localClickMonitor];
        self.localClickMonitor = nil;
    }
}

- (void)togglePopoverFromNotification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self togglePopover: nil];
    });
}

- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock {
    NSLog(@"addToBlocklist: %@", host);
    // Note we RETRIEVE the latest list from settings (ActiveBlocklist), but we SET the new list in defaults
    // since the helper daemon should be the only one changing ActiveBlocklist
    NSMutableArray* list = [[settings_ valueForKey: @"ActiveBlocklist"] mutableCopy];
    NSArray<NSString*>* cleanedEntries = [SCMiscUtilities cleanBlocklistEntry: host];
    
    if (cleanedEntries.count == 0) return;
    
    for (NSUInteger i = 0; i < cleanedEntries.count; i++) {
        NSString* entry = cleanedEntries[i];
        // don't add duplicate entries
        if (![list containsObject: entry]) {
            [list addObject: entry];
        }
    }
       
	[defaults_ setValue: list forKey: @"Blocklist"];

	if(![SCUIUtilities blockIsRunning]) {
		// This method shouldn't be getting called, a block is not on.
		// so the Start button should be disabled.
		// Maybe the UI didn't get properly refreshed, so try refreshing it again
		// before we return.
		[self refreshUserInterface];

        NSError* err = [SCErr errorWithCode: 102];
        [SCSentry captureError: err];
        [SCUIUtilities presentError: err];

		return;
	}

	if([defaults_ boolForKey: @"VerifyInternetConnection"] && ![SCUIUtilities networkConnectionIsAvailable]) {
		NSAlert* networkUnavailableAlert = [[NSAlert alloc] init];
		[networkUnavailableAlert setMessageText: NSLocalizedString(@"No network connection detected", "No network connection detected message")];
		[networkUnavailableAlert setInformativeText:NSLocalizedString(@"A block cannot be started without a working network connection.  You can override this setting in Preferences.", @"Message when network connection is unavailable")];
		[networkUnavailableAlert addButtonWithTitle: NSLocalizedString(@"OK", "OK button")];
        [networkUnavailableAlert runModal];
		return;
	}

    [NSThread detachNewThreadSelector: @selector(updateActiveBlocklist:) toTarget: self withObject: lock];
}

- (void)extendBlockTime:(NSInteger)minutesToAdd lock:(NSLock*)lock {
    // sanity check: extending a block for 0 minutes is useless; 24 hour should be impossible
    NSInteger maxBlockLength = [defaults_ integerForKey: @"MaxBlockLength"];
    if(minutesToAdd < 1) return;
    if (minutesToAdd > maxBlockLength) {
        minutesToAdd = maxBlockLength;
    }
    
    // ensure block health before we try to change it
    if(![SCUIUtilities blockIsRunning]) {
        // This method shouldn't be getting called, a block is not on.
        // so the Start button should be disabled.
        // Maybe the UI didn't get properly refreshed, so try refreshing it again
        // before we return.
        [self refreshUserInterface];
        
        NSError* err = [SCErr errorWithCode: 103];
        [SCSentry captureError: err];
        [SCUIUtilities presentError: err];
        
        return;
    }
  
    [self updateBlockEndDate: lock minutesToAdd: minutesToAdd];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self
													name: @"SCConfigurationChangedNotification"
												  object: nil];
	[[NSDistributedNotificationCenter defaultCenter] removeObserver: self
															   name: @"SCConfigurationChangedNotification"
															 object: nil];
}

- (void)installBlock {
    [SCSentry addBreadcrumb:@"App running installBlock method" category:@"app"];
    @autoreleasepool {
        self.addingBlock = true;

        if (domainListWindowController_ != nil) {
            [domainListWindowController_ refreshDomainList];
        }
        [self refreshUserInterface];

        SMAppService *service = [self daemonService];
        SMAppServiceStatus status = service.status;

        if (status == SMAppServiceStatusEnabled) {
            // Daemon already registered and running
            [self.xpc performSelectorOnMainThread:@selector(connectToHelperTool) withObject:nil waitUntilDone:YES];
            [self proceedWithBlockStart];
        } else {
            // Need to register the daemon first
            [self registerDaemonAndStartBlock];
        }
    }
}

/// Prepares block settings and sends the startBlock command to the daemon.
/// Called after verifying the daemon is running (either already or just installed).
- (void)proceedWithBlockStart {
    NSTimeInterval blockDurationSecs = MAX([[defaults_ valueForKey: @"BlockDuration"] intValue] * 60, 0);
    NSDate* newBlockEndDate = [NSDate dateWithTimeIntervalSinceNow: blockDurationSecs];

    [settings_ synchronizeSettings];
    [defaults_ synchronize];

    [self.xpc refreshConnectionAndRun:^{
        NSLog(@"Refreshed connection and ready to start block!");
        [self.xpc startBlockWithControllingUID: getuid()
                                     blocklist: [self->defaults_ arrayForKey: @"Blocklist"]
                                   isAllowlist: [self->defaults_ boolForKey: @"BlockAsWhitelist"]
                                       endDate: newBlockEndDate
                                 blockSettings: @{
                                                    @"ClearCaches": [self->defaults_ valueForKey: @"ClearCaches"],
                                                    @"AllowLocalNetworks": [self->defaults_ valueForKey: @"AllowLocalNetworks"],
                                                    @"EvaluateCommonSubdomains": [self->defaults_ valueForKey: @"EvaluateCommonSubdomains"],
                                                    @"IncludeLinkedDomains": [self->defaults_ valueForKey: @"IncludeLinkedDomains"],
                                                    @"BlockSoundShouldPlay": [self->defaults_ valueForKey: @"BlockSoundShouldPlay"],
                                                    @"BlockSound": [self->defaults_ valueForKey: @"BlockSound"],
                                                    @"EnableErrorReporting": [self->defaults_ valueForKey: @"EnableErrorReporting"]
                                                }
                                         reply:^(NSError * _Nonnull error) {
            if (error != nil) {
                [SCUIUtilities presentError: error];
            } else {
                [SCSentry addBreadcrumb: @"Block started successfully" category:@"app"];
            }

            [self->settings_ synchronizeSettingsWithCompletion:^(NSError * _Nullable syncError) {
                self.addingBlock = false;
                [self refreshUserInterface];
            }];
        }];
    }];
}

- (void)updateActiveBlocklist:(NSLock*)lockToUse {
	if(![lockToUse tryLock]) {
		return;
	}
    
    [SCSentry addBreadcrumb: @"App running updateActiveBlocklist method" category:@"app"];

    // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
    [settings_ synchronizeSettings];
    [defaults_ synchronize];

    [self.xpc refreshConnectionAndRun:^{
        NSLog(@"Refreshed connection updating active blocklist!");
        [self.xpc updateBlocklist: [self->defaults_ arrayForKey: @"Blocklist"]
                            reply:^(NSError * _Nonnull error) {
            if (error != nil) {
                [SCUIUtilities presentError: error];
            } else {
                [SCSentry addBreadcrumb: @"Blocklist updated successfully" category:@"app"];
            }

            [lockToUse unlock];
        }];
    }];
}

// it really sucks, but we can't change any values that are KVO-bound to the UI unless they're on the main thread
// to make that easier, here is a helper that always does it on the main thread
- (void)setDefaultsBlockDurationOnMainThread:(NSNumber*)newBlockDuration {
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread: @selector(setDefaultsBlockDurationOnMainThread:) withObject:newBlockDuration waitUntilDone: YES];
    }

    [defaults_ setInteger: [newBlockDuration intValue] forKey: @"BlockDuration"];
}

- (void)updateBlockEndDate:(NSLock*)lockToUse minutesToAdd:(NSInteger)minutesToAdd {
    // Lock is optional. SwiftUI callers (TimerPillView, ExtendBlockModal) pass nil
    // because the daemon already serializes XPC writes and the user-facing flow
    // intentionally allows multiple in-flight extends. Legacy TimerWindowController
    // still passes a real lock for its old single-window contention model.
    if (lockToUse != nil && ![lockToUse tryLock]) {
        return;
    }
    [SCSentry addBreadcrumb: @"App running updateBlockEndDate method" category:@"app"];

    minutesToAdd = MAX(minutesToAdd, 0); // make sure there's no funny business with negative minutes
    NSDate* oldBlockEndDate = [settings_ valueForKey: @"BlockEndDate"];
    NSDate* newBlockEndDate = [oldBlockEndDate dateByAddingTimeInterval: (minutesToAdd * 60)];

    // we're about to launch a helper tool which will read settings, so make sure the ones on disk are valid
    [settings_ synchronizeSettings];
    [defaults_ synchronize];

    [self.xpc refreshConnectionAndRun:^{
        // Before we try to extend the block, make sure the block time didn't run out (or is about to run out) in the meantime
        if ([SCBlockUtilities currentBlockIsExpired] || [oldBlockEndDate timeIntervalSinceNow] < 1) {
            // we're done, or will be by the time we get to it! so just let it expire. they can restart it.
            [lockToUse unlock];
            return;
        }

        NSLog(@"Refreshed connection updating active block end date!");
        [self.xpc updateBlockEndDate: newBlockEndDate
                               reply:^(NSError * _Nonnull error) {
            // Errors are surfaced to the SwiftUI pill via reconcile-and-shake
            // (BlockTimerCoordinator observes BlockEndDate changes and shakes
            // the pill on a downward correction). No modal here.
            if (error == nil) {
                [SCSentry addBreadcrumb: @"App extended block duration successfully" category:@"app"];
            }

            [lockToUse unlock];
        }];
    }];
}

- (IBAction)save:(id)sender {
	NSSavePanel *sp;
	long runResult;

	/* create or get the shared instance of NSSavePanel */
	sp = [NSSavePanel savePanel];
	sp.allowedFileTypes = @[@"selfcontrol"];

	/* display the NSSavePanel */
	runResult = [sp runModal];

	/* if successful, save file under designated name */
	if (runResult == NSModalResponseOK) {
        NSError* err;
        [SCBlockFileReaderWriter writeBlocklistToFileURL: sp.URL
                                   blockInfo: @{
                                       @"Blocklist": [defaults_ arrayForKey: @"Blocklist"],
                                       @"BlockAsWhitelist": [defaults_ objectForKey: @"BlockAsWhitelist"]
                                       
                                   }
                                   error: &err];

        if (err != nil) {
            NSError* displayErr = [SCErr errorWithCode: 101 subDescription: err.localizedDescription];
            [SCSentry captureError: displayErr];
            NSBeep();
            [SCUIUtilities presentError: displayErr];
			return;
        } else {
            [SCSentry addBreadcrumb: @"Saved blocklist to file" category:@"app"];
        }
	}
}

- (BOOL)openSavedBlockFileAtURL:(NSURL*)fileURL {
    NSDictionary* settingsFromFile = [SCBlockFileReaderWriter readBlocklistFromFile: fileURL];
    
    if (settingsFromFile != nil) {
        [defaults_ setObject: settingsFromFile[@"Blocklist"] forKey: @"Blocklist"];
        [defaults_ setObject: settingsFromFile[@"BlockAsWhitelist"] forKey: @"BlockAsWhitelist"];
        [SCSentry addBreadcrumb: @"Opened blocklist from file" category:@"app"];
    } else {
        NSLog(@"WARNING: Could not read a valid blocklist from file - ignoring.");
        return NO;
    }

    // send a notification so the domain list (etc) updates
    [[NSNotificationCenter defaultCenter] postNotificationName: @"SCConfigurationChangedNotification" object: self];
    
    [self refreshUserInterface];
    return YES;
}

- (IBAction)open:(id)sender {
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
	oPanel.allowedFileTypes = @[@"selfcontrol"];
	oPanel.allowsMultipleSelection = NO;

	long result = [oPanel runModal];
	if (result == NSModalResponseOK) {
		if([oPanel.URLs count] > 0) {
            [self openSavedBlockFileAtURL: oPanel.URLs[0]];
		}
	}
}

- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)filename {
    return [self openSavedBlockFileAtURL: [NSURL fileURLWithPath: filename]];
}

- (IBAction)openFAQ:(id)sender {
    [SCSentry addBreadcrumb: @"Opened SelfControl FAQ" category:@"app"];
	NSURL *url=[NSURL URLWithString: @"https://github.com/SelfControlApp/selfcontrol/wiki/FAQ#q-selfcontrols-timer-is-at-0000-and-i-cant-start-a-new-block-and-im-freaking-out"];
	[[NSWorkspace sharedWorkspace] openURL: url];
}

- (IBAction)openSupportHub:(id)sender {
    [SCSentry addBreadcrumb: @"Opened SelfControl Support Hub" category:@"app"];
    NSURL *url=[NSURL URLWithString: @"https://selfcontrolapp.com/support"];
    [[NSWorkspace sharedWorkspace] openURL: url];
}


@end
