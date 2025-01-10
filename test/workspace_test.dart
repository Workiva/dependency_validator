import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

final usesHttp = [
  d.dir('lib', [
    d.file('main.dart', 'import "package:http/http.dart";'),
  ]),
];

final dependsOnHttp = {
  'http': HostedDependency(
    version: VersionConstraint.any,
  ),
};

final usesMeta = [
  d.dir('lib', [
    d.file('main.dart', 'import "package:meta/meta.dart";'),
  ]),
];

final dependsOnMeta = {
  "meta": HostedDependency(version: VersionConstraint.any),
};

final excludeMain = DepValidatorConfig(
  exclude: ['lib/main.dart'],
);

void main() => group('Workspaces', () {
      initLogs();
      test(
          'works in the trivial case',
          () => checkWorkspace(
                workspaceDeps: {},
                workspace: [],
                subpackage: [],
                subpackageDeps: {},
              ));

      test(
          'works in a basic case',
          () => checkWorkspace(
                workspace: usesHttp,
                workspaceDeps: dependsOnHttp,
                subpackage: usesHttp,
                subpackageDeps: dependsOnHttp,
              ));

      test(
          'works when the packages have different dependencies',
          () => checkWorkspace(
                workspace: usesHttp,
                workspaceDeps: dependsOnHttp,
                subpackage: usesMeta,
                subpackageDeps: dependsOnMeta,
              ));

      group('fails when the root has an issue', () {
        test(
            '(sub-package is okay)',
            () => checkWorkspace(
                  workspace: [],
                  workspaceDeps: {},
                  subpackage: usesHttp,
                  subpackageDeps: dependsOnHttp,
                ));

        test(
            'even when it shares a dependency with the subpackage',
            () => checkWorkspace(
                  workspaceDeps: dependsOnHttp,
                  workspace: [],
                  subpackageDeps: dependsOnHttp,
                  subpackage: usesHttp,
                  matcher: isFalse,
                ));
      });

      group('fails when the subpackage has an issue', () {
        test(
            '(root is okay)',
            () => checkWorkspace(
                  workspace: usesHttp,
                  workspaceDeps: dependsOnHttp,
                  subpackage: [],
                  subpackageDeps: {},
                ));

        test(
            'even when it shares a dependency with the subpackage',
            () => checkWorkspace(
                  workspace: usesHttp,
                  workspaceDeps: dependsOnHttp,
                  subpackage: usesHttp,
                  subpackageDeps: {},
                  matcher: isFalse,
                ));
      });

      group('handles configs', () {
        test(
            'at the root',
            () => checkWorkspace(
                  workspace: usesHttp,
                  workspaceDeps: {},
                  workspaceConfig: excludeMain,
                  subpackage: [],
                  subpackageDeps: {},
                ));

        test(
            'and fails at root when config is in subpackage',
            () => checkWorkspace(
                  workspace: usesHttp,
                  workspaceDeps: {},
                  subpackage: [],
                  subpackageDeps: {},
                  subpackageConfig: excludeMain,
                  matcher: isFalse,
                ));

        test(
            'in a subpackage',
            () => checkWorkspace(
                  workspace: [],
                  workspaceDeps: {},
                  subpackage: usesHttp,
                  subpackageDeps: {},
                  subpackageConfig: excludeMain,
                ));

        test(
            'and fails in subpackage when config is in root',
            () => checkWorkspace(
                  workspace: [],
                  workspaceDeps: {},
                  workspaceConfig: excludeMain,
                  subpackage: usesHttp,
                  subpackageDeps: {},
                  matcher: isFalse,
                ));
      });
    });
