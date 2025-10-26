import 'package:flutter/services.dart';

class TwillioSdk {
  static const MethodChannel _channel = MethodChannel('twilio_video');
  static const EventChannel _eventChannel = EventChannel('twilio_video_events');

  /// Connects to a Twilio room using only the [token].
  static Future<void> connect(String token) async {
    await _channel.invokeMethod('connect', {'token': token});
  }

  /// Mutes the local audio track.
  static Future<void> muteAudio() => _channel.invokeMethod('muteAudio');

  /// Unmutes the local audio track.
  static Future<void> unmuteAudio() => _channel.invokeMethod('unmuteAudio');

  /// Enables local video track.
  static Future<void> enableVideo() => _channel.invokeMethod('enableVideo');

  /// Disables local video track.
  static Future<void> disableVideo() => _channel.invokeMethod('disableVideo');

  /// Switches between front and back camera.
  static Future<void> switchCamera() => _channel.invokeMethod('switchCamera');

  /// Disconnects from the current room.
  static Future<void> disconnect() => _channel.invokeMethod('disconnect');

  /// Event stream for remote participant connections/disconnections.
  static Stream<dynamic> get events => _eventChannel.receiveBroadcastStream();
}
