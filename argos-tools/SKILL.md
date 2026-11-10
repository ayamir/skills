---
name: argos-tools
description: "Executes structured Argos Tool queries and operations on monitoring and runtime data, including logs, metrics, dashboards, and APM or GenAI traces; retrieves saved self-evolution Case diagnoses and writes authorized repair-closeout reviews through the CLI. Use when execution steps are determined or a specific Argos Tool is requested."
skill_id: apm.argos.ai_agent_center/argos-tools
version: 1.0.43
---

# Argos Tools

本 skill 用 `argos tool` 执行步骤已确定的 Argos 操作，单独安装也能发现并调用当前控制面的全部 Tool。它不包含 `argos run` 的开放式诊断流程；两份 skill 都安装时，以 `argos` 作为默认入口。

另外提供 `argos evolution_diagnosis` 的 Case 检索、Handoff 读取和授权后的修复收尾复核回填；这是 CLI 命令，不是 MCP Tool，也不是报警诊断 Agent。

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
3. 先按下方功能目录选择能力并使用完整示例；新 Tool、示例不适用或参数校验失败时，用 `-h` 查询实时 schema。
4. 关键字日志默认用 CLI 的 `--paginate --json` 自动分页；其他 Tool 查询加 `--json` 获取机器可读结果。大结果写入文件时先读取文件再总结，说明查询范围与部分失败。

旧 CLI 不支持 `--paginate` 时先升级；兼容脚本用法见[日志能力](./references/log.md)。

```bash
argos auth status
# 仅未登录时执行对应控制面的登录
# argos auth login -e cn

# 仅需学习 CLI 或发现未覆盖 Tool 时运行
# argos --help
# argos tool list -e cn

# 下面仅演示关键词查询；实际任务使用对应能力卡片
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"China-North","keywords":["error"],"start":"2026-06-30T00:00:00Z","end":"2026-06-30T01:00:00Z"}' --paginate --json
```

## 按用户目标选择能力

先按用户场景选择能力。每份参考文件包含能力卡片：唯一首选 Tool、多种完整命令、结果判断和易错处。这里的 Tool 手册与完整的 `argos` skill 使用同一文档源。

获取自进化交接时，用 `argos evolution_diagnosis search` 定位 Case，再用 `handoff` 返回纯 Markdown。只交付 Handoff，不用检索 JSON 或原始诊断替代。不要在 `argos tool list` 中寻找它，也不要启动新诊断。

仅浏览分给自己的 Case 和根因时，用 `argos evolution_diagnosis list --assignee me`，可叠加 `--run-id`。可展示列表摘要，选中 Case 后再取 Handoff。

按标签或 Run 创建时间查历史评测批次时，用 `argos evolution_diagnosis runs --tag <标签> --start-time <Unix秒> --end-time <Unix秒>`，不启动新评测。创建打标与授权编辑见[诊断 Case](./references/diagnosis-cases.md)；仍是 CLI 命令，不是 MCP Tool。

修复 Case 后，若用户已授权回填，按同一参考中的 `feedback --yes` 保存并回读 Codex 复核；它是写操作，不覆盖人工评价，不额外启动 Agent。

| 能力域 | 参考文件 |
| --- | --- |
| 自进化诊断 Case：检索、读取 Handoff、授权后回填修复收尾复核（CLI） | [诊断 Case](./references/diagnosis-cases.md) |
| 日志：关键字日志检索、LogID 查日志、错误聚合、Pod 文件 | [日志能力](./references/log.md) |
| 监控：Metrics、Measurement（测点）、大盘取数，名称/参数纠偏与 URL 解析（`timeseries.inspect`），以及 `argos tool service inspect` 服务确定性巡检 | [监控能力](./references/monitoring.md) |
| APM Trace：RPC/HTTP 链路、按 PSM/时间窗/Tag 浏览 span 与诊断概览 | [APM Trace 能力](./references/apm-trace.md) |
| GenAI Trace：模型/Tool 链路、GenAI span 列表、业务会话 list→index→detail 与诊断概览 | [GenAI Trace 能力](./references/genai-trace.md) |

这些是常用入口，并非 Tool 全集。遇到未写入手册的能力，先用 `argos tool list` 发现 Tool，再用 `argos tool <category> <subcommand> -h` 读取当前 schema。已有卡片的命令可以直接使用；只有示例不适用、参数校验失败或遇到新 Tool 时才把 `-h` 当作兜底。

`-e` 选择 Argos 控制面（默认 `cn`）；Tool 参数中的 `region` 或 `vregion` 选择数据区域，两者不能混用。`--json` 用于机器读取。执行写操作前核对目标、影响和 Tool 权限，完成后回读确认；权限错误或部分响应不能当作数据为空或操作成功。

## 通用参考

- CLI 升级、skill 安装/更新/卸载与 Agent 目录见[安装与管理](./references/install.md)。
- 认证、PowerShell JSON、控制面及执行约束见[通用说明](./references/common.md)。
- 旧 Tool 与历史请求格式见[兼容说明](./references/compatibility.md)；能力卡片只推荐一个首选 Tool。
