//
//  QSTool.m
//  Demo
//
//  Created by fengqingsong on 2020/6/2.
//  Copyright © 2020 fqs. All rights reserved.
//

#import "QSTool.h"
#import <AVKit/AVKit.h>

@implementation QSTool

//http://music.163.com/song/media/outer/url?id=299449.mp3
//http://music.163.com/song/media/outer/url?id=1378603811.mp3

+ (void)create {
    // <一> 初始化AudioFileStream
    AudioFileStreamID fileStreamID = NULL;
    // 参数4:如果不知道文件的格式传0, 如果知道建议传上
    OSStatus status = AudioFileStreamOpen(NULL, audioFileStream_PropertyCallBack, audioFileStream_PacketsCallBack, 0, &fileStreamID);
    if (status != noErr) {
        NSLog(@"AudioFileStream初始化失败");
        return;
    }
    
    // <二> 开始解析数据
    void *byteData = NULL;
    UInt32 byteLength = 0;
    // 参数4:本次解析跟上一次连续传0 本次解析跟上一次不连续传kAudioFileStreamParseFlag_Discontinuity
    status = AudioFileStreamParseBytes(fileStreamID, byteLength, byteData, 0);
    if (status != noErr) {
        NSLog(@"AudioFileStream解析数据失败");
        return;
    }
    if (status == kAudioFileStreamError_NotOptimized) {
        // 音频文件头不存在或者文件头可能在文件的末尾, 无法正常parse
        NSLog(@"AudioFileStream无法解析流播, 需全部下载完才能播放");
        return;
    }
}

#pragma mark - 歌曲信息回调 解析帧数据回调

/**
 歌曲信息解析回调
 */
void audioFileStream_PropertyCallBack(void *inClientData, AudioFileStreamID inAudioFileStream, AudioFileStreamPropertyID inPropertyID, AudioFileStreamPropertyFlags *ioFlags) {
    if (inPropertyID == kAudioFileStreamProperty_BitRate) {
        // 码率
        UInt32 bitRate;
        UInt32 bitRateSize = sizeof(bitRate);
        OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &bitRateSize, &bitRate);
        if (status == noErr) {
            NSLog(@"成功获取到音频信息kAudioFileStreamProperty_BitRate: 帧率%d", bitRate);
        }
        /*
         有时数据流量比较小时会出现ReadyToProducePackets还是没有获取到bitRate的情况，
         这时就需要分离一些音频帧然后计算平均bitRate，计算公式如下：
         UInt32 averageBitRate = totalPackectByteCount / totalPacketCout;
         */
    } else if (inPropertyID == kAudioFileStreamProperty_DataOffset) {
        // 真实音频数据的offset(因为存在文件头)
        SInt64 dataOffset;
        UInt32 offsetSize = sizeof(dataOffset);
        OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &offsetSize, &dataOffset);
        if (status == noErr) {
            NSLog(@"成功获取到音频信息kAudioFileStreamProperty_DataOffset 真实音频数据offset%lld", dataOffset);
        }
    } else if (inPropertyID == kAudioFileStreamProperty_DataFormat) {
        // 音频格式信息(AudioStreamBasicDescription结构体)
        AudioStreamBasicDescription basicDesc;
        UInt32 descSize = sizeof(basicDesc);
        OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &descSize, &basicDesc);
        if (status == noErr) {
            NSLog(@"获取音频信息的kAudioFileStreamProperty_DataFormat成功: 帧率%f 帧大小%d", basicDesc.mSampleRate, basicDesc.mBytesPerPacket);
        }
    } else if (inPropertyID == kAudioFormatProperty_FormatList) {
        Boolean writable;
        UInt32 formatListDataSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(inAudioFileStream, inPropertyID, &formatListDataSize, &writable);
        if (status != noErr) {
            NSLog(@"获取音频信息的 kAudioFormatProperty_FormatList 的 PropertyInfo 失败");
            return;
        }
        
        AudioFormatListItem *formatList = malloc(formatListDataSize);
        status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &formatListDataSize, formatList);
        if (status != noErr) {
            NSLog(@"获取音频信息的 kAudioFormatProperty_FormatList 失败");
        }
        
        int listCount = formatListDataSize / sizeof(AudioFormatListItem);
        for (int i = 0; i < listCount; i++) {
            AudioFormatListItem item = formatList[i];
            AudioStreamBasicDescription desc = item.mASBD;
            NSLog(@"获取音频信息的kAudioFormatProperty_FormatList成功: 帧率%f 帧大小%d", desc.mSampleRate, desc.mBytesPerPacket);
        }
        free(formatList);
    } else if (inPropertyID == kAudioFileStreamProperty_AudioDataByteCount) {
        // 真实音频数据总量
        UInt64 audioDataByteCount;
        UInt32 byteCountSize = sizeof(audioDataByteCount);
        OSStatus status = AudioFileStreamGetProperty(inAudioFileStream, inPropertyID, &byteCountSize, &audioDataByteCount);
        if (status != noErr) {
            NSLog(@"获取音频信息的 kAudioFileStreamProperty_AudioDataByteCount 失败");
        }
        /*
         在流播放的情况下，有时数据流量比较小时会出现ReadyToProducePackets时,
         但是还没有获取到audioDataByteCount的情况，这时就需要近似计算audioDataByteCount。
         一般来说音频文件的总大小一定是可以得到的（利用文件系统或者Http请求中的contentLength）
         UInt64 dataOffset = ...; //kAudioFileStreamProperty_DataOffset
         UInt64 fileLength = ...; //音频文件大小
         UInt64 audioDataByteCount = fileLength - dataOffset;
         */
    } else if (inPropertyID == kAudioFileStreamProperty_ReadyToProducePackets) {
        // 代表音频解析完成，接下来可以对音频数据进行帧分离了
        NSLog(@"获取音频信息完成: 可以进行音频数据帧分离了");
    }
    
    /*
     音频总时长的获取:
     获取时长的最佳方法是从ID3信息中去读取，那样是最准确的。如果ID3信息中没有存，那就依赖于文件头中的信息去计算了。
     
     音频数据的字节总量audioDataByteCount可以通过kAudioFileStreamProperty_AudioDataByteCount获取，
     码率bitRate可以通过kAudioFileStreamProperty_BitRate获取也可以通过Parse一部分数据后计算平均码率来得到。
     计算duration的公式如下：double duration = (audioDataByteCount * 8) / bitRate
     
     对于CBR数据来说用这样的计算方法的duration会比较准确，对于VBR数据就不好说了。
     所以对于VBR数据来说，最好是能够从ID3信息中获取到duration，获取不到再想办法通过计算平均码率的途径来计算duration。
     */
     
}

