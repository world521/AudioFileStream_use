//
//  ViewController.m
//  AudioFileStream_use
//
//  Created by fengqingsong on 2020/6/5.
//  Copyright © 2020 agant. All rights reserved.
//

#import "ViewController.h"
#import "QSAudioFileStream.h"

@interface ViewController () <QSAudioFileStreamDelegate> {
    QSAudioFileStream *_audioFileStream;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)fire:(UIButton *)sender {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"babamama" ofType:@"mp3"];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileSize];
    NSError *error;
    _audioFileStream = [[QSAudioFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:fileSize error:&error];
    _audioFileStream.delegate = self;
    if (error) return;
    
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!file) return;
    
    UInt32 lengthPerRead = 10000;
    while (fileSize) {
        NSData *data = [file readDataOfLength:lengthPerRead];
        fileSize -= data.length;
        [_audioFileStream parseData:data error:&error];
        if (error) {
            if (error.code == kAudioFileStreamError_NotOptimized) {
                NSLog(@"audio not optimized");
            }
            break;
        }
    }
    
    
}

@end
