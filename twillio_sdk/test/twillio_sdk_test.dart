import 'package:flutter_test/flutter_test.dart';
import 'package:twillio_sdk/twillio_sdk.dart';
import 'package:twillio_sdk/twillio_sdk_platform_interface.dart';
import 'package:twillio_sdk/twillio_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockTwillioSdkPlatform
    with MockPlatformInterfaceMixin
    implements TwillioSdkPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final TwillioSdkPlatform initialPlatform = TwillioSdkPlatform.instance;

  test('$MethodChannelTwillioSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelTwillioSdk>());
  });

  test('getPlatformVersion', () async {
    TwillioSdk twillioSdkPlugin = TwillioSdk();
    MockTwillioSdkPlatform fakePlatform = MockTwillioSdkPlatform();
    TwillioSdkPlatform.instance = fakePlatform;

    // expect(await twillioSdkPlugin.getPlatformVersion(), '42');
  });
}
