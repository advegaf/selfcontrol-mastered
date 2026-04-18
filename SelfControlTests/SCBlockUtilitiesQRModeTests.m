#import <XCTest/XCTest.h>
#import "SCBlockUtilities.h"
#import "SCSettings.h"

@interface SCBlockUtilitiesQRModeTests : XCTestCase
@end

@implementation SCBlockUtilitiesQRModeTests

+ (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"isTest"];
    [SCSettings sharedSettings].readOnly = NO;
}

- (void)setUp {
    [super setUp];
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: @"time" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: nil forKey: @"BlockStartDate"];
}

- (void)tearDown {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"time" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: nil forKey: @"BlockStartDate"];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [super tearDown];
}

- (void)testTimeModeWithPastEndDateIsExpired {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"time" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: [NSDate dateWithTimeIntervalSinceNow: -60] forKey: @"BlockEndDate"];
    XCTAssertTrue([SCBlockUtilities currentBlockIsExpired]);
}

- (void)testTimeModeWithFutureEndDateIsNotExpired {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"time" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: [NSDate dateWithTimeIntervalSinceNow: 60] forKey: @"BlockEndDate"];
    XCTAssertFalse([SCBlockUtilities currentBlockIsExpired]);
}

- (void)testQRModeIsNeverExpiredRegardlessOfBlockEndDate {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"qr" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: nil forKey: @"BlockEndDate"];
    [settings setValue: [NSDate date] forKey: @"BlockStartDate"];
    XCTAssertFalse([SCBlockUtilities currentBlockIsExpired], @"QR-mode block should never expire by time");
}

- (void)testQRModeWithPastBlockEndDateSentinelStillNotExpired {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"qr" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: [NSDate distantPast] forKey: @"BlockEndDate"];
    XCTAssertFalse([SCBlockUtilities currentBlockIsExpired]);
}

@end
