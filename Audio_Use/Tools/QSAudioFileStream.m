//
//  QSAudioFileStream.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/11.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioFileStream.h"

#define MaxPacketsThatUpdateBitRate 5000
#define MinPacketsThatUpdateBitRate 10


@interface QSAudioFileStream() {
    BOOL _discontinuous;
    
    AudioFileStreamID _audioFileStreamID;
    
    UInt64 _processedPacketsSize;
    UInt64 _processedPacketsCount;
    
    NSTimeInterval _packetDuration;
    SInt64 _dataOffset;
}
- (void)handleAudioFileStreamProperty:(AudioFilePropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets numberOfBytes:(UInt32)numberOfBytes numberOfPackets:(UInt32)numberOfPackets packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions;
@end

@implementation QSAudioFileStreamParsedData

+ (instancetype)parseDataWithBytes:(const void *)bytes packectDescription:(AudioStreamPacketDescription)packetDescription {
    return [[self alloc] initWithBytes:bytes packectDescription:packetDescription];
}

- (instancetype)initWithBytes:(const void *)bytes packectDescription:(AudioStreamPacketDescription)packetDescription {
    if (bytes == NULL || packetDescription.mDataByteSize == 0) {
        return nil;
    }
    
    if (self = [super init]) {
        _data = [NSData dataWithBytes:bytes length:packetDescription.mDataByteSize];
        _packetDescription = packetDescription;
    }
    return self;
}

@end

@implementation QSAudioFileStream

static void QSAudioFileStreamProperty_Callback(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, AudioFileStreamPropertyFlags *ioFlags) {
    QSAudioFileStream *audioFileStream = (__bridge QSAudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamProperty:inPropertyID];
}

static void QSAudioFileStreamPackets_Callback(void *inClientData, UInt32 inNumberBytes, UInt32                            inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
    QSAudioFileStream *audioFileStream = (__bridge QSAudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamPackets:inInputData numberOfBytes:inNumberBytes numberOfPackets:inNumberPackets packetDescriptions:inPacketDescriptions];
}

- (void)dealloc {
    [self _closeAudioFileStream];
}

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(UInt64)fileSize error:(NSError *__autoreleasing *)error {
    if (self = [super init]) {
        _discontinuous = NO;
        _fileType = fileType;
        _fileSize = fileSize;
        [self _openAudioFileStreamWithFileTypeHint:_fileType error:error];
    }
    return self;
}

- (BOOL)_openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint error:(NSError *__autoreleasing *)error {
    OSStatus status = AudioFileStreamOpen((__bridge void *)self, QSAudioFileStreamProperty_Callback, QSAudioFileStreamPackets_Callback, fileTypeHint, &_audioFileStreamID);
    if (status != noErr) {
        _audioFileStreamID = NULL;
    }
    [self _errorForOSStatus:status error:error];
    
    return status == noErr;
}

- (BOOL)parseData:(NSData *)data error:(NSError *__autoreleasing *)error {
    if (self.readyToProducePackets && _packetDuration == 0) {
        [self _errorForOSStatus:-1 error:error];
        return NO;
    }
    AudioFileStreamParseFlags parseFlags = _discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0;
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID, (UInt32)data.length, data.bytes, parseFlags);
    [self _errorForOSStatus:status error:error];
    return status == noErr;
}

- (SInt64)seekToTime:(NSTimeInterval *)ioSeekTime {
    SInt64 seekByteOffset = 0;
    SInt64 approximateSeekOffset = 0;
    
    if (_duration) {
        approximateSeekOffset = _dataOffset + (*ioSeekTime / _duration) * _audioDataByteCount;
        NSLog(@"大概的seek offset: %lld", approximateSeekOffset);
    }
    
    if (_packetDuration) {
        SInt64 seekToPacket = *ioSeekTime / _packetDuration;
        SInt64 outDataByteOffset;
        AudioFileStreamSeekFlags ioFlags = 0;
        OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
        if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated)) {
            // 给出的是精确的 seek bytes
            if (_bitRate) {
                *ioSeekTime -= (approximateSeekOffset - _dataOffset - outDataByteOffset) * 8.0 / _bitRate;
                seekByteOffset = outDataByteOffset;
            }
        } else {
            seekByteOffset = approximateSeekOffset;
        }
    }
    
    _discontinuous = YES;
    
    return seekByteOffset;
}

- (NSData *)fetchMagicCookie {
    UInt32 cookie_length;
    Boolean outWritable;
    OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookie_length, &outWritable);
    if (status != noErr) {
        NSLog(@"获取kAudioFileStreamProperty_MagicCookieData失败");
        return nil;
    }
    
    void *cookieData = malloc(cookie_length);
    status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MagicCookieData, &cookie_length, cookieData);
    if (status != noErr) {
        NSLog(@"获取kAudioFileStreamProperty_MagicCookieData失败");
        free(cookieData);
        return nil;
    }
    
    NSData *cookie = [NSData dataWithBytes:cookieData length:cookie_length];
    free(cookieData);
    
    return cookie;
}

- (void)close {
    [self _closeAudioFileStream];
}

