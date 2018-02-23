# Dependency Validator

> A tool to help you find missing, under-promoted, over-promoted, and unused dependencies.

## Getting Started

### Install dependency_validator

Add the following to your pubspec.yaml:

```yaml
dev_dependencies:
  dependency_validator: ^1.0.0
```

## Usage

This package comes with a single executable: dependency_validator. To run this executable: `pub run dependency_validator`. This usage will run the tool and report any missing, under-promoted, over-promoted, and unused dependencies.

- Missing: When a dependency is used in the package but not declared in the `pubspec.yaml`
  - Optionaly do not fail by using the `--no-fatal-missing` flag.
- Under-promoted: When a dependency is used within `lib/` but only declared as a dev_dependency.
  - Optionaly do not fail by using the `--no-fatal-under-promoted` flag.
- Over-promoted: When a dependency is only used outside `lib/` but declared as a dependency.
  - Optionaly do not fail by using the `--no-fatal-over-promoted` flag.
- Unused: When a dependency is not used in the package but declared in the `pubspec.yaml`.
  - Optionaly do not fail by using the `--no-fatal-unused` flag.
  - Some packages are not imported by any dart files but are used for their executables. If that is the case they can be white-listed by using the `--ignore` option.

  ```bash
  dependency_validator --ignore coverage,dartdoc
  ```
