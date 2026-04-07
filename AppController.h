//
//  AppController.h
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

#import <Cocoa/Cocoa.h>
#import "DomainListWindowController.h"
#import <Security/Security.h>
#import <SystemConfiguration/SCNetwork.h>
#import <unistd.h>
#import "SCSettings.h"

// The main controller for the SelfControl app, which includes several methods
// to handle command flow and acts as delegate for the initial window.
@interface AppController : NSObject <NSApplicationDelegate> {
    IBOutlet NSMenuItem* editBlocklistMenuItem_;

	IBOutlet DomainListWindowController* domainListWindowController_;
	NSUserDefaults* defaults_;
    SCSettings* settings_;
	BOOL blockIsOn;
	BOOL addingBlock;
}

@property (assign) BOOL addingBlock;
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSPanel *menuPanel;
@property (nonatomic, strong) id clickMonitor;
@property (nonatomic, strong) id localClickMonitor;

// Called when the main Start button is clicked.  Launchs installBlock in another
// thread after some checking and syncing.
- (IBAction)addBlock:(id)sender;

// Checks whether the SelfControl block is active and accordingly changes the
// user interface.  Called very often by several parts of the program.
- (void)refreshUserInterface;

// Called when the "Edit blocklist" button is clicked or the menu item is
// selected.  Opens settings inside the popover.
- (IBAction)showDomainList:(id)sender;

// Calls the close method of our DomainListWindowController
- (void)closeDomainList;

// Gets authorization for and then immediately adds the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)installBlock;

// Prepares block settings and sends the startBlock command to the daemon.
// Called after verifying the daemon is running (either already or just installed).
- (void)proceedWithBlockStart;

// Gets authorization for and then immediately refreshes the block by calling
// SelfControl's helper tool with the appropriate arguments.  Meant to be called
// as a separate thread.
- (void)updateActiveBlocklist:(NSLock*)lockToUse;

// open preferences panel
- (IBAction)openPreferences:(id)sender;

// Opens a save panel and saves the blocklist.
- (IBAction)save:(id)sender;

// Opens an open panel and imports a blocklist, clearing the current one.
- (IBAction)open:(id)sender;

// opens the SelfControl FAQ in the default browser
- (IBAction)openFAQ:(id)sender;

// opens the SelfControl Support Hub in the default browser
- (IBAction)openSupportHub:(id)sender;

// Add a host to the blocklist and refresh the active block.
- (void)addToBlockList:(NSString*)host lock:(NSLock*)lock;

// Extend the active block by a specified number of minutes.
- (void)extendBlockTime:(NSInteger)minutes lock:(NSLock*)lock;

// Sets up the menu bar status item and popover
- (void)setupStatusItem;

// Toggles the popover visibility
- (void)togglePopover:(id)sender;

@end
