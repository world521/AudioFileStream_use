//
//  Audio_Play.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/11.
//  Copyright © 2020 agant. All rights reserved.
//

#import "Audio_Play.h"
#import <AVFoundation/AVFoundation.h>

@implementation Audio_Play

- (void)go {
    NSError *error;
    
    // 设置音频会话模式
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    if (!error) {
        NSLog(@"设置AVAudioSession会话模式成功");
    } else {
        NSLog(@"设置AVAudioSession音频会话模式失败");
        return;
    }
    
    // 打断通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(interruptHandler:) name:AVAudioSessionInterruptionNotification object:nil];
    NSLog(@"添加被打断时的监听通知");
    
    // 激活音频会话
    [[AVAudioSession sharedInstance] setActive:YES withOptions:0 error:&error];
    if (!error) {
        NSLog(@"激活AVAudioSession成功");
    } else {
        NSLog(@"激活AVAudioSession失败");
        return;
    }
    
    
}

/**
 打断逻辑
 */
- (void)interruptHandler:(NSNotification *)notifi {
    
}

@end
