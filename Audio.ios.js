'use strict';

/**
 * This module is a thin layer over the native module. It's aim is to obscure
 * implementation details for registering callbacks, changing settings, etc.
*/

var React, {NativeModules, NativeAppEventEmitter} = require('react-native');

var AudioPlayerManager = NativeModules.AudioPlayerManager;
var AudioRecorderManager = NativeModules.AudioRecorderManager;

var AudioPlayer = {
  play: function(path) {
    AudioPlayerManager.play(path);
  },
  playWithUrl: function(url) {
    AudioPlayerManager.playWithUrl(url);
  },
  pause: function() {
    AudioPlayerManager.pause();
  },
  stop: function() {
    AudioPlayerManager.stop();
    if (this.subscription) {
      this.subscription.remove();
    }
  }
};

var AudioRecorder = {
  prepareRecordingAtPath: function(path) {
    AudioRecorderManager.prepareRecordingAtPath(path);
    this.progressSubscription = NativeAppEventEmitter.addListener('recordingProgress',
      (data) => {
        console.log(data);
        if (this.onProgress) {
          this.onProgress(data);
        }
      }
    );

    this.FinishedSubscription = NativeAppEventEmitter.addListener('recordingFinished',
      (data) => {
        if (this.onFinished) {
          this.onFinished(data);
        }
      }
    );

    this.ErrorSubscription = NativeAppEventEmitter.addListener('recordingError',
      (data) => {
        if (this.onError) {
          this.onError(data);
        }
      }
    );
  },
  startRecording: function() {
    AudioRecorderManager.startRecording();
  },
  pauseRecording: function() {
    AudioRecorderManager.pauseRecording();
  },
  stopRecording: function() {
    AudioRecorderManager.stopRecording();
    if (this.subscription) {
      this.subscription.remove();
    }
  },
  deleteRecording: function() {
    AudioRecorderManager.deleteRecording();
  },
  playRecording: function() {
    AudioRecorderManager.playRecording();
  },
  stopPlaying: function() {
    AudioRecorderManager.stopPlaying();
  }
};

module.exports = {AudioPlayer, AudioRecorder};
