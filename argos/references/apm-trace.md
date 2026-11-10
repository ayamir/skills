# APM Trace 能力

查询 RPC/HTTP 请求链路、错误传播和耗时；模型或 Tool 调用及多轮会话见 [GenAI Trace](./genai-trace.md)。替换示例 ID、region 和时间后执行；不要将 TraceID 传给日志专用 `logid_prune`。

## 查询完整 APM Trace

**适用场景**：已知 TraceID，需要查看完整 span 列表以判断错误、调用路径或耗时。

**首选 Tool**：`argos tool bytedtrace get_trace`。

**必要输入**：`query_id` 和建议显式指定的 `region`。TraceID 未指定时间窗时通常查询最近 24 小时；旧 Trace 应提供 Unix 秒 `start_at`/`end_at`。

按 TraceID 查询：

```bash
argos tool bytedtrace get_trace '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","region":"China-North"}' --json
```

指定旧 Trace 的时间窗：

```bash
argos tool bytedtrace get_trace '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","region":"China-North","start_at":1785891600,"end_at":1785895200}' --json
```

**结果判断**：明确 trace 是否实际返回 span，以及时间窗、region 是否覆盖目标。不要仅凭 24 小时默认查询的空结果断言旧 Trace 不存在。

**权限与支持限制**：需要 Trace 数据权限，受采样与保留时间限制；“完整”表示获取该请求可返回的 APM span，不能保证所有 span 都被采集或保存。

## 按条件浏览 Span 列表

**适用场景**：没有具体 TraceID，但已知 PSM、时间窗与 span 类别/类型，需要按条件浏览 server/client 等 span（如统计某时段错误 span、按 Tag 过滤调用）。已知 TraceID 的全量链路用上一节的 `get_trace`，不要用列表接口拼全链路。

**首选 Tool**：`argos tool bytedtrace get_span_list`（server Tool 全名 `bytedtrace.get_span_list`）。

**必要输入**：`start_at`/`end_at`（Unix 秒）、`psm`、`category`（如 `span`；event/metric 等取值以 `-h` schema 为准）、`type`（如 `server`/`client`）、`region`、`limit`（每页上限，默认 100）、`desc`（布尔，时间倒序/正序）。

查询某服务最近一小时的 server span：

```bash
argos tool bytedtrace get_span_list '{"psm":"my.service.api","category":"span","type":"server","start_at":1785891600,"end_at":1785895200,"region":"China-North","limit":50,"desc":true}' --json
```

带 Tag 过滤的 client span（`view_point` 仅在 `category=span` 且 `type=client` 时使用，取 `caller`/`callee`）：

```bash
argos tool bytedtrace get_span_list '{"psm":"my.service.api","category":"span","type":"client","view_point":"caller","start_at":1785891600,"end_at":1785895200,"region":"China-North","limit":50,"desc":true,"filter_tags":[{"tag_key":"_status_code","data_type":"STRING","operator":"eq","values":["500"]}],"query_operator":"AND"}' --json
```

**结果判断**：返回 `items`（span 对象列表）与 `context`。默认只取一页；只有当前证据不足时才继续翻页，并设置硬预算：最多 5 页或 30 秒，任一先到即停止并将结果标记为截断/部分。翻页时保持全部查询参数不变，把上一页返回的 `context` 原样作为下一页入参；`items` 为空、`context` 为空或 `context` 与已见游标重复时立即停止。它是不透明游标，不得解析、改写或自行拼接。`filter_tags` 的 `data_type` 取 `STRING/IPV4/IPV6/UUID/INT/LONG/UINT64/BOOL/DOUBLE`，`operator` 支持 `eq/ne/in/not_in/gt/gte/lt/lte/between`（`between` 恰好两个值）；多个过滤之间用 `query_operator` 指定 `AND`/`OR`，缺省 `AND`。

**易错处**：该接口按时间窗做有界浏览，不返回单次请求的完整 Trace；需要全量 span 和层级关系时拿列表中的 trace ID 再调 `get_trace`。`only_normal_trace=true` 只查非 posttrace 采样数据。

**权限与支持限制**：需要对应 PSM 的 Trace 数据权限；结果受采样、保留时间与每页 `limit` 限制，空列表不能单独证明该时段无调用。

## 生成 APM Trace 诊断概览

**适用场景**：需要一次获取 APM Trace 概览、错误/慢 span、服务和 LogID 清单，再按证据深入。

**首选 Tool**：`argos tool trace inspect`。

**必要输入**：`query_id`、`source`、`region`；明确时间窗时使用 RFC3339 字符串的 `start_at`/`end_at`。

APM Trace：

```bash
argos tool trace inspect '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","source":"apm","region":"China-North","start_at":"2026-08-05T09:00:00Z","end_at":"2026-08-05T10:00:00Z"}' --json
```

**结果判断**：先读 Tool 返回的 `view.md`，只在概览不够时按问题读取 `error.md`、`duration.md`、`logids.md`、`psms.md` 或 `spans.jsonl`；`raw.json` 是最后手段。不要把生成的文件路径当作诊断结论。`inspect` 的时间是 RFC3339 字符串，而上面的 `bytedtrace` Tool 的时间是 Unix 秒。APM 场景显式用 `source=apm`。

**权限与支持限制**：需要对应 APM Trace 来源权限。返回可读取的诊断概览与证据产物，不等于已完成根因归因；文件存在也不证明采样或 span 完整。
