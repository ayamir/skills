# GenAI Trace 能力

查询模型、Tool、Prompt 等 AI span；RPC/HTTP 完整链路见 [APM Trace](./apm-trace.md)。GenAI Trace 与多轮 session 是不同查询对象。替换示例 ID、region 和时间后执行；不要将 TraceID 传给日志专用 `logid_prune`。

## 查询 GenAI Trace

**适用场景**：用户关心 Agent、模型、Tool 或 Prompt span，而无需完整 RPC/HTTP span 列表。

**首选 Tool**：`argos tool bytedtrace get_ai_trace`。

**必要输入**：`query_id`、建议显式指定的 `region`；查询旧 Trace 时提供 Unix 秒 `start_at`/`end_at`。

按 TraceID 获取 AI span：

```bash
argos tool bytedtrace get_ai_trace '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","region":"China-North"}' --json
```

查询旧时间窗：

```bash
argos tool bytedtrace get_ai_trace '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","region":"China-North","start_at":1785891600,"end_at":1785895200}' --json
```

**结果判断**：此 Tool 只返回 GenAI 相关 span。它的空结果不能证明完整 Trace 不存在；需要完整调用链时使用 [APM Trace](./apm-trace.md) 中的“查询完整 APM Trace”能力。

**权限与支持限制**：需要 GenAI Trace 数据权限；返回 AI 相关 span，不是跨轮次会话详情，也不覆盖全部 RPC/HTTP span。

## 按条件浏览 GenAI Span 列表

**适用场景**：没有具体 TraceID，但已知业务 PSM 与时间窗，需要浏览 GenAI 语义 span（Agent/Model/Tool/Prompt 等），例如排查某时段模型调用失败或按 Tag 过滤 AI 调用。

**首选 Tool**：`argos tool bytedtrace get_ai_span_list`（server Tool 全名 `bytedtrace.get_ai_span_list`）。

**必要输入**：`start_at`/`end_at`（Unix 秒）、`psm`、`region`、`limit`（每页上限，默认 100）、`desc`（布尔）。`category`/`type` 不需要也不能指定——服务端内部固定为 GenAI span（`span` + `gen_ai`）；需要通用 RPC/HTTP span 时使用 [APM Trace](./apm-trace.md) 的 `get_span_list`。

```bash
argos tool bytedtrace get_ai_span_list '{"psm":"example.ai.service","start_at":1785891600,"end_at":1785895200,"region":"China-North","limit":50,"desc":true}' --json
```

**结果判断**：返回 `items` 与不透明翻页游标 `context`。默认只取一页；只有当前证据不足时才继续翻页，并设置硬预算：最多 5 页或 30 秒，任一先到即停止并将结果标记为截断/部分。翻页时保持查询参数不变并原样回传 `context`，不得解析或改写；`items` 为空、`context` 为空或 `context` 与已见游标重复时立即停止。Tag 过滤（`filter_tags`）的 data_type/operator 取值、`query_operator`（AND/OR）规则与通用 `get_span_list` 相同；`view_point` 取 `trace`/`span`。

**权限与支持限制**：需要该 PSM 的 GenAI Trace 权限；结果受采样与保留时间限制，列表用于有界浏览，需要单请求完整 AI 链路时再用 trace ID 调 `get_ai_trace`。

## 查询业务 GenAI 会话（list → index → detail）

**适用场景**：排查某个业务 PSM（如 TRAE CLI 的 `trae.cli.monitor`、TRAE IDE 的 `trae.backend.monitor`，其他业务用其真实监控 PSM）在时间窗内的多轮会话：先发现会话，再看会话摘要与 turn 列表，最后取某个 turn 的完整轨迹。三个 Tool 都是只读确定性查询，按固定顺序使用；这与 `argos run` 的 Argos 执行 session 不是同一种 ID。

**首选 Tool（按顺序，server Tool 全名即 `bytedtrace.query_session_list` → `bytedtrace.query_session_index` → `bytedtrace.query_session_detail`）**：

