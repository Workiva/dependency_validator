import 'package:dependency_validator/src/pubspec_config.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'utils.dart';

final usesHttp = [
  d.dir('lib', [d.file('main.dart', 'import "package:http/http.dart";')]),
];

final dependsOnHttp = {
  'http': HostedDependency(version: VersionConstraint.any),
};

final usesMeta = [
  d.dir('lib', [d.file('main.dart', 'import "package:meta/meta.dart";')]),
];

final dependsOnMeta = {
  "meta": HostedDependency(version: VersionConstraint.any),
};

final excludeMain = DepValidatorConfig(exclude: ['lib/main.dart']);

void main() => group('Workspaces', () {
      initLogs();
      test(
        'works in the trivial case',
        () => checkWorkspace(
          workspaceDeps: {},
          workspace: [],
          subpackage: [],
          subpackageDeps: {},
        ),
      );

      test(
        'works in a basic case',
        () => checkWorkspace(
          workspace: usesHttp,
          workspaceDeps: dependsOnHttp,
          subpackage: usesHttp,
          subpackageDeps: dependsOnHttp,
        ),
      );

      test(
        'works when the packages have different dependencies',
        () => checkWorkspace(
          workspace: usesHttp,
          workspaceDeps: dependsOnHttp,
          subpackage: usesMeta,
          subpackageDeps: dependsOnMeta,
        ),
      );

      group('fails when the root has an issue', () {
        test(
          '(sub-package is okay)',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            subpackage: usesHttp,
            subpackageDeps: dependsOnHttp,
          ),
        );

        test(
          'even when it shares a dependency with the subpackage',
          () => checkWorkspace(
            workspaceDeps: dependsOnHttp,
            workspace: [],
            subpackageDeps: dependsOnHttp,
            subpackage: usesHttp,
            matcher: isFalse,
          ),
        );
      });

      group('fails when the subpackage has an issue', () {
        test(
          '(root is okay)',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: dependsOnHttp,
            subpackage: [],
            subpackageDeps: {},
          ),
        );

        test(
          'even when it shares a dependency with the subpackage',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: dependsOnHttp,
            subpackage: usesHttp,
            subpackageDeps: {},
            matcher: isFalse,
          ),
        );
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
          ),
        );

        test(
          'and fails at root when config is in subpackage',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: {},
            subpackage: [],
            subpackageDeps: {},
            subpackageConfig: excludeMain,
            matcher: isFalse,
          ),
        );

        test(
          'in a subpackage',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            subpackage: usesHttp,
            subpackageDeps: {},
            subpackageConfig: excludeMain,
          ),
        );

        test(
          'and fails in subpackage when config is in root',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceConfig: excludeMain,
            subpackage: usesHttp,
            subpackageDeps: {},
            matcher: isFalse,
          ),
        );
      });

      group('glob workspace patterns', () {
        /// A `packages/` directory containing a non-package sibling that a
        /// `packages/*` glob must skip.
        final packagesDirWithNonPackage = [
          d.dir('packages', [
            d.dir('not_a_package', [
              d.file('README.md', ''),
            ]),
          ]),
        ];

        /// Returns how many times [name] was validated according to [logs].
        int timesValidated(List<String> logs, String name) => logs
            .where((m) => m == 'Validating dependencies for $name...')
            .length;

        test('resolves packages/* to workspace members', () async {
          final logs = await checkWorkspace(
            workspace: packagesDirWithNonPackage,
            workspaceDeps: {},
            workspaceMembers: ['packages/*'],
            subpackages: [
              (
                path: 'packages/pkg_a',
                contents: usesHttp,
                deps: dependsOnHttp,
                config: null,
              ),
              (
                path: 'packages/pkg_b',
                contents: usesMeta,
                deps: dependsOnMeta,
                config: null,
              ),
            ],
            logLevel: Level.INFO,
          );

          expect(timesValidated(logs, 'pkg_a'), 1);
          expect(timesValidated(logs, 'pkg_b'), 1);
          expect(timesValidated(logs, 'workspace'), 1);
          expect(logs, isNot(contains(contains('not_a_package'))));
        });

        test('validates each glob-matched subpackage', () async {
          final logs = await checkWorkspace(
            workspace: packagesDirWithNonPackage,
            workspaceDeps: {},
            workspaceMembers: ['packages/*'],
            subpackages: [
              (
                path: 'packages/pkg_a',
                contents: usesHttp,
                deps: dependsOnHttp,
                config: null,
              ),
              (
                path: 'packages/pkg_b',
                contents: usesHttp,
                deps: {},
                config: null,
              ),
            ],
            logLevel: Level.INFO,
            matcher: isFalse,
          );

          expect(timesValidated(logs, 'pkg_a'), 1);
          expect(timesValidated(logs, 'pkg_b'), 1);
          // The missing dependency is reported for pkg_b, not pkg_a.
          expect(logs, contains(contains('not dependencies')));
        });

        test('supports mixed literal and glob workspace entries', () async {
          final logs = await checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceMembers: ['packages/foo', 'packages/*'],
            subpackages: [
              (
                path: 'packages/foo',
                contents: usesHttp,
                deps: dependsOnHttp,
                config: null,
              ),
              (
                path: 'packages/bar',
                contents: usesMeta,
                deps: dependsOnMeta,
                config: null,
              ),
            ],
            logLevel: Level.INFO,
          );

          // `packages/foo` is matched by both entries but validated once.
          expect(timesValidated(logs, 'foo'), 1);
          expect(timesValidated(logs, 'bar'), 1);
        });

        test('warns when a glob matches no packages', () async {
          final logs = await checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceMembers: ['pacakges/*'],
            subpackages: [],
            logLevel: Level.WARNING,
          );

          expect(
            logs,
            contains(contains('No workspace packages matching "pacakges/*"')),
          );
        });

        test('fails on invalid glob syntax', () async {
          final logs = await checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceMembers: ['packages/[a'],
            subpackages: [],
            logLevel: Level.WARNING,
            matcher: isFalse,
          );

          expect(logs, contains(contains('invalid glob syntax')));
        });
      });
    });
