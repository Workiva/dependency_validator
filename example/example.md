Either globally activate this package or add it as a dev_dependency:
```bash
# Install as a dev dependency on the project -- shared with all collaborators
$ dart pub add --dev dependency_validator

# Install globally on your system -- does not impact the project
$ dart pub global activate dependency_validator
```

Then run:

```bash
# If installed as a dependency:
$ dart run dependency_validator

# If globally activated:
$ dart pub global run dependency_validator
```

If needed, add a configuration in `dart_dependency_validator.yaml`:

```yaml
# Exclude one or more paths from being scanned. Supports glob syntax.
exclude:
  - "app/**"

# Ignore one or more packages.
ignore:
  - analyzer

# Allow dependencies to be pinned to a specific version instead of a range
allowPins: true
```
