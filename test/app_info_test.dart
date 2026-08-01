import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ssi_connect/app_info.dart';

void main() {
  group('AppInfo.version', () {
    test('matches the version in pubspec.yaml', () {
      // The info screen shows a constant, because reading the version at
      // runtime would mean a plugin that breaks the Android build. This
      // test is what keeps the constant honest: bump pubspec without
      // bumping AppInfo and the suite goes red.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec);

      expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
      expect(
        AppInfo.version,
        match!.group(1),
        reason: 'AppInfo.version und pubspec.yaml sind auseinandergelaufen',
      );
    });

    test('drops the build number for the short form', () {
      expect(AppInfo.versionName, isNot(contains('+')));
      expect(AppInfo.version, startsWith(AppInfo.versionName));
    });
  });
}
