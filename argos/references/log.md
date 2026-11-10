# 日志能力

按用户要完成的日志场景选择一项能力。以下命令均可直接运行；把示例 PSM、LogID、Pod、region 和时间换成目标值。`-e` 是控制面，JSON 中的 `region` 是日志数据区。只在示例不适用或新 Tool 尚未记录时查看实时 `-h`。

## Table of Contents

- [关键词检索](#关键词检索)
- [按 LogID 查日志](#按-logid-查日志)
- [错误日志聚合](#错误日志聚合)
- [按 Pod 查本地日志文件](#按-pod-查本地日志文件)
- [日志权限与范围](#日志权限与范围)

## 关键词检索

**适用场景**：已知服务、region 和时间窗，需要按包含词、排除词、日志级别或 KV 条件检索日志并连续取回多页结果。Tool 也允许不传包含词；不要为只有 level、KV 或排除条件的任务擅自补 `keywords`。

**首选 Tool**：`argos tool log search.keywords_stream`。默认加 `--paginate --json`，由共享 SDK 按前端节奏检索一批日志并返回完成状态。达到批次预算时保留 cursor；需要完整结果时必须沿同一分页链路继续，证据型任务可在证据充分后停止并明确结果不完整。用户明确要求单页调用时省略 `--paginate`。

**时间输入**：`start`/`end` 可传带时区的 RFC3339、Unix 秒、Unix 毫秒或以 `now` 开头的严格相对时间（如 `now-30m`、`now/d`）；共享 Tool Client 会在 schema 校验前固定为 UTC RFC3339。一次查询及其 cursor 翻页沿用首次解析后的绝对时间，不重复计算 `now`，避免分页窗口漂移。完整语法与边界见[通用执行规则](./common.md)。

**必要查询范围**：JSON 中的 `psm_list`、`region`、`start`/`end`。控制面使用 `-e`/`--site`，Project 使用 `--project`；分页预算使用 CLI 参数，不放进 Tool JSON。

**可选过滤**：`keywords`、`keywords_exclude`、`level`、`kv_filters` 等。`level` 是 `_level` KV 条件的简写，多个值匹配其中任一值；不要同时设置 `level` 和 `_level` KV，避免同一字段出现两组条件。Argos CLI 的 Tool Client 会把标准级别 `error`、`fatal`、`critical`、`warn`/`warning`、`notice`、`info`、`debug`、`trace` 展开为常见大小写写法，其中 `warn` 与 `warning` 视为同一组语义；该兼容只作用于显式调用 `adaptToolInput` 的客户端，服务端 Tool 合同保持原样。Argos 前端的 `_level` 下拉来自实际日志字段统计，并非封闭枚举；不属于上述标准级别的自定义值仍精确匹配并保留原始拼写。`error_log_preferred` 是先查 Warning+、空结果再回退全部级别的策略，不能代替精确的 `level` 过滤。通常至少给一种过滤以避免宽查询，但这是一项效率建议，不是把 `keywords` 单独变成必填；用户明确要求无过滤查询时保留其条件并说明范围和成本。

### 关键字查询参数与过滤语义

| 参数 | 合同与选择规则 |
| --- | --- |
| `keywords` | 包含词；多个值默认按 `AND` 组合。只有用户要求命中任意包含词时才设 `keyword_operator="OR"`；合法值只有 `AND`、`OR`。 |
| `keywords_exclude` | 排除词；当前 Tool 固定按 `AND` 组合，`keyword_operator` 不影响排除词。不要把 bytedcli 的 `exclude_operator` 写入本 Tool。 |
| `term_keywords` | 索引精确短语，不分词；新调用与 `index_mode="auto"` 或 `"on"` 一起使用，兼容旧调用时需要 `enable_index=true`。不要与 `index_mode="off"` 组合。 |
| `index_mode` | 合法值为 `legacy`、`auto`、`on`、`off`。新查询优先 `auto`；只有兼容旧调用时使用 `legacy`/`enable_index`，不要把 `enable_index` 与 `auto/on/off` 混为一套开关。 |
| `kv_filters` | 使用 `[{"key":"<field>","values":["<exact-value>"]}]`。字段名和值按原样传递；常见字段包括 `_cluster`、`_idc`、`_env`、`_stage`、`_podname`、`_location` 和 `__logid`，但不是封闭列表。`_pod` 不自动等价于 `_podname`。 |
| `level` | `_level` 的便捷写法；Argos CLI Tool Client 展开标准级别的常见大小写写法，自定义值精确匹配；不要同时再传 `key="_level"` 的 KV 条件。 |

Argos 前端的字段和值下拉来自当前服务、时间范围和日志样本的字段统计，不是 Tool 的固定枚举。当前 `search.keywords_stream` 不提供独立的下拉元数据查询：用户给出精确字段和值时保持原样；只有普通查询参数缺失时从上下文补齐或询问；需要先发现可用字段、值或索引口径时，按入口路由交给 `argos run`，不要猜字段名或把示例值当成全集。

`kv_filters` 接受任意字符串不代表目标业务字段已经配置为可过滤字段。`logs=[]` 或响应中的 `enable_index=true` 也不能单独证明某个 KV 条件有效。必须保留但当前入口不支持的过滤条件不能被静默删除；只有在原授权范围、结果规模可控且返回记录确实包含目标字段时，才能先取原始记录再做本地精确过滤，否则报告该过滤条件无法验证。不同日志 Tool 的过滤结构不能互换：`search.keywords_stream` 使用 `key`/`values`，`error_log` 使用 `metrics_tag`/`values`。

**调用步骤**：先确认 CLI 的 `argos tool --help` 支持 `--paginate`，使用已知查询条件调用。检查退出码，再读取 JSON 结果中的 `content[].text`；该文本内是查询结果，包含 `logs`、`cursor`、`finished` 和 `pagination`。报告本次查询范围与完成状态。

基础搜索并自动翻页：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --paginate --json
```

排除关键词并按集群过滤：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["timeout"],"keywords_exclude":["context canceled"],"kv_filters":[{"key":"_cluster","values":["default"]}],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --paginate --json
```

多个包含词按 OR 组合，并使用索引精确短语：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["timeout","deadline exceeded"],"keyword_operator":"OR","term_keywords":["request failed"],"index_mode":"auto","start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --paginate --json
```

不传包含词，仅按日志级别、排除词和 KV 条件查询：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","level":["error"],"keywords_exclude":["healthcheck"],"kv_filters":[{"key":"_cluster","values":["default"]}],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --paginate --json
```

显式设置查询预算并保存结果：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --paginate --max-logs 5000 --max-duration 300 --json > keyword-logs.json
```

保留原条件，用返回的 cursor 继续；本次最多查询 5 页：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z","cursor":"<cursor_from_previous_run>"}' --paginate --max-pages 5 --json
```

### cursor 续查状态机

1. 首次调用前把相对时间换算为固定的 RFC3339 `start`/`end`，保存不含 cursor 的完整查询为 `base_query`。控制面、Project、PSM、region、时间窗、包含词、排除词、level、KV 和索引语义都属于分页链路身份。
2. 每批结束后只按结果状态分支：后端 `finished=true`（对应 `pagination.complete=true`）表示完成；未完成且返回新 cursor 表示可续查；cursor 缺失、重复或响应报错时停止并交付部分结果，不能宣称完成。
3. 续查请求必须复制完整 `base_query` 并只追加上一批返回的最新 cursor。除 `--max-logs`、`--max-pages`、`--max-duration` 等客户端预算外，不得删除或改变原查询条件，也不得省略 cursor 重新发起首轮请求。退出码 `3` 是可续查或需说明异常的未完成状态，不是重置查询的理由。
4. 用户要求全量、精确计数或完整统计时，在总体预算内自动续查，不要每批询问用户；只需样本或根因证据时，可在证据充分后停止，但必须标注为部分结果。若要改变范围或过滤条件，开启新的分页链路，不复用旧 cursor，也不把两条链路合并成一个完整分页结果。
5. 跨批记录输入 cursor、输出 cursor、本批日志数、停止原因和结果文件。每次命令只返回本批拉取的日志；统计或聚合前先合并此前各批结果，并按稳定事件身份去重，不能只用可能缺失或重复的 LogID。
6. 最终交付查询范围、批次数、累计日志数、本批日志数、完成状态、停止原因和最新 cursor。若因预算或异常停止，保留最新 cursor 供后续从同一链路恢复。

**结果判断**：只有后端明确返回 `finished=true` 才报告分页完成。`pagination` 包含 `complete`、`pages`、`returned_logs`、`stop_reason` 和查询预算。退出码 `0` 表示完成，`3` 表示预算到达、cursor 缺失或重复等不完整状态，`1` 表示参数、Tool、传输或响应格式错误；失败时可能保留已取得的日志。不要只根据日志数量或退出码推断数据覆盖完整性。

**预算与命名**：

| 参数 | 含义 |
| --- | --- |
| `--paginate` | 显式启用关键字自动分页，原有单页调用不变 |
| `--max-logs` | 本批日志预算：首次搜索默认 1000，带 cursor 续查默认 1500；页边界检查，保留后端完整页 |
| `--max-pages` | 可选页数预算 |
| `--max-duration` | 分页总时间预算，秒，默认 300；单次传输超时也受剩余预算限制 |
| `--timeout` | 现有单次 Tool 调用超时，秒，不替代总预算 |
| JSON `limit` | 后端单页大小；CLI 后续按索引状态调整，并限制到剩余日志预算 |
| `--limit` | 现有终端输出长度，与分页日志条数无关 |

**易错处**：索引查询首轮取 1000 条；非索引或索引状态未确认时首轮取 100 条、后续取 200 条，不足一页时增加后端查询超时。带 cursor 的 Agent 续查每轮取 500 条、后端查询超时最高 60 秒。空页和不足 limit 都不是完成证据。Tool 当前未返回前端的 `log_size`，因此 CLI 无法精确执行前端 100 MB 暂停门槛；不能声称该项完全一致。`keywords_exclude` 始终按 AND 排除，`keyword_operator` 只控制包含词。[区域选择与组合](./regions.md#日志查询的区域选择与组合)说明控制面与多 region 查询。

**权限与支持限制**：认证、Project、控制面策略与单页调用相同，Agent 不增加 StreamLog 访问权限。完整分页只说明后端结束这次查询，仍需说明采样、权限和数据范围限制。部分结果可继续分析，但不能冒充全量；权限错误不能换控制面绕过。

**兼容旧 CLI**：不支持 `--paginate` 时升级 Argos CLI；暂时不能升级时，可从当前 skill 目录使用 `python3 scripts/log_search_keywords_stream.py '<json_input>' [max_pages]`。脚本仍保留原接口和退出码。只有备用脚本命令依赖 skill 目录，正常 CLI 用法不依赖 Python 或工作目录。

## 按 LogID 查日志

**适用场景**：用户提供的是 LogID，需要取回同一业务链路的日志；不要把 UUID 或 32 位十六进制 TraceID 当作 LogID。

**首选 Tool**：`argos tool log logid_prune`。

**必要输入**：`log_id`；v1 LogID 无法可靠推断 region 时显式指定 `region`。无需时间窗。有明确 PSM 范围时才传 `psm_list`，避免错误过滤遗漏日志。

单 region：

```bash
argos tool log logid_prune '{"log_id":"02177855...","region":"China-North"}' --json
```

同组多 region：

```bash
argos tool log logid_prune '{"log_id":"02177855...","region":"China-North|China-East"}' --json
```

**结果判断**：先确认请求的 region 和权限；空结果不等于 LogID 不存在。`logid_prune` 多 region 是一个以 `|` 分隔的 `region` 字符串，不是 `regions` 数组。v2 LogID 未提供 region 时，CLI 可使用 `auto` 推断。

**权限与支持限制**：需要各相关服务的日志权限；无权限或未覆盖 region 时，返回日志不代表完整链路。此调用取回日志，不自动证明错误根因。

## 错误日志聚合

**适用场景**：用户要看一个服务在某段时间的错误或 Panic 概览，而不是查一条特定关键词日志。

**首选 Tool**：`argos tool log error_log`。

**必要输入**：`psm`、`region`、Unix 秒整数格式的 `start`/`end` 和 `aggregator`。该 Tool 的 live schema 尚未启用时间转换，不要传 RFC3339、Unix 毫秒或 `now` 相对表达式。

按 location 聚合：

```bash
argos tool log error_log '{"psm":"my.service.api","region":"China-North","start":1785370800,"end":1785372600,"aggregator":"location"}' --json
```

按集群过滤后聚合：

```bash
argos tool log error_log '{"psm":"my.service.api","region":"China-North","start":1785370800,"end":1785372600,"aggregator":"location","kv_filters":[{"metrics_tag":"cluster","values":["default"]}]}' --json
```

**结果判断**：报告聚合维度、时间窗和返回的错误数量；没有 `aggregator` 导致的 `unsupported aggregator` 是参数错误，补上后再执行。

**权限与支持限制**：需要目标服务的错误日志数据权限；结果是指定维度与时间范围的聚合，不能据此解释每个请求的原因。

## 按 Pod 查本地日志文件

**适用场景**：已定位到 Pod，需要按文件路径、时间和关键词读取实例内日志。

**首选 Tool**：`argos tool log local_file`。

**必要输入**：`psms`、`regions`、`pod_names`、`paths`、`seek_position`。生产查询没有 Pod 可能返回 `pods len should not be empty`。路径和时间定位必须显式给出。

按时间段搜索并带上下文行：

```bash
argos tool log local_file '{"psms":["my.service.api"],"env":"prod","regions":["China-North"],"pod_names":["my-service-api-abc123"],"paths":["app/${psm}.log"],"seek_position":{"time_range":{"start_time":"2026-06-30T11:00:00+08:00","end_time":"2026-06-30T11:10:00+08:00"}},"keyword_filter_include":{"words":["error"],"operator":"AND","case_sensitive":false},"context_mode":{"before":3,"after":3},"limit":200}' --json
```

**结果判断**：确认返回的 Pod 和路径符合目标；缺 Pod 或文件路径错误不能归结为服务没有日志。

**权限与支持限制**：需要目标 Pod 与日志文件的访问能力；“本地”指服务实例日志文件，不是调用方电脑文件。这里只覆盖指定 Pod、路径和范围。

## 日志权限与范围

StreamLog 返回 `error_code=101403`、`need_permission=true`、`tag_infos[].iam_result=no_permission`，或权限结果含 `escapeParams.permission=argos.streamlog.view` 时，不要把空结果解释成没有日志。CLI 会输出 IAM 申请链接；`--json` 下读取 `permission_guidance.applications[]` 的 `psm` 与 `url`，交给用户审批后重试同一查询。不要擅自换工具或扩大时间窗来绕过权限。

关键词搜索中的 `region` 与 `-e` 必须匹配。[控制面与 region 映射](./regions.md)给出常见例子。日志 PPE 查询使用对应的非 PPE region。只有用户原查询明确指定 IDC 时才加 `_idc`；否则由 StreamLog 根据 region 路由。

旧关键词 Tool 与现有脚本输入的迁移规则见 [兼容说明](./compatibility.md)。
