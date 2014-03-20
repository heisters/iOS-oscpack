//
//  OSCPack.mm
//  iOS-OSCPack
//
//  Created by Ian Smith-Heisters on 3/19/14.
//  Copyright (c) 2014 Heisters Generative. All rights reserved.
//
//

#import "OSCPack.h"
#import "AsyncUdpSocket.h"
#include "osc/OscOutboundPacketStream.h"
#include "osc/OscReceivedElements.h"

const static int BUFFER_SIZE = 1024;

@interface OSCPackMessage ()
@end

@implementation OSCPackMessage

- (id)initWithAddress:(NSString *)address arguments:(NSArray *)arguments
{
    if ( !(self = [super init]) ) return nil;

    _address = address;
    _arguments = arguments;

    return self;
}

@end


@interface OSCPackMessageBuilder ()
@property (weak, nonatomic, readwrite) OSCPackSender *sender;
@property (strong, nonatomic, readwrite) NSString *address;
@property (strong, nonatomic, readwrite) NSMutableArray *arguments;
@end

@implementation OSCPackMessageBuilder

- (id)initWithSender:(OSCPackSender *)sender
{
    if ( !(self = [super init]) ) return nil;

    self.sender = sender;
    self.arguments = [NSMutableArray array];

    return self;
}

- (OSCPackMessageBuilder *)to:(NSString *)address
{
    self.address = address;
    return self;
}

- (void)addArgument:(const void *)arg_p objCType:(const char *)type
{
    [self.arguments addObject:[NSValue valueWithBytes:arg_p objCType:type]];
}

- (OSCPackMessageBuilder *)addInt32:(OSCPackInt32)aInt32
{
    [self addArgument:&aInt32 objCType:@encode(OSCPackInt32)];
    return self;
}
- (OSCPackMessageBuilder *)addFloat:(OSCPackFloat)aFloat
{
    [self addArgument:&aFloat objCType:@encode(OSCPackFloat)];
    return self;
}
- (OSCPackMessageBuilder *)addString:(OSCPackString)aString
{
    [self addArgument:&aString objCType:@encode(OSCPackString)];
    return self;
}
- (BOOL)send
{
    return [self.sender send:self.build];
}

- (OSCPackMessage *)build
{
    return [[OSCPackMessage alloc] initWithAddress:self.address
                                         arguments:self.arguments];
}

@end

@interface OSCPackBase()
@property (strong, nonatomic, readwrite) AsyncUdpSocket *socket;
@end

@implementation OSCPackBase

- (void)dealloc
{
    if ( self.socket ) {
        [self close];
    }
}

- (id)initWithPort:(OSCPackPortNumber)port
{
	if (!(self = [super init])) return nil;

    _port = port;
    // Use IPV4 only for now, to avoid getting duplicate packets on both IPV4
    // and IPV6
    self.socket = [[AsyncUdpSocket alloc] initIPv4];
    self.socket.delegate = self;
    [self.socket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];

	return self;
}

- (void)close
{
    [self.socket close];
}

- (BOOL)isClosed
{
    return self.socket.isClosed;
}

@end

#pragma mark - OSCPackListener

@interface OSCPackListener()
@property (strong, nonatomic, readwrite) NSMutableArray *messages;
@end

@implementation OSCPackListener

- (id)initWithPort:(OSCPackPortNumber)port
{
    if ( !(self = [super initWithPort:port]) ) return nil;

    self.messages = [NSMutableArray array];

    NSError *error = nil;
    [self.socket bindToPort:self.port error:&error];
    if ( error ) {
        [[NSException exceptionWithName:@"ListenerBindingException"
                                 reason:[NSString stringWithFormat:@"osc listener could not bind: %@", error]
                               userInfo:@{@"error":error}]
         raise];
    } else {
        NSLog(@"OSC listening on port %i", self.port);
    }

    return self;
}

- (void)receive
{
    [self.socket receiveWithTimeout:-1 tag:0];
}

