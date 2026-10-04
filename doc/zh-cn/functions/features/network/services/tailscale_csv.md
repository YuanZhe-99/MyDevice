# lib/features/network/services/tailscale_csv.dart

## 声明

| 声明 | 类型 | 用途 |
|---|---|---|
| `match` | 静态方法 | 建议节点 ID、精确名称、规范化名称匹配并显示歧义。 |
| `TailscaleCsv.parse` | 静态方法 | 解析引号 UTF-8 CSV、BOM、多行单元格和末尾空列。 |
| `addresses` | 静态方法 | 拆分并去重已解析的 IP 单元格。 |
| `assignment` | 静态方法 | 将原始列和地址映射至网络分配，保留手动字段。 |

拒绝缺少必需列、重复列名/节点 ID、错误引号、错误行宽、无效地址、无时区日期和
错误非空布尔值。错误带行/列或字符上下文。空出口状态保留已有标志，原始空值仍
保存在 `tailscale` 中。不执行 I/O。
