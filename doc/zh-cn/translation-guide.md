# 英语 → 简体中文翻译指南

本指南管理 `doc/zh-cn/` 如何产生并与 MyAnime、MyDay、MyDevice 和 MyApps-DATA 的 `doc/en-us/` 保持同步。第 1-4 节和第 6 节逐字节复制进每个仓库 `doc/en-us/translation-guide.md`；第 5 节术语表拆分为处处相同的共享核心加只列那个仓库使用术语的逐仓库小节（且一旦中文树存在，`doc/zh-cn/translation-guide.md` 持有同一指南的中文渲染）。写或更新任何中文文档页前先读此。

## 1. 范围与工作流

- `doc/en-us/` 是权威。`doc/zh-cn/` 是它的翻译，绝无独立来源。
- 英语内容先写，直接来自实际源码和 `AGENTS.md`。中文内容然后用本指南和第 5 节术语表从完成英语页产生。
- 未来任何函数、数据格式、同步规则或功能变更必须在同一提交更新英语页和中文页。绝不让两树漂移。
- 翻译中遇到的新术语进第 5 节。术语真正横切（同步、备份、存储、文档、Flutter 和 Dart 词汇）时放 **5.1 节**并复制到全部四个仓库。它命名只有某个应用有的东西时放那个仓库 **5.2 节**，别的仓库不管——MyDevice 无人能遇到的术语不属于 MyDevice 术语表。

## 2. 结构对等规则

`doc/zh-cn/<path>` 必须精确镜像 `doc/en-us/<path>`：

- 两树存在相同文件集合——不能一个语言有文件另一个缺。
- 相同标题层级和数量（`#`、`##`、`###`、……）。
- 相同数量和顺序的表格和表格行。
- 相同数量的围栏代码块，**内部代码相同**（代码是数据，非散文）。
- 相同内部链接和锚点，指向翻译等价物。

验证遍逐文件比较两树标题数、表格行数和代码围栏数；两者必须精确匹配。

## 3. 绝不翻译的内容

- 标识符：类/函数/变量/字段名、文件路径、目录名。
- CLI 命令及其标志/输出。
- 配置键（如 `storage_config.json` 键、`webdav_config.json` 键）。
- URL 和掩码占位符 `<local_gitea_address>`。
- 产品、框架和协议名：WebDAV、Riverpod、go_router、Flutter、Dart、Gitea、GitHub、MSIX、Inno Setup、AGP、Gradle、Jikan、AniList。
- 函数索引使用的 Tier A / Tier B 标签。
- 围栏代码块内任何东西，含作为示例代码一部分写的注释，除非注释是可执行行外解释示例的散文——那种情况翻译解释性注释文本但绝不译代码令牌本身。

## 4. 风格规则

