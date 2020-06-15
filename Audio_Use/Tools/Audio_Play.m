//
//  Audio_Play.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/11.
//  Copyright © 2020 agant. All rights reserved.
//

#import "Audio_Play.h"
#import <AVFoundation/AVFoundation.h>
#import "QSAudioFileStream.h"

@interface Audio_Play() <QSAudioFileStreamDelegate>
{
    QSAudioFileStream *_audioFileStream;
    
    NSFileHandle *_fileHandler;
    UInt64 _fileSize;
}

@end

@implementation Audio_Play

- (instancetype)init {
    if (self = [super init]) {
        [self activateAudioSession];
    }
    return self;
}

- (BOOL)activateAudioSession {
    NSError *error;
    
    // 设置音频会话模式
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!error) {
        NSLog(@"设置AVAudioSession会话模式成功");
    } else {
        NSLog(@"设置AVAudioSession音频会话模式失败");
        return NO;
    }
    
    // 打断通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptHandler:) name:AVAudioSessionInterruptionNotification object:nil];
    NSLog(@"添加被打断时的监听通知");
    
    // 激活音频会话
    [[AVAudioSession sharedInstance] setActive:YES withOptions:0 error:&error];
    if (!error) {
        NSLog(@"激活AVAudioSession成功");
    } else {
        NSLog(@"激活AVAudioSession失败");
        return NO;
    }
    
    return YES;
}

- (void)go {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileSize];
    _fileHandler = [NSFileHandle fileHandleForReadingAtPath:path];
    
    NSError *error;
    _audioFileStream = [[QSAudioFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:_fileSize error:&error];
    if (error) return;
    _audioFileStream.delegate = self;
    
    NSData *data = [_fileHandler readDataOfLength:1000];
    [_audioFileStream parseData:data error:&error];
    if (error) return;
}

/**
 打断逻辑
 */
- (void)interruptHandler:(NSNotification *)notifi {
    AVAudioSessionInterruptionType type = [notifi.userInfo[AVAudioSessionInterruptionTypeKey] intValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        
    }
}

#pragma mark - QSAudioFileStreamDelegate

- (void)audioFileStreamReadyToProducePackets:(QSAudioFileStream *)audioFileStream {
    
}

- (void)audioFileStream:(QSAudioFileStream *)audioFileStream audioDataParsed:(NSArray<QSAudioParsedData *> *)audioData {
    
}

@end
