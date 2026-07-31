# lib/shared/services/import_export_service.dart

**部分门面。** ZIP 半边（`exportZip` / `importZip`）委托给 `myapps_data` 包（`lib/src/data/zip_transfer.dart`）。Markdown 导出及其许多标签格式化器深度领域特定，留在这里。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| [`exportZip(destDir)`](#exportzip) | 静态方法 | A | 写 `mydevice_export_<stamp>.zip`。 |
| [`importZip(filePath)`](#importzip) | 静态方法 | A | 从导出恢复数据和图像。 |
| [`exportMarkdown(destDir)`](#exportmarkdown) | 静态方法 | A | 写 Markdown 清单报告。 |
| [`buildMarkdown({...})`](#buildmarkdown) | 静态方法 | A | 从加载数据构建 Markdown 正文。 |
| `_categoryLabel`、`_statusLabel`、`_acquisitionTypeLabel`、`_recurringCostKindLabel`、`_billingCycleLabel`、`_moneyText`、`_networkTypeLabel`、…… | 私有辅助 | B | 报告的领域标签格式化。 |

## 文档

### `exportZip(destDir)` <a id="exportzip"></a>
- **返回：** `Future<String?>` — 写入路径，失败时 null。
- **副作用：** 写 `mydevice_export_<yyyyMMdd_HHmmss>.zip`。
- **备注：** 按注册表顺序捆绑注册表的四个数据文件加扁平 `images/<basename>` 条目。配置、`.sync_base/` 和 `backups/` 绝不包含。

### `importZip(filePath)` <a id="importzip"></a>
- **返回：** `Future<bool>` — 成功 true。
- **副作用：** 覆盖允许列表数据文件和图像。
- **备注：** 只提取允许列表条目（注册表数据文件和 `images/` 下扁平文件），每个条目必须解析到应用目录内。

**抽取带来的行为变化：** 每个条目在任何写入前被分类，因此含路径遍历条目的存档现被直接拒绝——调用返回 false 且什么都不写——而非跳过坏条目导入其余。未知条目仍跳过，因此新版构建的存档仍导入。负载作为原始字节写入，如先前一样无 UTF-8 或模型验证。

### `exportMarkdown(destDir)` <a id="exportmarkdown"></a>
- **返回：** `Future<String?>` — 写入路径，失败时 null。
- **副作用：** 加载全部四个存储枢纽并写 `mydevice_export_<yyyyMMdd_HHmmss>.md`。

### `buildMarkdown({...})` <a id="buildmarkdown"></a>
- **用途：** 把设备、网络、数据集和服务渲染进 Markdown 报告正文。
- **备注：** 抽取不变；因完全领域特定留在应用侧。

## 引擎文档在哪里

`packages/myapps_data/doc/en-us/functions/src/data/zip_transfer.md`。
