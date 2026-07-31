# lib/features/services/models/service.dart

服务清单模型族：`ServiceNode`（设备上的服务实例）、`ServiceEndpoint`（一个手动记录的监听端点）、`ServiceRoute` 和 `ServiceRouteHop`（手动记录的访问路径及其跳）、由 [`../services/service_storage.md`](../services/service_storage.md) 持久化的顶层 `ServiceData` 容器，和每个支撑枚举（`ServiceKind`、`ServiceRuntime`、`ServiceState`、`ServiceProtocol`、`ServiceTransport`、`ServiceScope`、`ServiceRouteHopType`、`ServiceRouteMethod`、`ServiceAccessLevel`）。这里每个模型都遵循应用标准形态：带新鲜自动生成 `id`（`ServiceNode`/`ServiceRoute` 加新鲜 UTC `modifiedAt`）的构造函数、`toJson`/`fromJson` 和参与三方同步合并的 `mergeUnknownFieldsFrom`（泛型 `unknownJsonFields`/`mergeUnknownJsonFields` 辅助见 [三方合并](../../../../algorithms/three-way-merge.md) 和 [`json_preservation.md`](../../../shared/utils/json_preservation.md)，这里每个 `fromJson`/`mergeUnknownFieldsFrom` 都调用它们）。这些模型支撑的仅手动清单约束和视图级行为见 [服务与拓扑](../../../../features/services-topology.md)，穷举持久化字段参考见 [数据格式 — ServiceNode / ServiceEndpoint / ServiceRoute / ServiceRouteHop](../../../../data-formats.md#servicenode--serviceendpoint--serviceroute--serviceroutehop-libfeaturesservicesmodelsservicedart)。`lib/features/services/services/service_analysis.dart`（见 [`service_analysis.md`](../services/service_analysis.md)）是这些类型超出简单存储的主要消费者——它从它们构建拓扑图、端口冲突列表和引用警告列表。

## 声明

| 声明 | 种类 | Tier | 用途 |
|---|---|---|---|
| `jsonValue` | getter（`ServiceKind`） | B | 返回序列化枚举名。 |
| [`ServiceKind.fromJson`](#servicekind-fromjson) | 静态方法 | A | 解析 `ServiceKind`，默认 `custom`。 |
| `jsonValue` | getter（`ServiceRuntime`） | B | 返回序列化枚举名。 |
| [`ServiceRuntime.fromJson`](#serviceruntime-fromjson) | 静态方法 | A | 解析 `ServiceRuntime`，或 `null`。 |
| `jsonValue` | getter（`ServiceState`） | B | 返回序列化枚举名。 |
| [`ServiceState.fromJson`](#servicestate-fromjson) | 静态方法 | A | 解析 `ServiceState`，默认 `active`。 |
| `jsonValue` | getter（`ServiceProtocol`） | B | 返回序列化枚举名。 |
| [`ServiceProtocol.fromJson`](#serviceprotocol-fromjson) | 静态方法 | A | 解析 `ServiceProtocol`，默认 `custom`。 |
| `jsonValue` | getter（`ServiceTransport`） | B | 返回序列化枚举名。 |
| [`ServiceTransport.fromJson`](#servicetransport-fromjson) | 静态方法 | A | 解析 `ServiceTransport`，默认 `tcp`。 |
| `jsonValue` | getter（`ServiceScope`） | B | 返回序列化枚举名。 |
| [`ServiceScope.fromJson`](#servicescope-fromjson) | 静态方法 | A | 解析 `ServiceScope`，默认 `lan`。 |
| `jsonValue` | getter（`ServiceRouteHopType`） | B | 返回序列化枚举名。 |
| [`ServiceRouteHopType.fromJson`](#serviceroutehoptype-fromjson) | 静态方法 | A | 解析 `ServiceRouteHopType`，默认 `manual`。 |
| `jsonValue` | getter（`ServiceRouteMethod`） | B | 返回序列化枚举名。 |
| [`ServiceRouteMethod.fromJson`](#serviceroutemethod-fromjson) | 静态方法 | A | 解析 `ServiceRouteMethod`，或 `null`。 |
| `jsonValue` | getter（`ServiceAccessLevel`） | B | 返回序列化枚举名。 |
| [`ServiceAccessLevel.fromJson`](#serviceaccesslevel-fromjson) | 静态方法 | A | 解析 `ServiceAccessLevel`，默认 `lan`。 |
| [`ServiceEndpoint`](#serviceendpoint-new) | 构造函数 | A | 创建 `ServiceEndpoint` 实例（默认新鲜 `id`）。 |
| [`copyWith`](#serviceendpoint-copywith) | 方法（`ServiceEndpoint`） | A | 创建带任何子集字段替换或清除的副本。 |
| [`toJson`](#serviceendpoint-tojson) | 方法（`ServiceEndpoint`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `ServiceEndpoint`。 |
| [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) | 方法（`ServiceEndpoint`） | A | 从另一个 `ServiceEndpoint` 三方合并未知 JSON 字段。 |
| [`portText`](#serviceendpoint-porttext) | getter（`ServiceEndpoint`） | A | 把 `port`/`portEnd` 渲染为显示字符串（`"8080"`、`"8080-8090"` 或 `"-"`）。 |
| [`ServiceNode`](#servicenode-new) | 构造函数 | A | 创建 `ServiceNode` 实例（默认新鲜 `id`/`modifiedAt`）。 |
| [`copyWith`](#servicenode-copywith) | 方法（`ServiceNode`） | A | 创建带任何子集字段替换或清除的副本。 |
| [`toJson`](#servicenode-tojson) | 方法（`ServiceNode`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`ServiceNode.fromJson`](#servicenode-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `ServiceNode`。 |
| [`mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) | 方法（`ServiceNode`） | A | 合并未知字段加每个端点自己的未知字段。 |
| [`ServiceRouteHop`](#serviceroutehop-new) | 构造函数 | A | 创建 `ServiceRouteHop` 实例（默认新鲜 `id`）。 |
| [`copyWith`](#serviceroutehop-copywith) | 方法（`ServiceRouteHop`） | A | 创建带任何子集字段替换或清除的副本。 |
| [`toJson`](#serviceroutehop-tojson) | 方法（`ServiceRouteHop`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `ServiceRouteHop`。 |
| [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom) | 方法（`ServiceRouteHop`） | A | 从另一个 `ServiceRouteHop` 三方合并未知 JSON 字段。 |
| [`ServiceRoute`](#serviceroute-new) | 构造函数 | A | 创建 `ServiceRoute` 实例（默认新鲜 `id`/`modifiedAt`）。 |
| [`copyWith`](#serviceroute-copywith) | 方法（`ServiceRoute`） | A | 创建带任何子集字段替换或清除的副本。 |
| [`toJson`](#serviceroute-tojson) | 方法（`ServiceRoute`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`ServiceRoute.fromJson`](#serviceroute-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `ServiceRoute`。 |
| [`mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom) | 方法（`ServiceRoute`） | A | 合并未知字段加每个跳自己的未知字段。 |
| [`ServiceData`](#servicedata-new) | 构造函数 | A | 创建 `ServiceData` 实例。 |
| [`toJson`](#servicedata-tojson) | 方法（`ServiceData`） | A | 把此值序列化为 JSON 兼容映射。 |
| [`ServiceData.fromJson`](#servicedata-fromjson) | 工厂构造函数 | A | 从 JSON 解析 `ServiceData`。 |

行数（42）不匹配 `grep -c 'Purpose:' service.dart`（37）。直接读文件确认：五个声明完全无 `/// Purpose:` 文档注释——[`ServiceEndpoint.copyWith`](#serviceendpoint-copywith)、[`ServiceNode`](#servicenode-new) 的构造函数、[`ServiceNode.copyWith`](#servicenode-copywith)、[`ServiceNode.fromJson`](#servicenode-fromjson) 和 [`ServiceRouteHop.copyWith`](#serviceroutehop-copywith)。文件每个其他声明（全部 9 个枚举的 `jsonValue`/`fromJson` 对、`ServiceEndpoint` 其余、`ServiceNode` 其余、`ServiceRouteHop` 其余、`ServiceRoute` 全部含其自己 `copyWith`、`ServiceData` 全部）都带——37 个声明已文档化、5 个未、共 42。`ServiceAccessLane`/`ServiceTopologyNode*` 风格无自己 getter/方法的裸枚举会按本文档集只索引可执行声明的约定跳过，但本文件每个枚举至少带 `jsonValue` getter 和 `fromJson` 解析器，因此全部九个都出现。

## 文档

### `static ServiceKind fromJson(String? value)` <a id="servicekind-fromjson"></a>
- **种类：** 枚举 `ServiceKind` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 92 行）。
- **用途：** 从其序列化名解析 `ServiceKind`，任何无法识别或缺失值默认 `custom`。
- **输入：** `value` — 可空。
- **返回：** `ServiceKind` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `ServiceKind.values.where((e) => e.name == value).firstOrNull ?? ServiceKind.custom`。
- **用法：**
  ```dart
  kind: ServiceKind.fromJson(json['kind'] as String?),
  ```
  （来自 [`ServiceNode.fromJson`](#servicenode-fromjson)）
- **备注：** `custom` 是"无法识别"和"缺席"两者回退，也是 `ServiceNode` 自己 `kind` 构造函数默认——服务记录绝不可能以 null/无效 kind 告终。

### `static ServiceRuntime? fromJson(String? value)` <a id="serviceruntime-fromjson"></a>
- **种类：** 枚举 `ServiceRuntime` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 119 行）。
- **用途：** 从其序列化名解析 `ServiceRuntime`。
- **输入：** `value` — 可空。
- **返回：** `ServiceRuntime?` — `value` 为 `null` 或无法识别时 `null`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `ServiceRuntime.values.where((e) => e.name == value).firstOrNull`。
- **用法：** 被 [`ServiceNode.fromJson`](#servicenode-fromjson) 为 `runtime` 调用，被 `_ServiceTemplatePicker`/`service_edit_page.dart` 读模板 `runtime` 时直接调用。
- **备注：** 与 `ServiceKind.fromJson` 不同，无法识别 runtime 产生 `null`（无记录 runtime）而非回退值——匹配字段自己的可选性（`ServiceNode.runtime` 是 `ServiceRuntime?`）。

### `static ServiceState fromJson(String? value)` <a id="servicestate-fromjson"></a>
- **种类：** 枚举 `ServiceState` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 143 行）。
- **用途：** 解析 `ServiceState`，无法识别或缺席默认 `active`。
- **输入：** `value` — 可空。
- **返回：** `ServiceState` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceState.active`。
- **用法：** 被 [`ServiceNode.fromJson`](#servicenode-fromjson) 为 `state` 调用。
- **备注：** `active` 也是 `ServiceNode` 自己构造函数默认，因此新创建服务和从缺 `state` 键数据解析的服务行为相同。

### `static ServiceProtocol fromJson(String? value)` <a id="serviceprotocol-fromjson"></a>
- **种类：** 枚举 `ServiceProtocol` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 171 行）。
- **用途：** 解析 `ServiceProtocol`，默认 `custom`。
- **输入：** `value` — 可空。
- **返回：** `ServiceProtocol` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceProtocol.custom`。
- **用法：** 被 [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) 为 `protocol` 调用。
- **备注：** 无。

### `static ServiceTransport fromJson(String? value)` <a id="servicetransport-fromjson"></a>
- **种类：** 枚举 `ServiceTransport` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 193 行）。
- **用途：** 解析 `ServiceTransport`，默认 `tcp`。
- **输入：** `value` — 可空。
- **返回：** `ServiceTransport` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceTransport.tcp`。
- **用法：** 被 [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) 为 `transport` 调用。
- **备注：** `tcpUdp`（意为"两者"）是此枚举真实值，非此解析器特例——把 `tcpUdp` 端点展开为单独 TCP 和 UDP 端口用途的是 [`listServicePortUses`](../services/service_analysis.md#listserviceportuses)。

### `static ServiceScope fromJson(String? value)` <a id="servicescope-fromjson"></a>
- **种类：** 枚举 `ServiceScope` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 217 行）。
- **用途：** 解析 `ServiceScope`，默认 `lan`。
- **输入：** `value` — 可空。
- **返回：** `ServiceScope` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceScope.lan`。
- **用法：** 被 [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) 为 `scope` 调用。
- **备注：** 无。

### `static ServiceRouteHopType fromJson(String? value)` <a id="serviceroutehoptype-fromjson"></a>
- **种类：** 枚举 `ServiceRouteHopType` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 244 行）。
- **用途：** 解析 `ServiceRouteHopType`，默认 `manual`。
- **输入：** `value` — 可空。
- **返回：** `ServiceRouteHopType` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceRouteHopType.manual`。
- **用法：** 被 [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) 为 `type` 调用。
- **备注：** `manual` 既是解析回退也是 `ServiceRouteHop` 自己构造函数默认。

### `static ServiceRouteMethod? fromJson(String? value)` <a id="serviceroutemethod-fromjson"></a>
- **种类：** 枚举 `ServiceRouteMethod` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 273 行）。
- **用途：** 从其序列化名解析 `ServiceRouteMethod`。
- **输入：** `value` — 可空。
- **返回：** `ServiceRouteMethod?` — `value` 为 `null` 或无法识别时 `null`。
- **副作用：** 无。
- **算法：** Null 检查，然后 `.where(...).firstOrNull`。
- **用法：** 被 [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) 为 `method` 调用；也 [`service_analysis.md`](../services/service_analysis.md) 通篇读取（如 `serviceAccessLaneForRoute`、`_isPortMappingHop`）决定 FRP/反向代理/隧道行为。
- **备注：** `null` method（跳上无记录 method）与 `ServiceRouteMethod.custom` 有意义地不同——几个 `service_analysis.dart` 函数专门分支于 `hop.method == null`（如标签回退 `hop.type`）。

### `static ServiceAccessLevel fromJson(String? value)` <a id="serviceaccesslevel-fromjson"></a>
- **种类：** 枚举 `ServiceAccessLevel` 的静态方法。
- **来源：** `lib/features/services/models/service.dart`（第 298 行）。
- **用途：** 解析 `ServiceAccessLevel`，默认 `lan`。
- **输入：** `value` — 可空。
- **返回：** `ServiceAccessLevel` — 绝不 `null`。
- **副作用：** 无。
- **算法：** `.where(...).firstOrNull ?? ServiceAccessLevel.lan`。
- **用法：** 被 [`ServiceRoute.fromJson`](#serviceroute-fromjson) 为 `accessLevel` 调用。
- **备注：** `lan` 既是解析回退也是 `ServiceRoute` 自己构造函数默认，匹配本文件每个其他枚举解析器模式，除字段可空且完全无默认的 `ServiceRuntime.fromJson`/`ServiceRouteMethod.fromJson`。

### `ServiceEndpoint({String? id, this.label, this.protocol = ServiceProtocol.http, this.transport = ServiceTransport.tcp, this.bindAddress, this.port, this.portEnd, this.path, this.networkId, this.scope = ServiceScope.lan, this.isPrimary = false, this.notes, this.extraJson = const {}})` <a id="serviceendpoint-new"></a>
- **种类：** `ServiceEndpoint` 的构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 323 行）。
- **用途：** 创建手动记录的本地/监听端点，未提供时生成新鲜 UUID `id`。
- **输入：** 所有字段可选；`protocol` 默认 `http`、`transport` 默认 `tcp`、`scope` 默认 `lan`、`isPrimary` 默认 `false`、`extraJson` 默认 `{}`。
- **返回：** 新 `ServiceEndpoint`。
- **副作用：** 无（除 `id` 为 null 时 `Uuid().v4()`——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`；每个其他字段带声明默认普通赋值。
- **用法：**
  ```dart
  Navigator.pop(
    ctx,
    ServiceEndpoint(
      id: initial?.id,
      label: _emptyToNull(labelCtrl.text),
      protocol: protocol,
      transport: transport,
      bindAddress: _emptyToNull(bindCtrl.text),
      port: int.tryParse(portCtrl.text.trim()),
      portEnd: int.tryParse(portEndCtrl.text.trim()),
      path: _emptyToNull(pathCtrl.text),
      scope: scope,
      isPrimary: primary,
      extraJson: initial?.extraJson ?? const {},
    ),
  );
  ```
  （来自 `service_edit_page.dart` 的端点增/改对话框；也 `_applyTemplate` 复制 [`ServiceTemplate`](../services/service_template_service.md#servicetemplate-new) 端点时构造）
- **备注：** 传 `id: initial?.id`（既有端点 id，或新端点 `null`）正是让编辑端点在原处更新、而非对按 id 匹配端点的东西看起来像删除-加-添加的东西。

### `ServiceEndpoint copyWith({...})` <a id="serviceendpoint-copywith"></a>
- **种类：** `ServiceEndpoint` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 339 行）。
- **用途：** 创建此端点的任何子集字段被替换、或经 `clearXxx` 标志显式清除（`clearLabel`、`clearBindAddress`、`clearPort`、`clearPortEnd`、`clearPath`、`clearNetworkId`、`clearNotes`）的副本。
- **输入：** 每个可变字段一个可选参数，加每个可空字段一个 `bool clearXxx = false`。
- **返回：** 新 `ServiceEndpoint`——与 `this` 相同 `id` 和 `extraJson`。
- **副作用：** 无。
- **算法：** 对每个可空字段 `clearXxx ? null : (xxx ?? this.xxx)`——调用方碰巧两者都传时清除标志优先于替换值。非可空字段（`protocol`、`transport`、`scope`、`isPrimary`）用普通 `??`。
- **用法：** `lib/` 中无任何 `ServiceEndpoint.copyWith` 特定调用点——搜索仓库找 `endpoint.copyWith`/对 `ServiceEndpoint` 类型接收者的 `.copyWith(` 无结果。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。像 [`ServiceTemplate.toService`](../services/service_template_service.md#servicetemplate-toservice) 一样，此方法当前未使用——每个改变端点的地方直接构造全新 `ServiceEndpoint`（见构造函数自己上面 Usage 示例）而非复制既有。

### `Map<String, dynamic> toJson()`（`ServiceEndpoint`） <a id="serviceendpoint-tojson"></a>
- **种类：** `ServiceEndpoint` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 381 行）。
- **用途：** 把此端点序列化为持久化在服务 `endpoints` 列表内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，然后 `id` 和 `protocol`/`transport`/`scope` 无条件（经 `.jsonValue`）、每个其他字段只在 `if` 非 null/非空、`isPrimary` 只在 `if (isPrimary)`（`false` 值完全省略而非写出）。
- **副作用：** 无。
- **算法：** `{...extraJson, 'id': id, if (label...) ..., 'protocol': protocol.jsonValue, 'transport': transport.jsonValue, ..., 'scope': scope.jsonValue, if (isPrimary) 'isPrimary': true, if (notes...) ...}`。
- **用法：** 被 [`ServiceNode.toJson`](#servicenode-tojson) 为 `endpoints` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) 调用。
- **备注：** `false` 时完全省略 `isPrimary`（而非写 `"isPrimary": false`）让常见 case——多端点服务大多数端点非主——留在持久化 JSON 外。

### `factory ServiceEndpoint.fromJson(Map<String, dynamic> json)` <a id="serviceendpoint-fromjson"></a>
- **种类：** `ServiceEndpoint` 的工厂构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 403 行）。
- **用途：** 从 JSON 解析 `ServiceEndpoint`。
- **输入：** `json`。
- **返回：** 新 `ServiceEndpoint`；`extraJson` 持有不在 `_serviceEndpointJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 对每个已知键直接字段提取，`protocol`/`transport`/`scope` 经各自枚举 `fromJson` 解析器解析；`isPrimary` 缺席默认 `false`。
- **用法：** 被 [`ServiceNode.fromJson`](#servicenode-fromjson) 为 `json['endpoints']` 每个条目调用。
- **备注：** 无。

### `ServiceEndpoint mergeUnknownFieldsFrom(ServiceEndpoint other, {ServiceEndpoint? base})` <a id="serviceendpoint-mergeunknownfieldsfrom"></a>
- **种类：** `ServiceEndpoint` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 425 行）。
- **用途：** 三方合并此端点的未知 JSON 字段与另一个的，使无法识别键像已知字段一样经受同步合并。
- **输入：** `other` — `this` 为本地时典型为远程侧；可选 `base` — 上次同步快照。
- **返回：** 新 `ServiceEndpoint`——与 `this` 相同已知字段、`extraJson` 被合并结果替换。
- **副作用：** 无。
- **算法：** 经 `ServiceEndpoint.fromJson` 重新解析 `{...toJson(), ...mergeUnknownJsonFields(primary: extraJson, secondary: other.extraJson, base: base?.extraJson)}`——底层逐键三方合并规则见 [`mergeUnknownJsonFields`](../../../shared/utils/json_preservation.md)。
- **用法：** 被 [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) 对每对索引对齐 `endpoints` 条目调用一次（按 `id` 匹配，另一侧无匹配端点时回退新鲜空 `ServiceEndpoint(id: endpoint.id)`）。
- **备注：** 这里只合并 `extraJson`——已知端点字段（`protocol`、`port` 等）总是来自 `this`（primary 侧），匹配本文件每个其他模型 `mergeUnknownFieldsFrom` 对待自己已知字段的方式。

### `String get portText` <a id="serviceendpoint-porttext"></a>
- **种类：** `ServiceEndpoint` 的 getter。
- **来源：** `lib/features/services/models/service.dart`（第 444 行）。
- **用途：** 把此端点端口（和不同时端口范围结束）渲染为紧凑显示字符串。
- **输入：** 无。
- **返回：** `String` — `port` 为 `null` 时 `'-'`；`portEnd` 已设且不同于 `port` 时 `'$port-$portEnd'`；否则 `'$port'`。
- **副作用：** 无。
- **算法：** 1. `port == null` → `'-'`。2. `portEnd != null && portEnd != port` → `'$port-$portEnd'`。3. 否则 `'$port'`。
- **用法：**
  ```dart
  detail: [
    if (endpoint.bindAddress?.trim().isNotEmpty == true) endpoint.bindAddress!.trim(),
    endpoint.portText,
    if (endpoint.path?.trim().isNotEmpty == true) endpoint.path!.trim(),
  ].where((part) => part.isNotEmpty && part != '-').join(':'),
  ```
  （来自 [`buildServiceTopology` 的 `addEndpointNode`](../services/service_analysis.md#buildservicetopology) 给端点节点加标签时；也被 `service_list_page.dart` 和 `service_edit_page.dart` 的端点列表块直接读取）
- **备注：** `'-'` 结果被大多数调用方过滤掉（如上面拓扑标签器经 `part != '-'`）而非字面显示——此 getter 的 `'-'` 哨兵存在使调用方有单个非 null `String` 可测试，非为显示给用户。

### `ServiceNode({String? id, required this.deviceId, required this.name, this.templateId, this.icon, this.kind = ServiceKind.custom, this.runtime, this.state = ServiceState.active, this.endpoints = const [], this.tags = const [], this.notes, this.dockerCompose, DateTime? modifiedAt, this.extraJson = const {}})` <a id="servicenode-new"></a>
- **种类：** `ServiceNode` 的构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 467 行）。
- **用途：** 创建服务实例记录，两者都未提供时生成新鲜 UUID `id` 和 UTC `modifiedAt` 时间戳。
- **输入：** `deviceId`、`name` 必填；每个其他字段可选（`kind` 默认 `custom`、`state` 默认 `active`、`endpoints`/`tags` 默认 `[]`）。
- **返回：** 新 `ServiceNode`。
- **副作用：** 无（除 `Uuid().v4()`/`DateTime.now()` 调用——无 IO）。
- **算法：** 初始化器列表中 `id = id ?? const Uuid().v4()`、`modifiedAt = modifiedAt ?? DateTime.now().toUtc()`；每个其他字段普通赋值。
- **用法：**
  ```dart
  final service = ServiceNode(
    id: existing?.id,
    deviceId: _deviceId!,
    name: _nameCtrl.text.trim(),
    templateId: _templateId,
    icon: _icon,
    kind: _kind,
    runtime: _runtime,
    state: _state,
    endpoints: _endpoints,
    tags: existing?.tags ?? const [],
    notes: _emptyToNull(_notesCtrl.text),
    dockerCompose: _emptyToNull(_composeCtrl.text),
    extraJson: existing?.extraJson ?? const {},
  );
  await ServiceStorage.addOrUpdateService(service);
  ```
  （来自 `service_edit_page.dart` 的保存处理器——传 `existing?.id` 编辑时保留相同 `id` 而非铸造新的，恰如 [`Device`](../../devices/models/device.md#device-new) 构造函数所做）
- **备注：** 此声明源码无 `/// Purpose:` 文档注释（见声明表上方行数说明）。除非显式覆盖 `modifiedAt` 总是刷新为"现在"，这是 [`mergeRecords<ServiceNode>`](../../../../algorithms/three-way-merge.md)（从 `lib/shared/services/sync_merge.dart` 调用）用来检测哪侧变化的东西。

### `ServiceNode copyWith({...})` <a id="servicenode-copywith"></a>
- **种类：** `ServiceNode` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 485 行）。
- **用途：** 创建此服务的任何子集字段被替换、或经 `clearXxx` 标志显式清除（`clearTemplateId`、`clearIcon`、`clearRuntime`、`clearNotes`、`clearDockerCompose`）的副本。
- **输入：** 每个可变字段一个可选参数，加五个 `clearXxx` 标志。
- **返回：** 新 `ServiceNode`——与 `this` 相同 `id` 和 `extraJson`；未显式传入时 `modifiedAt` 默认 `DateTime.now().toUtc()`（不同于大多数字段默认 `this` 当前值）。
- **副作用：** 无。
- **算法：** 与 [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith) 相同清除标志优先形态，`modifiedAt: modifiedAt ?? DateTime.now().toUtc()` 而非回退 `this.modifiedAt`——因此零参数调用 `copyWith()` 仍 bump 时间戳。
- **用法：** `lib/` 中无任何调用点——`service_edit_page.dart` 的保存处理器直接构造全新 `ServiceNode`（见构造函数自己 Usage 示例）而非对 `existing` 调用 `copyWith`。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释，且——像 [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith)——当前未使用。其总是刷新的 `modifiedAt` 默认意味着若有人开始调用它，全默认 `copyWith()` 调用仍会登记为同步相关变更，不同于典型无操作副本。

### `Map<String, dynamic> toJson()`（`ServiceNode`） <a id="servicenode-tojson"></a>
- **种类：** `ServiceNode` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 529 行）。
- **用途：** 把此服务序列化为持久化在 `ServiceData.services` 内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，`id`/`deviceId`/`name`/`kind`/`state`/`modifiedAt` 无条件、每个其他字段只在 `if` 存在/非空。
- **副作用：** 无。
- **算法：** 与 [`ServiceEndpoint.toJson`](#serviceendpoint-tojson) 相同的展开-然后-已知字段形态；`endpoints` 只在 `if (endpoints.isNotEmpty)` 时经 `endpoints.map((e) => e.toJson()).toList()` 序列化。
- **用法：** 被 [`ServiceData.toJson`](#servicedata-tojson) 为 `services` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) 调用。
- **备注：** 无。

### `factory ServiceNode.fromJson(Map<String, dynamic> json)` <a id="servicenode-fromjson"></a>
- **种类：** `ServiceNode` 的工厂构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 548 行）。
- **用途：** 从 JSON 解析 `ServiceNode`。
- **输入：** `json`。
- **返回：** 新 `ServiceNode`；`extraJson` 持有不在 `_serviceNodeJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 对每个已知键直接字段提取；`kind`/`runtime`/`state` 经其枚举 `fromJson` 解析器；`endpoints` 经 [`ServiceEndpoint.fromJson`](#serviceendpoint-fromjson) 映射（键缺席默认 `[]`）；`modifiedAt` 经 `DateTime.parse`（必填，缺失/格式错误抛）。
- **用法：** 被 [`ServiceData.fromJson`](#servicedata-fromjson) 为 `json['services']` 每个条目调用。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。与 [`Device.fromJson`](../../devices/models/device.md#device-fromjson) 不同，这里无遗留字符串形态容忍——`ServiceNode` 无 `Device.storage` 普通字符串向后兼容路径的等价物。

### `ServiceNode mergeUnknownFieldsFrom(ServiceNode other, {ServiceNode? base})` <a id="servicenode-mergeunknownfieldsfrom"></a>
- **种类：** `ServiceNode` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 576 行）。
- **用途：** 三方合并此服务的未知 JSON 字段与另一个的，含按端点 `id` 匹配合并每个端点自己的未知字段。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并顶层 `extraJson` 和（`endpoints` 非空时）合并 `endpoints` 列表的新 `ServiceNode`。
- **副作用：** 无。
- **算法：** 1. 从 `toJson()` 开始，与本文件每个其他模型相同经 `mergeUnknownJsonFields` 合并进顶层 `extraJson`。2. `endpoints.isNotEmpty` 时，对 `this` 的每个端点，用该端点自己的 [`mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) 对照 `other.endpoints` 中匹配端点（按 `id` 匹配，`other` 无匹配端点时新鲜空 `ServiceEndpoint(id: endpoint.id)`）并也传 `base?.endpoints` 匹配条目，覆盖 `json['endpoints']`。3. 经 `ServiceNode.fromJson` 重新解析。
- **用法：**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  （来自 `lib/shared/services/sync_merge.dart` 的 `mergeRecords<ServiceNode>` 调用，它把它作为逐记录未知字段合并回调提供——见 [三方合并](../../../../algorithms/three-way-merge.md)）
- **备注：** 此递归合并只按 `id` 匹配端点——每个端点*已知*字段（protocol、port 等）仍完全来自 `this` 侧；只有每端点嵌套 `extraJson` 三方调和，与 [`DeviceRecurringCost.mergeUnknownFieldsFrom`](../../devices/models/device.md#devicerecurringcost-mergeunknownfieldsfrom) 文档化的相同限制。

### `ServiceRouteHop({String? id, this.type = ServiceRouteHopType.manual, this.serviceId, this.endpointId, this.deviceId, this.label, this.scheme, this.host, this.port, this.path, this.method, this.notes, this.extraJson = const {}})` <a id="serviceroutehop-new"></a>
- **种类：** `ServiceRouteHop` 的构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 625 行）。
- **用途：** 创建服务路由的一跳，未提供时生成新鲜 UUID `id`。
- **输入：** 所有字段可选；`type` 默认 `manual`。
- **返回：** 新 `ServiceRouteHop`。
- **副作用：** 无（除 `id` 为 null 时 `Uuid().v4()`）。
- **算法：** `id = id ?? const Uuid().v4()`；每个其他字段普通赋值。
- **用法：**
  ```dart
  return ServiceRouteHop(
    type: ServiceRouteHopType.portForward,
    method: method,
    serviceId: _relayServiceId,
    deviceId: _remoteDeviceId,
    label: _relayServiceId == null ? serviceRouteMethodLabel(method) : null,
    host: _emptyToNull(_remoteHostCtrl.text),
    port: int.tryParse(_remotePortCtrl.text.trim()),
  );
  ```
  （来自 `service_list_page.dart` 的 `_buildHop`，快速访问路由创建流程的单跳构建器——见 [服务与拓扑 — 快速访问路由创建 vs 高级编辑器](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)；也由 `service_route_edit_page.dart` 的高级多跳编辑器对话框直接构造）
- **备注：** 无。

### `ServiceRouteHop copyWith({...})` <a id="serviceroutehop-copywith"></a>
- **种类：** `ServiceRouteHop` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 641 行）。
- **用途：** 创建此跳的任何子集字段被替换、或经 `clearXxx` 标志显式清除（每个可空字段一个：`serviceId`、`endpointId`、`deviceId`、`label`、`scheme`、`host`、`port`、`path`、`method`、`notes`）的副本。
- **输入：** 每个可变字段一个可选参数，加十个 `clearXxx` 标志。
- **返回：** 新 `ServiceRouteHop`——与 `this` 相同 `id` 和 `extraJson`。
- **副作用：** 无。
- **算法：** 与 [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith) 相同清除标志优先形态。
- **用法：** `lib/` 中无任何调用点——跳总是整体替换（路由 `hops` 列表被重建或构造新鲜 `ServiceRouteHop`，按构造函数自己 Usage 示例）而非逐字段复制。
- **备注：** 此声明源码无 `/// Purpose:` 文档注释。这是本文件三个当前无调用点的 `copyWith` 方法中的第三个（与 [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith) 和 [`ServiceNode.copyWith`](#servicenode-copywith) 一起）——只有 [`ServiceRoute.copyWith`](#serviceroute-copywith) 实际被本代码库任何地方调用。

### `Map<String, dynamic> toJson()`（`ServiceRouteHop`） <a id="serviceroutehop-tojson"></a>
- **种类：** `ServiceRouteHop` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 686 行）。
- **用途：** 把此跳序列化为持久化在路由 `hops` 列表内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，`id`/`type` 无条件、每个其他字段只在 `if` 存在/非空。
- **副作用：** 无。
- **算法：** 与本文件其他 `toJson` 方法相同展开-然后-已知字段形态；`type`/`method` 经 `.jsonValue` 序列化。
- **用法：** 被 [`ServiceRoute.toJson`](#serviceroute-tojson) 为 `hops` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom) 调用。
- **备注：** 无。

### `factory ServiceRouteHop.fromJson(Map<String, dynamic> json)` <a id="serviceroutehop-fromjson"></a>
- **种类：** `ServiceRouteHop` 的工厂构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 707 行）。
- **用途：** 从 JSON 解析 `ServiceRouteHop`。
- **输入：** `json`。
- **返回：** 新 `ServiceRouteHop`；`extraJson` 持有不在 `_serviceRouteHopJsonKeys` 的每个键。
- **副作用：** 无。
- **算法：** 直接字段提取；`type` 经 [`ServiceRouteHopType.fromJson`](#serviceroutehoptype-fromjson)（默认 `manual`）；`method` 经 [`ServiceRouteMethod.fromJson`](#serviceroutemethod-fromjson)（可空，无回退）。
- **用法：** 被 [`ServiceRoute.fromJson`](#serviceroute-fromjson) 为 `json['hops']` 每个条目调用。
- **备注：** 无。

### `ServiceRouteHop mergeUnknownFieldsFrom(ServiceRouteHop other, {ServiceRouteHop? base})` <a id="serviceroutehop-mergeunknownfieldsfrom"></a>
- **种类：** `ServiceRouteHop` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 729 行）。
- **用途：** 三方合并此跳的未知 JSON 字段与另一个的。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并 `extraJson` 的新 `ServiceRouteHop`。
- **副作用：** 无。
- **算法：** 与 [`ServiceEndpoint.mergeUnknownFieldsFrom`](#serviceendpoint-mergeunknownfieldsfrom) 相同形态。
- **用法：** 被 [`ServiceRoute.mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom) 对每对索引对齐 `hops` 条目调用一次（按 `id` 匹配）。
- **备注：** 无。

### `ServiceRoute({String? id, required this.name, required this.sourceServiceId, this.sourceEndpointId, this.hops = const [], this.finalUrl, this.accessLevel = ServiceAccessLevel.lan, this.notes, DateTime? modifiedAt, this.extraJson = const {}})` <a id="serviceroute-new"></a>
- **种类：** `ServiceRoute` 的构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 761 行）。
- **用途：** 创建手动记录访问路径，两者都未提供时生成新鲜 UUID `id` 和 UTC `modifiedAt` 时间戳。
- **输入：** `name`、`sourceServiceId` 必填；每个其他字段可选（`hops` 默认 `[]`、`accessLevel` 默认 `lan`）。
- **返回：** 新 `ServiceRoute`。
- **副作用：** 无（除 `Uuid().v4()`/`DateTime.now()` 调用）。
- **算法：** `id = id ?? const Uuid().v4()`、`modifiedAt = modifiedAt ?? DateTime.now().toUtc()`；每个其他字段普通赋值。
- **用法：**
  ```dart
  final route = ServiceRoute(
    id: existing?.id,
    name: serviceRouteGeneratedName(
      sourceName: source?.name ?? existing?.name ?? '',
      hops: _hops,
      targets: targets,
    ),
    sourceServiceId: _sourceServiceId!,
    sourceEndpointId: _sourceEndpointId,
    hops: _hops,
    finalUrl: targets.firstOrNull,
    accessLevel: _accessLevel,
    notes: _emptyToNull(_notesCtrl.text),
    extraJson: serviceRouteExtraJsonWithTargets(existing?.extraJson ?? const {}, targets),
  );
  ```
  （来自 `service_route_edit_page.dart` 的保存处理器；路由 `name` 总是经 [`serviceRouteGeneratedName`](../services/service_analysis.md#serviceroutegeneratedname) 机器生成而非用户输入——见 [服务与拓扑 — 快速访问路由创建 vs 高级编辑器](../../../../features/services-topology.md#quick-access-route-creation-vs-the-advanced-editor)）
- **备注：** `finalUrl` 只为向后兼容存储第一/主目标；共享相同访问路径的额外分组 URL 住在 `extraJson['publicTargets']`，由 [`serviceRouteExtraJsonWithTargets`](../services/service_analysis.md#servicerouteextrajsonwithtargets) 写入而非此构造函数直接。

### `ServiceRoute copyWith({...})` <a id="serviceroute-copywith"></a>
- **种类：** `ServiceRoute` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 780 行）。
- **用途：** 创建此路由的任何子集字段被替换、或经 `clearSourceEndpointId`/`clearFinalUrl`/`clearNotes` 显式清除的副本。
- **输入：** 每个可变字段一个可选参数，加三个 `clearXxx` 标志。
- **返回：** 新 `ServiceRoute`——与 `this` 相同 `id`/`extraJson`；未显式传入时 `modifiedAt` 默认 `DateTime.now().toUtc()`，与 [`ServiceNode.copyWith`](#servicenode-copywith) 相同。
- **副作用：** 无。
- **算法：** 与本文件其他 `copyWith` 方法相同清除标志优先形态。
- **用法：**
  ```dart
  final routes = data.routes
      .where((route) => route.sourceServiceId != id)
      .map(
        (route) => route.copyWith(
          hops: route.hops.where((hop) => hop.serviceId != id).toList(),
        ),
      )
      .toList();
  ```
  （来自 [`ServiceStorage.deleteService`](../services/service_storage.md#deleteservice) 和 [`ServiceStorage.removeDeviceReferences`](../services/service_storage.md#removedevicereferences)，两者重建路由 `hops` 列表同时让每个其他字段不动）
- **备注：** 这是本文件唯一有真实调用点的 `copyWith`——不像 [`ServiceEndpoint.copyWith`](#serviceendpoint-copywith)、[`ServiceNode.copyWith`](#servicenode-copywith) 和 [`ServiceRouteHop.copyWith`](#serviceroutehop-copywith) 都当前未使用。两个调用点只传 `hops:`，依赖每个其他字段默认 `this` 当前值——但注意那仍把 `modifiedAt` bump 为"现在"（见 Algorithm），因此跳清理遍即使给定路由实际无需移除任何跳也总是标记路由为同步变更。

### `Map<String, dynamic> toJson()`（`ServiceRoute`） <a id="serviceroute-tojson"></a>
- **种类：** `ServiceRoute` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 814 行）。
- **用途：** 把此路由序列化为持久化在 `ServiceData.routes` 内的 JSON。
- **输入：** 无。
- **返回：** `Map<String, dynamic>` — 先展开 `extraJson`，`id`/`name`/`sourceServiceId`/`accessLevel`/`modifiedAt` 无条件、其他一切只在 `if` 存在/非空。
- **副作用：** 无。
- **算法：** 与其他 `toJson` 方法相同展开-然后-已知字段形态；`hops` 只在 `if (hops.isNotEmpty)` 时经 `hops.map((h) => h.toJson()).toList()` 序列化。
- **用法：** 被 [`ServiceData.toJson`](#servicedata-tojson) 为 `routes` 每个条目调用，也被 [`mergeUnknownFieldsFrom`](#serviceroute-mergeunknownfieldsfrom) 调用。
- **备注：** 无。

### `factory ServiceRoute.fromJson(Map<String, dynamic> json)` <a id="serviceroute-fromjson"></a>
- **种类：** `ServiceRoute` 的工厂构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 832 行）。
- **用途：** 从 JSON 解析 `ServiceRoute`。
- **输入：** `json`。
- **返回：** 新 `ServiceRoute`；`extraJson` 持有不在 `_serviceRouteJsonKeys` 的每个键（含 `publicTargets`，它不是已知顶层键，因此像任何其他无法识别字段一样经 `extraJson` 往返）。
- **副作用：** 无。
- **算法：** 直接字段提取；`hops` 经 [`ServiceRouteHop.fromJson`](#serviceroutehop-fromjson) 映射（默认 `[]`）；`accessLevel` 经 [`ServiceAccessLevel.fromJson`](#serviceaccesslevel-fromjson)；`modifiedAt` 经 `DateTime.parse`（必填）。
- **用法：** 被 [`ServiceData.fromJson`](#servicedata-fromjson) 为 `json['routes']` 每个条目调用。
- **备注：** 无。

### `ServiceRoute mergeUnknownFieldsFrom(ServiceRoute other, {ServiceRoute? base})` <a id="serviceroute-mergeunknownfieldsfrom"></a>
- **种类：** `ServiceRoute` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 854 行）。
- **用途：** 三方合并此路由的未知 JSON 字段与另一个的，含按跳 `id` 匹配合并每个跳自己的未知字段。
- **输入：** `other`；可选 `base`。
- **返回：** 带合并顶层 `extraJson` 和（`hops` 非空时）合并 `hops` 列表的新 `ServiceRoute`。
- **副作用：** 无。
- **算法：** 与 [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) 相同形态：重新解析与顶层 `mergeUnknownJsonFields` 结果合并的 `toJson()`，然后（`hops.isNotEmpty` 时）用每个跳自己的 [`mergeUnknownFieldsFrom`](#serviceroutehop-mergeunknownfieldsfrom) 对照 `other.hops` 中匹配跳（按 `id`，回退新鲜 `ServiceRouteHop(id: hop.id)`）覆盖 `json['hops']`，然后经 `ServiceRoute.fromJson` 重新解析。
- **用法：**
  ```dart
  mergeUnknownFields: (primary, secondary, base) =>
      primary.mergeUnknownFieldsFrom(secondary, base: base),
  ```
  （来自 `lib/shared/services/sync_merge.dart` 的 `mergeRecords<ServiceRoute>` 调用，是 [`ServiceNode.mergeUnknownFieldsFrom`](#servicenode-mergeunknownfieldsfrom) 用法路由侧对应物）
- **备注：** 因为 `publicTargets` 住在 `extraJson` 内（非声明字段），此方法的泛型 `extraJson` 三方合并也是跨同步调和路由分组公共目标的东西，非专用字段级合并规则。

### `const ServiceData({this.services = const [], this.routes = const [], this.extraJson = const {}})` <a id="servicedata-new"></a>
- **种类：** `ServiceData` 的构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 894 行）。
- **用途：** 持有完整服务清单：每个 `ServiceNode` 和每个 `ServiceRoute`，加任何无法识别顶层 JSON 字段。
- **输入：** 所有字段可选，默认空。
- **返回：** 新 `ServiceData`。
- **副作用：** 无。
- **算法：** 平凡字段赋值（这是文件非枚举类型中带新鲜 id/时间戳模式唯一 `const` 构造函数——`ServiceData` 自己无 `id`/`modifiedAt`，因为是单例顶层容器而非逐记录模型）。
- **用法：**
  ```dart
  await save(
    ServiceData(services: services, routes: data.routes, extraJson: data.extraJson),
  );
  ```
  （来自 [`ServiceStorage.addOrUpdateService`](../services/service_storage.md#addorupdateservice) 和每个其他 `ServiceStorage` 修改器，各重建完整 `ServiceData` 传给 [`ServiceStorage.save`](../services/service_storage.md#save)；单独 `const ServiceData()` 是 `ServiceStorage.load()` 的空文件回退）
- **备注：** 与 `Device`/`ServiceNode`/`ServiceRoute` 不同，`ServiceData` 无自己的 `mergeUnknownFieldsFrom`——其两个列表（`services`/`routes`）作为顶层 `mergeRecords<T>` 集合在 `lib/shared/services/sync_merge.dart` 独立合并，不像嵌套值对象（如 `Device` 内 `CpuInfo`）那样作为整文档合并。

### `Map<String, dynamic> toJson()`（`ServiceData`） <a id="servicedata-tojson"></a>
- **种类：** `ServiceData` 的方法。
- **来源：** `lib/features/services/models/service.dart`（第 905 行）。
- **用途：** 把完整服务清单序列化为持久化为 `service_data.json` 的 JSON。
- **输入：** 无。
- **返回：** 带 `services`/`routes` 总是存在（即使空，不同于省略空列表字段的每个嵌套模型 `toJson`）的 `Map<String, dynamic>`。
- **副作用：** 无。
- **算法：** `{...extraJson, 'services': services.map((s) => s.toJson()).toList(), 'routes': routes.map((r) => r.toJson()).toList()}`。
- **用法：** 被 [`ServiceStorage.save`](../services/service_storage.md#save) 经 `data.toJson()` 调用。
- **备注：** `services`/`routes` 无条件写（无 `if (...isNotEmpty)` 守卫），不同于 `ServiceNode`/`ServiceRoute` 上列表字段——空清单仍序列化为 `{"services": [], "routes": []}` 而非 `{}`。

### `factory ServiceData.fromJson(Map<String, dynamic> json)` <a id="servicedata-fromjson"></a>
- **种类：** `ServiceData` 的工厂构造函数。
- **来源：** `lib/features/services/models/service.dart`（第 916 行）。
- **用途：** 从 JSON 解析 `ServiceData`。
- **输入：** `json`。
- **返回：** 新 `ServiceData`；`extraJson` 持有不在 `_serviceDataJsonKeys`（`{'services', 'routes'}`）的每个键。
- **副作用：** 无。
- **算法：** 把 `json['services']` 经 [`ServiceNode.fromJson`](#servicenode-fromjson)、`json['routes']` 经 [`ServiceRoute.fromJson`](#serviceroute-fromjson) 映射，各键缺席默认 `[]`。
- **用法：**
  ```dart
  final json = jsonDecode(raw) as Map<String, dynamic>;
  return ServiceData.fromJson(json);
  ```
  （来自 [`ServiceStorage.load`](../services/service_storage.md#load)）
- **备注：** 无。
