//
//  AudioRecorderManager.m
//  AudioRecorderManager
//
//  Created by Joshua Sierles on 15/04/15.
//  Copyright (c) 2015 Joshua Sierles. All rights reserved.
//

#import "AudioRecorderManager.h"
#import "RCTConvert.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import <AVFoundation/AVFoundation.h>

NSString *const AudioRecorderEventProgress = @"recordingProgress";
NSString *const AudioRecorderEventFinished = @"recordingFinished";
NSString *const AudioRecorderEventError = @"recordingError";
NSString *const AudioPeakPower = @"audioPeakPower";

@implementation AudioRecorderManager {

  AVAudioRecorder *_audioRecorder;
  AVAudioPlayer *_audioPlayer;

  NSTimeInterval _currentTime;
  id _progressUpdateTimer;
  int _progressUpdateInterval;
  NSDate *_prevProgressUpdateTime;
  NSURL *_audioFileURL;
  AVAudioSession *_recordSession;
  NSTimer *_levelTimer;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
  if (_audioRecorder && _audioRecorder.recording) {
    _currentTime = _audioRecorder.currentTime;
  } else if (_audioPlayer && _audioPlayer.playing) {
    _currentTime = _audioPlayer.currentTime;
  } else {
    return;
  }

  if (_prevProgressUpdateTime == nil ||
   (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) {
      [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventProgress body:@{
      @"currentTime": [NSNumber numberWithFloat:_currentTime]
    }];

    _prevProgressUpdateTime = [NSDate date];
  }
}

- (void)stopProgressTimer {
  [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
  _progressUpdateInterval = 250;
  _prevProgressUpdateTime = nil;

  [self stopProgressTimer];

  _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
  [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
  if (!flag) {
    [self.bridge.eventDispatcher sendAppEventWithName:AudioRecorderEventFinished body:@{
          @"status": @"ERROR"
        }];
  }
  
  NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[_audioRecorder.url path] error:nil];
  
  typeof(self) __weak weakSelf = self;
  AVURLAsset *asset = [AVURLAsset assetWithURL:_audioRecorder.url];
  [asset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObjects:@"duration", nil]
      completionHandler: ^{
        BOOL done = NO;
        switch ([asset statusOfValueForKey:@"duration" error: nil]) {
          case AVKeyValueStatusLoaded:
          case AVKeyValueStatusCancelled:
          case AVKeyValueStatusFailed:
            done = YES;
          default:;
            // nothing to do
        }
        
        if (!done) {
          return;
        }

        [weakSelf _emitEventWithName: AudioRecorderEventFinished
           body:@{
              @"status": @"OK",
              @"uri": [_audioRecorder.url absoluteString],
              @"duration":[NSNumber numberWithFloat: CMTimeGetSeconds([asset duration])],
              @"size":  [NSNumber numberWithUnsignedLongLong: [attributes fileSize]]
            }];
      }];
}

- (void)_emitEventWithName:(NSString*) eventName body:(NSDictionary*) body {
  [self.bridge.eventDispatcher sendAppEventWithName:eventName body:body];
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError *) error {
  [self.bridge.eventDispatcher sendAppEventWithName:
      AudioRecorderEventError body:@{
      @"error": error.localizedDescription
    }];
}

- (void)levelTimerCallback:(NSTimer *)timer {

  [_audioRecorder updateMeters];

  [self.bridge.eventDispatcher sendAppEventWithName:
    AudioPeakPower body:@{
      @"peakPower": [NSNumber numberWithFloat: [_audioRecorder peakPowerForChannel:0]]
    }];
}

- (NSString *) applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

RCT_EXPORT_METHOD(prepareRecordingAtPath:(NSString *)path)
{

  _prevProgressUpdateTime = nil;
  [self stopProgressTimer];

  NSString *audioFilePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:path];

  _audioFileURL = [NSURL fileURLWithPath:audioFilePath];

  NSDictionary *recordSettings = [NSDictionary dictionaryWithObjectsAndKeys:
           [NSNumber numberWithInt:kAudioFormatMPEG4AAC], AVFormatIDKey,
           [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,
           [NSNumber numberWithFloat:16000.0], AVSampleRateKey,
          nil];

  NSError *error = nil;

  _recordSession = [AVAudioSession sharedInstance];
  [_recordSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
  
  if (error) {
    NSLog(@"error: %@", [error localizedDescription]);
    // TODO: dispatch error over the bridge
    return;
  }
  
  [_recordSession setActive:YES error:&error];
  if (error) {
    NSLog(@"error: %@", [error localizedDescription]);
    // TODO: dispatch error over the bridge
    return;
  }

  _audioRecorder = [[AVAudioRecorder alloc]
                initWithURL:_audioFileURL
                settings:recordSettings
                error:&error];

  _audioRecorder.delegate = self;

  if (error) {
      NSLog(@"error: %@", [error localizedDescription]);
      // TODO: dispatch error over the bridge
    } else {
      BOOL successfully = [_audioRecorder prepareToRecord];
      if (!successfully) {
        NSLog(@"fail to prepare to record");
      } else {
        _audioRecorder.meteringEnabled = YES;
      }
  }
}

RCT_EXPORT_METHOD(startRecording)
{
  if (_audioRecorder.recording) {
    return;
  }
  
  
  [self startProgressTimer];
  BOOL successfully = [_audioRecorder record];
  if (!successfully) {
    NSLog(@"fail to record");
  } else {
    [_levelTimer invalidate];
    dispatch_async(dispatch_get_main_queue(), ^{
      _levelTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5 target: self selector: @selector(levelTimerCallback:) userInfo: nil repeats: YES];
    });
  }
}

RCT_EXPORT_METHOD(stopRecording)
{
  if (_audioRecorder.recording) {
    [_audioRecorder stop];
    [_recordSession setActive:NO error:nil];
    _prevProgressUpdateTime = nil;
    [_levelTimer invalidate];
  }
}

RCT_EXPORT_METHOD(deleteRecording)
{
  if (!_audioRecorder.recording) {
    [_audioRecorder deleteRecording];
  }
}

RCT_EXPORT_METHOD(pauseRecording)
{
  if (_audioRecorder.recording) {
    [self stopProgressTimer];
    [_audioRecorder pause];
  }
}

RCT_EXPORT_METHOD(playRecording)
{
  if (_audioRecorder.recording) {
    NSLog(@"stop the recording before playing");
    return;

  } else {

    NSError *error;

    if (!_audioPlayer.playing) {
      _audioPlayer = [[AVAudioPlayer alloc]
        initWithContentsOfURL:_audioRecorder.url
        error:&error];

      if (error) {
        [self stopProgressTimer];
        NSLog(@"audio playback loading error: %@", [error localizedDescription]);
        // TODO: dispatch error over the bridge
      } else {
        [self startProgressTimer];
        [_audioPlayer play];
      }
    }
  }
}

RCT_EXPORT_METHOD(pausePlaying)
{
  if (_audioPlayer.playing) {
    [_audioPlayer pause];
  }
}

RCT_EXPORT_METHOD(stopPlaying)
{
  if (_audioPlayer.playing) {
    [_audioPlayer stop];
  }
}

@end
