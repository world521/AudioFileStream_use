//
//  QSAudioOutputQueue.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/16.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioOutputQueue.h"

static const int QSAudioQueueBufferCount = 2;

@interface QSAudioQueueBuffer : NSObject
@property (nonatomic, assign) AudioQueueBufferRef buffer;
@end

@implementation QSAudioQueueBuffer
@end

@interface QSAudioOutputQueue() {
    AudioQueueRef _audioQueue;
    NSMutableArray <QSAudioQueueBuffer *>*_buffers;
    NSMutableArray <QSAudioQueueBuffer *>*_reusableBuffers;
    
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
}
@end

@implementation QSAudioOutputQueue

/// 某块Buffer被使用之后的回调
static void QSAudioQueueOutput_Callback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    QSAudioOutputQueue *audioOutputQueue = (__bridge QSAudioOutputQueue *)inUserData;
    [audioOutputQueue handleAudioQueueOutput:inAQ buffer:inBuffer];
}

/// AudioQueue属性变化回调
static void QSAudioQueueProperty_Callback(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueuePropertyID inID) {
    QSAudioOutputQueue *audioOutputQueue = (__bridge QSAudioOutputQueue *)inUserData;
    [audioOutputQueue handleAudioQueueProperty:inAQ property:inID];
}

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize magicCookie:(NSData *)magicCookie {
    if (self = [super init]) {
        _format = format;
        _bufferSize = bufferSize;
        _volume = 1.0;
        _buffers = [NSMutableArray array];
        _reusableBuffers = [NSMutableArray array];
        [self _createAudioOutputQueue:magicCookie];
        [self mutexInit];
    }
    return self;
}

- (void)_createAudioOutputQueue:(NSData *)magicCookie {
    OSStatus status = AudioQueueNewOutput(&_format, QSAudioQueueOutput_Callback, (__bridge void *)self, NULL, NULL, 0, &_audioQueue);
    if (status != noErr) {
        NSLog(@"创建AudioQueue失败: AudioQueueNewOutput()");
        _audioQueue = NULL;
        return;
    }
    
    status = AudioQueueAddPropertyListener(_audioQueue, kAudioQueueProperty_IsRunning, QSAudioQueueProperty_Callback, (__bridge void *)self);
    if (status != noErr) {
        NSLog(@"添加AudioQueue属性监听失败: AudioQueueAddPropertyListener()");
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
        return;
    }
    
    if (_buffers.count == 0) {
        for (int i = 0; i < QSAudioQueueBufferCount; i++) {
            AudioQueueBufferRef buffer;
            status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
            if (status != noErr) {
                AudioQueueDispose(_audioQueue, YES);
                _audioQueue = NULL;
                break;
            }
            QSAudioQueueBuffer *ocBuffer = [[QSAudioQueueBuffer alloc] init];
            ocBuffer.buffer = buffer;
            [_buffers addObject:ocBuffer];
            [_reusableBuffers addObject:ocBuffer];
        }
    }
    
#if TARGET_OS_IPHONE
    UInt32 property = kAudioQueueHardwareCodecPolicy_PreferSoftware;
    [self setProperty:kAudioQueueProperty_HardwareCodecPolicy dataSize:sizeof(property) data:&property error:NULL];
#endif
    
    if (magicCookie) {
        AudioQueueSetProperty(_audioQueue, kAudioQueueProperty_MagicCookie, magicCookie.bytes, (UInt32)magicCookie.length);
    }
    
    [self setParameter:kAudioQueueParam_Volume value:_volume error:NULL];
}

- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError * __autoreleasing *)error {
    OSStatus status = AudioQueueSetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForStatus:status error:error];
    return status == noErr;
}

- (BOOL)setParameter:(AudioQueueParameterID)parameterID value:(AudioQueueParameterValue)value error:(NSError * __autoreleasing *)error {
    OSStatus status = AudioQueueSetParameter(_audioQueue, parameterID, value);
    [self _errorForStatus:status error:error];
    return status == noErr;
}


- (void)handleAudioQueueOutput:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer {
    for (QSAudioQueueBuffer *ocBuffer in _buffers) {
        if (ocBuffer.buffer == buffer) {
            [_reusableBuffers addObject:ocBuffer];
            break;
        }
    }
    
    
}

- (void)handleAudioQueueProperty:(AudioQueueRef)audioQueue property:(AudioQueuePropertyID)property {
    
}

- (void)_errorForStatus:(OSStatus)status error:(NSError * __autoreleasing *)outError {
    if (status != noErr && outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

#pragma mark - mutex

- (void)mutexInit {
    
}

- (void)mutexWait {
    
}

@end
