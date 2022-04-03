# Dependency Validator

> A tool to help you find missing, under-promoted, over-promoted, and unused dependencies.

## Installation

Add the following to your pubspec.yaml:

```yaml
dev_dependencies:
  dependency_validator: ^3.0.0
```

## Usage

```bash
pub run dependency_validator
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

# Set true if you use pinned dependencies
ignored_pinned_packages: true
# Exclude one or more paths from being scanned. Supports glob syntax.
exclude:
  - "app/**"
# Ignore one or more packages.
ignore:
  - analyzer
```

> Note: Previously this configuration lived in the `pubspec.yaml`, but that
> option was deprecated because `pub publish` warns about unrecognized keys.
