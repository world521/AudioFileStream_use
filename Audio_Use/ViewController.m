//
//  ViewController.m
//  AudioFileStream_use
//
//  Created by fengqingsong on 2020/6/5.
//  Copyright © 2020 agant. All rights reserved.
//

#import "ViewController.h"
#import "QSAudioFileStream.h"
#import "QSAudioFile.h"
#import "QSAudioParsedData.h"

@interface ViewController () <QSAudioFileStreamDelegate>
{
    NSFileHandle *_file;
    QSAudioFileStream *_audioFileStream;
    
    QSAudioFile *_audioFile;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
}

- (IBAction)fire:(UIButton *)sender {
    [self test_QSAudioFile];
}

- (IBAction)fire2:(UIButton *)sender {
    
}

- (IBAction)fire3:(UIButton *)sender {
    
}

#pragma mark - QSAudioFile

- (void)test_QSAudioFile {
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    _audioFile = [[QSAudioFile alloc] initWithFilePath:path fileType:kAudioFileMP3Type];
    BOOL isEOF = NO;
    while(!isEOF) {
        NSArray <QSAudioParsedData *>*parsedData = [_audioFile parseData:&isEOF];
        NSLog(@"解析出来的数据packet大小: %ld", parsedData.count);
    }
}

#pragma mark - QSAudioFileStream

- (void)test_QSAudioFileStream {
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"她来听我的演唱会" ofType:@"mp3"];
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"小城大事" ofType:@"mp3"];
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL] fileSize];
    
    NSError *error;
    _audioFileStream = [[QSAudioFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:fileSize error:&error];
    _audioFileStream.delegate = self;
    if (error) return;
    
    _file = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!_file) return;
    
    UInt32 lengthPerRead = 10000;
    while (fileSize) {
        NSData *data = [_file readDataOfLength:lengthPerRead];
        fileSize -= data.length;
        [_audioFileStream parseData:data error:&error];
        if (error) {
            if (error.code == kAudioFileStreamError_NotOptimized) {
                NSLog(@"audio not optimized");
            }
            break;
        }
    }
    
    NSLog(@"audio format: bitrate = %d, duration = %f.", _audioFileStream.bitRate, _audioFileStream.duration);
    
    [_audioFileStream close];
    _audioFileStream = nil;
    [_file closeFile];
    _file = nil;
}

- (void)audioFileStreamReadyToProducePackets:(QSAudioFileStream *)audioFileStream {
    NSLog(@"开始解析Packet了");
}

- (void)audioFileStream:(QSAudioFileStream *)audioFileStream audioDataParsed:(NSArray<QSAudioParsedData *> *)audioData {
    NSLog(@"解析出Packet了 个数:%ld", audioData.count);
}

@end
