# 监控能力

先判断用户给的是 Measurement（测点）、底层 Metrics 指标还是大盘，再选择取数路径。命令中的服务、region、时间和大盘 ID 是示例值，执行时替换成实际对象。

## 先判断监控对象

| 用户提供的对象 | 先确认什么 | 取数路径 |
| --- | --- | --- |
| 服务监控或 Measurement 名称/链接 | 精确服务、测点标识或定义、region、时间与维度；不要把测点显示名当成 metric name | 使用当前控制面开放的 Measurement 能力；输入形状不明确时先核对对应 schema |
| 已知 Metrics 指标名或表达式 | metric、聚合/字段、Tag 过滤或分组、region 与时间 | 按下方“查询指标数据”卡片使用 `metrics.data`；未知名称或 Tag 时按卡片发现候选 |
| Argos 自定义大盘链接或 ID | 大盘、变量与实际时间范围 | 按下方“大盘定义取数”卡片先取 panel/query 定义，再按每条 query 类型选择数据源 |
| 明确 PSM 的服务巡检 | PSM、region 与时间窗 | 按下方“服务确定性巡检”卡片使用 `argos tool service inspect` |

只给服务和“可用性/延迟”等目标时，先利用已有链接或上下文确认对象与统计口径，不能仅凭词义捏造测点或指标名；无法确定关键对象时再追问。

本页完整命令示例覆盖 Metrics 纠偏/取数与大盘取数；未展开的入口通过 `argos tool list` 和目标 Tool 的 `-h` 核实，不猜字段。已有卡片适用时直接执行，不把发现步骤变成每次查询的固定前置操作。

## 查询指标数据

**适用场景**：按服务、时间和维度查询 QPS、延迟、CPU 等时序值。QPS/P99/Tag 过滤是同一能力的不同用法。

**首选 Tool**：`argos tool metrics data`。

**必要输入**：指标名、region、`start_time`/`end_time`、聚合方式和必要 Tag。时间可传带时区的 RFC3339、Unix 秒、Unix 毫秒或以 `now` 开头的严格相对表达式，共享 Tool Client 会在 schema 校验前归一化；完整语法见[通用执行规则](./common.md)。指标名或维度不明确时，可先用 `metrics.name_suggestion`、`metrics.tag_key`、`metrics.tag_value` 获取候选，再回到 `metrics.data`。

QPS（多值 throughput 取 `rate` 字段）：

```bash
argos tool metrics data '{"metric":"service.request.server.throughput.total","region":"China-North","start_time":1700000000,"end_time":1700003600,"aggregator":"sum","top_bottom":"top-10-max","is_multi_field":true,"multi_field_expr":"rate","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true}]}' --json
```

P99 延迟（多值 timer 的加权百分位）：

```bash
argos tool metrics data '{"metric":"service.request.server.latency","region":"China-North","start_time":1700000000,"end_time":1700003600,"aggregator":"sum","top_bottom":"top-5-max","is_multi_field":true,"multi_field_expr":"weighted_avg(value=pct99,weight=counter)","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true}]}' --json
```

按方法分组下钻：

```bash
argos tool metrics data '{"metric":"service.request.server.throughput.total","region":"China-North","start_time":1700000000,"end_time":1700003600,"aggregator":"sum","top_bottom":"top-10-max","is_multi_field":true,"multi_field_expr":"delta","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true},{"key":"_method","value":"*","function":"literal_or","is_filter":false}]}' --json
```

单值 CPU 指标：

```bash
argos tool metrics data '{"metric":"tce.container.cpu_usage","region":"China-North","start_time":1700000000,"end_time":1700003600,"aggregator":"avg","top_bottom":"top-20-max","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true}]}' --json
```

查一个指标的 Tag Key 与 `_method` 可选值：

```bash
argos tool metrics tag_key '{"region":"China-North","metrics_name":"service.request.server.throughput.total","tenant":"default"}' --json
argos tool metrics tag_value '{"region":"China-North","metrics_name":"service.request.server.throughput.total","tagK":"_method","tenant":"default","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true}]}' --json
```

**结果判断**：报告指标名、聚合、时间窗、Tag 过滤/分组和实际返回的值。`is_filter=true` 仅过滤；`false` 按该 Tag 分组。报 `41111012` 或“多值指标请明确指定”时，补 `is_multi_field=true` 与适合指标类型的 `multi_field_expr`，不要把参数错误说成无数据。无数据时先核对 PSM 与 region；如指标体系要求，可尝试 `<psm>.<metric_name>` 一次，不自动换近似指标名。

**易错处**：`top_bottom` 是 TopN 排序，格式如 `top-10-max`；`function=literal_or` 是精确匹配，`regexp` 是正则。计数器速率可用 `rate=true` 与 `rate_options.counter=true`，多值指标取某个字段用 `multi_field_expr`，两种语义不同。长时间窗可增加 `downsample_interval`，但需在结论中说明粒度。

**权限与支持限制**：需要对应指标数据权限。返回值受时间范围、下采样、Tag 和 TopN 限制，空序列不能单独证明服务无流量或健康；取数不包含异常归因。

