import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'twillio_sdk_platform_interface.dart';

/// An implementation of [TwillioSdkPlatform] that uses method channels.
class MethodChannelTwillioSdk extends TwillioSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('twillio_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
