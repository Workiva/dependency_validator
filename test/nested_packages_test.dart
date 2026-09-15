import 'dart:convert';
import 'package:dependency_validator/src/dependency_validator.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'pubspec_to_json.dart';
import 'utils.dart';

void main() => group('Nested packages', () {
  initLogs();

  test('ignores dependencies used only in nested packages', () async {
    final rootPubspec = Pubspec(
      'code_assets',
      environment: requireDart36,
      dependencies: {'http': HostedDependency(version: VersionConstraint.any)},
    );

    final nestedPubspec = Pubspec(
      'host_name',
      environment: requireDart36,
      devDependencies: {
        'ffigen': HostedDependency(version: VersionConstraint.any),
      },
    );

    final dir = d.dir('code_assets', [
      d.file('pubspec.yaml', jsonEncode(pubspecToJson(rootPubspec))),
      d.dir('lib', [
        d.file('code_assets.dart', 'import "package:http/http.dart";'),
      ]),
      d.dir('example', [
        d.dir('host_name', [
          d.file('pubspec.yaml', jsonEncode(pubspecToJson(nestedPubspec))),
          d.dir('tool', [
            d.file('ffigen.dart', 'import "package:ffigen/ffigen.dart";'),
          ]),
          d.dir('lib', [
            d.file('host_name.dart', 'import "package:archive/archive.dart";'),
          ]),
        ]),
      ]),
    ]);

    await dir.create();
    final result = await checkPackage(root: '${d.sandbox}/code_assets');
    expect(result, isTrue);
  });

  test(
    'fails when root package itself has undeclared dependencies outside nested packages',
    () async {
      final rootPubspec = Pubspec(
        'code_assets',
        environment: requireDart36,
        dependencies: {},
      );

      final nestedPubspec = Pubspec(
        'host_name',
        environment: requireDart36,
        devDependencies: {
          'ffigen': HostedDependency(version: VersionConstraint.any),
        },
      );

      final dir = d.dir('code_assets_with_issue', [
        d.file('pubspec.yaml', jsonEncode(pubspecToJson(rootPubspec))),
        d.dir('tool', [
          // Undeclared dependency in root package's own tool dir
          d.file('root_tool.dart', 'import "package:meta/meta.dart";'),
        ]),
        d.dir('example', [
          d.dir('host_name', [
            d.file('pubspec.yaml', jsonEncode(pubspecToJson(nestedPubspec))),
            d.dir('tool', [
              d.file('ffigen.dart', 'import "package:ffigen/ffigen.dart";'),
            ]),
          ]),
        ]),
      ]);

      await dir.create();
      final result = await checkPackage(
        root: '${d.sandbox}/code_assets_with_issue',
      );
      expect(result, isFalse);
    },
  );

  test('ignores deeply nested packages', () async {
    final rootPubspec = Pubspec('root_pkg', environment: requireDart36);

    final deeplyNestedPubspec = Pubspec('deep_pkg', environment: requireDart36);

    final dir = d.dir('root_pkg', [
      d.file('pubspec.yaml', jsonEncode(pubspecToJson(rootPubspec))),
      d.dir('example', [
        d.dir('nested', [
          d.dir('deep', [
            d.file(
              'pubspec.yaml',
              jsonEncode(pubspecToJson(deeplyNestedPubspec)),
            ),
            d.dir('lib', [
              d.file('deep.dart', 'import "package:meta/meta.dart";'),
            ]),
          ]),
        ]),
      ]),
    ]);

    await dir.create();
    final result = await checkPackage(root: '${d.sandbox}/root_pkg');
    expect(result, isTrue);
  });

  test('ignores SCSS and Less files in nested packages', () async {
    final rootPubspec = Pubspec('web_pkg', environment: requireDart36);

    final nestedPubspec = Pubspec('nested_web_pkg', environment: requireDart36);

    final dir = d.dir('web_pkg', [
      d.file('pubspec.yaml', jsonEncode(pubspecToJson(rootPubspec))),
      d.dir('example', [
        d.dir('nested_web', [
          d.file('pubspec.yaml', jsonEncode(pubspecToJson(nestedPubspec))),
          d.dir('web', [
            d.file('style.scss', '@import "package:foo_styles/style.scss";'),
            d.file('style.less', '@import "packages/bar_styles/style.less";'),
          ]),
        ]),
      ]),
    ]);

    await dir.create();
    final result = await checkPackage(root: '${d.sandbox}/web_pkg');
    expect(result, isTrue);
  });

  test(
    'works with workspace subpackages that contain nested packages',
    () async {
      final workspacePubspec = Pubspec(
        'workspace_root',
        environment: requireDart36,
        workspace: ['pkgs/code_assets'],
      );

      final subpackagePubspec = Pubspec(
        'code_assets',
        environment: requireDart36,
        resolution: 'workspace',
        dependencies: {
          'http': HostedDependency(version: VersionConstraint.any),
        },
      );

      final nestedPubspec = Pubspec(
        'host_name',
        environment: requireDart36,
        dependencies: {
          'ffigen': HostedDependency(version: VersionConstraint.any),
        },
      );

      final dir = d.dir('workspace', [
        d.file('pubspec.yaml', jsonEncode(pubspecToJson(workspacePubspec))),
        d.dir('pkgs', [
          d.dir('code_assets', [
            d.file(
              'pubspec.yaml',
              jsonEncode(pubspecToJson(subpackagePubspec)),
            ),
            d.dir('lib', [
              d.file('code_assets.dart', 'import "package:http/http.dart";'),
            ]),
            d.dir('example', [
              d.dir('host_name', [
                d.file(
                  'pubspec.yaml',
                  jsonEncode(pubspecToJson(nestedPubspec)),
                ),
                d.dir('tool', [
                  d.file('ffigen.dart', 'import "package:ffigen/ffigen.dart";'),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]);

      await dir.create();
      final result = await checkPackage(root: '${d.sandbox}/workspace');
      expect(result, isTrue);
    },
  );
});
