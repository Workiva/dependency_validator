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

      group('workspace_global_ignore', () {
        test(
          'ignores packages in subpackages when set in workspace root',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceConfig: DepValidatorConfig(
              workspaceGlobalIgnore: ['http'],
            ),
            subpackage: usesHttp,
            subpackageDeps: {},
          ),
        );

        test(
          'is inherited by subpackages without local config',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: dependsOnHttp,
            workspaceConfig: DepValidatorConfig(
              workspaceGlobalIgnore: ['meta'],
            ),
            subpackage: usesMeta,
            subpackageDeps: {},
          ),
        );

        test(
          'does not apply when subpackage has its own config',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceConfig: DepValidatorConfig(
              workspaceGlobalIgnore: ['http'],
            ),
            subpackage: usesHttp,
            subpackageDeps: {},
            subpackageConfig: DepValidatorConfig(ignore: []),
            matcher: isFalse,
          ),
        );
      });

      group('workspace_package_ignore', () {
        test(
          'skips validation for ignored workspace packages',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceConfig: DepValidatorConfig(
              workspacePackageIgnore: ['subpackage'],
            ),
            subpackage: usesHttp,
            subpackageDeps: {},
          ),
        );
      });

      group('allow_pins inheritance', () {
        // Note: Pin checking doesn't affect the return value of checkPackage,
        // it only sets exitCode. These tests verify configuration inheritance,
        // while actual pin detection is tested in executable_test.dart

        test(
          'workspace with explicit allow_pins configuration',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: dependsOnHttp,
            workspaceConfig: DepValidatorConfig(allowPins: true),
            subpackage: usesMeta,
            subpackageDeps: dependsOnMeta,
          ),
        );

        test(
          'subpackage with local config can override workspace allow_pins',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: dependsOnHttp,
            workspaceConfig: DepValidatorConfig(allowPins: false),
            subpackage: usesMeta,
            subpackageDeps: dependsOnMeta,
            subpackageConfig: DepValidatorConfig(allowPins: true),
          ),
        );
      });

      group('configuration precedence', () {
        test(
          'local config ignore list takes precedence over workspace global ignore',
          () => checkWorkspace(
            workspace: [],
            workspaceDeps: {},
            workspaceConfig: DepValidatorConfig(
              workspaceGlobalIgnore: ['http'],
              ignore: ['meta'],
            ),
            subpackage: [...usesHttp, ...usesMeta],
            subpackageDeps: {},
            subpackageConfig: DepValidatorConfig(ignore: ['http', 'meta']),
          ),
        );

        test(
          'workspace root uses its own ignore list, not workspace_global_ignore',
          () => checkWorkspace(
            workspace: usesHttp,
            workspaceDeps: {},
            workspaceConfig: DepValidatorConfig(
              ignore: ['http'],
              workspaceGlobalIgnore: ['meta'],
            ),
            subpackage: [],
            subpackageDeps: {},
          ),
        );
      });
    });
