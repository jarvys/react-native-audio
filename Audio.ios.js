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
    var progressSubscription = NativeAppEventEmitter.addListener('recordingProgress',
      (data) => {
        console.log(data);
        if (this.onProgress) {
          this.onProgress(data);
        }
      }
    );

    var finishedSubscription = NativeAppEventEmitter.addListener('recordingFinished',
      (data) => {
        if (this.onFinished) {
          this.onFinished(data);
        }
      }
    );

    var errorSubscription = NativeAppEventEmitter.addListener('recordingError',
      (data) => {
        if (this.onError) {
          this.onError(data);
        }
      }
    );

    this.subscriptions = [
      progressSubscription,
      finishedSubscription,
      errorSubscription
    ];
  },
  startRecording: function() {
    AudioRecorderManager.startRecording();
  },
  pauseRecording: function() {
    AudioRecorderManager.pauseRecording();
  },
  stopRecording: function() {
    AudioRecorderManager.stopRecording();
    this.subscriptions.forEach(sub => sub.remove());
    this.subscriptions = null;
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
