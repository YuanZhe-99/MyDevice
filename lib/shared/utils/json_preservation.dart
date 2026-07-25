/// Purpose: Re-export the shared flat-map JSON preservation helpers.
/// Inputs: None (library declaration only).
/// Returns: N/A.
/// Side effects: None.
/// Notes: `unknownJsonFields`, `mergeUnknownJsonFields`, and `jsonValueEquals`
/// moved to the `myapps_data` package, which exports both this
/// flat-map style and MyDay's schema-driven engine. This file stays so every
/// existing import — models and `sync_merge.dart` — keeps working (I7).
library;

export 'package:myapps_data/myapps_data.dart'
    show unknownJsonFields, mergeUnknownJsonFields, jsonValueEquals;
