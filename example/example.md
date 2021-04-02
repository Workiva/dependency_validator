Either globally activate this package or add it as a dev_dependency. Then run:

```bash
# If installed as a dependency:
$ dart run dependency_validator

# If globally activated:
$ dart pub global run dependency_validator
```

If needed, configure dependency_validator in your `pubspec.yaml`:

```yaml
# pubsec.yaml
dependency_validator:
  # Exclude one or more paths from being scanned.
  # Supports glob syntax.
  exclude:
    - "app/**"
  # Ignore one or more packages.
  ignore:
    - analyzer
```
