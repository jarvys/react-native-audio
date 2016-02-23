'use strict';

/**
 * This module is a thin layer over the native module. It's aim is to obscure
 * implementation details for registering callbacks, changing settings, etc.
*/

var React, {NativeModules, NativeAppEventEmitter} = require('react-native');

var AudioPlayerManager = NativeModules.AudioPlayerManager;
var AudioRecorderManager = NativeModules.AudioRecorderManager;

var counter = 0;
var AudioPlayer = {
  play: function(path) {
    counter++;
    AudioPlayerManager.play(path, counter);
    return counter;
  },
  playWithUrl: function(url) {
    counter++;
    AudioPlayerManager.playWithUrl(url, counter);
    return counter;
  },
  pause: function() {
    AudioPlayerManager.pause();
  },
  stop: function() {
    AudioPlayerManager.stop();
    if (this.subscription) {
      this.subscription.remove();
    }
  },

  addListener: function(event, listener) {
    if (event !== 'finish') {
      throw new Error('invalid event type, only support finish event');
    }

    return NativeAppEventEmitter.addListener('playerFinished', listener);
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

    var peakPowerSubscription = NativeAppEventEmitter.addListener('audioPeakPower',
      (data) => {
        if(this.onPeakPower) {
          this.onPeakPower(data);
        }
      }
    );

    var finishedSubscription = NativeAppEventEmitter.addListener('recordingFinished',
      (data) => {
        if (this.onFinished) {
          this.onFinished(data);
        }
        this._removeSubscriptions();
      }
    );

    var errorSubscription = NativeAppEventEmitter.addListener('recordingError',
      (data) => {
        if (this.onError) {
          this.onError(data);
        }
        this._removeSubscriptions();
      }
    );

    this.subscriptions = [
      progressSubscription,
      peakPowerSubscription,
      finishedSubscription,
      errorSubscription
    ];
  },

  _removeSubscriptions: function() {
    this.subscriptions.forEach(sub => sub.remove());
    this.subscriptions = null;
  },

  startRecording: function() {
    AudioRecorderManager.startRecording();
  },
  pauseRecording: function() {
    AudioRecorderManager.pauseRecording();
  },
  stopRecording: function() {
    AudioRecorderManager.stopRecording();
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
