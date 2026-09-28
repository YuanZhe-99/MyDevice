# lib/features/services/widgets/service_avatar.dart

`ServiceAvatar` 仅在存储的 Material 图标未更改或未设置时，按稳定的模板 ID 查找内置品牌标志。
显式自定义图标以及未知模板继续使用 Material 后备图标。
`serviceTemplateIconAssets` 将同一产品的变体映射到共用资源，不更改持久化服务数据。
`TemplateIcon` 以透明背景和圆内留白完整显示矢量图。

## 声明

| 声明 | 类型 | 层级 | 用途 |
|---|---|---|---|
| `ServiceAvatar` | 构造函数 | B | 配置模板标识、图标和大小。 |
| `ServiceAvatar.fromService` | 构造函数 | B | 从已有服务读取显示元数据。 |
| `build` | 方法 | B | 将未更改的模板图标解析为内置品牌资源。 |

## 文档

单色标志和选定的中性前景色跟随主题，保证明暗模式下的对比度。内置标志可离线使用，不替换用户自选图标。资源来源记录于
`assets/service_icons/SOURCES.md`。
