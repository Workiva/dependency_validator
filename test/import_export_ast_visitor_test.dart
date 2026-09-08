@TestOn('vm')
import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:dependency_validator/src/import_export_ast_visitor.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

void main() {
  group('featureSetForSdkConstraint', () {
    test('bounded constraint ^3.6.0 uses language version 3.6', () {
      final constraint = VersionConstraint.compatibleWith(Version.parse('3.6.0'));
      final featureSet = featureSetForSdkConstraint(constraint);

      expectSameLanguageVersion(featureSet, 3, 6);
      expectParsesFinalParameterCode(featureSet);
    });

    test('pinned constraint 3.6.0 uses language version 3.6', () {
      final constraint = Version.parse('3.6.0');
      final featureSet = featureSetForSdkConstraint(constraint);

      expectSameLanguageVersion(featureSet, 3, 6);
      expectParsesFinalParameterCode(featureSet);
    });

    test('unbounded any constraint uses latest language version', () {
      final featureSet = featureSetForSdkConstraint(VersionConstraint.any);
      final latest = FeatureSet.latestLanguageVersion();

      expectSameFeatureSet(featureSet, latest);
    });

    test('null constraint falls back to latest language version', () {
      final featureSet = featureSetForSdkConstraint(null);
      final latest = FeatureSet.latestLanguageVersion();

      expectSameFeatureSet(featureSet, latest);
    });

    test('pre-release minimum maps to major.minor language version', () {
      final constraint = Version.parse('3.7.0-dev');
      final featureSet = featureSetForSdkConstraint(constraint);

      expectSameLanguageVersion(featureSet, 3, 7);
    });
  });

  group('getDartDirectivePackageNames', () {
    test(
      'falls back to latest language version when pinned feature set fails',
      () async {
        await d
            .file(
              'test.dart',
              "import 'package:foo/bar.dart'; void f() { [?1]; }",
            )
            .create();
        final file = File('${d.sandbox}/test.dart');
        final featureSet = featureSetForSdkConstraint(
          VersionConstraint.compatibleWith(Version.parse('3.6.0')),
        );

        expect(
          getDartDirectivePackageNames(file, featureSet: featureSet),
          {'foo'},
        );
      },
    );
  });
}

void expectSameLanguageVersion(FeatureSet actual, int major, int minor) {
  final expected = FeatureSet.fromEnableFlags2(
    sdkLanguageVersion: Version(major, minor, 0),
    flags: const [],
  );
  expectSameFeatureSet(actual, expected);
}

void expectSameFeatureSet(FeatureSet actual, FeatureSet expected) {
  for (final version in [
    Version(3, 5, 0),
    Version(3, 6, 0),
    Version(3, 7, 0),
    Version(3, 8, 0),
  ]) {
    final restrictedActual = actual.restrictToVersion(version);
    final restrictedExpected = expected.restrictToVersion(version);
    for (final feature in _sampleFeatures) {
      expect(
        restrictedActual.isEnabled(feature),
        restrictedExpected.isEnabled(feature),
        reason: 'at language version $version',
      );
    }
  }
}

void expectParsesFinalParameterCode(FeatureSet featureSet) {
  expect(
    () => parseString(
      content: "import 'package:foo/bar.dart'; void f(final int x) {}",
      featureSet: featureSet,
    ),
    returnsNormally,
  );
}

final _sampleFeatures = <Feature>[
  Feature.patterns,
  Feature.records,
  Feature.null_aware_elements,
  Feature.class_modifiers,
];
