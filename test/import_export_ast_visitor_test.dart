// Copyright 2017 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

@TestOn('vm')
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void main() {
  group('languageVersionForSdkConstraint', () {
    test('null constraint returns null', () {
      expect(languageVersionForSdkConstraint(null), isNull);
    });

    test('any constraint returns null', () {
      expect(languageVersionForSdkConstraint(VersionConstraint.any), isNull);
    });

    test('exact version returns major.minor.0', () {
      expect(
        languageVersionForSdkConstraint(VersionConstraint.parse('3.6.0')),
        Version(3, 6, 0),
      );
    });

    test('caret range returns min major.minor.0', () {
      expect(
        languageVersionForSdkConstraint(VersionConstraint.parse('^3.6.0')),
        Version(3, 6, 0),
      );
    });
  });

  group('featureSetForSdkConstraint', () {
    test('null constraint uses latest language version', () {
      expect(
        featureSetForSdkConstraint(null).isEnabled(Feature.records),
        isTrue,
      );
    });

    test('any constraint uses latest language version', () {
      expect(
        featureSetForSdkConstraint(VersionConstraint.any).isEnabled(
          Feature.records,
        ),
        isTrue,
      );
    });

    test('exact version uses declared language version', () {
      final featureSet = featureSetForSdkConstraint(
        VersionConstraint.parse('3.6.0'),
      );

      expect(featureSet.isEnabled(Feature.records), isTrue);
      expect(featureSet.isEnabled(Feature.null_aware_elements), isFalse);
    });

    test('caret range uses min language version', () {
      final featureSet = featureSetForSdkConstraint(
        VersionConstraint.parse('^2.12.0'),
      );

      expect(featureSet.isEnabled(Feature.records), isFalse);
      expect(featureSet.isEnabled(Feature.non_nullable), isTrue);
    });
  });

  group('getDartDirectivePackageNames', () {
    test('retries with latest language version on parse failure', () {
      final file = File('${Directory.systemTemp.path}/retry_test.dart')
        ..writeAsStringSync('''
import 'package:logging/logging.dart';

void log(final Logger logger) {
  (int, int) record = (1, 2);
  logger.info('\$record');
}
''');

      addTearDown(file.deleteSync);

      final packages = getDartDirectivePackageNames(
        file,
        sdkConstraint: VersionConstraint.parse('^2.12.0'),
      );

      expect(packages, {'logging'});
    });
  });
}