- (void)handleAudioFileStreamProperty:(AudioFilePropertyID)propertyID {
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
        _readyToProducePackets = YES;
        _discontinuous = YES;
        
        UInt32 maxPacketSize_length = sizeof(_maxPacketSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &maxPacketSize_length, &_maxPacketSize);
        if (status != noErr || _maxPacketSize == 0) {
            status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &maxPacketSize_length, &_maxPacketSize);
        }
        
        if ([self.delegate respondsToSelector:@selector(audioFileStreamReadyToProducePackets:)]) {
            [self.delegate audioFileStreamReadyToProducePackets:self];
        }
    } else if (propertyID == kAudioFileStreamProperty_DataOffset) {
        UInt32 dataOffset_length = sizeof(_dataOffset);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataOffset, &dataOffset_length, &_dataOffset);
        _audioDataByteCount = _fileSize - _dataOffset;
        [self _calculateDuration];
    } else if (propertyID == kAudioFileStreamProperty_DataFormat) {
        UInt32 format_size = sizeof(_format);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &format_size, &_format);
        [self _calculatePacketDuration];
    } else if (propertyID == kAudioFileStreamProperty_FormatList) {
        UInt32 formatList_length;
        Boolean outWriteable;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatList_length, &outWriteable);
        if (status != noErr) {
            NSLog(@"获取kAudioFileStreamProperty_FormatList失败");
            return;
        }
        
        AudioFormatListItem *formatList = malloc(formatList_length);
        UInt32 formatListCount = formatList_length / sizeof(AudioFormatListItem);
        status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatList_length, formatList);
        if (status != noErr) {
            NSLog(@"获取kAudioFileStreamProperty_FormatList失败");
            free(formatList);
            return;
        }
        
        UInt32 supportedFormats_length;
        status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormats_length);
        if (status != noErr) {
            NSLog(@"获取kAudioFormatProperty_DecodeFormatIDs失败");
            free(formatList);
            return;
        }
        
        OSType *supportedFormats = malloc(supportedFormats_length);
        UInt32 supportedFormatsCount = supportedFormats_length / sizeof(OSType);
        status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormats_length, supportedFormats);
        if (status != noErr) {
            NSLog(@"获取kAudioFormatProperty_DecodeFormatIDs失败");
            free(supportedFormats);
            free(formatList);
            return;
        }
        
        for (int i = 0; i < formatListCount; i++) {
            AudioStreamBasicDescription format = formatList[i].mASBD;
            for (int j = 0; j < supportedFormatsCount; j++) {
                if (format.mFormatID == supportedFormats[j]) {
                    _format = format;
                    [self _calculatePacketDuration];
                    break;
                }
            }
        }
        
        free(supportedFormats);
        free(formatList);
    }
}

- (void)handleAudioFileStreamPackets:(const void *)packets numberOfBytes:(UInt32)numberOfBytes numberOfPackets:(UInt32)numberOfPackets packetDescriptions:(AudioStreamPacketDescription *)packetDescriptions {
    if (_discontinuous) {
        _discontinuous = NO;
    }
    
    if (numberOfBytes == 0 || numberOfPackets == 0) {
        return;
    }
    
    BOOL deletePacketDesc = NO;
    if (packetDescriptions == NULL) {
        deletePacketDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        packetDescriptions = malloc(numberOfPackets * sizeof(AudioStreamPacketDescription));
        for (int i = 0; i < numberOfPackets; i++) {
            UInt32 packetOffset = packetSize * i;
            packetDescriptions[i].mStartOffset = packetOffset;
            packetDescriptions[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets - 1) {
                packetDescriptions[i].mDataByteSize = numberOfBytes - packetOffset;
            } else {
                packetDescriptions[i].mDataByteSize = packetSize;
            }
        }
    }
    
    NSMutableArray *parsedDataArray = [NSMutableArray array];
    for (int i = 0; i < numberOfPackets; i++) {
        SInt64 packetOffset = packetDescriptions[i].mStartOffset;
        QSAudioFileStreamParsedData *parsedData = [QSAudioFileStreamParsedData parseDataWithBytes:packets + packetOffset packectDescription:packetDescriptions[i]];
        [parsedDataArray addObject:parsedData];
        
        _processedPacketsSize += parsedData.packetDescription.mDataByteSize;
        _processedPacketsCount += 1;
        
        if (_processedPacketsCount > MinPacketsThatUpdateBitRate && _processedPacketsCount < MaxPacketsThatUpdateBitRate) {
            // 刚开始时近似计算并更新码率
            [self _calculateBitRate];
            [self _calculateDuration];
        }
    }
    
    [_delegate audioFileStream:self audioDataParsed:parsedDataArray];
    
    if (deletePacketDesc) {
        free(packetDescriptions);
    }
}

- (void)_calculateDuration {
    if (_fileSize > 0 && _bitRate > 0) {
        _duration = (_fileSize - _dataOffset) * 8.0 / _bitRate;
    }
}

- (void)_calculateBitRate {
    if (_packetDuration) {
        double packetSize = _processedPacketsSize / _processedPacketsCount;
        _bitRate = packetSize * 8.0 / _packetDuration;
    }
}

- (void)_calculatePacketDuration {
    if (_format.mSampleRate > 0) {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}

- (void)_errorForOSStatus:(OSStatus)status error:(NSError *__autoreleasing *)outError {
    if (status != noErr && outError != NULL) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
}

- (void)_closeAudioFileStream {
    if (!_audioFileStreamID) {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}

@end


