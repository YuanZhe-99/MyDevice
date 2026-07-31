# lib/app/flavor.dart

定义 `AppFlavor`，[架构](../../architecture.md) 和本仓库 `AGENTS.md` Build Flavors 表描述的构建风格门。`store` 风格构建必须隐藏在线设备/芯片搜索；`full` 风格构建（GitHub Releases、侧载、桌面安装器）显示它。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`AppFlavor._`](#appflavor-new) | 私有构造函数 | A | 阻止实例化；`AppFlavor` 仅静态。 |
| `isStore` | 静态 const getter | B | 此构建是否以 `--dart-define=FLAVOR=store` 编译。 |
| `isFull` | 静态 const getter | B | `isStore` 的逻辑否定。 |

## 文档

### `AppFlavor._()` <a id="appflavor-new"></a>
- **种类：** `AppFlavor` 的私有未命名构造函数。
- **来源：** `lib/app/flavor.dart`（第 11 行）。
- **用途：** 让 `AppFlavor` 成为编译期风格标志的不可实例化、仅静态持有类。
- **输入：** 无。
- **返回：** 不适用（构造函数私有且从不调用）。
- **副作用：** 无。
- **算法：** 无函数体；其唯一角色是私有，阻止 `AppFlavor()` 在本文件外任何地方编译。
- **用法：** 从不调用；`AppFlavor.isFull`/`AppFlavor.isStore` 作为静态常量被设备功能（搜索门控）和设置 UI 通篇直接读取。
- **备注：** `_flavor` 从 `String.fromEnvironment('FLAVOR', defaultValue: 'full')` 编译期解析，因此风格选择是 `--dart-define` 构建期常量，非运行时设置。
