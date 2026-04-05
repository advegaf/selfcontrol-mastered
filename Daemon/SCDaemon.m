//
//  SCDaemon.m
//  SelfControl
//
//  Created by Charlie Stigler on 5/28/20.
//

#import "SCDaemon.h"
#import "SCDaemonProtocol.h"
#import "SCDaemonXPC.h"
#import"SCDaemonBlockMethods.h"
#import "SCFileWatcher.h"

static NSString* serviceName = @"org.eyebeam.selfcontrold";
float const INACTIVITY_LIMIT_SECS = 60 * 2; // 2 minutes

@interface NSXPCConnection(PrivateAuditToken)

// This property exists, but it's private. Make it available:
@property (nonatomic, readonly) audit_token_t auditToken;

@end

@interface SCDaemon () <NSXPCListenerDelegate>

@property (nonatomic, strong, readwrite) NSXPCListener* listener;
@property (strong, readwrite) NSTimer* checkupTimer;
@property (strong, readwrite) NSTimer* inactivityTimer;
@property (nonatomic, strong, readwrite) NSDate* lastActivityDate;

@property (nonatomic, strong) SCFileWatcher* hostsFileWatcher;

@end

@implementation SCDaemon

+ (instancetype)sharedDaemon {
    static SCDaemon* daemon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        daemon = [SCDaemon new];
    });
    return daemon;
}

- (id) init {
    _listener = [[NSXPCListener alloc] initWithMachServiceName: serviceName];
    _listener.delegate = self;
    
    return self;
}

- (void)start {
    [self.listener resume];

    // if there's any evidence of a block (i.e. an official one running,
    // OR just block remnants remaining in hosts), we should start
    // running checkup regularly so the block gets found/removed
    // at the proper time.
    // we do NOT run checkup if there's no block, because it can result
    // in the daemon actually unloading itself before the app has a chance
    // to start the block
    if ([SCBlockUtilities anyBlockIsRunning] || [SCBlockUtilities blockRulesFoundOnSystem]) {
        [self startCheckupTimer];
    }
    
    [self startInactivityTimer];
    [self resetInactivityTimer];
    
    self.hostsFileWatcher = [SCFileWatcher watcherWithFile: @"/etc/hosts" block:^(NSError * _Nonnull error) {
        if ([SCBlockUtilities anyBlockIsRunning]) {
            NSLog(@"INFO: hosts file changed, checking block integrity");
            [SCDaemonBlockMethods checkBlockIntegrity];
        }
    }];
}

- (void)startCheckupTimer {
    // this method must always be called on the main thread, so the timer will work properly
    if (![NSThread isMainThread]) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self startCheckupTimer];
        });
        return;
    }

    // if the timer's already running, don't stress it!
    if (self.checkupTimer != nil) {
        return;
    }
    
    self.checkupTimer = [NSTimer scheduledTimerWithTimeInterval: 1 repeats: YES block:^(NSTimer * _Nonnull timer) {
       [SCDaemonBlockMethods checkupBlock];
    }];

    // run the first checkup immediately!
    [SCDaemonBlockMethods checkupBlock];
}
- (void)stopCheckupTimer {
    if (self.checkupTimer == nil) {
        return;
    }
    
    [self.checkupTimer invalidate];
    self.checkupTimer = nil;
}


- (void)startInactivityTimer {
    // Inactivity auto-unload disabled. The daemon stays alive after installation
    // so consecutive blocks don't need re-authorization via SMJobBless.
    // The plist has KeepAlive=true, so launchd manages the lifecycle.
}
- (void)resetInactivityTimer {
    self.lastActivityDate = [NSDate date];
}

- (void)dealloc {
    if (self.checkupTimer) {
        [self.checkupTimer invalidate];
        self.checkupTimer = nil;
    }
    if (self.inactivityTimer) {
        [self.inactivityTimer invalidate];
        self.inactivityTimer = nil;
    }
    if (self.hostsFileWatcher) {
        [self.hostsFileWatcher stopWatching];
        self.hostsFileWatcher = nil;
    }
}

#pragma mark - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
    // Use audit token (not PID) to avoid TOCTOU race conditions
    audit_token_t auditToken = newConnection.auditToken;
    NSDictionary *guestAttributes = @{
        (id)kSecGuestAttributeAudit: [NSData dataWithBytes:&auditToken length:sizeof(audit_token_t)]
    };

    SecCodeRef guest = NULL;
    OSStatus copyStatus = SecCodeCopyGuestWithAttributes(NULL,
        (__bridge CFDictionaryRef)(guestAttributes), kSecCSDefaultFlags, &guest);

    if (copyStatus != errSecSuccess) {
        NSLog(@"ERROR: SecCodeCopyGuestWithAttributes failed with status %d", (int)copyStatus);
        return NO;
    }

    // Validate the connecting process is signed by our team
    NSString *requirementStr =
        @"anchor apple generic"
        @" and (identifier \"org.eyebeam.SelfControl\""
        @"      or identifier \"org.eyebeam.selfcontrol-cli\")"
        @" and certificate leaf[subject.OU] = \"DV483F72N3\"";

    SecRequirementRef requirement = NULL;
    OSStatus reqStatus = SecRequirementCreateWithString(
        (__bridge CFStringRef)requirementStr, kSecCSDefaultFlags, &requirement);

    if (reqStatus != errSecSuccess) {
        NSLog(@"ERROR: SecRequirementCreateWithString failed with status %d", (int)reqStatus);
        CFRelease(guest);
        return NO;
    }

    OSStatus validStatus = SecCodeCheckValidity(guest, kSecCSDefaultFlags, requirement);
    CFRelease(requirement);
    CFRelease(guest);

    if (validStatus != errSecSuccess) {
        NSLog(@"ERROR: SecCodeCheckValidity failed with status %d — rejecting XPC connection", (int)validStatus);
        return NO;
    }

    NSLog(@"Accepted XPC connection (code signature validated)");

    SCDaemonXPC *scdXPC = [[SCDaemonXPC alloc] init];
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(SCDaemonProtocol)];
    newConnection.exportedObject = scdXPC;
    [newConnection resume];

    [SCSentry addBreadcrumb:@"Daemon accepted new connection" category:@"daemon"];
    return YES;
}

@end
