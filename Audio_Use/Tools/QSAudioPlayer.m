//
//  QSAudioPlayer.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioPlayer.h"
#import "QSAudioBuffer.h"
#import "QSAudioFile.h"
#import "QSAudioFileStream.h"
#import <pthread.h>
#import <AVFoundation/AVFoundation.h>

@interface QSAudioPlayer() <QSAudioFileStreamDelegate> {
    NSThread *_thread;
    pthread_mutex_t _mutex;
    pthread_cond_t _cond;
    
    NSFileHandle *_fileHander;
    unsigned long long _fileSize;
    
    UInt32 _bufferSize;
    QSAudioBuffer *_buffer;
    
    BOOL _started;
    BOOL _usingAudioFile;
    
    QSAudioFileStream *_audioFileStream;
    QSAudioFile *_audioFile;
    
    
    NSTimeInterval _seekTime;
}
@end

@implementation QSAudioPlayer

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType {
    if (self = [super init]) {
        _status = QSAPStatusStopped;
        
        _filePath = filePath;
        _fileType = fileType;
        
        _fileHander = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        _fileSize = [[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil].fileSize;
        if (!_fileHander || !_fileSize) {
            [_fileHander closeFile];
            _failed = YES;
        } else {
            _buffer = [QSAudioBuffer buffer];
        }
    }
    return self;
}

- (void)play {
    if (!_started) {
        _started = YES;
        [self _mutexInit];
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(_threadMain) object:nil];
        [_thread start];
    } else {
        
    }
}

- (void)_internalSetStatus:(QSAudioPlayerStatus)status {
    if (_status == status) {
        return;
    }
    
    [self willChangeValueForKey:@"status"];
    _status = status;
    [self didChangeValueForKey:@"status"];
}

- (void)_interruptHandler:(NSNotification *)notification {
    
}

- (void)_cleanup {
    
}

#pragma mark - thread

- (void)_threadMain {
    _failed = NO;
    
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    if (!success) {
        NSLog(@"设置音频会话模式失败");
        _failed = YES;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_interruptHandler:) name:AVAudioSessionInterruptionNotification object:nil];
    
    success = [[AVAudioSession sharedInstance] setActive:YES error:nil];
    if (!success) {
        NSLog(@"激活音频会话失败");
        _failed = YES;
    }
    
    NSError *error = nil;
    _audioFileStream = [[QSAudioFileStream alloc] initWithFileType:_fileType fileSize:_fileSize error:&error];
    if (error) {
        NSLog(@"创建QSAudioFileStream失败");
        _failed = YES;
    }
    _audioFileStream.delegate = self;
    
    if (_failed) {
        [self _cleanup];
        return;
    }

    [self _internalSetStatus:QSAPStatusWaiting];
    
    BOOL isEOF = NO;
    while (self.status != QSAPStatusStopped && !_failed && _started) {
        if (_usingAudioFile) {
            if (!_audioFile) {
                _audioFile = [[QSAudioFile alloc] initWithFilePath:_filePath fileType:_fileType];
            }
            [_audioFile seekToTime:_seekTime];
            if ([_buffer bufferedSize] < _bufferSize) {
                
            }
        }
    }
    
}

#pragma mark - mutex

- (void)_mutexInit {
    pthread_mutex_init(&_mutex, NULL);
    pthread_cond_init(&_cond, NULL);
}

#pragma mark - QSAudioFileStreamDelegate

- (void)audioFileStream:(QSAudioFileStream *)audioFileStream audioDataParsed:(NSArray <QSAudioParsedData *> *)audioData {
    
}

- (void)audioFileStreamReadyToProducePackets:(QSAudioFileStream *)audioFileStream {
    
}

@end
