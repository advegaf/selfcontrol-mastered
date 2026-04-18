//
//  SCSettingsEndConditionTests.m
//  SelfControlTests
//

#import <XCTest/XCTest.h>
#import "SCSettings.h"

@interface SCSettingsEndConditionTests : XCTestCase
@end

@implementation SCSettingsEndConditionTests

+ (void)setUp {
    [super setUp];
    [[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"isTest"];
    // SCSettings shouldn't be readOnly during tests so we can write values
    [SCSettings sharedSettings].readOnly = NO;
}

- (void)tearDown {
    SCSettings* settings = [SCSettings sharedSettings];
    [settings setValue: @"time" forKey: @"ActiveBlockEndCondition"];
    [settings setValue: nil forKey: @"BlockStartDate"];
    [super tearDown];
}

- (void)testActiveBlockEndConditionDefaultsToTime {
    SCSettings* settings = [SCSettings sharedSettings];
    NSString* direct = [settings valueForKey: @"ActiveBlockEndCondition"];
    XCTAssertEqualObjects(direct, @"time", @"Default end condition must be 'time'");
    NSString* viaDict = [settings dictionaryRepresentation][@"ActiveBlockEndCondition"];
    XCTAssertEqualObjects(viaDict, @"time", @"Default must be materialized into dictionaryRepresentation");
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
    XCTAssertEqualObjects([settings valueForKey: @"EmergencyUnlockCount"], @0);
    XCTAssertEqualObjects([settings dictionaryRepresentation][@"EmergencyUnlockCount"], @0);
}

@end
