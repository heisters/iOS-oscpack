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

- (void)tick
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
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
    BOOL success = [[[[self.sender message] to:@"/path/1"] addFloat:1.0] send];
    XCTAssert(success, @"sender did not send data");
    [self.listener receive];
    [self tick];

    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have received one message");
}

- (void)testReadingMessages
{
    XCTAssert([[[[self.sender message] to:@"/path/1"] addFloat:1.0] send], @"sender did not send data");
    XCTAssert([[[[self.sender message] to:@"/path/2"] addFloat:2.0] send], @"sender did not send data");

    [self.listener receive];
    [self tick];


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
    XCTAssert([[[[self.sender message] to:@"/path"] addInt32:1] send], @"sender did not send data");

    [self.listener receive];
    [self tick];

    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m = [self.listener popMessage];

    XCTAssertEqualObjects(m.address, @"/path");
    XCTAssertEqualObjects(m.arguments, @[@1]);
}

- (void)testStringMessages
{
    XCTAssert([[[[self.sender message] to:@"/path"] addString:"string"] send], @"sender did not send data");

    [self.listener receive];
    [self tick];

    XCTAssertEqual(self.listener.countMessages, 1, @"listener should have %d message", 1);
    OSCPackMessage *m = [self.listener popMessage];

    XCTAssertEqualObjects(m.address, @"/path");
    XCTAssertEqualObjects(m.arguments, @[@"string"]);
}

@end
