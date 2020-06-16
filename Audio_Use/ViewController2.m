//
//  ViewController2.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/15.
//  Copyright © 2020 agant. All rights reserved.
//

#import "ViewController2.h"
#import "QSAudioPlayer.h"

@interface ViewController2 ()
{
    QSAudioPlayer *_player;
}

@end

@implementation ViewController2

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    
}

- (IBAction)pauseClicked:(UIButton *)sender {
    
}

- (IBAction)stopClicked:(UIButton *)sender {
    
}

- (IBAction)sliderValueChanged:(UISlider *)sender {
    
}


@end