/**
 分离部分帧的回调
 */
void audioFileStream_PacketsCallBack(void *inClientData, UInt32 inNumberBytes, UInt32                            inNumberPackets, const void *inInputData, AudioStreamPacketDescription *inPacketDescriptions) {
    if (inNumberBytes == 0 || inNumberPackets == 0) {
        return;
    }

    // AudioStreamPacketDescription 存储着每一帧从第几个字节开始的, 这一帧共有多少字节
    // AudioStreamPacketDescription mVariableFramesInPacket VBR的数据会用得到(一个帧里会有好几个数据帧)

    // 如果inPacketDescriptions不存在, 可以按照CBR来处理;
    // 另外, 即使存在inPacketDescriptions也不一定代表就是VBR, 因为CBR帧大小也不是固定的
    BOOL needFreePackedDesc = NO;
    if (inPacketDescriptions == NULL) {
        needFreePackedDesc = YES;
        UInt32 packetSize = inNumberBytes / inNumberPackets;
        inPacketDescriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * inNumberPackets);
        
        for (int i = 0; i < inNumberPackets; i++) {
            UInt32 packetOffset = packetSize * i;
            inPacketDescriptions[i].mStartOffset = packetOffset;
            inPacketDescriptions[i].mVariableFramesInPacket = 0;
            if (i == inNumberPackets - 1) {
                inPacketDescriptions[i].mDataByteSize = inNumberPackets - packetOffset;
            } else {
                inPacketDescriptions[i].mDataByteSize = packetSize;
            }
        }
    }
    
    for (int i = 0; i < inNumberPackets; i++) {
        SInt64 packetOffset = inPacketDescriptions[i].mStartOffset;
        UInt32 packetSize = inPacketDescriptions[i].mDataByteSize;
        NSLog(@"解析出来帧数据: 帧起始偏移量 %lld 帧数据长度 %d", packetOffset, packetSize);
#warning 使用解析出来的帧数据
    }
    
    if (needFreePackedDesc) free(inPacketDescriptions);
}

#pragma mark - seek逻辑

/*
 原始的PCM数据来说每一个PCM帧都是固定长度的，对应的播放时长也是固定的，压缩后的音频数据就会因为编码形式的不同而不同了。
 对于CBR而言每个帧中所包含的PCM数据帧是恒定的，所以每一帧对应的播放时长也是恒定的；
 而VBR则不同，为了保证数据最优并且文件大小最小，VBR的每一帧中所包含的PCM数据帧是不固定的，
 这就导致在流播放的情况下VBR的数据想要做seek并不容易。这里只讨论CBR下的seek。
 */

- (void)seek:(double)seekToTime {
    // 近似计算seek到哪一个字节
    UInt64 audioDataByteCount = 0; // 通过kAudioFileStreamProperty_AudioDataByteCount获取的值
    SInt64 dataOffset = 0; // 通过kAudioFileStreamProperty_DataOffset获取的值
    UInt32 bitRate = 0; // 通过kAudioFileStreamProperty_BitRate获取的值
    double duration = audioDataByteCount * 8 / bitRate; // 计算音频时长
    SInt64 seekOffset = dataOffset + (seekToTime / duration) * audioDataByteCount;
    NSLog(@"%lld", seekOffset);
    
    // 计算seek到第几个packet
    AudioStreamBasicDescription asbd; // 通过kAudioFileStreamProperty_DataFormat或者kAudioFormatProperty_FormatList获取的值
    double packetDuration = asbd.mFramesPerPacket / asbd.mSampleRate;
    SInt64 seetToPacket = floor(seekToTime / packetDuration);
}

@end