1. `argos tool bytedtrace query_session_list`：在有界时间窗内取一页会话。
2. `argos tool bytedtrace query_session_index`：取单个会话的摘要与 turn 列表（含每个 turn 的 `user_message_id`）。
3. `argos tool bytedtrace query_session_detail`：取单个 turn 的完整时间线。

第一步，分页列出会话（`start_time`/`end_time` 是 Unix 秒、左闭右开且必须 `start_time < end_time`；`limit` 为 1～100）：

```bash
argos tool bytedtrace query_session_list '{"psm":"trae.cli.monitor","start_time":1761000000,"end_time":1761003600,"limit":20,"access_mode":"personal"}' --json
```

翻页时**必须重复完全相同的时间窗**，并把上一页返回的 `context` 原样传回；它是 opaque page token，不得解析、改写或跨时间窗/跨 PSM 复用：

```bash
argos tool bytedtrace query_session_list '{"psm":"trae.cli.monitor","start_time":1761000000,"end_time":1761003600,"limit":20,"access_mode":"personal","context":"<上一页原样返回的 context>"}' --json
```

第二步，用列表中的 `session_id` 取会话索引（返回会话摘要、按时间排序的 `turns` 与 `turns_truncated`）：

```bash
argos tool bytedtrace query_session_index '{"psm":"trae.cli.monitor","session_id":"<业务会话 ID>","access_mode":"personal"}' --json
```

第三步，用 index 中 turn 的 `user_message_id` 取该 turn 详情（返回 user/agent 元数据、用户消息、时间线 `items` 与统计 `stat`）：

```bash
argos tool bytedtrace query_session_detail '{"psm":"trae.cli.monitor","session_id":"<业务会话 ID>","user_message_id":"<index 返回的 user_message_id>","access_mode":"personal"}' --json
```

**结果判断**：列表返回 `sessions`（含首条输入、最近输出、开始/活跃时间、token、turn 数等；会话内时间戳为**微秒**）、`desensitized` 与下一页 `context`（空表示无下页）。需要多个 turn 时严格按 index 顺序逐个调 detail，并在结论中标出失败的 turn ID 与 `turns_truncated` 截断状态；部分 turn 失败不代表整个会话不存在。

**易错处**：`access_mode` 仅支持 `personal`（默认）或 `viewer`；按指定 `user_id` 过滤他人会话时应配合 `viewer`。`sort_field`（`start_time`/`last_active_time`）与 `sort_order`（`asc`/`desc`）只在 list 阶段使用。不要跳步猜测 `user_message_id`——它只能来自 index 返回。

**权限与支持限制**：只能读取当前用户有权访问的会话与 turn；`desensitized=true` 表示内容已脱敏，引用时按脱敏后的内容报告。会话数据有保留期限，空列表只代表该时间窗/过滤条件下无可见会话。

## 生成 GenAI Trace 诊断概览

**适用场景**：需要一次获取 GenAI Trace 概览、错误/慢 span、服务和 LogID 清单，再按证据深入。

**首选 Tool**：`argos tool trace inspect`。

**必要输入**：`query_id`、`source`、`region`；明确时间窗时使用 RFC3339 字符串的 `start_at`/`end_at`。

GenAI Trace：

```bash
argos tool trace inspect '{"query_id":"5a25e2f7-3063-326c-b0da-6584cc4b7c6e","source":"ai","region":"China-North","start_at":"2026-08-05T09:00:00Z","end_at":"2026-08-05T10:00:00Z"}' --json
```

**结果判断**：先读 Tool 返回的 `view.md`，只在概览不够时按问题读取 `error.md`、`duration.md`、`logids.md`、`psms.md` 或 `spans.jsonl`；`raw.json` 是最后手段。不要把生成的文件路径当作诊断结论。`inspect` 的时间是 RFC3339 字符串，而上面的 `bytedtrace` Tool 的时间是 Unix 秒。`source=auto` 当前按 APM 处理，GenAI 场景必须显式用 `source=ai`。

**权限与支持限制**：需要对应 GenAI Trace 来源权限。返回可读取的诊断概览与证据产物，不等于已完成根因归因；文件存在也不证明采样或 span 完整。
