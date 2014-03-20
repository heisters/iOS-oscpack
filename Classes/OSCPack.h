//
//  OSCPack.h
//  iOS-OSCPack
//
//  Created by Ian Smith-Heisters on 3/19/14.
//  Copyright (c) 2014 Heisters Generative. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"

typedef UInt16 OSCPackPortNumber;
typedef float OSCPackFloat;
typedef signed int OSCPackInt32;
typedef const char * OSCPackString;

@interface OSCPackMessage : NSObject
@property (strong, nonatomic, readonly) NSString *address;
@property (strong, nonatomic, readonly) NSArray *arguments;

- (id)initWithAddress:(NSString *)address arguments:(NSArray *)arguments;
@end


@interface OSCPackMessageBuilder : NSObject
- (OSCPackMessageBuilder *)to:(NSString *)address;
- (OSCPackMessageBuilder *)add:(NSObject *)obj;
- (OSCPackMessageBuilder *)addInt32:(OSCPackInt32)aInt32;
- (OSCPackMessageBuilder *)addFloat:(OSCPackFloat)aFloat;
- (OSCPackMessageBuilder *)addString:(OSCPackString)aString;
- (OSCPackMessage *)build;
- (void)send;
@end


@interface OSCPackBase : NSObject< GCDAsyncUdpSocketDelegate >
@property (assign, nonatomic, readonly) OSCPackPortNumber port;

- (id)initWithPort:(OSCPackPortNumber)port;
- (BOOL)isClosed;
- (void)close;
@end


@interface OSCPackListener : OSCPackBase
- (NSUInteger)countMessages;
- (OSCPackMessage *)popMessage;
@end


@interface OSCPackSender : OSCPackBase
@property (strong, nonatomic, readwrite) NSString *host;
- (id)initWithHost:(NSString *)host port:(OSCPackPortNumber)port;
- (void)enableBroadcast;
- (void)send:(OSCPackMessage *)message;
- (OSCPackMessageBuilder *)message;
@end


