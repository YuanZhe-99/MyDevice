# 共享界面基础

MyApps-UI v0.1.7 用居中换行标签保持紧凑设置选项横向排列，超过两行才纵向回退。

DATA v1.0.5 管理 WebDAV 连接和操作控件，AI v0.4.3 管理通用偏好组件。
应用回调保留持久化和领域策略。

MyApps-UI v0.1.6 管理外观和导航设置行布局、全宽选项及大字体回退。
MyApps-DATA v1.0.4 管理通用数据操作和备份偏好；MyApps-AI v0.4.2 管理 AI 呈现。
值、文案和回调由应用负责。

## P5 分区策略与授权

MyApps-UI v0.1.5 提供自动和用户选择列数决策及设计分栏。列表偏好仍由应用保存
并按容量限制。设置页使用 MyAppsPaneBody，保留原条件和宽度策略。
LicensePage 明确列出使用的三个包、源码链接和 GNU GPL v3。业务页面设计由应用负责。

## 设置与公共目录

应用固定 MyApps-UI v0.1.4。公共设置分组和分段控件保留原状态回调、存储及路由。
公共外观和导航 ARB 值由库负责，shared_l10n_test 检查一致性。
应用专用文字和运行时代理仍保留在应用。抽取已完成，库的正式概念文档替代
已完成的路线图。

MyApps-UI `v0.1.2` 作为子模块放在 `packages/myapps_ui`，相对地址为
`../MyApps-UI.git`。克隆后递归初始化子模块。

`lib/app/theme.dart` 调用 `myapps_ui`，保留蓝色 `0xFF1565C0`
品牌色和所有公开方法。风格及导航枚举保留序列化名称。
动态配色是否启用仍由应用控制，且仅在 Android 上启用。

`lib/shared/utils/adaptive_layout.dart` 重新导出 `myapps_adaptive` 的公共
阈值及四个纯函数 `canSplitLayout`、`useNavigationRail`、`columnCapacity`、
`listRowCount`。设备、服务指标、拓扑、财务汇总和对话框尺寸仍由应用负责。
资料、设置和同步格式不变。

## 升级

先把共享库发布到两个远程。固定到标签提交，验证应用后
再提交应用指针。库文档维护公共声明；
应用文档维护适配、品牌和内容相关的布局。

## P2 导航与实际空间

应用现在把导航绘制交给 `MyAppsNavigationShell`。应用导航壳保留路由、
目的地过滤、选中位置持久化和提醒回调。页面把 `context` 传入宽度和底部留白
函数，只使用一次实际内容宽度；全窗口路由不再扣除侧栏。无上下文的兼容函数
保留原计算方式。固定内容位置在缩放、风格和侧栏方向切换时保留页面状态。
MyVidComp 保留经典导航、展开侧栏和审核角标。

P3 资料抽取已完成，数据格式不变。

## P3 资料与头像

五个拥有资料功能的应用接入 `myapps_profile`，共享资料模型、合并、图片处理、
存储协调、头像显示、编辑器和标题组件。应用 ProfileStore 提供当前目录、原子写入
和同步通知，图片解析和删除通过适配注入。原导入文件成为重新导出包装。
Riverpod 状态、数据模块注册、选择器和本地化编辑对话框仍由应用负责。
JSON、模块顺序、图片命名和字段合并行为不变。

## 统一 AI 设置

应用固定 MyApps-UI v0.1.8、MyApps-DATA v1.1.0 与 MyApps-AI v0.6.0。AI 设置使用 MyAppsAiSettingsSkeleton、MyAppsAiSourcePicker 与共享模型管理。已有开关和快速模型设置保持序列化键名。本地 CPU 推理不再受系统 AI 平台限制。WebDAV 操作要求本设备确认提醒。
