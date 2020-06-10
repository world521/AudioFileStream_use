//
//  AudioQueue_Use.m
//  Audio_Use
//
//  Created by fengqingsong on 2020/6/9.
//  Copyright © 2020 agant. All rights reserved.
//

#import "AudioQueue_Use.h"
#import <AVFoundation/AVFoundation.h>

@implementation AudioQueue_Use

/*
 https://github.com/mattgallagher/AudioStreamer
 https://github.com/muhku/FreeStreamer
 https://github.com/msching/MCSimpleAudioPlayer
 */

/*
 根据Apple提供的AudioQueue工作原理结合自己理解，可以得到其工作流程大致如下：
 1. 创建AudioQueue，创建一个自己的buffer数组BufferArray;
 2. 使用AudioQueueAllocateBuffer创建若干个AudioQueueBufferRef（一般2-3个即可），放入BufferArray；
 3. 有数据时从BufferArray取出一个buffer，memcpy数据后用AudioQueueEnqueueBuffer方法把buffer插入AudioQueue中；
 4. AudioQueue中存在Buffer后，调用AudioQueueStart播放。（具体等到填入多少buffer后再播放可以自己控制，只要能保证播放不间断即可）；
 5. AudioQueue播放音乐后消耗了某个buffer，在另一个线程回调并送出该buffer，把buffer放回BufferArray供下一次使用；
 6. 返回步骤3继续循环直到播放结束
 */

#pragma mark - 创建AudioQueue

- (void)start {
    AudioStreamBasicDescription *inFormat;
    void *inUserData = NULL;
    AudioQueueRef outAQ;
    // 参数2: 表示某块Buffer被使用之后的回调；
    // 参数4: 表示AudioQueueOutputCallback需要在的哪个RunLoop上被回调，
    //       如果传入NULL的话就会在AudioQueue的内部RunLoop中被回调，所以一般传NULL就可以了；
    // 参数5: 表示RunLoop模式，如果传入NULL就相当于kCFRunLoopCommonModes，也传NULL就可以了；
    // 参数6: inFlags是保留字段，目前没作用，传0；
    // 还有一个创建AudioQueue的方法: AudioQueueNewOutputWithDispatchQueue, 仅仅把RunLoop替换成了一个dispatch_queue_t
    OSStatus status = AudioQueueNewOutput(inFormat, AudioQueueOutputCallback_Func, inUserData, NULL, NULL, 0, &outAQ);
    if (status == noErr) {
        NSLog(@"创建AudioQueue成功");
    }
}

// 某块Buffer被使用之后的回调
void AudioQueueOutputCallback_Func(void * __nullable inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer) {
    
}

#pragma mark - Buffer相关

/// 创建Buffer
- (void)createBuffer {
    /*
    AudioQueueRef inAQ = NULL;
    UInt32 inBufferByteSize = 0;
    AudioQueueBufferRef outBuffer;
    OSStatus status = AudioQueueAllocateBuffer(inAQ, inBufferByteSize, &outBuffer);
    if (status == noErr) {
        NSLog(@"创建AudioQueueBufferRef成功");
    }
     */
    
    AudioQueueRef inAQ = NULL;
    UInt32 inBufferByteSize = 0;
    UInt32 inNumberPacketDescriptions = 0;
    AudioQueueBufferRef outBuffer = NULL;
    OSStatus status = AudioQueueAllocateBufferWithPacketDescriptions(inAQ, inBufferByteSize, inNumberPacketDescriptions, &outBuffer);
    if (status == noErr) {
        NSLog(@"创建AudioQueueBuffer成功");
    }
}

/// 销毁Buffer
- (void)destroyBuffer {
    // 注意这个方法一般只在需要销毁特定某个buffer时才会被用到（因为dispose方法会自动销毁所有buffer），
    // 并且这个方法只能在AudioQueue不在处理数据时才能使用。所以这个方法一般不太能用到。
    AudioQueueRef inAQ = NULL;
    AudioQueueBufferRef inBuffer = NULL;
    OSStatus status = AudioQueueFreeBuffer(inAQ, inBuffer);
    if (status == noErr) {
        NSLog(@"销毁AudioQueueBuffer成功");
    }
}

/// 插入Buffer
- (void)enqueueBuffer {
    AudioQueueRef inAQ = NULL;
    AudioQueueBufferRef inBuffer = NULL;
    UInt32 inNumPacketDescs = 0;
    AudioStreamPacketDescription *inPacketDescs = NULL;
    // 参数3和参数4:
    // 对于有inNumPacketDescs和inPacketDescs则需要根据需要选择传入，文档上说这两个参数主要是在播放VBR数据时使用，
    // 但之前我们提到过即便是CBR数据AudioFileStream或者AudioFile也会给出PacketDescription所以不能如此一概而论。
    // 简单的来说就是有就传PacketDescription没有就给NULL，不必管是不是VBR。
    OSStatus status = AudioQueueEnqueueBuffer(inAQ, inBuffer, inNumPacketDescs, inPacketDescs);
    if (status == noErr) {
        NSLog(@"插入AudioQueueBuffer成功");
    }
}

#pragma mark - 播放控制

