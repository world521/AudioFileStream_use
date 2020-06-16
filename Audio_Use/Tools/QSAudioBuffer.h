//
//  QSAudioBuffer.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>
@class QSAudioParsedData;

@interface QSAudioBuffer : NSObject

+ (instancetype)buffer;

- (void)enqueueData:(QSAudioParsedData *)data;
- (void)enqueueFromDataArray:(NSArray <QSAudioParsedData *>*)dataArray;

- (NSData *)dequeueDataWithSize:(UInt32)requestSize packetCount:(UInt32 *)packetCount descriptions:(AudioStreamPacketDescription **)descriptions;

- (BOOL)hasData;
- (UInt32)bufferedSize;
- (void)clean;

@end
