---
name: argos
description: "Queries and analyzes monitoring and runtime data through Argos, including service health, metrics, logs, alarms, APM and GenAI traces, and saved self-evolution Case diagnoses by Task, Run or assignee; retrieves evidence, investigates root causes, and writes authorized Case repair-closeout reviews."
skill_id: apm.argos.ai_agent_center/argos
version: 1.0.43
---

# Argos

这是 Argos 的默认入口。单独安装本 skill 也能使用 `argos run` 和当前控制面开放的全部 `argos tool`；`argos-tools` 只是可选的 Tool 专用子集。

## 安装 Argos CLI

推荐全局安装一次，后续直接调用 `argos`：

```bash
npm install -g @byted/argos@latest --registry https://bnpm.byted.org
argos --version
```

Linux/macOS 也可使用官方安装脚本：

```bash
sh -c "$(curl -L https://argos.byted.org/cli/install.sh)" && export PATH=~/.local/bin:$PATH
```

## 基本使用

1. 访问数据前检查登录状态，未登录时执行 `argos auth login`。
2. `-e` 选择控制面，默认 `cn`；Tool 的 `region`/`vregion` 选择数据区域，两者按[region 映射](./references/regions.md)匹配。
3. 先判断执行计划能否预先确定：Skill 已覆盖且能由输入确定 Tool 和查询口径的日志、Metrics 等取数直接使用 `argos tool`；需要选择能力、指标口径或根据结果下钻时使用 `argos run`。
4. 直接调用 Tool 时，关键字日志默认用 CLI 的 `--paginate --json` 自动分页；其他查询加 `--json` 获取机器可读结果。大结果写入文件时先读取文件再总结，说明查询范围与部分失败。

旧 CLI 不支持 `--paginate` 时先升级；兼容脚本用法见[日志能力](./references/log.md)。

```bash
argos auth status
# 仅未登录时执行对应控制面的登录
# argos auth login -e cn

# 仅需学习 CLI 或发现未覆盖 Tool 时运行
# argos --help
# argos tool list -e cn

# 高频且执行计划确定的日志查询直接使用 Tool
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T00:00:00Z","end":"2026-06-30T01:00:00Z"}' --paginate --json

# 底层指标和接口维度尚未确定时交给 Argos Agent 选择口径
argos run '查询 my.service.api 在 China-North 最近一小时指定 HTTP 接口的 P90 耗时，只报告查询口径、结果和数据限制' --output-format text --timeout 300000
```

## 按用户目标选择能力

- 获取自进化 Case 的交接：使用 `argos evolution_diagnosis search` 定位，再用 `handoff` 返回可直接交给 Codex 的 Markdown；不要用诊断 JSON 代替 Handoff。按[诊断 Case](./references/diagnosis-cases.md)执行，不启动新的 Agent 或评测。
- 浏览分给自己的 Case 或根因：使用 `argos evolution_diagnosis list --assignee me`，可加 `--run-id`；此时可展示列表摘要，不必逐条拉取 Handoff。
- 按标签或 Run 创建时间查历史评测批次：使用 `argos evolution_diagnosis runs --tag <标签> --start-time <Unix秒> --end-time <Unix秒>`，不启动新评测。创建打标与授权编辑见[诊断 Case](./references/diagnosis-cases.md)。
- 修复 Case 后，若用户已授权回填，按同一参考中的 `feedback --yes` 保存原诊断的 Codex 复核并回读；不覆盖人工评价，不把修复成功等同于诊断准确。
- 用户请求与现有能力卡片匹配，且能从输入确定稳定的 Tool/action、查询口径和执行步骤时，直接使用 `argos tool`。关键字日志、LogID、已知 Measurement/Metrics 的时序取数等高频查询应保留这条低成本路径；固定且完全确定的多步查询也可以使用 Tool。
- 缺少普通查询参数时，先从上下文补齐或询问，不要仅因用户用自然语言表达就改走 `run`。当真正缺少的是“该选什么能力或口径”，需要发现 Measurement、指标、Tag、接口维度、报警类型，或需要根据中间结果继续下钻时，才使用 `argos run`。
- 无法从当前 Skill 确定稳定执行计划时，使用 `argos run`；不要先枚举 Tool 再猜测指标或参数。接口分位耗时、服务观测报告、报警分析和规则诊断只是这一通用原则的示例，不是 Agent 能力全集。
- 已选择的 `argos tool` 因能力未覆盖、当前控制面未暴露或权限不足而无法完成目标时，先说明具体限制，再使用 `argos run` 让 Argos Agent 尝试完成同一用户目标。这是能力回退，不得将 `run` 用于绕过权限；Agent 仍无法完成时明确报告失败和未覆盖边界。
- 路由到 `run` 不改变用户要求的范围：只要求取数时不要擅自扩展成根因分析；分析请求也不自动授权 ACK、静默、修改规则或其他写操作。
- 用户明确指定命令族时遵循其选择；若用户限定仅使用 `tool` 或仅使用 `run`，能力或权限不支持时说明限制，不静默切换命令族。

| 能力入口 | 何时使用 | 参考 |
| --- | --- | --- |
| 自进化诊断 Case | 按 Task、诊断 Run、责任人查已有诊断，再读取选中 Case 的证据 | [诊断 Case](./references/diagnosis-cases.md) |
| Argos Agent | 执行计划不能预先确定的能力或口径发现、调查分析和报告；场景示例不是能力全集 | [Argos Agent](./references/argos-agent.md) |
| 日志 Tool | 已确定查询条件的关键词、LogID、错误聚合或 Pod 日志取数 | [日志](./references/log.md) |
| 监控 Tool | 已确定 Measurement、Metrics 或大盘对象及查询口径后的取数；名称/参数纠偏与查询 URL 解析用 `timeseries.inspect`；服务黄金指标、方法与上下游依赖（参数明确）用 `argos tool service inspect` | [监控](./references/monitoring.md) |
| APM Trace Tool | 已确定 Trace 查询参数的请求级链路、按 PSM/时间窗/Tag 浏览 span、错误/慢 span 与诊断概览 | [APM Trace](./references/apm-trace.md) |
| GenAI Trace Tool | 已确定 Trace 查询参数的模型/Tool 链路、按条件浏览 GenAI span、业务会话 list→index→detail 与诊断概览 | [GenAI Trace](./references/genai-trace.md) |

有 LogID、TraceID、PSM 或报警标识不代表执行计划已经固定，仍按是否需要 Agent 选择能力、口径或后续步骤判断。不要把 TraceID 传给只接受 LogID 的 Tool。只读取当前任务需要的参考；这些查询卡片不是 Tool 全集。仅在直接 Tool 路径中遇到未覆盖能力、示例不适用或参数校验失败时，再用 `argos tool list` 和目标 Tool 的 `-h` 发现当前入口与 schema。

`-e` 选择 Argos 控制面（默认 `cn`）；Tool 参数中的 `region` 或 `vregion` 选择数据区域，两者不能混用。`--json` 用于机器读取。执行写操作前核对目标、影响和 Tool 权限，完成后回读确认；权限错误或部分响应不能当作数据为空或操作成功。

## 通用参考

- CLI 升级、skill 安装/更新/卸载与 Agent 目录见[安装与管理](./references/install.md)。
- 认证、PowerShell JSON、控制面及执行约束见[通用说明](./references/common.md)。
- 旧 Tool 与历史请求格式见[兼容说明](./references/compatibility.md)；能力卡片只推荐一个首选 Tool。
