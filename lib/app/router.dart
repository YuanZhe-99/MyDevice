import 'package:go_router/go_router.dart';

import '../features/datasets/views/dataset_list_page.dart';
import '../features/devices/views/device_list_page.dart';
import '../features/network/views/network_list_page.dart';
import '../features/settings/views/settings_page.dart';
import '../shared/widgets/shell_scaffold.dart';

final appRouter = GoRouter(
  initialLocation: '/devices',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ShellScaffold(child: child),
      routes: [
        GoRoute(
          path: '/devices',
          builder: (context, state) => const DeviceListPage(),
        ),
        GoRoute(
          path: '/network',
          builder: (context, state) => const NetworkListPage(),
        ),
        GoRoute(
          path: '/datasets',
          builder: (context, state) => const DataSetListPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);
