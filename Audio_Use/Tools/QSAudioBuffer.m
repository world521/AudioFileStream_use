//
//  QSAudioBuffer.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioBuffer.h"
#import "QSAudioParsedData.h"

@interface QSAudioBuffer()
{
    NSMutableArray *_bufferBlockArray;
    UInt32 _bufferedSize;
}
@end

@implementation QSAudioBuffer

+ (instancetype)buffer {
    return [[self alloc] init];
}

- (instancetype)init {
    if (self = [super init]) {
        _bufferBlockArray = [NSMutableArray array];
    }
    return self;
}


- (BOOL)hasData {
    return _bufferedSize > 0;
}

- (UInt32)bufferedSize {
    return _bufferedSize;
}

- (void)enqueueData:(QSAudioParsedData *)data {
    if ([data isKindOfClass:[QSAudioParsedData class]]) {
        [_bufferBlockArray addObject:data];
        _bufferedSize += data.data.length;
    }
}

- (void)enqueueFromDataArray:(NSArray<QSAudioParsedData *> *)dataArray {
    for (QSAudioParsedData *data in dataArray) {
        [self enqueueData:data];
    }
}

- (NSData *)dequeueDataWithSize:(UInt32)requestSize packetCount:(UInt32 *)packetCount descriptions:(AudioStreamPacketDescription **)descriptions {
    if (requestSize == 0 || _bufferBlockArray.count == 0) {
        *packetCount = 0;
        return nil;
    }
    
    UInt32 size = 0;
    UInt32 count = 0;
    for (int i = 0; i < _bufferBlockArray.count; i++) {
        QSAudioParsedData *block = _bufferBlockArray[i];
        size += block.data.length;
        if (size > requestSize) {
            count = i;
            break;
        } else if (size == requestSize) {
            count = i + 1;
            break;
        }
    }
    
    count = size < requestSize ? (UInt32)_bufferBlockArray.count : count;
    *packetCount = count;
    if (count == 0) {
        return nil;
    }
    
    if (descriptions) {
        *descriptions = malloc(sizeof(AudioStreamPacketDescription) * count);
    }
    
    NSMutableData *mutData = [NSMutableData data];
    for (int i = 0; i < count; i++) {
        QSAudioParsedData *block = _bufferBlockArray[i];
        if (descriptions) {
            (*descriptions)[i] = block.packetDescription;
            (*descriptions)[i].mStartOffset = mutData.length;
        }
        [mutData appendData:block.data];
    }
    
    [_bufferBlockArray removeObjectsInRange:NSMakeRange(0, count)];
    _bufferedSize -= mutData.length;
    
    return mutData;
}

- (void)clean {
    _bufferedSize = 0;
    [_bufferBlockArray removeAllObjects];
}

@end
