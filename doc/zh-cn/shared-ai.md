# 共享 AI

## 所有权

当前实现使用 MyApps-AI v0.4.1 缓存条目序列化及一次备用生成。模块键、指纹、存储、
提示词和解析器仍留在应用，财务备用策略保持不变。

MyApps-AI v0.4.1 通过相对同级 URL `../MyApps-AI.git` 嵌入 `packages/myapps_ai`。
全新检出先执行 `git submodule update --init --recursive`，再执行 `flutter pub get`。
依赖路径为 `packages/myapps_ai/packages/myapps_ai`。

`genai_backend.dart` 保留既有通道名称并导出共享类型。
`on_device_ai_service.dart` 负责单例和 Riverpod provider，共享代码负责执行。
`output_validation.dart` 导出共享清理工具。原生通道、业务提示词、事实、解析器和
缓存格式留在应用，原生通道由共享 myapps_ai_platform 插件注册。
授权页列出 myapps_ai、myapps_ai_platform 及 GPL v3 源码。

## 行为

关闭时不查询后端或生成。开关和模型偏好变更使晚到结果失效。45 秒超时现在会在
推进队列前请求原生后端取消。应用 dispose 结束队列中的任务。保留交互优先、
后台节奏、生命周期门控和当日配额行为。取消仍受原生系统实现约束。

## 验证

适配器变更后运行 flutter analyze 和应用测试套件。共享包测试覆盖独立能力状态和
晚到结果失效。共享 CI 已通过 Android ARM64、iOS/macOS release 构建和 Apple 弱链接。
消费者 release 构建及真机推理仍是独立检查。

共享呈现使用 myapps_ai_ui，设置文案、功能门控和操作由应用负责。
洞察调度使用 AiInsightCoordinator，应用回调负责生成、JSON 存储、模块键、提示词与解析。

## AI 来源与 WebDAV 隐私

MyApps-AI v0.6.0 新增 `myapps_ai_sources`：`createAiSourceRouter` 返回共享的 `AiSourceRouter`，取代应用自有的 `AiSourceBackend`。共享来源分区提供来源选择、本地模型入口和本地模型的 GPU 开关（仅在 GPU 已验证时显示）；MyDevice 没有在线来源。全局来源选择仍保存在设备本地（`aiSourceSelection`），默认系统 AI，不会自动回退到在线来源。路由器还会写入设备本地键 `aiComputePreference`、`aiGpuFailures`、`aiCustomModels` 和 `aiModelAliases`，它们从不同步，也不进入备份。本地模型（Qwen3.5 0.8B/2B Q4_K_M、Gemma 4 E2B Q4_0）显示路由器提供的友好名称，例如 `Qwen: Qwen3.5 0.8B (Q4_K_M)`，并可重命名；可在强制警告后从 Hugging Face 仓库添加自定义 GGUF 模型。除非打开 GPU 开关，否则只用 CPU 运行。下载仅由明确操作触发，使用固定地址与 SHA-256，保存在 `ai_models/`，不进入数据模块、同步、备份或 ZIP。模型租约避免使用中移除文件。切换来源取消旧任务并释放模型资源。AI 设置中的技术详情使用 `MyAppsAiDiagnosticsView` 与 `router.diagnostics()`：列出每个包含的后端（应用与平台、选择、系统 AI、llama.cpp 库与设备、每个本地模型），可复制。MyNihongo 的系统校对保持独立。

WebDAV 第 1 版提醒必须在每个设备上确认后，才能测试连接、手动/强制同步或后台同步。记录保存在设备本地 storage_config.json。已有配置保持不变，同步暂停时 WebDAV 页面显示查看提醒横幅。拒绝不保存配置、不发出请求。JSON/图片没有应用层加密；HTTPS 加密传输，HTTP 不加密。线格式、锁和冲突策略保持不变。
