//
//  QSAudioPlayer.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioFile.h>

typedef NS_ENUM(NSUInteger, QSAudioPlayerStatus) {
    QSAPStatusStopped = 0,
    QSAPStatusPlaying,
    QSAPStatusWaiting,
    QSAPStatusPaused,
    QSAPStatusFlushing
};

@interface QSAudioPlayer : NSObject

@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;

@property (nonatomic, assign, readonly) QSAudioPlayerStatus status;
@property (nonatomic, assign, readonly) BOOL failed;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;

@end

