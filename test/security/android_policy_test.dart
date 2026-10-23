import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android application opts out of cleartext network traffic', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, isNot(contains('android:networkSecurityConfig=')),
        reason:
            'A network security config must be reviewed for HTTP overrides');
  });

  test('Android release never falls back to a debug signing identity', () {
    final gradle = File('android/app/build.gradle').readAsStringSync();
    expect(
        gradle, isNot(matches(r'signingConfig\s*=?\s*signingConfigs\.debug')));
  });
}