- (BOOL)onUdpSocket:(AsyncUdpSocket *)socket didReceiveData:(NSData *)data withTag:(long)tag fromHost:(NSString *)host port:(UInt16)port
{
    NSUInteger length = [data length];
    const char *c_data = (char *)[data bytes];
    osc::ReceivedPacket p( c_data, length );

    if ( p.IsBundle() ) {
        // do nothing :(


    } else {
        NSString *address = nil;
        NSMutableArray *arguments = [NSMutableArray array];
        osc::ReceivedMessage m_in(p);

        address = [NSString stringWithUTF8String:m_in.AddressPattern()];
        for ( osc::ReceivedMessage::const_iterator arg = m_in.ArgumentsBegin();
             arg != m_in.ArgumentsEnd();
             ++arg )
        {
            if ( arg->IsInt32() )
                [arguments addObject:@(arg->AsInt32Unchecked())];
            else if ( arg->IsFloat() )
                [arguments addObject:@(arg->AsFloatUnchecked())];
            else if ( arg->IsString() )
                [arguments addObject:[NSString stringWithUTF8String:arg->AsStringUnchecked()]];
            else
            {
                [[NSException exceptionWithName:@"OSCMessageReceiveException"
                                         reason:@"message is not an int, float, or string"
                                       userInfo:nil]
                 raise];
            }
        }

        OSCPackMessage *m_out = [[OSCPackMessage alloc] initWithAddress:address
                                                              arguments:arguments];
        [self.messages insertObject:m_out atIndex:0];
    }

    return NO; // no, we are not finished
}

- (NSUInteger)countMessages
{
    return self.messages.count;
}

- (OSCPackMessage *)popMessage
{
    OSCPackMessage *message = self.messages.lastObject;
    [self.messages removeLastObject];
    return message;
}
@end

#pragma mark - OSCPackSender

@interface OSCPackSender()
@end

@implementation OSCPackSender

- (id)initWithPort:(OSCPackPortNumber)port
{
    if ( !(self = [super initWithPort:port]) ) return nil;

    self.host = @"127.0.0.1";

    return self;
}

- (id)initWithHost:(NSString *)host port:(OSCPackPortNumber)port
{
    if ( !(self = [super initWithPort:port]) ) return nil;

    self.host = host;

    return self;
}

- (void)enableBroadcast
{
    NSError *error = nil;
    [self.socket enableBroadcast:YES error:&error];
    if ( error ) {
        [[NSException exceptionWithName:@"SenderEnableBroadcastException"
                                reason:[NSString stringWithFormat:@"osc sender could not enable broadcast: %@", error]
                              userInfo:@{@"error":error}]
         raise];
    }
}

- (OSCPackMessageBuilder *)message
{
    return [[OSCPackMessageBuilder alloc] initWithSender:self];
}

- (BOOL)send:(OSCPackMessage *)message
{
    // Send accelerometer data
    char buffer[BUFFER_SIZE];

    osc::OutboundPacketStream packet(buffer, BUFFER_SIZE);
    packet << osc::BeginMessage([message.address UTF8String]);

    for ( NSValue *arg in message.arguments )
    {
        if ( strcmp(arg.objCType, @encode(OSCPackFloat)) == 0 )
        {
            OSCPackFloat aFloat;
            [arg getValue:&aFloat];
            packet << aFloat;
        }
        else if ( strcmp(arg.objCType, @encode(OSCPackInt32)) == 0 )
        {
            OSCPackInt32 aInt32;
            [arg getValue:&aInt32];
            packet << aInt32;
        }
        else if ( strcmp(arg.objCType, @encode(OSCPackString)) == 0 )
        {
            OSCPackString aString;
            [arg getValue:&aString];
            packet << aString;
        }
        else
        {
            [[NSException exceptionWithName:@"OSCArgumentException"
                                     reason:[NSString stringWithFormat:@"argument with encoding %s is not an int, float, or string", arg.objCType]
                                   userInfo:nil]
             raise];
        }

    }

    packet << osc::EndMessage;

    return [self.socket sendData:[NSData dataWithBytes:packet.Data() length:packet.Size()]
                          toHost:self.host
                            port:self.port
                     withTimeout:-1
                             tag:0];

}
@end


