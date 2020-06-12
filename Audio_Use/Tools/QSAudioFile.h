//
//  QSAudioFile.h
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/12.
//  Copyright © 2020 agant. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

NS_ASSUME_NONNULL_BEGIN

@interface QSAudioFile : NSObject

@property (nonatomic, copy, readonly) NSString *filePath;
@property (nonatomic, assign, readonly) AudioFileTypeID fileType;
@property (nonatomic, assign, readonly) unsigned long long fileSize;

- (instancetype)initWithFilePath:(NSString *)filePath fileType:(AudioFileTypeID)fileType;

@end

NS_ASSUME_NONNULL_END
