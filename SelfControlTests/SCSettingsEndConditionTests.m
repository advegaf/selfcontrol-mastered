//
//  SCSettingsEndConditionTests.m
//  SelfControlTests
//

#import <XCTest/XCTest.h>
#import "SCSettings.h"

@interface SCSettingsEndConditionTests : XCTestCase
@end

@implementation SCSettingsEndConditionTests

- (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"isTest"];
    // SCSettings shouldn't be readOnly during tests so we can write values
    [SCSettings sharedSettings].readOnly = NO;
}

- (void)testActiveBlockEndConditionDefaultsToTime {
    SCSettings* settings = [SCSettings sharedSettings];
    NSString* value = [settings valueForKey: @"ActiveBlockEndCondition"];
    XCTAssertEqualObjects(value, @"time", @"Default end condition must be 'time' for legacy installs");
}

- (void)testBlockStartDateRoundTrips {
    SCSettings* settings = [SCSettings sharedSettings];
    NSDate* now = [NSDate date];
    [settings setValue: now forKey: @"BlockStartDate"];
    NSDate* readBack = [settings valueForKey: @"BlockStartDate"];
    XCTAssertEqualWithAccuracy([readBack timeIntervalSince1970], [now timeIntervalSince1970], 0.001);
}

- (void)testEndConditionRoundTripsQR {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"qr" forKey: @"ActiveBlockEndCondition"];
    XCTAssertEqualObjects([settings valueForKey: @"ActiveBlockEndCondition"], @"qr");
}

- (void)testEmergencyUnlockCountDefaultsToZero {
    SCSettings* settings = [SCSettings sharedSettings];
    NSNumber* count = [settings valueForKey: @"EmergencyUnlockCount"];
    XCTAssertEqualObjects(count, @0);
}

@end