## 测点/指标查询纠偏与 URL 解析

**适用场景**：已经尝试过 `measurement.data` / `metrics.data` 但名称或参数不对，需要在**已知前缀或已知名称**基础上纠正候选、核实精确定义（聚合器、Tag、必填输入）或取某个 Tag 的可选值；以及把 Metrics FE / Argos Explore 页面 URL 还原成数据 Tool 请求。它不是任意自然语言指标发现入口，显示名不能代替精确 name。

**首选 Tool**：`argos tool timeseries inspect`（server Tool 全名 `timeseries.inspect`）。

**必要输入与最小调用顺序**：`command` 必填，取值 `suggest_names` / `describe` / `values` / `parse`；前三种还必须指定 `source`（`measurement` 或 `metrics`，两者对象与 Tag 语义不同，不能混查）。

1. `suggest_names`：measurement 源用 `observable_object`（`obj_type:obj_name`）+ `region`；metrics 源用 `name_prefix` + `region`。
2. `describe`：拿到候选后核实精确定义；measurement 源需要 `name` + `observable_object` + `region`，metrics 源需要 `name` + `region`。返回可用聚合器、`tag_keys`、`requirements`/`missing_inputs` 与 `query_ready`，作为下一步依据。
3. `values`：只对 `describe` 返回过的 `tag_key` 取值；measurement 源带 `name` + `observable_object` + `region` + `tag_key`，metrics 源带 `name` + `region` + `tag_key`；已知固定输入通过 `inputs` 提供，缺少必填维度时先按 `missing_inputs` 补齐。
4. 输入完整后再回到上面的 `measurement.data` / `metrics.data` 取数。

按已知前缀纠偏 Metrics 名称：

```bash
argos tool timeseries inspect '{"command":"suggest_names","source":"metrics","name_prefix":"sample.","region":"China-North"}' --json
```

核实已知 Measurement 的精确定义与可用 Tag：

```bash
argos tool timeseries inspect '{"command":"describe","source":"measurement","name":"sample.measurement","observable_object":"service:my.service.api","region":"China-North"}' --json
```

取一个 describe 已返回的 Tag 的可选值：

```bash
argos tool timeseries inspect '{"command":"values","source":"measurement","name":"sample.measurement","observable_object":"service:my.service.api","region":"China-North","tag_key":"method"}' --json
```

`parse` 只需要 `url`，解析 Metrics FE 指标详情 hash、Metrics FE Bosun 查询或 Argos Explore/Dashboard/Overview 链接（保留 URL 中完整查询状态），输出 `measurement.data` / `metrics.data` / `bosun.data` 的 `parsed_queries`：

```bash
argos tool timeseries inspect '{"command":"parse","url":"https://metrics-fe.byted.org/web/plot/metrics#now-1h,now,,,,,,,China-North,false,,;sum:store:top-20-max:sample.metric{}{_psm=literal_or(my.service.api)};0"}' --json
```

**结果判断**：`limit` 范围 1～50、默认 10；`namespace`/`tenant` 默认 `default`；measurement 候选可用 `sections` 限定 `measurement`/`sli`。先读 `query_ready` 与 `missing_inputs`，不要跳过 `describe` 直接猜 Tag。

**易错处**：`parse` 只还原请求、**不执行查询也不验证指标存在**；普通大盘首页和 Grafana URL 不在支持范围。Tag 值发现不会替你补资源类身份输入（标记为不可发现的必填项），这些必须来自用户或可信上下文。

**权限与支持限制**：需要对应元数据与 Tag 值的读取权限；纠偏结果是候选和定义，不代表查询一定有数据，空候选不能证明指标不存在。

## 服务确定性巡检

**适用场景**：PSM、region、时间窗都明确时，一次性获取服务黄金指标（可用性 Availability、QPS、P99 延迟）、方法维度（Top50 吞吐量/错误/延迟并集及成功率）以及上下游服务依赖（Top20）和方法依赖。`argos tool service inspect` 是 CLI/Tool SDK 的确定性组合能力，由本地固定编排通过**类型化的 measurement HTTP API 直连适配器**取数（不是 sre_agent server Tool、不进 MCP catalog、不需要 TCC allowlist），语义与分组回退链对齐全局 bytedcli；它不是新的服务端 Tool，也不进入 Agent 默认 Tool 集，不迁移 metadata、SLI monitor、告警分桶、TCE 集群等完整 preview 内容；需要开放式诊断或根因分析时仍使用 `argos run`。

**首选 Tool**：`argos tool service inspect`。

