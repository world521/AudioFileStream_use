//
//  QSAudioParsedData.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import "QSAudioParsedData.h"

@implementation QSAudioParsedData

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
