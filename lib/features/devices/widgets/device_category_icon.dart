import 'package:flutter/material.dart';

import '../models/device.dart';

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