**必要输入**：`psm` 必填；`regions` 为可选数组，默认 `China-North`，输入会先 trim、过滤空值、按 APM 别名归一化后再按出现顺序去重，去重后最多 5 个 region。region→后端站点的路由由 region metadata 与 TCC `argos.fe.config/service-config` 推导（与 argos-fe HostResolver 一致）：当前发布 gate 仅开放 `cn` 与 `i18n`；只有 caller 与目标 site 都已验证才取数。BOE、Sandbox、I18N-BD、US/EU TTP 与 `us-ttpbd` 均明确报 unsupported，不以快照或硬编码地址继续取数。`start_time`/`end_time` 为 Unix 秒，缺省查询最近 12 小时。每个 region 内固定并发执行所需的 measurement 查询（service 三项、methods、上下游服务依赖、上下游方法依赖），不同 region 之间串行执行，不做无界放大。该能力是本地确定性能力，不能与 `--server` 一起使用（传入即 fail-fast，不发起任何 server catalog/JWT 请求）。

默认时间窗与单个 region：

```bash
argos tool service inspect '{"psm":"my.service.api"}' --json
```

显式时间窗与多 region（自动按 region metadata 路由到对应站点后端）：

```bash
argos tool service inspect '{"psm":"my.service.api","regions":["China-North","China-East"],"start_time":1700000000,"end_time":1700003600}' --json
```

i18n 控制面查询已验证的 Singapore-Central：

```bash
argos tool service inspect '{"psm":"my.service.api","regions":["Singapore-Central"],"start_time":1700000000,"end_time":1700003600}' --env i18n --json
```

**结果判断**：输出包含 `combined` 与 `partial`/`warnings`；多 region 时另含 `regions[]`（每个 region 的 service、methods、upstream、downstream、upstreamMethods、downstreamMethods），单 region 时不重复输出 `regions[]`。service 指标为有界 summary：`points/min/max/avg/last`，并显式给出 `availability`；method 显式给出 `successRate`（按 bytedcli 规则由 error_rate 推导：百分号单位直接使用，≤1 的小数按比例换算），P99 不会因为缺少正 QPS 被丢弃；methods 是 total/error/latency 三类 Top50 的并集；用于成功率的辅助 error-rate 查询及逐方法补查使用 bytedcli 默认 Top10。method 维度的分组严格按 bytedcli 四级回退链执行：先 `group_by_observable_object_tags=["method"]`，无效或失败再试 `["service.method"]`，之后才退 observable tag wildcard，再退 measurement tag wildcard；deps 是 total/error/error_rate 三类 Top20 的并集；方法依赖唯一键保留 `self_method + peer service + peer method`。单个维度失败时保留其余维度结果，`partial` 为 `true` 并在 `warnings` 中说明；全部底层查询失败或均无有效指标（空序列、全 `null`、不支持指标）时整体报错失败。输出不携带原始 datapoints，规模有界，必须结合 `partial` 与 `warnings` 判断后再下结论。

**权限与支持限制**：以当前登录用户身份直连 measurement HTTP API（用户 JWT、对应站点/region 端点、401 自动刷新一次），不使用 admin 或服务账号加宽，也不需要 `measurement.data` server Tool 的 catalog 可见性或交互确认 gate。直连与 server Tool 是两份独立合同，互不静默 fallback；直连失败（如 403/业务错误码）会原样报错，不会改调 server Tool。`argos tool measurement data` 仍然是既有 sre_agent server Tool，服务端 Agent/runtime 复用与集中治理继续走它。结果只反映指定时间窗内的指标与依赖，不包含异常归因或 RCA；未验证面需要在对应网络以普通用户完成 TCC smoke 与固定窗口对照后再开放；本地 `-h` 不访问 server catalog/auth，`--timeout` 覆盖整个命令。

## 按大盘定义取数

**适用场景**：给定 Argos 自定义大盘链接或 ID，按大盘已有面板和变量确定性查询其数据。

**首选 Tool**：`argos tool dashboard data_query`，先取得面板/查询定义；返回的是面板查询配置，本身不返回时序值。后续按每条 query 的类型调用相应 `measurement.data`、`metrics.data` 或 `bosun.data`。

**必要输入**：`dashboard_id`、`vregion` 和大盘实际使用的业务 `variables`；后续时序取数还需要用户指定或页面提供的时间范围。

获取面板查询定义：

```bash
argos tool dashboard data_query '{"dashboard_id":"123456","vregion":"China-North","variables":[{"key":"psm","value":"my.service.api"}]}' --json
```

从一个 Metrics 面板定义继续取数（将返回的指标、Tag 和时间范围代入）：

```bash
argos tool metrics data '{"metric":"service.request.server.throughput.total","region":"China-North","start_time":1700000000,"end_time":1700003600,"aggregator":"sum","top_bottom":"top-10-max","is_multi_field":true,"multi_field_expr":"rate","tags":[{"key":"_psm","value":"my.service.api","function":"literal_or","is_filter":true}]}' --json
```

**结果判断**：保留大盘 panel/query 顺序，逐条记录是否成功和返回的数据。时间范围用于后续时序查询，不放进 `variables`。仅总结成功返回的数值；失败、不支持或未执行的 query 要显式列出。

**权限与支持限制**：需要大盘读取权限及各面板数据源权限；此 Tool 读取 panel/query 定义，后续 Tool 才返回时序值。仅使用当前目录开放的入口，不将大盘管理或 Agent Session 工具当成可直接调用的替代。
