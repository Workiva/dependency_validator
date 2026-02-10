# Dependency Validator

> A tool to help you find missing, under-promoted, over-promoted, and unused dependencies.

## Installation

```
dart pub global activate dependency_validator
```

## Usage

```bash
dart pub global run dependency_validator
```

This will report any missing, under-promoted, over-promoted, and unused
dependencies. Any package that either provides an executable or a builder that
will be auto-applied via the [dart build system][dart-build] will be considered
used even if it isn't imported.

[dart-build]: https://github.com/dart-lang/build

- Missing: When a dependency is used in the package but not declared in the `pubspec.yaml`
- Under-promoted: When a dependency is used within `lib/` but only declared as a dev_dependency.
- Over-promoted: When a dependency is only used outside `lib/` but declared as a dependency.
- Unused: When a dependency is not used in the package but declared in the `pubspec.yaml`.

## Configuration

There may be packages that are intentionally depended on but not used, or there
may be directories that need to be ignored. You can statically configure these
things in a `dart_dependency_validator.yaml` file in the root of your package:


```yaml
# dart_dependency_validator.yaml

# Set true if you allow pinned packages in your project.
allow_pins: true
# Exclude one or more paths from being scanned. Supports glob syntax.
exclude:
  - "app/**"
# Ignore one or more packages.
ignore:
  - analyzer
```

> [!Note]
> Previously this configuration lived in the `pubspec.yaml`, but that
> option was deprecated because `pub publish` warns about unrecognized keys.

## Pub Workspaces (monorepos)

This package supports [Pub Workspaces](https://dart.dev/tools/pub/workspaces), a collection of packages in one repository. Workspaces allow Pub to share dependencies between your packages. Your top-level package's `pubspec.yaml` should have a `workspace` field that indicates which sub-packages should be included, like this:

```yaml
workspace:
  - pkg1
  - pkg2
```

and your sub-packages should have `resolution: workspace` in their `pubspec.yaml`s. For more information, see the linked documentation.

**Running `dependency_validator` will always validate the package your terminal is in**. If you run the tool on the top-level workspace package, it will analyze the workspace package _and_ its sub-packages. To just analyze a sub-package, run the tool in its folder, or pass the `-C` argument:

```bash
$ dart run dependency_validator -C pkg1
```

### Workspace Configuration

When working with workspaces, you can configure workspace-specific settings in the root package's `dart_dependency_validator.yaml` file:

```yaml
# dart_dependency_validator.yaml (in workspace root)

# Allow pinned packages across the workspace
allow_pins: true

# Ignore specific packages in all workspace sub-packages
workspace_global_ignore:
  - some_package
  - another_package

# Skip validation for specific workspace packages
workspace_package_ignore:
  - pkg1
  - pkg2
```

#### Configuration Inheritance

By default, sub-packages inherit certain configuration settings from the workspace root:
- `workspace_global_ignore`: Packages listed here will be ignored in all sub-packages
- `allow_pins`: If set to `true` in the workspace root, sub-packages will also allow pinned dependencies
- `ignore`: The standard ignore list from the workspace root is also inherited

**Important**: If a sub-package has its own `dart_dependency_validator.yaml` file, it will take complete precedence over the workspace configuration. The local config file is always prioritized over any inherited workspace settings.
