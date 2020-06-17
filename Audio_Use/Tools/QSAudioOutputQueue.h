//
//  QSAudioOutputQueue.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/16.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface QSAudioOutputQueue : NSObject

@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign, readonly) UInt32 bufferSize;
/// 0.0 - 1.0
@property (nonatomic, assign) float volume;
@property (nonatomic, assign, readonly) BOOL available;
@property (nonatomic, assign, readonly) BOOL isRunning;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize magicCookie:(NSData *)magicCookie;
- (BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof;
- (BOOL)pause;
/// seek的时候调用
- (BOOL)reset;
- (BOOL)stop:(BOOL)immediately;
/// 播完的时候调用
- (BOOL)flush;
- (NSTimeInterval)playedTime;

- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize data:(void *)data error:(NSError *__autoreleasing *)outError;
- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError * __autoreleasing *)outError;
- (BOOL)getParameter:(AudioQueueParameterID)parameterID value:(AudioQueueParameterValue *)value error:(NSError * __autoreleasing *)outError;
- (BOOL)setParameter:(AudioQueueParameterID)parameterID value:(AudioQueueParameterValue)value error:(NSError * __autoreleasing *)outError;

@end
