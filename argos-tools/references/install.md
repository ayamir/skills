# 安装与管理 Argos 用户 skill

安装分两步：先安装带有 skill 资源的 CLI，再将所选 skill 安装到调用方 Agent 的技能目录。认证用于访问 Argos 数据，不是安装本地 skill 的前提。

## Table of Contents

- [1. 安装 CLI](#1-安装-cli)
- [2. 选择并安装 skill](#2-选择并安装-skill)
- [3. 安装目录与加载](#3-安装目录与加载)
- [4. 升级与同步](#4-升级与同步)
- [5. 卸载与故障处理](#5-卸载与故障处理)

## 1. 安装 CLI

推荐 npm，适用于 Linux、macOS 和 Windows：

```bash
npm install -g @byted/argos@latest --registry https://bnpm.byted.org
argos --version
```

Linux/macOS 也可使用官方安装脚本：

```bash
sh -c "$(curl -L https://argos.byted.org/cli/install.sh)" && export PATH=~/.local/bin:$PATH
argos --version
```

npm 包带有 `skills/`；脚本安装会下载同版本 `skills.tar.gz` 到 `~/.local/share/argos/skills/`。这些是安装源，尚未代表 Agent 已加载 skill。只有单个二进制、没有配套资源时，`argos skill install` 无法凭空恢复手册。

## 2. 选择并安装 skill

默认综合入口：

```bash
argos skill install argos
argos skill list
```

只需要 `argos tool` 的调用方可独立安装：

```bash
argos skill install argos-tools
argos skill list
```

兼容需要时安装两份：

```bash
argos skill install --all
```

`argos` 包含完整 Tool 手册和独立的 Argos Agent 能力页，不依赖 `argos-tools`。两份都安装时，以 `argos` 为默认入口；`argos-tools` 提供 tool-only 子集。

## 3. 安装目录与加载

当前按名称安装内置 skill 的范围是全局，命令不需要 `-g`。安装会写入 `~/.agents/skills/<name>/`；如果对应配置目录存在，也会复制到以下位置：

| 调用方 | 全局目录 |
| --- | --- |
| 支持通用技能目录的 Agent | `~/.agents/skills/<name>/` |
| Claude Code | `~/.claude/skills/<name>/` |
| Trae | `~/.trae/skills/<name>/` |
| Trae CN | `~/.trae-cn/skills/<name>/` |

当前内置 skill 安装没有指定 Agent 的 `-a/--agent` 选项。`ARGOS_HOME` 改变配置与 lock 的位置，不改变上述 Agent 的全局技能目录。

`argos skill list` 根据 lock 展示安装状态及版本，不是 Agent 已加载的证明，也不逐一校验目标目录。安装后按调用方的刷新方式加载；若已有会话仍未发现 skill，重新开启会话并确认其技能列表。

`argos skill install <local_dir> --project` 是旧的本地目录导入模式，导入到 Argos 当前 Project 的 skills 路径；它不等于将内置 `argos` 安装到当前仓库的 `.agents/skills/`。不要将它当作调用方 Agent 的项目级内置 skill 安装。

## 4. 升级与同步

npm 安装的 CLI 使用 npm 升级，再同步所需 skill：

```bash
npm install -g @byted/argos@latest --registry https://bnpm.byted.org
argos skill install argos
argos skill list
```

tool-only 用户将上面的安装命令替换为 `argos skill install argos-tools`。显式按名称安装会重新复制当前包中的完整内容，适合恢复缺失文件或同版本文档变化。

脚本安装的 CLI：

```bash
argos update
argos skill list
```

当前 `argos update` 的 CLI 更新流程会尝试执行新 CLI 的 `skill update`。也可以手动触发：

```bash
argos skill update
argos skill list
```

**当前更新语义**：`argos skill update` 遍历全部内置 skill，会补装未安装项；同 CLI 版本且已有 lock 时会跳过，不核对内容 hash 或目标目录是否缺失。因此仅安装一份、移除另一份后执行更新，可能重新安装两份。按需安装、修复单份内容时使用按名称的 `install`。

## 5. 卸载与故障处理

使用管理命令，同时清理记录与当前可检测的目标目录：

```bash
argos skill remove argos-tools
argos skill list
```

不要只手工删除 Agent 目录，否则 lock 仍可能显示已安装。当前更新会补装全部内置项，卸载不是永久禁用记录。

| 现象 | 处理方式 |
| --- | --- |
| CLI 可运行，但提示 bundled skills not found | 用 npm 重装完整包；脚本用户运行 `argos update` 恢复配套资源后再按名称安装 |
| 显示同版本，但手册或 Agent 副本缺失 | `argos skill install argos` 或 `argos skill install argos-tools`，再确认目录与调用方加载状态 |
| 新安装调用方 Agent 后未出现 skill | 确认其配置目录已存在，再按名称重新安装；支持通用目录的调用方检查 `.agents/skills/` |
| 卸载后更新又出现另一份 skill | 当前更新会补装全部项；按上述更新语义检查，不把它解释为卸载失败 |

访问数据前再按 [认证与通用规则](./common.md) 登录。安装命令本身无需查询控制面或调用线上 Tool。
