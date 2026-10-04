# lib/features/devices/widgets/hardware_entries_editor.dart

## 声明

| 声明 | 类型 | 用途 |
|---|---|---|
| `HardwareEntriesEditor` | 构造函数 | 将硬件列表绑定至父级草稿。 |
| `label` | 静态方法 | 本地化类型/角色，保留未知值。 |
| `_field` | 方法 | 构建稳定的控制器字段。 |
| `_gpu` | 方法 | 替换 GPU 字段，保留 ID 和未知键。 |
| `_display` | 方法 | 替换屏幕字段，保留 ID 和未知键。 |
| `build` | 方法 | 构建增删、上移、预设/搜索及独立规格。 |
| `_HardwareField` | 构造函数 | 绑定标签、值及回调。 |
| `createState` | 方法 | 创建字段控制器状态。 |
| `initState` | 方法 | 分配文本控制器。 |
| `didUpdateWidget` | 方法 | 反映外部变更，不重置匹配的文本。 |
| `dispose` | 方法 | 释放控制器。 |
| `_HardwareFieldState.build` | 方法 | 构建受控输入。 |

ID 是卡片和字段的键。父级持有草稿列表，折叠展开保留编辑。预设/搜索仅替换型号和
架构。未知类型/角色仍可选择。每块屏幕独立计算 PPI，未完成的数字输入保留在字段内。