- (void)play {
    // 开始播放
    AudioQueueRef inAQ = NULL;
    // 参数2: 可以用来控制播放开始的时间，一般情况下直接开始播放传入NULL即可。
    OSStatus status = AudioQueueStart(inAQ, NULL);
    if (status == noErr) {
        NSLog(@"开始播放成功");
    }
    
    // 解码数据
    // 这个方法并不常用，因为直接调用AudioQueueStart会自动开始解码（如果需要的话）。
    UInt32 inNumberOfFramesToPrepare = 0;
    UInt32 outNumberOfFramesPrepared = 0;
    // 参数2和参数3: 用来指定需要解码帧数和实际完成解码的帧数；
    status = AudioQueuePrime(inAQ, inNumberOfFramesToPrepare, &outNumberOfFramesPrepared);
    if (status == noErr) {
        NSLog(@"解码成功");
    }
    
    // 暂停播放
    // 需要注意的是这个方法一旦调用后播放就会立即暂停，这就意味着AudioQueueOutputCallback回调也会暂停，
    // 这时需要特别关注线程的调度以防止线程陷入无限等待
    status = AudioQueuePause(inAQ);
    if (status == noErr) {
        NSLog(@"暂停播放成功");
    }
    
    // 停止播放
    // 第二个参数如果传入true的话会立即停止播放（同步），如果传入false的话AudioQueue
    // 会播放完已经Enqueue的所有buffer后再停止（异步）。使用时注意根据需要传入适合的参数。
    status = AudioQueueStop(inAQ, true);
    
    // Flush
    // 调用后会播放完Enqueu的所有buffer后重置解码器状态，以防止当前的解码器状态
    // 影响到下一段音频的解码（比如切换播放的歌曲时）。如果和AudioQueueStop(AQ,false)一起使用并不会起效，
    // 因为Stop方法的false参数也会做同样的事情。
    status = AudioQueueFlush(inAQ);
    
    // 重置
    // 重置AudioQueue会清除所有已经Enqueue的buffer，并触发AudioQueueOutputCallback,调用AudioQueueStop方法时同样会触发该方法。
    // 这个方法的直接调用一般在seek时使用，用来清除残留的buffer（seek时还有一种做法是先AudioQueueStop，等seek完成后重新start）。
    status = AudioQueueReset(inAQ);
    
    // 获取播放时间
    // 参数2: 传入NULL
    AudioTimeStamp outTimeStamp;
    Boolean outTimelineDiscontinuity;
    status = AudioQueueGetCurrentTime(inAQ, NULL, &outTimeStamp, &outTimelineDiscontinuity);
    AudioStreamBasicDescription asbd; // 之前的获取到的音频格式信息
    NSTimeInterval currentTime = outTimeStamp.mSampleTime / asbd.mSampleRate;
    NSLog(@"当前时间: %f", currentTime);
    /*
      1、 第一个需要注意的时这个播放时间是指实际播放的时间和一般理解上的播放进度是有区别的。
      举个例子，开始播放8秒后用户操作slider把播放进度seek到了第20秒之后又播放了3秒钟，此时通常意义上播放时间应该是23秒，即播放进度；
      而用GetCurrentTime方法中获得的时间为11秒，即实际播放时间。
     
      所以每次seek时都必须保存seek的timingOffset;
      NSTimeInterval seekTime = 0;
      NSTimeInterval currentTime = 0;
      NSTimeInterval timingOffset = seekTime - currentTime;
     
      seek后获取当前播放时间需要加上timingOffset;
      NSTimeInterval currTime = timingOffset + currentTime;
     
      2、 第二个需要注意的是GetCurrentTime方法有时候会失败，所以上次获取的播放时间最好保存起来，如果遇到调用失败，就返回上次保存的结果。
     */
    
    // 销毁AudioQueue
    status = AudioQueueDispose(inAQ, true);
    /*
     这个方法使用时需要注意当AudioQueueStart调用之后AudioQueue其实还没有真正开始，期间会有一个短暂的间隙。
     如果在AudioQueueStart调用后到AudioQueue真正开始运作前的这段时间内调用AudioQueueDispose方法的话会导致程序卡死。
     
     如AudioStreamer库会在音频EOF时就进入Cleanup环节，Cleanup环节会flush所有数据然后调用Dispose，
     那么当音频文件中数据非常少时就有可能出现AudioQueueStart调用之时就已经EOF进入Cleanup，此时就会出现上述问题。
     
     要规避这个问题第一种方法是做好线程的调度，保证Dispose方法调用一定是在每一个播放RunLoop之后（即至少是一个buffer被成功播放之后）。
     第二种方法是监听kAudioQueueProperty_IsRunning属性，这个属性在AudioQueue真正运作起来之后会变成1，停止后会变成0，
     所以需要保证Start方法调用后Dispose方法一定要在IsRunning为1时才能被调用。
     */
}

#pragma mark - AudioQueue的几个有用的属性和参数

/*
 其中比较有价值的属性有：
 kAudioQueueProperty_IsRunning监听它可以知道当前AudioQueue是否在运行，这个参数的作用在讲到AudioQueueDispose时已经提到过。
 kAudioQueueProperty_MagicCookie部分音频格式需要设置magicCookie，这个cookie可以从AudioFileStream和AudioFile中获取。
 
 比较有价值的参数有：
 kAudioQueueParam_Volume，它可以用来调节AudioQueue的播放音量，注意这个音量是AudioQueue的内部播放音量和系统音量相互独立设置并且最后叠加生效。
 kAudioQueueParam_VolumeRampTime参数和Volume参数配合使用可以实现音频播放淡入淡出的效果；
 kAudioQueueParam_PlayRate参数可以调整播放速率；
 */

@end
