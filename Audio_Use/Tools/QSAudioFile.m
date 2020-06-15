//
//  QSAudioFile.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/12.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioFile.h"
#import "QSAudioParsedData.h"

static const UInt32 packetPerRead = 15;

@interface QSAudioFile()
{
    NSFileHandle *_fileHandler;
    AudioFileID _audioFileID;
    NSTimeInterval _packetDuration;
    SInt64 _dataOffset;
    SInt64 _packetOffset;
}
- (NSData *)_dataAtOffset:(SInt64)inPosition length:(UInt32)length;
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

- (void)dealloc {
    [_fileHandler closeFile];
    [self _closeAudioFile];
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

- (NSData *)fetchMagicCookie {
    UInt32 cookieData_Length;
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieData_Length, NULL);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyMagicCookieData长度失败");
        return nil;
    }
    
    void *cookieData = malloc(cookieData_Length);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMagicCookieData, &cookieData_Length, cookieData);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyMagicCookieData失败");
        return nil;
    }
    
    NSData *data = [NSData dataWithBytes:cookieData length:cookieData_Length];
    free(cookieData);
    
    return data;
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
    OSStatus status = AudioFileGetPropertyInfo(_audioFileID, kAudioFilePropertyFormatList, &formatList_Length, NULL);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyFormatList属性长度失败");
        [self _closeAudioFile];
        return;
    }
    
    AudioFormatListItem *formatList = malloc(formatList_Length);
    UInt32 formatListCount = formatList_Length / sizeof(AudioFormatListItem);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyFormatList, &formatList_Length, formatList);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyFormatList属性失败");
        free(formatList);
        [self _closeAudioFile];
        return;
    }
    
    UInt32 supportedFormats_Length;
    status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormats_Length);
    if (status != noErr) {
        NSLog(@"获取kAudioFormatProperty_DecodeFormatIDs长度失败");
        free(formatList);
        [self _closeAudioFile];
        return;
    }
    
    OSType *supportedFormats = malloc(supportedFormats_Length);
    UInt32 supportedFormatsCount = supportedFormats_Length / sizeof(OSType);
    status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormats_Length, supportedFormats);
    if (status != noErr) {
        NSLog(@"获取kAudioFormatProperty_DecodeFormatIDs失败");
        free(supportedFormats);
        free(formatList);
        [self _closeAudioFile];
        return;
    }
    
    BOOL foundFormat = NO;
    for (int i = 0; i < formatListCount; i++) {
        AudioStreamBasicDescription format = formatList[i].mASBD;
        for (int i = 0; i < supportedFormatsCount; i++) {
            if (format.mFormatID == supportedFormats[i]) {
                _format = format;
                foundFormat = YES;
                break;
            }
        }
    }
    if (!foundFormat) {
        NSLog(@"系统不支持kAudioFormatProperty_DecodeFormatIDs解码格式");
        free(supportedFormats);
        free(formatList);
        [self _closeAudioFile];
        return;
    }
    
    free(supportedFormats);
    free(formatList);
    [self _calculatePacketDuration];
    
    UInt32 prop_length;
    
    prop_length = sizeof(_bitRate);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyBitRate, &prop_length, &_bitRate);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyBitRate失败");
        [self _closeAudioFile];
        return;
    }
    
    prop_length = sizeof(_dataOffset);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyDataOffset, &prop_length, &_dataOffset);
    if (status != noErr) {
        NSLog(@"获取kAudioFilePropertyDataOffset失败");
        [self _closeAudioFile];
        return;
    }
    _audioDataByteCount = _fileSize - _dataOffset;
    
    prop_length = sizeof(_duration);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyEstimatedDuration, &prop_length, &_duration);
    if (status != noErr) {
        [self _calculateDuration];
    }
    
    prop_length = sizeof(_maxPacketSize);
    status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyPacketSizeUpperBound, &prop_length, &_maxPacketSize);
    if (status != noErr || _maxPacketSize == 0) {
        status = AudioFileGetProperty(_audioFileID, kAudioFilePropertyMaximumPacketSize, &prop_length, &_maxPacketSize);
        if (status != noErr) {
            NSLog(@"获取kAudioFilePropertyMaximumPacketSize失败");
            [self _closeAudioFile];
            return;
        }
    }
}

- (NSArray<QSAudioParsedData *> *)parseData:(BOOL *)isEOF {
    UInt32 ioNumPackets = packetPerRead;
    UInt32 ioNumBytes = ioNumPackets * _maxPacketSize;
    void *outBuffer = malloc(ioNumBytes);
    AudioStreamPacketDescription *outPacketDescriptions = malloc(sizeof(AudioStreamPacketDescription) * ioNumPackets);
    OSStatus status = AudioFileReadPacketData(_audioFileID, false, &ioNumBytes, outPacketDescriptions, _packetOffset, &ioNumPackets, outBuffer);
    if (status != noErr) {
        NSLog(@"AudioFileReadPacketData失败");
        *isEOF = status == kAudioFileEndOfFileError;
        free(outBuffer);
        return nil;
    }
    
    if (ioNumBytes == 0) {
        *isEOF = YES;
    }
    
    _packetOffset += ioNumPackets;
    
    NSMutableArray <QSAudioParsedData *>*parsedDataArray = [NSMutableArray array];
    for (int i = 0; i < ioNumPackets; i++) {
        AudioStreamPacketDescription packetDescription;
        if (outPacketDescriptions) {
            packetDescription = outPacketDescriptions[i];
        } else {
            packetDescription.mStartOffset = i * _format.mBytesPerPacket;
            packetDescription.mDataByteSize = _format.mBytesPerPacket;
            packetDescription.mVariableFramesInPacket = _format.mFramesPerPacket;
        }
        QSAudioParsedData *parsedData = [QSAudioParsedData parseDataWithBytes:outBuffer + packetDescription.mStartOffset packectDescription:packetDescription];
        if (parsedData) {
            [parsedDataArray addObject:parsedData];
        }
    }
    
    free(outBuffer);
    
    return parsedDataArray;
}

- (void)seekToTime:(NSTimeInterval)seekTime {
    _packetOffset = floor(seekTime / _packetDuration);
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

- (void)_calculatePacketDuration {
    if (_format.mSampleRate > 0) {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}

- (void)_calculateDuration {
    if (_bitRate > 0 && _fileSize > 0) {
        _duration = (_fileSize - _dataOffset) * 8.0 / _bitRate;
    }
}

- (void)_closeAudioFile {
    if (_audioFileID) {
        AudioFileClose(_audioFileID);
        _audioFileID = NULL;
    }
}

- (void)close {
    [self _closeAudioFile];
}

@end
