//
//  QSAudioParsedData.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface QSAudioParsedData : NSObject
@property (nonatomic, strong, readonly) NSData *data;
@property (nonatomic, assign, readonly) AudioStreamPacketDescription packetDescription;
+ (instancetype)parseDataWithBytes:(const void *)bytes packectDescription:(AudioStreamPacketDescription)packetDescription;
@end

NS_ASSUME_NONNULL_END
