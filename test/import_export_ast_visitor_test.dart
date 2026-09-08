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
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

Version _sdkLanguageVersion(FeatureSet featureSet) =>
    getSdkLanguageVersion_forTesting(featureSet as ExperimentStatus);

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
        _sdkLanguageVersion(featureSetForSdkConstraint(null)),
        ExperimentStatus.currentVersion,
      );
    });

    test('any constraint uses latest language version', () {
      expect(
        _sdkLanguageVersion(
          featureSetForSdkConstraint(VersionConstraint.any),
        ),
        ExperimentStatus.currentVersion,
      );
    });

    test('exact version uses declared language version', () {
      expect(
        _sdkLanguageVersion(
          featureSetForSdkConstraint(VersionConstraint.parse('3.6.0')),
        ),
        Version(3, 6, 0),
      );
    });

    test('caret range uses min language version', () {
      expect(
        _sdkLanguageVersion(
          featureSetForSdkConstraint(VersionConstraint.parse('^3.6.0')),
        ),
        Version(3, 6, 0),
      );
    });
  });

  group('getDartDirectivePackageNames', () {
    test('retries with latest language version on parse failure', () {
      final file = File('${Directory.systemTemp.path}/retry_test.dart')
        ..writeAsStringSync('''
import 'package:logging/logging.dart';

void log(List<int>? values, final Logger logger) {
  final copied = [?values];
  logger.info('\$copied');
}
''');

      addTearDown(file.deleteSync);

      final packages = getDartDirectivePackageNames(
        file,
        featureSet: featureSetForSdkConstraint(
          VersionConstraint.parse('^3.0.0'),
        ),
        derivedLanguageVersion: Version(3, 0, 0),
      );

      expect(packages, {'logging'});
    });
  });
}
