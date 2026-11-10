# Argos Agent

执行计划不能预先确定，需要系统选择能力、观测对象、统计口径或后续步骤时，使用 `argos run`。这既包括根据中间证据继续调查、解释异常或形成归因，也包括尚未确定 Measurement、指标、Tag 或接口维度的一次性取数。已匹配现有能力卡片、能确定 Tool 和查询口径的日志、Metrics 等高频取数直接使用对应 Tool；仅缺少普通查询参数时先补齐或询问，不因此改走 `run`。

本页中的 Argos Agent 指执行观测查询与调查的产品能力；GenAI Trace 和 session 是可能被调查的数据对象，两者不要混淆。下列场景用于说明如何表达目标，不是 Agent 能力全集。实际可执行范围取决于目标控制面的 Agent、Tool、数据与权限，不要将场景示例理解为对结果的保证。使用 `run` 不会扩大用户授权或任务范围：用户只要求取数时保留该范围，不自动追加根因分析或写操作。

对本页未单列的任何 Argos 相关目标，只要无法预先确定为某个稳定 Tool/action，就保留用户原始目标交给 `argos run`，由 Agent 读取当前控制面已加载的 Skills 和 Tools 选择能力。能力范围包括但不限于服务健康和 Metrics、日志、APM/GenAI Trace、报警与值守、大盘、运行时配置、调用依赖与代码证据、根因调查及观测报告。不要因本页没有对应标题就拒绝调用；当前 Agent 无该能力或无权访问时，再明确报告限制，不猜测结果。

## Table of Contents

