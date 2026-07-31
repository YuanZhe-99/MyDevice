# lib/shared/utils/json_preservation.dart

**重新导出垫片。** `unknownJsonFields`、`mergeUnknownJsonFields` 和 `jsonValueEquals` 移到共享 `myapps_data` 包（`lib/src/json/json_preservation.dart`），它导出扁平映射风格和 MyDay 的模式驱动引擎两者。

```dart
export 'package:myapps_data/myapps_data.dart'
    show unknownJsonFields, mergeUnknownJsonFields, jsonValueEquals;
```

本文件保留使模型和 `sync_merge.dart` 不加修改编译。行为相同：未知顶层键解析时捕获、同步时三方合并、写回时写出，使新构建字段经受旧构建保存。

## 声明

没有自己的。

## 真实文档在哪里

`packages/myapps_data/doc/en-us/functions/src/json/json_preservation.md`。
