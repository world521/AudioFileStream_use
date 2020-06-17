//
//  QSAudioOutputQueue.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/16.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioOutputQueue.h"
#import <pthread.h>

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
    
    BOOL _started;
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
        [self _mutexInit];
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

- (BOOL)playData:(NSData *)data packetCount:(UInt32)packetCount packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions isEof:(BOOL)isEof {
    if (data.length > _bufferSize) {
        return NO;
    }
    
    if (_reusableBuffers.count == 0) {
        if (!_started && ![self _start]) {
            return NO;
        }
        [self _mutexWait];
    }
    
    QSAudioQueueBuffer *bufferObj = [_reusableBuffers firstObject];
    [_reusableBuffers removeObject:bufferObj];
    
    if (!bufferObj) {
        AudioQueueBufferRef buffer;
        OSStatus status = AudioQueueAllocateBuffer(_audioQueue, _bufferSize, &buffer);
        if (status != noErr) {
            NSLog(@"创建AudioQueueBufferRef失败");
            return NO;
        }
        bufferObj = [[QSAudioQueueBuffer alloc] init];
        bufferObj.buffer = buffer;
    }
    
    memcpy(bufferObj.buffer->mAudioData, data.bytes, data.length);
    bufferObj.buffer->mAudioDataByteSize = (UInt32)data.length;
    
    OSStatus status = AudioQueueEnqueueBuffer(_audioQueue, bufferObj.buffer, packetCount, packetDescriptions);
    if (status != noErr) {
        NSLog(@"AudioQueueEnqueueBuffer失败");
        return NO;
    }
    
    if (_reusableBuffers.count == 0 || isEof) {
        if (!_started && ![self _start]) {
            return NO;
        }
    }
    
    return YES;
}

/// 某块Buffer被使用之后
- (void)handleAudioQueueOutput:(AudioQueueRef)audioQueue buffer:(AudioQueueBufferRef)buffer {
    for (QSAudioQueueBuffer *ocBuffer in _buffers) {
        if (ocBuffer.buffer == buffer) {
            [_reusableBuffers addObject:ocBuffer];
            break;
        }
    }
    [self _mutexSignal];
}

/// AudioQueue属性变化
- (void)handleAudioQueueProperty:(AudioQueueRef)audioQueue property:(AudioQueuePropertyID)property {
    if (property == kAudioQueueProperty_IsRunning) {
        UInt32 isRunning = 0;
        UInt32 size = sizeof(isRunning);
        AudioQueueGetProperty(audioQueue, property, &isRunning, &size);
        _isRunning = isRunning;
    }
}

- (BOOL)_start {
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    _started = status == noErr;
    return _started;
}

- (BOOL)pause {
    OSStatus status = AudioQueuePause(_audioQueue);
    _started = NO;
    return status == noErr;
}

- (BOOL)resume {
    return [self _start];
}

- (BOOL)reset {
    OSStatus status = AudioQueueReset(_audioQueue);
    return status == noErr;
}

- (BOOL)stop:(BOOL)immediately {
    OSStatus status;
    if (immediately) {
        status = AudioQueueStop(_audioQueue, true);
    } else {
        status = AudioQueueStop(_audioQueue, false);
    }
    _started = NO;
    return status == noErr;
}

- (BOOL)flush {
    OSStatus status = AudioQueueFlush(_audioQueue);
    return status == noErr;
}

- (BOOL)available {
    return _audioQueue != NULL;
}

- (NSTimeInterval)playedTime {
    if (_format.mSampleRate) {
        return 0;
    }
    
    AudioTimeStamp time;
    OSStatus status = AudioQueueGetCurrentTime(_audioQueue, NULL, &time, NULL);
    if (status == noErr) {
        return time.mSampleTime / _format.mSampleRate;
    }
    
    return 0;
}

- (void)setVolume:(float)volume {
    _volume = volume;
    [self setParameter:kAudioQueueParam_Volume value:_volume error:NULL];
}

- (BOOL)getProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32 *)dataSize data:(void *)data error:(NSError *__autoreleasing *)outError {
    OSStatus status = AudioQueueGetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setProperty:(AudioQueuePropertyID)propertyID dataSize:(UInt32)dataSize data:(const void *)data error:(NSError * __autoreleasing *)outError {
    OSStatus status = AudioQueueSetProperty(_audioQueue, propertyID, data, dataSize);
    [self _errorForStatus:status error:outError];
    return status == noErr;
}

- (BOOL)getParameter:(AudioQueueParameterID)parameterID value:(AudioQueueParameterValue *)value error:(NSError *__autoreleasing *)outError {
    OSStatus status = AudioQueueGetParameter(_audioQueue, parameterID, value);
    [self _errorForStatus:status error:outError];
    return status == noErr;
}

- (BOOL)setParameter:(AudioQueueParameterID)parameterID value:(AudioQueueParameterValue)value error:(NSError * __autoreleasing *)outError {
    OSStatus status = AudioQueueSetParameter(_audioQueue, parameterID, value);
    [self _errorForStatus:status error:outError];
    return status == noErr;
}

- (void)_errorForStatus:(OSStatus)status error:(NSError * __autoreleasing *)outError {
    if (status != noErr && outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

#pragma mark - mutex

- (void)_mutexInit {
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
}

- (void)_mutexWait {
    pthread_mutex_lock(&_mutex);
    pthread_cond_wait(&_cond, &_mutex);
    pthread_mutex_unlock(&_mutex);
}

- (void)_mutexSignal {
    pthread_mutex_lock(&_mutex);
    pthread_cond_signal(&_cond);
    pthread_mutex_unlock(&_mutex);
}

@end