- 用中性、陈述技术语气。不用正式代词您；只有不可避免第二人称时用你，否则偏好非人称措辞。
- 散文用全角中文标点（，。：；「」），但所有 Markdown 语法字符（`#`、`` ` ``、`|`、`-`、`*`、`[]()`）保持普通 ASCII 形态，使 Markdown 仍解析。
- 中文字符与相邻拉丁字母或数字间插入单个空格（如"支持 WebDAV 同步"、"保留 60 秒"）。
- 保持句子短；偏好把长英语句拆成两个中文句而非产生一个密集流水句。
- 数字、版本号、文件名和代码标识符保持与英语完全一致。

## 5. 术语表

第 5.1 节是共享核心，必须在四个仓库保持相同。第 5.2 节列出本仓库自己领域特有术语，逐仓库刻意不同。添加术语前决定它属于哪节——见第 1 节规则。

### 5.1 共享核心（四个仓库相同）

| 英语 | 中文 | 备注 |
|---|---|---|
| sync / synchronization | 同步 | |
| three-way merge | 三方合并 | base/local/remote 三方 |
| base snapshot | 基线快照 | 合并比较使用的 `.sync_base` 副本 |
| conflict / conflict resolution | 冲突 / 冲突解决 | |
| auto-resolve | 自动解决 | |
| backup / restore | 备份 / 恢复 | |
| snapshot | 快照 | |
| blob | blob | 不译；指内容寻址的二进制附件对象 |
| retention (policy) | 保留策略 | |
| WebDAV | WebDAV | 不译 |
| lock / lock file | 锁 / 锁文件 | |
| heartbeat | 心跳 | periodic lock-refresh signal |
| stale lock | 过期锁 | |
| interrupted upload | 中断的上传 | |
| provider | provider | Riverpod 术语，不译 |
| route / router | 路由 / 路由器 | |
| deep link | 深层链接 | |
| flavor (build flavor) | 构建风味 | Flutter build flavor 概念，不译作"口味"以外的怪异译法时保留英文首次标注 |
| barrel file | 桶文件（barrel file） | 首次出现附英文原词 |
| unknown-key preservation | 未知键保留 | 向前兼容的数据保留机制 |
| duplicate detection | 重复检测 | |
| declaration | 声明 | function/method/constructor/getter/setter 统称 |
| getter / setter | getter / setter | 不译 |
| widget | 组件（widget） | 首次出现附英文原词 |
| side effects | 副作用 | |
| remote (git) | 远程仓库 | |
| submodule | 子模块 | git submodule |
| facade | 门面（facade） | 设计模式术语，首次出现附英文原词 |
| atomic write | 原子写入 | tmp-then-rename pattern |
| storage hub | 存储中枢 | per-app central storage class |
| function index | 函数索引 | |
| algorithm documentation | 算法文档 | |
| usage / example documentation | 用法 / 示例文档 | |
| Tier A / Tier B | Tier A / Tier B | 文档覆盖分级标签，不译 |
| build method | build 方法 | Flutter widget 的 build() |
| l10n / localization | 本地化（l10n） | |
| ARB file | ARB 文件 | Application Resource Bundle |
| ZIP export / import | ZIP 导出 / 导入 | |
| path traversal | 路径穿越 | 安全术语，指目录遍历攻击 |
| allowlist | 允许列表 | |
| garbage collection (GC) | 垃圾回收（GC） | 指备份 blob 的引用计数回收 |
| debounce | 防抖 | |
| wake lock | 唤醒锁 | screen wake lock, `wakelock_plus` |
| adaptive layout | 自适应布局 | |
| window size class | 窗口尺寸类别 | Material 的 compact/medium/expanded 分级 |
| breakpoint | 断点 | 布局阈值 |
| viewport | 视口 | |
| logical pixel (dp) | 逻辑像素（dp） | 与密度无关的布局单位 |
| aspect ratio | 宽高比 | width / height |
| foldable | 折叠屏设备 | |
| cover screen | 外屏 | 折叠状态下的外部屏幕 |
| split layout | 分栏布局 | |
| pane | 窗格（pane） | 首次出现附英文原词 |
| two-pane | 双栏 | 左右两个窗格的布局 |
| navigation rail | 导航栏（NavigationRail） | Material 侧边导航；不译作「轨道」 |
| bottom navigation bar | 底部导航栏 | |
| content width | 内容宽度 | 扣除导航栏后页面内容实际获得的宽度 |
| column capacity | 列容量 | 给定最小列宽时一行能容纳的列数 |

### 5.2 MyDevice 特有术语

不复制到其他仓库——其他应用无这些。

| 英语 | 中文 | 备注 |
|---|---|---|
| tray (system tray) | 系统托盘 | |
| local API server | 本地 API 服务器 | |
| trend chart | 趋势图 | |
| metric | 指标 | a selectable series on a trend chart |

## 6. 复核清单（提交中文页前运行）

- [ ] 文件存在于 `doc/zh-cn/` 下与其英语对应物相同相对路径。
- [ ] 标题数匹配（`grep -c '^#'`）。
- [ ] 代码围栏数匹配（`grep -c '^```'`），代码内容与英语逐字节相同。
- [ ] 表格行数匹配。
- [ ] 每个使用术语与第 5 节精确匹配；任何新横切术语已添加到全部四个仓库 5.1 节，任何应用特有术语只添加到本仓库 5.2 节。
- [ ] 无真实 Gitea 主机出现；主机处用 `<local_gitea_address>`。
- [ ] 内部链接解析到中文树等价物，不回到 `doc/en-us/`。
