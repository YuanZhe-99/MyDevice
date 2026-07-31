# lib/shared/services/sync_wake_lock.dart

**重新导出垫片。** `SyncWakeLock` 逐字移到共享 `myapps_data` 包（那里的 `lib/src/sync/sync_wake_lock.dart`）。三个应用的副本逐字节相同（经 SHA-256 验证）。

```dart
export 'package:myapps_data/myapps_data.dart' show SyncWakeLock;
```

锁仍引用计数、所有权跟踪并吞掉所有插件错误。它由运行前台操作（手动同步、冲突终定、强制上传/下载）的**页面**获取和释放，不由同步引擎——后台自动同步绝不能用它。

## 声明

没有自己的。

## 真实文档在哪里

`packages/myapps_data/doc/en-us/functions/src/sync/sync_wake_lock.md`。
