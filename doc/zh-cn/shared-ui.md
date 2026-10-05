# 共享界面基础

MyApps-UI `v0.1.0` 作为子模块放在 `packages/myapps_ui`，相对地址为
`../MyApps-UI.git`。克隆后递归初始化子模块。

`lib/app/theme.dart` 调用 `myapps_ui`，保留蓝色 `0xFF1565C0`
品牌色和所有公开方法。风格及导航枚举保留序列化名称。
动态配色是否启用仍由应用控制，且仅在 Android 上启用。

`lib/shared/utils/adaptive_layout.dart` 重新导出 `myapps_adaptive` 的公共
阈值及四个纯函数 `canSplitLayout`、`useNavigationRail`、`columnCapacity`、
`listRowCount`。设备、服务指标、拓扑、财务汇总和对话框尺寸仍由应用负责。
内容宽度预测保持不变，等待后续导航容器阶段。
资料、设置和同步格式不变。

## 升级

先把共享库发布到两个远程。固定到标签提交，验证应用后
再提交应用指针。库文档维护公共声明；
应用文档维护适配、品牌和内容相关的布局。
