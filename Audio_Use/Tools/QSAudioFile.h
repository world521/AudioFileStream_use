//
//  QSAudioFile.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/12.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@class QSAudioParsedData;

@interface QSAudioFile : NSObject

@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;
@property (nonatomic, assign, readonly) unsigned long long fileSize;
@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign, readonly) UInt32 bitRate;
@property (nonatomic, assign, readonly) UInt64 audioDataByteCount;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) UInt32 maxPacketSize;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;
- (NSArray <QSAudioParsedData *>*)parseData:(BOOL *)isEOF;
- (void)seekToTime:(NSTimeInterval)seekTime;
- (NSData *)fetchMagicCookie;
- (void)close;

@end