- [快速调用与场景选择](#快速调用与场景选择)
- [调查场景](#调查场景)
- [结果判断与续接](#结果判断与续接)
- [按需执行参考](#按需执行参考)

## 快速调用与场景选择

`new` 是 `run` 的默认子命令，因此 `argos run '<query>'` 与
`argos run new '<query>'` 都会启动新会话；下文通常使用更简洁的 `argos run`。
续接已有会话时必须显式使用 `argos run resume`。

```bash
argos run '调查 my.service.api 在 China-North 最近一小时错误率升高的原因，列出证据、候选原因和未确认项' --output-format text --timeout 300000
argos run resume <session_id> '继续核对最可能的原因，并补充仍缺少的证据'
```

| 用户目标 | 关键上下文 | 场景 |
| --- | --- | --- |
| 按业务目标查询服务或接口指标 | PSM、接口/方法、region、时间与所需口径 | [服务健康与指标异常分析](#服务健康与指标异常分析) |
| 解释服务健康或指标异常 | PSM、region、时间与异常现象 | [服务健康与指标异常分析](#服务健康与指标异常分析) |
| 一次性检查大盘异常 | 大盘链接/ID、变量与实际时间范围 | [大盘异常巡检](#大盘异常巡检) |
| 解释报警为何触发、影响什么 | 可定位的报警与 region | [单报警原因分析](#单报警原因分析) |
| 诊断已有规则噪音或阈值 | 规则标识或 PSM/群、控制面 | [已有报警规则诊断与优化](#已有报警规则诊断与优化) |
| 解释错误日志及传播关系 | LogID 或服务日志查询范围 | [分析错误日志原因](#分析错误日志原因) |
| 分析 RPC/HTTP 请求错误与耗时 | APM TraceID、region、必要时间范围 | [APM 链路错误与耗时分析](#apm-链路错误与耗时分析) |
| 分析模型/Tool 调用失败与耗时 | GenAI TraceID、region、必要时间范围 | [GenAI 链路错误与耗时分析](#genai-链路错误与耗时分析) |
| 解释多轮会话从何处偏离 | PSM、GenAI session_id、region、现象 | [GenAI 多轮会话归因](#genai-多轮会话归因) |
| 用部署代码核实处理逻辑 | 上述任一运行证据及已有代码线索 | [结合运行证据与源码解释问题](#结合运行证据与源码解释问题) |
| 其他 Argos 相关能力 | 用户原始目标及已知对象、region、时间范围 | 直接使用 `argos run`，由 Agent 发现当前可用能力 |

按所选场景补齐关键上下文，不要把所有场景的输入合并成一份必填清单。只分析实际获得的证据，区分观察、候选原因和已验证结论；权限或数据缺失时保留已有证据并报告缺口。

## 调查场景

### 服务健康与指标异常分析

**适用任务**：给定服务和时间范围，需要查询尚未明确底层 Measurement/指标的服务或接口口径，或判断健康状况、解释流量、错误率或延迟异常并根据证据下钻。

**必要上下文**：精确 PSM、region、时间范围；指定接口/RPC 方法、百分位、已知异常现象、对比时间或关注维度按用户目标提供。缺少底层指标名不应阻止 `run`，由 Agent 核对实际可用口径。

仅查询接口耗时：

```bash
argos run '查询 apm.argos.ai_agent_center 在 China-North 最近一小时 HTTP 接口 /agent_center/api/v1/lui/project/list 的 P90 耗时。先核对实际可用的接口维度与统计口径；只报告查询口径、结果和数据限制，不扩展根因分析' --output-format text --timeout 300000
```

综合检查：

```bash
argos run '检查 my.service.api 在 China-North 于 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z 的服务健康，分析流量、错误率和延迟异常，按证据下钻，列出影响范围、可能原因和未确认项' --output-format text --timeout 300000
```

围绕延迟调查：

```bash
argos run '调查 my.service.api 在 China-North 于 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z 的 P99 延迟升高，对比前一小时，识别异常接口或依赖，并说明每个判断的指标证据' --output-format text --timeout 300000
```

**预期结果**：实际查询的指标和时间窗、异常时段与维度、影响范围、证据支持的原因及后续建议。相关性应与已确认因果区分。

**权限与支持限制**：需有目标服务的指标权限。报告实际成功查询的指标和维度，不能因某条序列无数据就判断服务健康；指标异常检测、原因假设与已证实根因分别表达，不因一次相关变化推断因果。

### 大盘异常巡检

**适用任务**：给定 Argos 自定义大盘，对多个面板做一次低频异常巡检，筛选异常并汇总。

**必要上下文**：Argos 自定义大盘链接或 ID；region、时间范围与业务变量优先从用户或链接获取。如需阈值或排除项，由用户提供；使用默认范围时明确报告实际范围。

```bash
argos run '巡检 Argos 大盘 123456，region 为 China-North，业务变量 psm=my.service.api，时间为 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z。列出异常面板、异常时段和依据，汇总相关现象，说明未成功查询的面板' --output-format text --timeout 300000
```

**预期结果**：面板级异常明细、时间和判断依据、关联现象及未覆盖项。大盘定义或部分面板取数成功不能代表完成整盘巡检。

**权限与支持限制**：需有大盘与面板数据源权限。多面板查询受 Metrics 查询频率限制，适用于低频巡检，不作为持续监控或报警机制。这里的示例针对 Argos 自定义大盘；Grafana 或其他大盘类型需另行确认目标环境支持。读取大盘定义不等于取得时序数据；说明未取数或未分析的面板。

### 单报警原因分析

**适用任务**：解释一个报警为什么触发、影响什么，以及后续应检查什么，需要结合实时详情和相关观测数据。

**必要上下文**：报警链接，或能唯一定位报警的标识与 region；传统报警使用 alert_group_id，Duty 使用 anomaly_id 与 space_id。已知影响、时间和调查线索可补充。

从报警链接开始：

```bash
argos run '分析这个报警：<alarm_link>。核对实时详情与触发条件，结合相关指标、日志或 Trace 调查原因，说明影响范围、证据和未确认项，并给出处理建议' --output-format text --timeout 300000
```

从传统报警标识开始：

```bash
argos run '分析 China-North 的传统报警 alert_group_id=123456789，解释触发条件和异常时间，调查相关观测证据，区分已确认事实与候选原因，给出后续建议' --output-format text --timeout 300000
```

**预期结果**：触发原因、异常时间线、影响范围、根因证据或候选方向及下一步建议。历史 RCA 和值守记录只能提供线索，不能替代本次证据。分析请求不包含确认、静默或修改报警的授权。

**权限与支持限制**：需能读取目标报警及相关指标、日志、Trace。无法获得某类证据时说明缺口，不把触发条件、历史 RCA 或最后一个报错节点当成已证实根因；分析请求不包含 ACK、静默、改规则等操作。

### 已有报警规则诊断与优化

**适用任务**：诊断已有规则的误报、漏报、报警风暴或阈值/消抖合理性，形成待采纳的优化建议。

**必要上下文**：单条 rule_uid、2–8 条 rule_uid，或精确 PSM / open_chat_id；目标控制面必须明确。

单条规则：

```bash
argos run new -e cn --space argos --project argos '优化报警规则 <rule_uid>' --timeout 600000
```

批量规则：

```bash
argos run new -e cn --space argos --project argos '批量优化报警规则 <rule_uid_1> <rule_uid_2>' --timeout 600000
```

PSM 汇总诊断：

```bash
argos run new -e cn --space argos --project argos '汇总诊断 my.service.api 的报警规则' --timeout 600000
```

**预期结果**：单条和批量模式返回待采纳方案及预览链接；PSM/群模式返回汇总诊断。提交方案不等于修改生产规则，需要用户在预览页手动采纳后生效。

**权限与支持限制**：

- 使用与目标规则一致的 `-e <env>` 和官方 `argos` Project，确认该入口已提供 `alarm-rule-optimizing`；缺失时说明限制，不静默回落到 CN。
- 遵守规则读取与方案提交权限。原样返回预览链接；生成和提交方案不代表已采纳，只有确认采纳并生效后才报告生产规则已修改。
- PSM/群模式只做汇总诊断，不逐条提交方案。用户选定具体规则后再进入单条或批量模式。
- 明确目标值的规则修改和新建规则属于其他流程，不能借优化请求自动执行。

### 分析错误日志原因

**适用任务**：已知 LogID 或日志检索范围，需要解释错误、识别最早异常并判断上下游关系。

**必要上下文**：按 LogID 分析给真实 LogID；按关键词分析给精确 PSM 与真实关键词。已知 region、时间范围或过滤条件时一并提供；示例显式指定这些信息以固定调查范围。PSM 可作为调查重点，不应据此遗漏调用链中的其他服务。

按 LogID 分析：

```bash
argos run '分析 LogID 20261010090000000000000000000000 在 China-North 的全链路日志，定位最早异常，说明上下游关系和可能原因，列出证据与尚不能确认的结论' --output-format text --timeout 300000
```

按关键词和时间范围分析：

```bash
argos run '分析 my.service.api 在 China-North 于 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z 的日志，用户提供的关键词是 connection refused。查找代表性请求并追踪错误来源，说明影响范围与证据' --output-format text --timeout 300000
```

**预期结果**：查询范围、代表性 LogID、异常传播路径、证据支持的原因及仍缺少的信息。检索无数据或权限不足时应说明限制。

**权限与支持限制**：日志仍受 Argos/StreamLog 的数据权限约束，Agent 不增加访问权限。保留用户给出的真实关键词；对采样、分页、截断和缺少权限的服务说明实际覆盖范围。未提供时间或区域时报告实际采用的查询范围；有限日志中的最早异常不等于已确认根因。

### 结合运行证据与源码解释问题

**适用任务**：用户明确要求结合源码，或日志、报警调查、Trace 已提供堆栈、文件、函数等线索，需要验证服务处理逻辑。没有代码线索且任务不需要代码验证时，不强制读取仓库。

**必要上下文**：能定位问题的日志/LogID、报警或 Trace 对象，对应 region 和时间范围；已知服务、仓库、部署 revision 与代码线索一并提供。不要求用户提前查齐仓库和版本，先从运行证据核实，无法确认时不猜测。

**调查步骤**：

1. 从运行证据核实关联服务、仓库和问题发生时的部署 revision，不能把当前主分支直接当作当时的部署代码。
2. 确认当前执行端可用的代码工作区与读取权限。宿主当前目录不会自动成为服务端 `argos run` 的工作区；预绑定 Project 代码资源可提供固定版本或多仓上下文，但不是发现仓库的前提。
3. 只读取与已定位线索有关的代码，解释运行证据与具体逻辑的对应关系。工作区不可用、没有权限或版本无法确认时保留观测结论，标明尚未完成的源码验证。

```bash
argos run '结合源码分析 LogID 20261010090000000000000000000000 在 China-North 的错误。先收集运行证据，核实关联服务、仓库及问题发生时的部署版本，确认当前执行端可读取相应代码后再解释处理逻辑；不能读取或不能确认版本时保留已有证据并说明限制。只分析并给出建议' --output-format text --timeout 300000
```

**预期结果**：运行证据、部署版本与代码位置之间的对应关系，以及支持的原因、建议和未验证项。普通 timeout/5xx、单个慢 span 或报警触发本身不足以认定代码缺陷。

**权限与支持限制**：观测数据和代码分别遵守各自读取权限。分析和修复建议不授权改代码、push 或创建 MR；任何写操作需要另行明确目标、授权与验证。

### APM 链路错误与耗时分析

**适用任务**：已知 TraceID，需要定位失败或耗时来源，区分上游表现与实际异常节点，并视证据关联日志。

**必要上下文**：对应 APM 来源的 TraceID、region；旧链路提供时间范围，已知现象可作为调查重点。

APM 慢请求：

```bash
argos run '分析 APM Trace 5a25e2f7-3063-326c-b0da-6584cc4b7c6e，region 为 China-North，时间为 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z。定位关键耗时路径和慢节点，必要时关联日志，说明证据和未确认项' --output-format text --timeout 300000
```

**预期结果**：关键 span、错误或耗时路径、关联证据、原因及局限。单个慢 span 或失败 span 不足以自动判定整个请求的根因。

**权限与支持限制**：需要 Trace 读取权限；采样、保留时间或 span 缺失会限制分析，报告实际覆盖的链路与时间窗。单条 Trace 不代表整体服务健康；慢 span、错误传播节点和根因分别判断。关联日志时使用返回的 LogID，不把 TraceID 传给日志专用 Tool。

### GenAI 链路错误与耗时分析

**适用任务**：已知 AI TraceID，需要定位模型或 Tool 调用的失败与耗时来源，判断异常传播路径。

**必要上下文**：对应 GenAI 来源的 TraceID、region；旧链路提供时间范围，已知现象可作为调查重点。

GenAI 链路失败：

```bash
argos run '分析 AI Trace 5a25e2f7-3063-326c-b0da-6584cc4b7c6e，region 为 China-North，时间为 2026-10-10T01:00:00Z 至 2026-10-10T02:00:00Z。检查模型和 Tool 调用的失败来源，解释异常传播过程，列出关键 span 与证据' --output-format text --timeout 300000
```

**预期结果**：关键模型/Tool span、失败或耗时路径、关联证据、原因及局限。单个慢 span 或失败 span 不足以自动判定整个请求的根因。

**权限与支持限制**：需要 Trace 读取权限；采样、保留时间或 span 缺失会限制分析，报告实际覆盖的链路与时间窗。单条 Trace 不代表整体服务健康；慢 span、错误传播节点和根因分别判断。关联日志时使用返回的 LogID，不把 TraceID 传给日志专用 Tool。

### GenAI 多轮会话归因

**适用任务**：问题跨多个 Agent/模型/Tool 轮次，需要解释一次 GenAI 会话从哪轮开始偏离目标。

**必要上下文**：PSM、GenAI session_id、region，以及用户观察到的问题；如已知时间范围一并提供。不要把 GenAI session_id 与 `argos run resume` 使用的 CLI session 混用。

```bash
argos run '分析 my.service.api 在 China-North 的 GenAI 会话 session_id=<genai_session_id>。按轮次核对模型和 Tool 证据，定位最早偏离用户目标的位置，解释后续影响并给出改进建议' --output-format text --timeout 300000
```

**预期结果**：会话轮次时间线、关键模型/Tool 行为、最早偏离点及证据支持的归因；无法访问的轮次明确列出。

**权限与支持限制**：需要目标 PSM 的 GenAI 会话与轮次证据读取权限，以及当前环境可用的会话分析能力。仅根据实际读取到的模型/Tool 行为归因；缺失轮次和截断内容明确标出，不推测不可见的模型内部过程。

## 结果判断与续接

- 先确认最终状态是完成、失败还是需要输入/授权；退出码 `0`、`1`、`2` 分别对应成功、失败、需要人工动作。
- 成功回答也要核对实际查询范围、证据来源与未覆盖项；部分日志、span、面板或指标不能冒充完整调查。
- 普通补充问题使用输出中的 session ID 继续：`argos run resume <session_id> '<后续问题>'`。不要把 GenAI session_id、TraceID 或 LogID 当作 CLI session ID。
- 需要授权或交互式审批时，在支持该动作的客户端完成；普通续问不能代替授权。
- 仅在任务需要 profile、事件流、输出格式或本地能力时读取下方执行参考，不把低频参数作为每次调查的前置步骤。

## 按需执行参考

### `run` 子命令参数

| 参数 | 描述 | 默认值 |
|------|------|--------|
| `-e, --env <env>` | 环境（cn / i18n / i18n-bd / eu-ttp / us-ttp / boe / sandbox / dev） | `cn` |
| `-a, --agent <name>` | Agent 名称 | `Common` |
| `-m, --model <model>` | 模型覆盖 | - |
| `--space <space>` | 绑定的 Project workspace / namespace；仅在需要指定 Project 资源时使用 | - |
| `--project <name>` | 绑定的 Project 名称；需与 `--space` 及目标控制面一致 | - |
| `-y, --yes` | interactive profile 下自动确认本地工具执行 | `false` |
| `-o, --output-format <format>` | 输出格式（text / json / stream-json） | `text` |
| `--max-turns <n>` | 最大 Agent 轮次 | - |
| `--timeout <ms>` | 超时时间（毫秒） | - |
| `--session <id>` | 恢复已有 session | - |
| `--show-session` | 执行后额外打印 CLI 实际使用的本地 session 路径（默认 `~/.sre-agent/sessions/<id>`，受 `ARGOS_HOME`/临时目录回退影响） | `false` |
| `--verbose` | 在过程流上叠加有界（截断 + 脱敏）的工具参数与结果详情，便于诊断 | `false` |
| `--quiet` | 抑制 stderr 过程输出；若同时显式传 `--show-session`，仍打印 session 路径 | `false` |
| `--execution-profile <profile>` | `server` / `interactive` / `auto` | `server` |

`server` profile 调用 `POST /api/v1/cli/agent/call`，由服务端完成 Agent 与
工具执行。它是 Windows 和无本地 runtime 环境的推荐模式，但不支持逐事件流、
本地文件、local MCP、交互式工具审批或 Bridge。

### `run` 输出与退出码

- `text`（默认）：stdout 仅含最终回答；stderr 默认展示执行过程流——session 生命周期、简短的动作说明、工具名及有界参数摘要（`→ tool({...})`），以及重连、HTTP 降级、警告、工具失败、需要人工动作（授权/追问）、终态错误等异常提示；成功后还会打印可执行的 `run resume` 提示。Agent 未在工具前输出可见说明时，CLI 会按工具类型补一条简短说明；说明和参数均单行、截断并脱敏，不打印工具结果或成功完成行；`--verbose` 再叠加更完整但仍有界的工具参数与结果详情；`--quiet` 抑制 stderr 过程输出，但显式 `--show-session` 的路径仍会打印。内部 `fs.*`（CLIFS 文件操作）和 `finish` 控制调用是实现细节，不出现在过程流与 `toolCalls` 里。
- `json`：stdout 仅含一个最终 JSON 对象。
- `stream-json`：stdout 为 JSONL，每行包含 `type`、ISO 8601 `timestamp`、`data`，并且每次运行仅有一个终态事件：`result`、`needs_input` 或 `error`。
- 过程事件：`session_started`、`connection_status`、`agent_status`、`tool_started`、`tool_finished`、`warning`、`http_fallback`。仅工具事件使用 `name`（不是 `tool`）并通过 `call_id` 关联；其他事件按类型使用 `session_id`、`status`、`stage`、`code` 等字段。默认 text 过程流展示用户可见的简短 `thought` 摘要和工具开始行，省略成功的工具完成行，工具失败仍会提示；不展示模型内部 thinking、完整参数或工具结果，`--verbose` 才叠加经过截断和脱敏的有界摘要。内部 `fs.*` 与 `finish` 控制调用不会产生 `tool_started`/`tool_finished` 事件。
- 退出码：成功 `0`，失败 `1`，需要输入/授权 `2`。普通问题可按输出的 `run resume` 示例续跑；权限请求需在支持审批的客户端处理，不能假设普通 prompt 可以恢复审批。
- `http_fallback` 表示已切换到 HTTP Message 轮询路径；`live_progress_available=true`、
  `progress_transport=polling`，后续仍会收到已持久化的思考摘要和工具进度，但不是逐 token 实时流。

---
