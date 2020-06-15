//
//  QSAudioPlayer.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioPlayer.h"
#import "QSAudioBuffer.h"

@interface QSAudioPlayer()
{
    NSFileHandle *_fileHander;
    unsigned long long _fileSize;
    QSAudioBuffer *_buffer;
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

@end
