//
//  QSAudioFileStream.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/11.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
@class QSAudioFileStream;
@class QSAudioParsedData;

@protocol QSAudioFileStreamDelegate <NSObject>
@required
- (void)audioFileStream:(QSAudioFileStream *)audioFileStream audioDataParsed:(NSArray <QSAudioParsedData *> *)audioData;
@optional
- (void)audioFileStreamReadyToProducePackets:(QSAudioFileStream *)audioFileStream;
@end

@interface QSAudioFileStream : NSObject

@property (nonatomic, weak) id<QSAudioFileStreamDelegate> delegate;

@property (nonatomic, assign, readonly) AudioFileTypeID fileType;
@property (nonatomic, assign, readonly) UInt64 fileSize;
@property (nonatomic, assign, readonly) BOOL readyToProducePackets;

@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly) UInt64 audioDataByteCount;
@property (nonatomic, assign, readonly) UInt32 bitRate;

@property (nonatomic, assign, readonly) UInt32 maxPacketSize;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType fileSize:(UInt64)fileSize error:(NSError *__autoreleasing *)error;
- (BOOL)parseData:(NSData *)data error:(NSError *__autoreleasing *)error;
- (NSData *)fetchMagicCookie;
- (SInt64)seekToTime:(NSTimeInterval *)ioSeekTime;
- (void)close;

@end

