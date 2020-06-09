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
    
}

@end
