# lib/shared/utils/json_preservation.dart

**Re-export shim.** `unknownJsonFields`, `mergeUnknownJsonFields`, and `jsonValueEquals` moved to the
shared `myapps_data` package (`lib/src/json/json_preservation.dart`), which exports both this
flat-map style and MyDay's schema-driven engine.

```dart
export 'package:myapps_data/myapps_data.dart'
    show unknownJsonFields, mergeUnknownJsonFields, jsonValueEquals;
```

This file remains so the models and `sync_merge.dart` keep compiling unchanged. Behavior is
identical: unknown top-level keys are captured on parse, merged three-way on sync, and written back
out, so a newer build's fields survive an older build's save.

## Declarations

None of its own.

## Where the real documentation lives

`packages/myapps_data/doc/en-us/functions/src/json/json_preservation.md`.
