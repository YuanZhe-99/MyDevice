import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../models/device.dart';

/// Purpose: Implement the device category icon behavior for this file.
/// Inputs: `category`.
/// Returns: `IconData`.
/// Side effects: None.
/// Notes: None.
IconData deviceCategoryIcon(DeviceCategory category) {
  return switch (category) {
    DeviceCategory.desktop => Icons.desktop_windows_outlined,
    DeviceCategory.laptop => Icons.laptop_outlined,
    DeviceCategory.phone => Icons.smartphone_outlined,
    DeviceCategory.tablet => Icons.tablet_mac_outlined,
    DeviceCategory.headphone => Icons.headphones_outlined,
    DeviceCategory.watch => Icons.watch_outlined,
    DeviceCategory.router => Icons.router_outlined,
    DeviceCategory.gameConsole => Icons.sports_esports_outlined,
    DeviceCategory.vps => Icons.dns_outlined,
    DeviceCategory.devBoard => Icons.developer_board_outlined,
    DeviceCategory.other => Icons.devices_other_outlined,
  };
}

/// Purpose: Return the localized name of a device category.
/// Inputs: `l10n`, `category`.
/// Returns: `String`.
/// Side effects: None.
/// Notes: The strings the device editor, device list and finance overview
/// show for a category; the service topology's node details use it for a
/// node's device.
String deviceCategoryLabel(AppLocalizations l10n, DeviceCategory category) =>
    switch (category) {
      DeviceCategory.desktop => l10n.deviceCategoryDesktop,
      DeviceCategory.laptop => l10n.deviceCategoryLaptop,
      DeviceCategory.phone => l10n.deviceCategoryPhone,
      DeviceCategory.tablet => l10n.deviceCategoryTablet,
      DeviceCategory.headphone => l10n.deviceCategoryHeadphone,
      DeviceCategory.watch => l10n.deviceCategoryWatch,
      DeviceCategory.router => l10n.deviceCategoryRouter,
      DeviceCategory.gameConsole => l10n.deviceCategoryGameConsole,
      DeviceCategory.vps => l10n.deviceCategoryVps,
      DeviceCategory.devBoard => l10n.deviceCategoryDevBoard,
      DeviceCategory.other => l10n.deviceCategoryOther,
    };
