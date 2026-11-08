import 'dart:io';

import 'package:dartlab/utils/feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests guard what the privacy policy and the Play Data Safety form say
/// about v1.0: the app is offline and asks for no permissions. When a test here
/// fails because of a real, wanted change (for example Git in v1.1), update the
/// policy and the Data Safety form first, then this test.
void main() {
  String normalised(String path) => path.replaceAll('\\', '/');

  group('v1.0 stays offline', () {
    test('only the Git service uses the network', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final usesHttp = entity.readAsStringSync().contains('package:http/');
        if (usesHttp && !normalised(entity.path).endsWith('services/git_service.dart')) {
          offenders.add(normalised(entity.path));
        }
      }

      expect(offenders, isEmpty);
    });

    test('Git is switched off until the policy and Data Safety cover it', () {
      expect(kGitEnabled, isFalse);
    });

    test('the main Android manifest asks for no permissions', () {
      final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

      expect(manifest.contains('<uses-permission'), isFalse);
    });
  });
}
