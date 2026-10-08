# lib/features/ai/widgets/ai_source_controls.dart

## AI 来源与 WebDAV 隐私

MyApps-AI v0.6.0 新增 `myapps_ai_sources`：`createAiSourceRouter` 返回共享的 `AiSourceRouter`，取代应用自有的 `AiSourceBackend`。共享来源分区提供来源选择、本地模型入口和本地模型的 GPU 开关（仅在 GPU 已验证时显示）；MyDevice 没有在线来源。全局来源选择仍保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。路由器还会写入设备本地键 `aiComputePreference`、`aiGpuFailures`、`aiCustomModels` 和 `aiModelAliases`，它们从不同步，也不进入备份。本地模型（Qwen3.5 0.8B/2B Q4_K_M、Gemma 4 E2B Q4_0）显示路由器提供的友好名称，例如 `Qwen: Qwen3.5 0.8B (Q4_K_M)`，并可重命名；可在强制警告后从 Hugging Face 仓库添加自定义 GGUF 模型。除非打开 GPU 开关，否则只用 CPU 运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。AI 设置中的技术详情使用 `MyAppsAiDiagnosticsView` 与 `router.diagnostics()`：列出每个包含的后端（应用与平台、选择、系统 AI、llama.cpp 库与设备、每个本地模型），可复制。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。

## Declarations

| Declaration | Purpose |
|---|---|
| `const AiSourceControls({` | Bind the router. Inputs: backend and the selection callback that pauses the AI service. |
| `Widget build(BuildContext context) {` | Build the shared `MyAppsAiSourceSection` (source picker, local models entry, GPU switch; no online entry). |
| `Future<void> openAiLocalModels(BuildContext context, AiSourceRouter backend, String? initial) {` | Open the local models page with a rename menu and the "Add a custom model" entry (`MyAppsAddCustomModelPage`). |
| `MyAppsLocalModelLabels _modelLabels(AppLocalizations l, AiSourceRouter backend) =>` | Build the model list labels; names come from the router (friendly name or alias). |
| `const _ModelMenu({required this.backend, required this.modelId});` | Bind a model to its menu. Inputs: backend, model id. |
| `Widget build(BuildContext context) {` (`_ModelMenu`) | Build the rename and, for custom models, remove-from-list menu. |
| `const _AliasDialog({required this.modelId});` | Bind a model to the rename dialog. Inputs: model id. |
| `Widget build(BuildContext context) {` (`_AliasDialogState`) | Build the rename dialog; pops the typed alias on save. |
