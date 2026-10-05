# 共享界面基础

MyApps-UI `v0.1.1` 作为子模块放在 `packages/myapps_ui`，相对地址为
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

资料抽取仍属于 P3，数据格式不变。
