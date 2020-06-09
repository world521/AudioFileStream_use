//
//  AudioFile_Use.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/9.
//  Copyright © 2020 agant. All rights reserved.
//

#import "AudioFile_Use.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioFile_Use

#pragma mark - 打开音频文件

- (void)start {
    /*
    // <一>打开音频文件(方式1: 读取本地文件)
    NSURL *url = [NSURL URLWithString:@"http://music.163.com/song/media/outer/url?id=198620.mp3"];
    CFURLRef inFileRef = (__bridge_retained CFURLRef)url;
    AudioFileID audioFile;
    OSStatus status = AudioFileOpenURL(inFileRef, kAudioFileReadPermission, kAudioFileMP3Type, &audioFile);
    if (status == noErr) {
        NSLog(@"打开音频文件成功");
    }
     */
    
    // <一>打开音频文件(方式2: 自由度更高)
    // AudioFile在Open方法调用时就会对音频格式信息进行解析，只有符合要求的音频格式才能被成功打开, 否则Open方法就会返回错误码
    // 换句话说，Open方法一旦调用成功就相当于AudioStreamFile在Parse后返回ReadyToProducePackets一样，
    // 只要Open成功就可以开始读取音频数据，所以在Open方法调用的过程中就需要提供一部分音频数据来进行解析；
    void *inClientData = NULL;
    AudioFileID audioFile;
    OSStatus status = AudioFileOpenWithCallbacks(inClientData, audioFile_ProcCallBack, NULL, audioFile_sizeProcCallBack, NULL, kAudioFileMP3Type, &audioFile);
    if (status == noErr) {
        NSLog(@"打开音频文件成功");
    }
}

// 调用Open或者Read后同步回调, 获取对应字节的音频数据
OSStatus audioFile_ProcCallBack(void *inClientData, SInt64 inPosition, UInt32 requestCount, void *buffer, UInt32 *actualCount) {
    // 1. 有充足的数据：把这个范围内的数据拷贝到buffer中，并且给actualCount赋值requestCount，最后返回noError；
    // 2. 数据不足：没有充足数据的话就只能把手头有的数据拷贝到buffer中，需要注意的是这部分被拷贝的数据必须是从inPosition开始的连续数据，
    // 3. 拷贝完成后给actualCount赋值实际拷贝进buffer中的数据长度后返回noErr
    NSData *data = nil;
    memcpy(buffer, data.bytes, data.length);
    *actualCount = (UInt32)data.length;
    return noErr;
    /*
     AudioFile的Open方法会根据文件格式类型分几步进行数据读取以解析确定是否是一个合法的文件格式，
     其中每一步的inPosition和requestCount都不一样，如果某一步不成功就会直接进行下一步，如果几部下来都失败了，那么Open方法就会失败。
     简单的说就是在调用Open之前首先需要保证音频文件的格式信息完整，这就意味着AudioFile并不能独立用于音频流的读取，
     在流播放时首先需要使用AudioStreamFile来得到ReadyToProducePackets标志位来保证信息完整；
     */
}

// 调用Open或者Read后同步回调, 获取音频文件的大小
SInt64 audioFile_sizeProcCallBack(void *inClientData) {
    return 0;
}

#pragma mark - 读取音频格式

- (void)readFormat {
    AudioFileID audioFile = NULL;
    
    // <二>读取音频格式信息
    // 成功打开音频文件后就可以读取其中的格式信息了
    // 获取码率:
    UInt32 bitRate;
    UInt32 bitRateSize = sizeof(bitRate);
    OSStatus status = AudioFileGetProperty(audioFile, kAudioFilePropertyBitRate, &bitRateSize, &bitRate);
    if (status == noErr) {
        NSLog(@"获取码率成功");
    }
    // 获取格式信息:
    UInt32 formatListSize;
    status = AudioFileGetPropertyInfo(audioFile, kAudioFilePropertyFormatList, &formatListSize, NULL);
    if (status != noErr) {
        NSLog(@"获取音频格式失败");
        return;
    }
    AudioFormatListItem *formatList = (AudioFormatListItem *)malloc(formatListSize);
    status = AudioFileGetProperty(audioFile, kAudioFilePropertyFormatList, &formatListSize, formatList);
    if (status != noErr) {
        NSLog(@"获取音频格式失败");
        return;
    }
    UInt32 formatListCount = formatListSize / sizeof(AudioFormatListItem);
    for (UInt32 i = 0; i < formatListCount; i++) {
        AudioFormatListItem item = formatList[i];
        AudioStreamBasicDescription asbd = item.mASBD;
        NSLog(@"获取音频格式成功: mFormatID:%d mSampleRate:%f", asbd.mFormatID, asbd.mSampleRate);
    }
    free(formatList);
    // 通过AudioFilePropertyID的不同类型(如kAudioFilePropertyDataFormat)还可以获取更多的格式信息, 略...
}

#pragma mark - 读取音频数据

- (void)readData {
    AudioFileID audioFile = NULL;
    
    // 按字节读取音频数据
    // 使用这个方法得到的数据都是没有进行过帧分离的数据，如果想要用来播放或者解码还必须通过AudioFileStream进行帧分离；
    /*
    SInt64 startByte = 0;
    UInt32 numBytes = 0;
    void *data = malloc(numBytes);
    OSStatus status = AudioFileReadBytes(audioFile, false, startByte, &numBytes, data);
    if (status == noErr) {
        NSLog(@"读取音频数据成功");
    }
     */
    
    // 按Packet读取音频数据
    SInt64 inStartingPacket = 0;
    UInt32 ioNumPackets = 0;
    UInt32 bytesPerPacket = 0; //通过kAudioFilePropertyFormatList的AudioStreamBasicDescription获取
    UInt32 ioNumBytes = bytesPerPacket * ioNumPackets;
    AudioStreamPacketDescription *outPacketDescriptions = malloc(ioNumPackets * sizeof(AudioStreamPacketDescription));
    void *outBuffer = malloc(ioNumBytes);
    OSStatus status = AudioFileReadPacketData(audioFile, false, &ioNumBytes, outPacketDescriptions, inStartingPacket, &ioNumPackets, outBuffer);
    if (status == noErr) {
        NSLog(@"按Packet获取音频数据成功");
    }
    free(outPacketDescriptions);
    free(outBuffer);
}

#pragma mark - seek

- (void)seek:(double)seekToTime {
    // seek的思路和之前讲AudioFileStream时讲到的是一样的，
    // 区别在于AudioFile没有方法来帮助修正seek的offset和seek的时间
    // 使用AudioFileReadBytes时需要计算出approximateSeekOffset
    // 使用AudioFileReadPacketData或者AudioFileReadPackets时需要计算出seekToPacket
}

#pragma mark - 关闭

- (void)close {
    AudioFileID audioFile = NULL;
    OSStatus status = AudioFileClose(audioFile);
    if (status == noErr) {
        NSLog(@"关闭AudioFile成功");
    }
}

@end
