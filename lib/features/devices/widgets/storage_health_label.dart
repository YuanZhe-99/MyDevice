import '../../../l10n/app_localizations.dart';
import '../models/device.dart';

/// Purpose: Return the localized name of a drive's health.
/// Inputs: `l10n`, `health`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: Shared by the device editor, the device details and the data set
/// views.
String storageHealthLabel(AppLocalizations l10n, StorageHealth health) =>
    switch (health) {
      StorageHealth.ok => l10n.storageStatusOk,
      StorageHealth.failed => l10n.storageStatusFailed,
      StorageHealth.offline => l10n.storageStatusOffline,
    };
