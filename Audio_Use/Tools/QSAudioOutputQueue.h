//
//  QSAudioOutputQueue.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/16.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface QSAudioOutputQueue : NSObject

@property (nonatomic, assign, readonly) AudioStreamBasicDescription format;
@property (nonatomic, assign, readonly) UInt32 bufferSize;
@property (nonatomic, assign) float volume;

- (instancetype)initWithFormat:(AudioStreamBasicDescription)format bufferSize:(UInt32)bufferSize magicCookie:(NSData *)magicCookie;

@end

NS_ASSUME_NONNULL_END
