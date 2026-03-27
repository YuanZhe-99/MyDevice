import 'package:flutter/material.dart';

import '../models/device.dart';

IconData deviceCategoryIcon(DeviceCategory category) {
  return switch (category) {
    DeviceCategory.desktop => Icons.desktop_windows,
    DeviceCategory.laptop => Icons.laptop,
    DeviceCategory.phone => Icons.smartphone,
    DeviceCategory.tablet => Icons.tablet,
    DeviceCategory.headphone => Icons.headphones,
    DeviceCategory.watch => Icons.watch,
    DeviceCategory.router => Icons.router,
    DeviceCategory.gameConsole => Icons.sports_esports,
    DeviceCategory.vps => Icons.dns,
    DeviceCategory.devBoard => Icons.developer_board,
    DeviceCategory.other => Icons.devices_other,
  };
}
