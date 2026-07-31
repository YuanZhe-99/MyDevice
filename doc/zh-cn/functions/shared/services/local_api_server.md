# lib/shared/services/local_api_server.dart

`LocalApiServer` 是 [平台说明](../../../platform-notes.md) 描述的仅桌面本地 HTTP API：基于 `shelf`、默认禁用、暴露设备/网络/数据集/服务只读清单端点加一个修改性设备添加端点的服务器。每个非添加端点只浮出手动保存数据——按本仓库 `AGENTS.md`，服务功能（并延伸此 API）绝不能扫描端口、连接服务器或检查 Docker。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `port` | 静态 getter | B | 配置 API 服务器端口（默认 7789）。 |
| `listenAddress` | 静态 getter | B | 配置 API 服务器监听地址。 |
| `enabled` | 静态 getter | B | API 服务器是否在保存设置中启用。 |
| `isRunning` | 静态 getter | B | 服务器当前是否绑定。 |
| `lastError` | 静态 getter | B | 上次启动/运行时错误码（如有）。 |
| [`loadConfig`](#loadconfig) | 静态方法 | A | 从 `storage_config.json` 加载 API 服务器设置。 |
| [`start`](#start) | 静态方法 | A | 按当前配置绑定并服务 API 服务器。 |
| [`stop`](#stop) | 静态方法 | A | 强制关闭运行中服务器（如有）。 |
| [`restart`](#restart) | 静态方法 | A | 重新加载配置并重启服务器。 |
| `_handlePing` | 静态方法（路由处理器） | B | `GET /ping` 存活检查。 |
| [`_handleList`](#handlelist) | 静态方法（路由处理器） | A | `GET /device/list`：设备，可选按类别过滤。 |
| [`_handleSearch`](#handlesearch) | 静态方法（路由处理器） | A | `GET /device/search`：匹配文本查询的设备。 |
| [`_handleAdd`](#handleadd) | 静态方法（路由处理器） | A | `POST /device/add`：从 JSON 体创建设备。 |
| [`_handleStats`](#handlestats) | 静态方法（路由处理器） | A | `GET /device/stats`：跨模块摘要统计。 |
| [`_handleNetworkList`](#handlenetworklist) | 静态方法（路由处理器） | A | `GET /network/list`：带赋值详情的网络。 |
| [`_handleNetworkSearch`](#handlenetworksearch) | 静态方法（路由处理器） | A | `GET /network/search`：匹配查询的网络/赋值。 |
| [`_handleDatasetList`](#handledatasetlist) | 静态方法（路由处理器） | A | `GET /dataset/list`：带链接存储详情的数据集。 |
| [`_handleDatasetSearch`](#handledatasetsearch) | 静态方法（路由处理器） | A | `GET /dataset/search`：匹配查询的数据集。 |
| [`_handleServiceList`](#handleservicelist) | 静态方法（路由处理器） | A | `GET /service/list`：带简单过滤器的服务。 |
| [`_handleServiceSearch`](#handleservicesearch) | 静态方法（路由处理器） | A | `GET /service/search`：匹配查询的服务。 |
| [`_handleServiceRoutes`](#handleserviceroutes) | 静态方法（路由处理器） | A | `GET /service/routes`：保存的访问路由。 |
| [`_handleServiceStats`](#handleservicestats) | 静态方法（路由处理器） | A | `GET /service/stats`：仅服务摘要统计。 |
| [`buildStatsJson`](#buildstatsjson) | 静态方法 | A | 构建 `/device/stats` 响应体。 |
| [`deviceToJson`](#devicetojson) | 静态方法 | A | 序列化 `Device` 供 API 响应。 |
| [`storageToJson`](#storagetojson) | 静态方法 | A | 序列化 `StorageInfo`。 |
| [`filterDevicesForSearch`](#filterdevicesforsearch) | 静态方法 | A | 不区分大小写设备文本搜索。 |
| [`buildNetworkListJson`](#buildnetworklistjson) | 静态方法 | A | 带分组赋值序列化网络。 |
| [`networkToJson`](#networktojson) | 静态方法 | A | 序列化一个 `Network`，带可选赋值/设备名富化。 |
| [`filterNetworksForSearch`](#filternetworksforsearch) | 静态方法 | A | 不区分大小写网络/赋值文本搜索。 |
| [`buildDataSetListJson`](#builddatasetlistjson) | 静态方法 | A | 带链接存储序列化数据集。 |
| [`dataSetToJson`](#datasettojson) | 静态方法 | A | 带解析存储链接序列化一个 `DataSet`。 |
| [`filterDataSetsForSearch`](#filterdatasetsforsearch) | 静态方法 | A | 不区分大小写数据集/链接文本搜索。 |
| [`buildServiceListJson`](#buildservicelistjson) | 静态方法 | A | 为 API 响应序列化服务。 |
| [`serviceToJson`](#servicetojson) | 静态方法 | A | 序列化一个 `ServiceNode`。 |
| [`filterServicesForList`](#filterservicesforlist) | 静态方法 | A | 按 `deviceId`/`kind`/`state` 过滤服务。 |
| [`filterServicesForSearch`](#filterservicesforsearch) | 静态方法 | A | 不区分大小写服务文本搜索。 |
| [`buildServiceRouteListJson`](#buildserviceroutelistjson) | 静态方法 | A | 为 API 响应序列化服务路由。 |
| [`serviceRouteToJson`](#serviceroutetojson) | 静态方法 | A | 序列化一个 `ServiceRoute`。 |
| [`buildServiceStatsJson`](#buildservicestatsjson) | 静态方法 | A | 构建 `/service/stats` 响应体。 |
| `_deviceToJson` | 静态方法 | B | `deviceToJson` 的私有转发别名。 |
| [`_serviceEndpointToJson`](#serviceendpointtojson) | 静态方法 | A | 带解析网络名序列化 `ServiceEndpoint`。 |
| [`_serviceRouteHopToJson`](#serviceroutehoptojson) | 静态方法 | A | 带解析名序列化 `ServiceRouteHop`。 |
| [`_publicTargets`](#publictargets) | 静态方法 | A | 从路由 `extraJson` 读取分组公共目标。 |
| [`_deviceNameMap`](#devicenamemap) | 静态方法 | A | 构建设备 id 到名查找映射。 |
| [`_countBy`](#countby) | 静态方法 | A | 泛型分组计数辅助。 |
| [`_containsText`](#containstext) | 静态方法 | A | 跨多个值的不区分大小写子串测试。 |
| [`_intValue`](#intvalue) | 静态方法 | A | API 请求体容忍 int 解析器。 |
| [`_doubleValue`](#doublevalue) | 静态方法 | A | API 请求体容忍 double 解析器。 |
| [`_dateValue`](#datevalue) | 静态方法 | A | API 请求体容忍 `DateTime` 解析器。 |
| [`_moneyValueFromJson`](#moneyvaluefromjson) | 静态方法 | A | 从 JSON 映射解析可选 `MoneyValue`。 |
| [`_recurringCostFromJson`](#recurringcostfromjson) | 静态方法 | A | 从 JSON 映射解析可选 `DeviceRecurringCost`。 |
| `_json` | 静态方法 | B | 把值包装为 `200 application/json` `Response`。 |
| `_error` | 静态方法 | B | 为给定状态构建 JSON 错误 `Response`。 |
| [`_parseBody`](#parsebody) | 静态方法 | A | 把请求体解析为 JSON，容忍格式错误输入。 |
| [`_corsMiddleware`](#corsmiddleware) | 静态方法 | A | 每个响应的宽松 CORS 中间件。 |
| [`_authMiddleware`](#authmiddleware) | 静态方法 | A | 执行 Basic Auth / 仅回环访问规则。 |
| [`_validateBasicAuth`](#validatebasicauth) | 静态方法 | A | 对照配置凭据验证 `Authorization: Basic` 页头。 |
| [`_errorMiddleware`](#errormiddleware) | 静态方法 | A | 把未处理处理器异常捕获为 `500` JSON 错误。 |

## 文档

### `static Future<void> loadConfig()` <a id="loadconfig"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** 第 66 行。
- **用途：** 从 `storage_config.json` 读取持久化 API 设置（`apiPort`、`apiListenAddress`、`apiEnabled`、`apiUsername`、`apiPassword`）。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 经 `DeviceStorage.readConfig()` 读取配置；设置静态字段（默认端口 `7789`、默认地址 `'localhost'`）。
- **算法：** 带缺失键默认的直接映射读取。
- **用法：** 被 `start()`/`restart()` 和设置 UI 调用。
- **备注：** 凭据按明文读取，按本应用文档化安全姿态。

### `static Future<void> start()` <a id="start"></a>
- **种类：** `LocalApiServer` 的静态方法。
- **来源：** 第 80 行。
- **用途：** 按当前设置绑定并启动 API 服务器，禁用时不做事。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 绑定监听套接字；设置 `_server`/`_lastError`；记录到 stdout。
- **算法：** `loadConfig()`、`stop()` 任何先前实例、清除 `_lastError`；禁用提前返回。计算 `isNonLoopback`（地址是 `0.0.0.0` 或既非 `localhost` 也非 `127.0.0.1`）和 `hasCredentials`；非回环无凭据时以 `_lastError = 'credentials_required'` 拒绝启动。构建带 13 条路由（`/ping`、`/device/list`、`/device/search`、`/device/add`、`/device/stats`、`/network/list`、`/network/search`、`/dataset/list`、`/dataset/search`、`/service/list`、`/service/search`、`/service/routes`、`/service/stats`）的 `Router`；把它包进 `_corsMiddleware` → `_authMiddleware` → `_errorMiddleware`；解析绑定地址并 `shelf_io.serve`；把绑定失败捕获进 `_lastError`。
- **用法：** 桌面平台从 `main()` 调用。
- **备注：** 与 MyAnime 的 `LocalApiServer.start` 相同的无凭据不安全非本地主机拒绝，但带 MyDevice 自己默认端口 `7789`（对比 MyAnime `7788`）和路由表。

### `static Future<void> stop()` <a id="stop"></a>
- **种类：** 静态方法。**来源：** 第 148 行。
- **用途：** 强制关闭运行中服务器（如有）。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 关闭套接字（`force: true`）；设 `_server = null`。
- **算法：** `await _server?.close(force: true); _server = null;`。
- **用法：** 在 `start()` 开头和设置 UI 禁用操作调用。
- **备注：** 丢弃在途连接；无优雅排空。

### `static Future<void> restart()` <a id="restart"></a>
- **种类：** 静态方法。**来源：** 第 158 行。
- **用途：** 重新加载设置并重新绑定。
- **输入：** 无。**返回：** `Future<void>`。
- **副作用：** 与 `loadConfig()` + `start()` 相同。
- **算法：** `await loadConfig(); await start();`。
- **用法：** 被设置 UI 的 API 小节保存操作调用。
- **备注：** 无。

### `static Future<Response> _handleList(Request request)` <a id="handlelist"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 179 行。
- **用途：** 返回保存设备，可选按类别过滤。
- **输入：** `request` — 可选 `?category=` 匹配 `DeviceCategory.name`。
- **返回：** 带设备列表（经 `buildStatsJson` 邻近序列化，见 `deviceToJson`）的 `200` JSON。
- **副作用：** 读取设备存储。
- **算法：** 加载设备；`category` 存在且有效时按 `d.category.name == category` 过滤；每个经 `deviceToJson` 序列化。
- **用法：** 想要完整或类别过滤设备清单的本地/局域网客户端调用。
- **备注：** 类别值必须精确匹配 `DeviceCategory.name`（区分大小写枚举名）。

### `static Future<Response> _handleSearch(Request request)` <a id="handlesearch"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 202 行。
- **用途：** 按人类可读清单字段搜索保存设备。
- **输入：** `request` — `?q=` 搜索文本。
- **返回：** `200` JSON 列表；无匹配时空列表。
- **副作用：** 读取设备存储。
- **算法：** 加载设备；匹配委托 `filterDevicesForSearch`；序列化结果。
- **用法：** 不经完整列表倾倒按名/品牌/型号等查找设备调用。
- **备注：** 绝不执行在线查找——只清单字段。

### `static Future<Response> _handleAdd(Request request)` <a id="handleadd"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 217 行。
- **用途：** 从 JSON 体创建新设备。
- **输入：** `request` — JSON 体；`name` 和 `category` 必填，其他一切可选（CPU/GPU/存储/财务/位置字段）。
- **返回：** 缺失/无效体、缺失名或无效类别时 `400`；否则带 `{success: true, id, name}` 的 `200`。
- **副作用：** 经 `DeviceStorage.addOrUpdate` 持久化新设备（可触发自动同步本地数据变更通知）。
- **算法：** 验证 `name`/`category`（对照 `DeviceCategory.values` 按名匹配）；把可选嵌套 `cpu`/`gpu`/`storage` 映射解析为 `CpuInfo`/`GpuInfo`/`List<StorageInfo>`（缺席或错误形态默认空值）；经 `_recurringCostFromJson` 解析 `recurringCosts`，丢弃格式错误条目（`whereType`）；经容忍 `_intValue`/`_doubleValue`/`_dateValue`/`_moneyValueFromJson` 辅助解析标量字段；构造并保存 `Device`。
- **用法：** 外部工具程序化添加设备时调用。
- **备注：** 未知或格式错误可选字段静默忽略而非拒绝整个请求——只有 `name`/`category` 是硬要求。

### `static Future<Response> _handleStats(Request request)` <a id="handlestats"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 326 行。
- **用途：** 返回跨模块摘要统计。
- **输入：** `request`（不直接使用）。**返回：** `200` JSON，见 `buildStatsJson`。
- **副作用：** 读取设备、服务、网络和数据集存储。
- **算法：** 加载全部四个存储；委托 `buildStatsJson`。
- **用法：** 跨所有清单类型的仪表盘式总览调用。
- **备注：** 为 API 兼容保留遗留顶层设备摘要字段。

### `static Future<Response> _handleNetworkList(Request request)` <a id="handlenetworklist"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 350 行。
- **用途：** 返回富化赋值详情的保存网络。
- **输入：** `request`（未用）。**返回：** `200` JSON，见 `buildNetworkListJson`。
- **副作用：** 读取网络和设备存储（供赋值设备名）。
- **算法：** 加载两个存储；委托 `buildNetworkListJson`。
- **用法：** 只读网络清单列出。
- **备注：** 只读端点。

### `static Future<Response> _handleNetworkSearch(Request request)` <a id="handlenetworksearch"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 367 行。
- **用途：** 搜索保存网络及其设备赋值。
- **输入：** `request` — `?q=`。**返回：** `200` JSON 列表。
- **副作用：** 读取网络和设备存储。
- **算法：** 加载两个存储；委托 `filterNetworksForSearch`；序列化匹配。
- **用法：** 按名/寻址字段/备注/赋值主机或 IP 查找网络。
- **备注：** 也搜索赋值主机/IP 数据，不只网络记录本身。

### `static Future<Response> _handleDatasetList(Request request)` <a id="handledatasetlist"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 394 行。
- **用途：** 返回带链接设备存储详情的保存数据集。
- **输入：** `request`（未用）。**返回：** `200` JSON，见 `buildDataSetListJson`。
- **副作用：** 读取数据集和设备存储。
- **算法：** 加载两个存储；委托 `buildDataSetListJson`。
- **用法：** 只读数据集清单列出。
- **备注：** 只读端点。

### `static Future<Response> _handleDatasetSearch(Request request)` <a id="handledatasetsearch"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 410 行。
- **用途：** 搜索数据集及其链接设备存储槽。
- **输入：** `request` — `?q=`。**返回：** `200` JSON 列表。
- **副作用：** 读取数据集和设备存储。
- **算法：** 加载两个存储；委托 `filterDataSetsForSearch`；序列化匹配。
- **用法：** 按名加链接设备/存储摘要查找数据集。
- **备注：** 无。

### `static Future<Response> _handleServiceList(Request request)` <a id="handleservicelist"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 432 行。
- **用途：** 返回带可选简单过滤器的保存服务节点。
- **输入：** `request` — 可选 `?deviceId=`、`?kind=`、`?state=`（序列化枚举名）。
- **返回：** `200` JSON，见 `buildServiceListJson`。
- **副作用：** 读取服务、设备和网络存储（供名富化）。
- **算法：** 加载存储；应用 `filterServicesForList`；经 `buildServiceListJson` 序列化。
- **用法：** 服务清单列出，可选限定到一个设备/kind/state。
- **备注：** 适用时过滤值用序列化枚举名。

### `static Future<Response> _handleServiceSearch(Request request)` <a id="handleservicesearch"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 457 行。
- **用途：** 按名、设备、端点、标签和备注搜索服务节点。
- **输入：** `request` — `?q=`。**返回：** `200` JSON 列表。
- **副作用：** 读取服务、设备和网络存储。
- **算法：** 加载存储；委托 `filterServicesForSearch`；序列化匹配。
- **用法：** 跨保存元数据查找服务。
- **备注：** 不扫描活端口或不检查运行中服务——仅手动清单。

### `static Future<Response> _handleServiceRoutes(Request request)` <a id="handleserviceroutes"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 485 行。
- **用途：** 返回保存服务访问路由。
- **输入：** `request`（未用）。**返回：** `200` JSON，见 `buildServiceRouteListJson`。
- **副作用：** 读取服务和设备存储。
- **算法：** 加载存储；委托 `buildServiceRouteListJson`。
- **用法：** 获取完整访问路由清单，如供外部拓扑工具。
- **备注：** 路由名可内部生成；按本仓库服务功能约定，调用方显示应偏好备注/最终目标。

### `static Future<Response> _handleServiceStats(Request request)` <a id="handleservicestats"></a>
- **种类：** 静态方法（路由处理器）。**来源：** 第 502 行。
- **用途：** 返回服务特定摘要统计。
- **输入：** `request`（未用）。**返回：** `200` JSON，见 `buildServiceStatsJson`。
- **副作用：** 读取服务存储。
- **算法：** 加载服务；委托 `buildServiceStatsJson`。
- **用法：** `/device/stats` 的仅服务仪表盘较窄伴生。
- **备注：** 无。

### `static Map<String, dynamic> buildStatsJson({required List<Device> devices, ...})` <a id="buildstatsjson"></a>
- **种类：** 静态方法。**来源：** 第 517 行。
- **用途：** 构建跨模块 `/device/stats` 响应：设备总计/按类别计数/最近添加，加嵌入服务/网络/数据集摘要计数。
- **输入：** `devices`、`services`、`routes`，加可选 `networks`/`datasets` 列表。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无（对输入纯计算）。
- **算法：** 计算 `total` 设备数、经 `_countBy` 的 `byCategory`、`recentlyAdded` 切片（按 `modifiedAt`/`createdAt` 最近设备），并嵌入与 `buildServiceStatsJson` 构建方式相同的 `services` 摘要对象，加任何提供网络/数据集的计数。
- **用法：** 被 `_handleStats` 调用，可直接单元测试（接受加载数据而非自己读存储）。
- **备注：** `total`、`byCategory`、`recentlyAdded` 和 `services` 为 API 兼容原因文档化为稳定字段名。

### `static Map<String, dynamic> deviceToJson(Device device)` <a id="devicetojson"></a>
- **种类：** 静态方法。**来源：** 第 605 行。
- **用途：** 把 `Device` 序列化进本地 API 公共响应形态。
- **输入：** `device`。**返回：** `Map<String, dynamic>` — 身份/类别/CPU/GPU/RAM/存储/屏幕/位置/生命周期/财务字段加 `imagePath`。
- **副作用：** 无。
- **算法：** 直接字段映射，含每个存储槽嵌套 `storageToJson` 和计算财务摘要字段。
- **用法：** 被 `_handleList`/`_handleSearch`/`_handleAdd` 响应和 `buildNetworkListJson`/`buildDataSetListJson` 的设备名富化路径经 `_deviceNameMap` 间接调用。
- **备注：** 保留遗留键，同时附加包含原始 API 契约后添加的生命周期/位置/图像/财务字段。

### `static Map<String, dynamic> storageToJson(StorageInfo storage)` <a id="storagetojson"></a>
- **种类：** 静态方法。**来源：** 第 663 行。
- **用途：** 为设备/数据集 API 响应序列化 `StorageInfo` 槽。
- **输入：** `storage`。**返回：** `Map<String, dynamic>`（容量、类型、接口、品牌、序列号）。
- **副作用：** 无。
- **算法：** 直接字段映射。
- **用法：** 被 `deviceToJson` 为每个存储槽调用。
- **备注：** 含原始契约后添加到 API 的品牌和序列号。

### `static List<Device> filterDevicesForSearch({required List<Device> devices, required String query})` <a id="filterdevicesforsearch"></a>
- **种类：** 静态方法。**来源：** 第 676 行。
- **用途：** 设备清单字段不区分大小写文本搜索。
- **输入：** `devices`、`query`。**返回：** 匹配设备，保留原始顺序。
- **副作用：** 无。
- **算法：** 小写查询；保留 `_containsText` 在名/品牌/型号/序列号/CPU/GPU/操作系统/位置/备注字段找到它的设备。
- **用法：** 被 `_handleSearch` 调用。
- **备注：** 只搜索清单字段；绝不执行在线查找。

### `static List<Map<String, dynamic>> buildNetworkListJson({required List<Network> networks, ...})` <a id="buildnetworklistjson"></a>
- **种类：** 静态方法。**来源：** 第 718 行。
- **用途：** 序列化网络，其设备赋值分组其下。
- **输入：** `networks`、`assignments`、`devices`（供名解析）。
- **返回：** `List<Map<String, dynamic>>`。
- **副作用：** 无。
- **算法：** 经 `_deviceNameMap` 构建设备名映射；对每个网络分组其赋值（`a.networkId == n.id`）并调用 `networkToJson`。
- **用法：** 被 `_handleNetworkList` 调用。
- **备注：** 无。

### `static Map<String, dynamic> networkToJson(Network network, {List<NetworkDevice>? assignments, Map<String, String>? deviceNames})` <a id="networktojson"></a>
- **种类：** 静态方法。**来源：** 第 742 行。
- **用途：** 序列化一个 `Network`，可选包含其解析设备赋值。
- **输入：** `network`；可选 `assignments`/`deviceNames`。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射（类型/子网/网关/DNS/备注）加提供 `assignments` 时嵌套 `{deviceId, deviceName, ipAddress, hostname, addressMode, isExitNode}` 列表。
- **用法：** 被 `buildNetworkListJson` 调用。
- **备注：** 无。

### `static List<Network> filterNetworksForSearch({required List<Network> networks, ...})` <a id="filternetworksforsearch"></a>
- **种类：** 静态方法。**来源：** 第 775 行。
- **用途：** 跨网络和赋值文本字段不区分大小写搜索。
- **输入：** `networks`、`assignments`、`devices`、`query`。
- **返回：** 匹配网络，保留原始顺序。
- **副作用：** 无。
- **算法：** 匹配网络自己字段（名/子网/网关/DNS/备注）或其任何赋值主机/IP/主机名字段（含被分配设备解析名）。
- **用法：** 被 `_handleNetworkSearch` 调用。
- **备注：** 含设备名让调用方能搜"设备 X 在哪个网络"。

### `static List<Map<String, dynamic>> buildDataSetListJson({required List<DataSet> datasets, required List<Device> devices})` <a id="builddatasetlistjson"></a>
- **种类：** 静态方法。**来源：** 第 814 行。
- **用途：** 序列化带解析链接设备存储详情的数据集。
- **输入：** `datasets`、`devices`。**返回：** `List<Map<String, dynamic>>`。
- **副作用：** 无。
- **算法：** 对每个数据集带设备列表调用 `dataSetToJson` 供链接解析。
- **用法：** 被 `_handleDatasetList` 调用。
- **备注：** 无。

### `static Map<String, dynamic> dataSetToJson(DataSet dataset, {List<Device>? devices})` <a id="datasettojson"></a>
- **种类：** 静态方法。**来源：** 第 828 行。
- **用途：** 序列化一个 `DataSet`，解析每个存储链接设备名和当前存储槽摘要。
- **输入：** `dataset`；可选 `devices` 供解析。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射加每存储链接查找链接设备并经 `storageToJson` 等价显示字符串渲染其存储槽摘要。
- **用法：** 被 `buildDataSetListJson` 调用。
- **备注：** 存储链接在输出保留槽索引，因为数据集按索引链接存储（见 [数据集](../../../features/datasets.md)）。

### `static List<DataSet> filterDataSetsForSearch({required List<DataSet> datasets, required List<Device> devices, required String query})` <a id="filterdatasetsforsearch"></a>
- **种类：** 静态方法。**来源：** 第 864 行。
- **用途：** 跨数据集、链接设备和链接存储文本不区分大小写搜索。
- **输入：** `datasets`、`devices`、`query`。**返回：** 匹配数据集，原始顺序。
- **副作用：** 无。
- **算法：** 匹配数据集自己名加每存储链接的链接设备名和存储摘要文本。
- **用法：** 被 `_handleDatasetSearch` 调用。
- **备注：** 无。

### `static List<Map<String, dynamic>> buildServiceListJson({required List<ServiceNode> services, ...})` <a id="buildservicelistjson"></a>
- **种类：** 静态方法。**来源：** 第 907 行。
- **用途：** 为 API 响应序列化服务节点。
- **输入：** `services`、`devices`、`networks`（供端点网络名解析）。
- **返回：** `List<Map<String, dynamic>>`。
- **副作用：** 无。
- **算法：** 构建设备/网络名映射；每服务调用 `serviceToJson`。
- **用法：** 被 `_handleServiceList` 调用。
- **备注：** 只暴露保存备注；绝不查询活服务状态。

### `static Map<String, dynamic> serviceToJson(ServiceNode service, {Map<String, String>? deviceNames, Map<String, String>? networkNames})` <a id="servicetojson"></a>
- **种类：** 静态方法。**来源：** 第 932 行。
- **用途：** 序列化一个 `ServiceNode`，含经 `_serviceEndpointToJson` 的端点。
- **输入：** `service`；可选名映射供富化。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射（设备/名/模板/图标/kind/runtime/state/标签/备注/`dockerCompose`）加嵌套端点列表。
- **用法：** 被 `buildServiceListJson` 调用。
- **备注：** 端点端口范围同时暴露原始 `port` 值和格式化 `portText`。

### `static List<ServiceNode> filterServicesForList({required List<ServiceNode> services, String? deviceId, String? kind, String? state})` <a id="filterservicesforlist"></a>
- **种类：** 静态方法。**来源：** 第 960 行。
- **用途：** 应用 `/service/list` 端点可选简单相等过滤器。
- **输入：** `services`；可选 `deviceId`/`kind`/`state`。
- **返回：** 匹配服务，原始顺序。
- **副作用：** 无。
- **算法：** 连续相等过滤器，参数 null/空时各跳过。
- **用法：** 被 `_handleServiceList` 调用。
- **备注：** 空过滤字符串当作"无过滤"，非"匹配空"。

### `static List<ServiceNode> filterServicesForSearch({required List<ServiceNode> services, required List<Device> devices, required List<Network> networks, required String query})` <a id="filterservicesforsearch"></a>
- **种类：** 静态方法。**来源：** 第 982 行。
- **用途：** 服务元数据、端点和链接名不区分大小写自由文本搜索。
- **输入：** `services`、`devices`、`networks`、`query`。**返回：** 匹配服务，原始顺序。
- **副作用：** 无。
- **算法：** 匹配服务名/标签/备注/设备名，加每个端点标签/协议/绑定地址/备注及其解析网络名。
- **用法：** 被 `_handleServiceSearch` 调用。
- **备注：** 只搜索保存元数据和链接名——绝不活端口/进程状态。

### `static List<Map<String, dynamic>> buildServiceRouteListJson({required List<ServiceRoute> routes, required List<ServiceNode> services, required List<Device> devices})` <a id="buildserviceroutelistjson"></a>
- **种类：** 静态方法。**来源：** 第 1031 行。
- **用途：** 为 API 响应序列化服务访问路由。
- **输入：** `routes`、`services`、`devices`。**返回：** `List<Map<String, dynamic>>`。
- **副作用：** 无。
- **算法：** 构建 services-by-id 映射；每路由调用 `serviceRouteToJson`。
- **用法：** 被 `_handleServiceRoutes` 调用。
- **备注：** 无。

### `static Map<String, dynamic> serviceRouteToJson(ServiceRoute route, {Map<String, ServiceNode>? servicesById, Map<String, String>? deviceNames})` <a id="serviceroutetojson"></a>
- **种类：** 静态方法。**来源：** 第 1054 行。
- **用途：** 序列化一个 `ServiceRoute`，含解析源服务/端点、跳（经 `_serviceRouteHopToJson`）和分组公共目标（经 `_publicTargets`）。
- **输入：** `route`；可选查找映射。
- **返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射（`finalUrl`、`accessLevel`、`notes`）加嵌套跳和 `publicTargets`。
- **用法：** 被 `buildServiceRouteListJson` 调用。
- **备注：** 即使 `extraJson.publicTargets` 持有额外分组目标，`finalUrl` 也为 API 兼容保持第一目标（见 [服务与拓扑](../../../features/services-topology.md)）。

### `static Map<String, dynamic> buildServiceStatsJson({required List<ServiceNode> services, required List<ServiceRoute> routes})` <a id="buildservicestatsjson"></a>
- **种类：** 静态方法。**来源：** 第 1092 行。
- **用途：** 构建 `/service/stats` 响应：服务/路由总计和按 kind/按 state 细分。
- **输入：** `services`、`routes`。**返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 总计加按服务 kind 和 state 的 `_countBy` 分组，和路由计数。
- **用法：** 被 `_handleServiceStats` 调用，并嵌入 `buildStatsJson` 的 `services` 字段。
- **备注：** 镜像 `/device/stats` 中嵌入的服务部分，作为独立端点。

### `static Map<String, dynamic> _serviceEndpointToJson(ServiceEndpoint endpoint, Map<String, String>? networkNames)` <a id="serviceendpointtojson"></a>
- **种类：** 静态方法。**来源：** 第 1127 行。
- **用途：** 可能时把端点网络 id 解析为显示名序列化 `ServiceEndpoint`。
- **输入：** `endpoint`、`networkNames`。**返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射加 `networkNames` 含端点 `networkId` 时解析 `networkName`。
- **用法：** 被 `serviceToJson` 为服务每个端点调用。
- **备注：** 服务响应和路由响应都用的内部辅助。

### `static Map<String, dynamic> _serviceRouteHopToJson(ServiceRouteHop hop, Map<String, ServiceNode>? servicesById, Map<String, String>? deviceNames)` <a id="serviceroutehoptojson"></a>
- **种类：** 静态方法。**来源：** 第 1152 行。
- **用途：** 序列化 `ServiceRouteHop`，可能时解析其引用服务/设备名同时保留自由形式字段。
- **输入：** `hop`；可选查找映射。**返回：** `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** 直接字段映射（类型/scheme/主机/端口/路径/备注）加跳引用时解析 `serviceName`/`deviceName`。
- **用法：** 被 `serviceRouteToJson` 为每个跳调用。
- **备注：** 即使无服务/设备引用解析也保持自由形式跳字段（scheme/主机/端口/路径）完好。

### `static List<String> _publicTargets(ServiceRoute route)` <a id="publictargets"></a>
- **种类：** 静态方法。**来源：** 第 1181 行。
- **用途：** 读取路由 `extraJson.publicTargets` 存储的分组公共目标。
- **输入：** `route`。**返回：** `List<String>`。
- **副作用：** 无。
- **算法：** 读 `route.extraJson['publicTargets']`；是列表时只保留字符串条目（为向前兼容忽略非字符串条目）；否则返回 `[]`。
- **用法：** 被 `serviceRouteToJson` 调用。
- **备注：** 静默忽略意外条目形态而非抛，支持向前兼容 JSON。

### `static Map<String, String> _deviceNameMap(List<Device> devices)` <a id="devicenamemap"></a>
- **种类：** 静态方法。**来源：** 第 1192 行。
- **用途：** 为设备交叉引用构建 id 到名查找。
- **输入：** `devices`。**返回：** `Map<String, String>`。
- **副作用：** 无。
- **算法：** 映射推导 `{for (final d in devices) d.id: d.name}`。
- **用法：** 被 `buildNetworkListJson` 和类似富化路径调用。
- **备注：** 无。

### `static Map<String, int> _countBy<T>(Iterable<T> values, String Function(T) keyOf)` <a id="countby"></a>
- **种类：** 静态泛型方法。**来源：** 第 1201 行。
- **用途：** 按调用方提供键函数分组计数元素。
- **输入：** `values`、`keyOf`。**返回：** `Map<String, int>`。
- **副作用：** 无。
- **算法：** 折叠 `values`，每个递增 `result[keyOf(v)]`。
- **用法：** 被 `buildStatsJson`/`buildServiceStatsJson` 做按类别/按 kind/按 state 细分调用。
- **备注：** 泛型——任何分组键可复用，不绑定特定枚举。

### `static bool _containsText(Iterable<Object?> values, String lowerQuery)` <a id="containstext"></a>
- **种类：** 静态方法。**来源：** 第 1218 行。
- **用途：** 测试多个值中是否有任何含小写查询子串。
- **输入：** `values`（容忍可空条目）、`lowerQuery`（已小写）。
- **返回：** `bool`。
- **副作用：** 无。
- **算法：** `values.any((v) => v != null && v.toString().toLowerCase().contains(lowerQuery))`。
- **用法：** 每个 `filter*ForSearch` 函数背后公共子串匹配原语。
- **备注：** 跳过 null 而非抛；调用方每次搜索一次传预小写查询，而非逐候选。

### `static int? _intValue(Object? value)` <a id="intvalue"></a>
- **种类：** 静态方法。**来源：** 第 1230 行。
- **用途：** 从可能已是 `int`、数字字符串或其他东西的 JSON 解码输入容忍解析 `int`。
- **输入：** `value`。**返回：** `int?` — 不可解析 `null`。
- **副作用：** 无。
- **算法：** 已 `int` 直接返回；否则对 `String`（或等价数字强转）尝试 `int.tryParse`；任何其他类型或解析失败 `null`。
- **用法：** 被 `_handleAdd` 为 `screenResolutionW`/`screenResolutionH` 调用。
- **备注：** 容忍数字字符串，使最小/松散类型 API 客户端不被拒绝。

### `static double? _doubleValue(Object? value)` <a id="doublevalue"></a>
- **种类：** 静态方法。**来源：** 第 1242 行。
- **用途：** 从 JSON 解码输入容忍解析 `double`。
- **输入：** `value`。**返回：** `double?`。
- **副作用：** 无。
- **算法：** `value is num` 时直接返回 `value.toDouble()`；否则尝试字符串解析；失败 `null`。
- **用法：** 被 `_handleAdd` 为 `latitude`/`longitude` 调用。
- **备注：** 经共享 `num` 检查接受 `int` 和 `double` JSON 数字编码两者。

### `static DateTime? _dateValue(Object? value)` <a id="datevalue"></a>
- **种类：** 静态方法。**来源：** 第 1253 行。
- **用途：** 从 JSON 字符串容忍解析 `DateTime`。
- **输入：** `value`。**返回：** `DateTime?` — 非字符串、空字符串或不可解析字符串 `null`。
- **副作用：** 无。
- **算法：** 拒绝非 `String`/空输入；否则 `DateTime.tryParse`。
- **用法：** 被 `_handleAdd` 为 `purchaseDate`/`releaseDate`/`retiredDate` 调用。
- **备注：** 无效字符串被忽略（非错误），为与最小添加请求兼容。

### `static MoneyValue? _moneyValueFromJson(Object? value)` <a id="moneyvaluefromjson"></a>
- **种类：** 静态方法。**来源：** 第 1263 行。
- **用途：** 从 JSON 映射解析可选 `MoneyValue`（金额 + 货币）。
- **输入：** `value`。**返回：** `MoneyValue?` — `value` 不是 `Map<String, dynamic>` 或所需子字段格式错误时 `null`。
- **副作用：** 无。
- **算法：** 类型检查映射，然后解析金额/货币字段（适用处用容忍数字解析器）。
- **用法：** 被 `_handleAdd` 为 `purchasePrice`/`soldPrice` 调用。
- **备注：** 格式错误货币映射被忽略而非拒绝整个添加请求。

### `static DeviceRecurringCost? _recurringCostFromJson(Object? value)` <a id="recurringcostfromjson"></a>
- **种类：** 静态方法。**来源：** 第 1277 行。
- **用途：** 从 JSON 映射解析可选 `DeviceRecurringCost` 条目。
- **输入：** `value`。**返回：** `DeviceRecurringCost?` — 错误形态 `null`。
- **副作用：** 无。
- **算法：** 类型检查映射，然后解析 kind/price/计费周期/名 字段。
- **用法：** 被 `_handleAdd` 为 `recurringCosts` 调用（映射于列表上）。
- **备注：** 格式错误条目单独跳过（经调用方 `whereType` 过滤）而非拒绝整个列表。

### `static Future<Map<String, dynamic>?> _parseBody(Request request)` <a id="parsebody"></a>
- **种类：** 静态方法。**来源：** 第 1312 行。
- **用途：** 读取并 JSON 解码请求体，容忍格式错误输入。
- **输入：** `request`。**返回：** `Future<Map<String, dynamic>?>` — 任何解码失败或非对象体 `null`。
- **副作用：** 读取请求体流。
- **算法：** 包在 try/catch 的 `jsonDecode(await request.readAsString())`，失败返回 `null` 而非传播。
- **用法：** 被 `_handleAdd` 调用。
- **备注：** 这正是格式错误 JSON 产生干净 `400` 而非泛型 `500` 的原因。

### `static Middleware _corsMiddleware()` <a id="corsmiddleware"></a>
- **种类：** 静态方法。**来源：** 第 1329 行。
- **用途：** 给每个响应附加宽松 CORS 页头。
- **输入：** 无。**返回：** `Middleware`。
- **副作用：** 除包裹处理器外无。
- **算法：** 在内层处理器产生每个响应周围添加宽松 allow-origin/allow-headers 响应页头。
- **用法：** `start()` 的 `Pipeline` 中第一中间件。
- **备注：** 显式文档化权衡——这正是 `_authMiddleware` 的回环+凭据规则存在的全部原因。

### `static Middleware _authMiddleware()` <a id="authmiddleware"></a>
- **种类：** 静态方法。**来源：** 第 1347 行。
- **用途：** 执行 API 访问规则：回环默认受信，但一旦配置凭据，每个请求（含回环）必须呈现有效 Basic Auth。
- **输入：** 无。**返回：** `Middleware`。
- **副作用：** 从 `request.context` 读取连接远程地址。
- **算法：** 从连接信息确定回环状态；未配置凭据时直接拒绝非回环请求（`403`）；配置凭据时经 `_validateBasicAuth` 要求有效 `Authorization: Basic` 页头，无论回环状态（失败 `401` + `WWW-Authenticate`）；否则放行。
- **用法：** `start()` 的 `Pipeline` 中第二中间件。
- **备注：** 与 MyAnime 的 `LocalApiServer._authMiddleware` 相同安全规则和理由——完整引用推理见那个页面备注。

### `static bool _validateBasicAuth(String header)` <a id="validatebasicauth"></a>
- **种类：** 静态方法。**来源：** 第 1397 行。
- **用途：** 对照配置凭据验证 `Authorization: Basic <base64>` 页头。
- **输入：** `header`。**返回：** `bool`。
- **副作用：** 无。
- **算法：** 拒绝任何非 `"Basic "` 开头的；base64 解码，在第一个 `:` 拆分为用户名/密码，对照 `_username`/`_password` 比较。
- **用法：** 被 `_authMiddleware` 调用。
- **备注：** 对照明文存储凭据的普通相等检查。

### `static Middleware _errorMiddleware()` <a id="errormiddleware"></a>
- **种类：** 静态方法。**来源：** 第 1414 行。
- **用途：** 捕获任何未处理路由处理器异常并返回干净 JSON `500` 而非未处理崩溃。
- **输入：** 无。**返回：** `Middleware`。
- **副作用：** 除包裹处理器外无。
- **算法：** 内层处理器调用周围 try/catch；任何异常经 `_error` 构建 JSON 错误响应。
- **用法：** `start()` 的 `Pipeline` 中最内中间件。
- **备注：** 最后防线；预期失败模式预期路由返回自己 `400`/`401`/`403`。
