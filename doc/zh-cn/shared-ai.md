# 共享 AI

## 所有权

MyApps-AI v0.1.0 通过相对同级 URL `../MyApps-AI.git` 嵌入 `packages/myapps_ai`。
全新检出先执行 `git submodule update --init --recursive`，再执行 `flutter pub get`。
依赖路径为 `packages/myapps_ai/packages/myapps_ai`。

`genai_backend.dart` 保留既有通道名称并导出共享类型。
`on_device_ai_service.dart` 负责单例和 Riverpod provider，共享代码负责执行。
`output_validation.dart` 导出共享清理工具。原生通道、业务提示词、事实、解析器和
缓存格式留在应用。授权页列出 myapps_ai 及 GPL v3 源码。

## 行为

关闭时不查询后端或生成。开关和模型偏好变更使晚到结果失效。45 秒超时现在会在
推进队列前请求原生后端取消。应用 dispose 结束队列中的任务。保留交互优先、
后台节奏、生命周期门控和当日配额行为。取消仍受原生系统实现约束。

## 验证

适配器变更后运行 flutter analyze 和应用测试套件。共享包测试覆盖独立能力状态和
晚到结果失效。本步骤原生代码不变；平台整合发布前需验证 release 构建与 Apple 弱链接。
