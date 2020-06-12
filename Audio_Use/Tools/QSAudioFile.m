//
//  QSAudioFile.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/12.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioFile.h"

@interface QSAudioFile()
{
    NSFileHandle *_fileHandler;
    AudioFileID _audioFileID;
}

@end

@implementation QSAudioFile

static OSStatus QSAudioFileRead_Callback(void *inClientData, SInt64 inPosition, UInt32 requestCount, void *buffer, UInt32 *actualCount) {
    QSAudioFile *audioFile = (__bridge QSAudioFile *)inClientData;
    *actualCount = [audioFile _availableDataLengthAtOffset:inPosition maxLength:requestCount];
    if (actualCount > 0) {
        NSData *data = [audioFile _dataAtOffset:inPosition length:*actualCount];
        memcpy(buffer, data.bytes, data.length);
    }
    return noErr;
}

static SInt64 QSAudioFileGetSize_Callback (void *inClientData) {
    QSAudioFile *audioFile = (__bridge QSAudioFile *)inClientData;
    return audioFile.fileSize;
}

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType {
    if (self = [super init]) {
        _filePath = filePath;
        _fileType = fileType;
        
        _fileHandler = [NSFileHandle fileHandleForReadingAtPath:_filePath];
        _fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:_filePath error:nil] fileSize];
        if (_fileHandler && _fileSize > 0) {
            if ([self _openAudioFile]) {
                [self _fetchFormatInfo];
            }
        } else {
            [_fileHandler closeFile];
        }
    }
    return self;
}

- (BOOL)_openAudioFile {
    OSStatus status = AudioFileOpenWithCallbacks((__bridge void *)self, QSAudioFileRead_Callback, NULL, QSAudioFileGetSize_Callback, NULL, _fileType, &_audioFileID);
    if (status != noErr) {
        _audioFileID = NULL;
        return NO;
    }
    return YES;
}

- (void)_fetchFormatInfo {
    UInt32 formatList_Length;
    Boolean isWritable;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatList_Length, &isWritable);
    
}

- (UInt32)_availableDataLengthAtOffset:(SInt64)inPosition maxLength:(UInt32)requestCount {
    if (inPosition + requestCount > _fileSize) {
        if (inPosition > _fileSize) {
            return 0;
        } else {
            return (UInt32)(_fileSize - inPosition);
        }
    } else {
        return requestCount;
    }
}

- (NSData *)_dataAtOffset:(SInt64)inPosition length:(UInt32)length {
    [_fileHandler seekToFileOffset:inPosition];
    return [_fileHandler readDataOfLength:length];
}

@end
