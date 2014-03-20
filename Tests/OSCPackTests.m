//
//  iOS_oscpackTests.m
//  iOS-oscpackTests
//
//  Created by Ian Smith-Heisters on 3/19/14.
//  Copyright (c) 2014 Heisters Generative. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "OSCPack.h"

static int PORT = 5555;

@interface OSCPackTests : XCTestCase
@property (strong, nonatomic, readwrite) OSCPackListener *listener;
@property (strong, nonatomic, readwrite) OSCPackSender *sender;
@end

@implementation OSCPackTests

- (void)setUp
{
    [super setUp];
    self.listener = [[OSCPackListener alloc] initWithPort:PORT];
    self.sender = [[OSCPackSender alloc] initWithHost:@"255.255.255.255" port:PORT];
    [self.sender enableBroadcast];
}

- (void)tearDown
{
    [self.listener close];
    [self.sender close];

    [super tearDown];
}

// From https://github.com/sas71/AsyncTest

- (dispatch_queue_t)serialQueue
{
    static dispatch_queue_t serialQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serialQueue = dispatch_queue_create("SenTestCase.serialQueue", DISPATCH_QUEUE_SERIAL);
    });
    return serialQueue;
}


// new version based on GHUnit
- (void)waitWithTimeout:(NSTimeInterval)timeout forSuccessInBlock:(BOOL(^)())block
{
    BOOL(^serialBlock)() = ^BOOL{
        __block BOOL result;
        // suppress spurious analyser warning
#ifndef __clang_analyzer__
        dispatch_sync(self.serialQueue, ^{
            if (block) {
                result = block();
            }
        });
#endif
        return result;
    };
    NSArray *_runLoopModes = [NSArray arrayWithObjects:NSDefaultRunLoopMode, NSRunLoopCommonModes, nil];

    NSTimeInterval checkEveryInterval = 0.01;
    NSDate *runUntilDate = [NSDate dateWithTimeIntervalSinceNow:timeout];
    NSInteger runIndex = 0;
    while(! serialBlock()) {
        NSString *mode = [_runLoopModes objectAtIndex:(runIndex++ % [_runLoopModes count])];

        @autoreleasepool {
            if (!mode || ![[NSRunLoop currentRunLoop] runMode:mode beforeDate:[NSDate dateWithTimeIntervalSinceNow:checkEveryInterval]]) {
                // If there were no run loop sources or timers then we should sleep for the interval
                [NSThread sleepForTimeInterval:checkEveryInterval];
            }
        }

        // If current date is after the run until date
        if ([runUntilDate compare:[NSDate date]] == NSOrderedAscending) {
            break;
        }
    }
}

- (void)waitForMessages:(NSInteger)numMessages
{
    [self waitWithTimeout:0.25 forSuccessInBlock:^BOOL{
        return self.listener.countMessages == numMessages;
    }];
}


- (void)testCanCloseSocket
{
    OSCPackListener *l1 = [[OSCPackListener alloc] initWithPort:PORT+1];
    [l1 close];
    XCTAssert(l1.isClosed, @"socket should be closed");
    l1 = nil;

    // second should be able to connect
    OSCPackListener *l2 = [[OSCPackListener alloc] initWithPort:PORT+1];
    XCTAssertFalse(l2.isClosed, @"socket should be open");
}

- (void)testRoundtrip
{
    [[[[self.sender message] to:@"/path/1"] addFloat:1.0] send];

    [self waitForMessages:1];
    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have received one message");
}

- (void)testReadingMessages
{
    [[[[self.sender message] to:@"/path/1"] addFloat:1.0] send];
    [[[[self.sender message] to:@"/path/2"] addFloat:2.0] send];

    [self waitForMessages:3]; // will timeout


    XCTAssertEqual(self.listener.countMessages, 2, @"listener should have %d messages", 2);
    OSCPackMessage *m1 = [self.listener popMessage];
    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m2 = [self.listener popMessage];
    XCTAssertEqual(self.listener.countMessages, 0, @"listener should have %d messages", 0);
    OSCPackMessage *m3 = [self.listener popMessage];


    XCTAssertNil(m3);

    XCTAssertEqualObjects(m1.address, @"/path/1");
    XCTAssertEqualObjects(m2.address, @"/path/2");
    XCTAssertEqualObjects(m1.arguments, @[@1.0]);
    XCTAssertEqualObjects(m2.arguments, @[@2.0]);
}

- (void)testIntegerMessages
{
    [[[[self.sender message] to:@"/path"] addInt32:1] send];

    [self waitForMessages:1];


    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m = [self.listener popMessage];

    XCTAssertEqualObjects(m.address, @"/path");
    XCTAssertEqualObjects(m.arguments, @[@1]);
}

- (void)testStringMessages
{
    [[[[self.sender message] to:@"/path"] addString:"string"] send];

    [self waitForMessages:1];


    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m = [self.listener popMessage];

    XCTAssertEqualObjects(m.address, @"/path");
    XCTAssertEqualObjects(m.arguments, @[@"string"]);
}

- (void)testPolymorphicArguments
{
    // NB: you need to be specific about NSValue types: @1.1f, NOT @1.1
    [[[[[[self.sender message] to:@"/path"] add:@"string"] add:@1] add:@1.1f] send];

    [self waitForMessages:1];


    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m = [self.listener popMessage];

    XCTAssertEqualObjects(m.address, @"/path");
    NSArray *args = @[@"string", @1, @1.1f]; // parser doesn't like this inline :P
    XCTAssertEqualObjects(m.arguments, args);
}

@end
