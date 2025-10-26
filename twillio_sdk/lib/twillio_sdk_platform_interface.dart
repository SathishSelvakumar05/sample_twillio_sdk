import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'twillio_sdk_method_channel.dart';

abstract class TwillioSdkPlatform extends PlatformInterface {
  /// Constructs a TwillioSdkPlatform.
  TwillioSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static TwillioSdkPlatform _instance = MethodChannelTwillioSdk();

  /// The default instance of [TwillioSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelTwillioSdk].
  static TwillioSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [TwillioSdkPlatform] when
  /// they register themselves.
  static set instance(TwillioSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
