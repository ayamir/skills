# Argos CLI setup and execution rules

This reference applies to both `argos` and `argos-tools`. Use the complete commands in the capability guides first. Check a live Tool schema with `argos tool <category> <subcommand> -h` if an example fails validation or a newly discovered Tool is not documented.

## Install and authenticate

CLI 安装、两份 skill 的选择、Agent 目录、升级、卸载和故障处理见 [安装与管理](./install.md)。安装本地 skill 不需要登录；访问 Argos 数据前检查认证：

```bash
argos auth status
argos auth login -e cn
```

`argos auth login` prints a URL and QR code for device-code login. `argos auth status --json` checks a supplied JWT with the destination service, not only the token's expiration claim.

Headless processes can set `ARGOS_JWT_TOKEN` and, for service-account access, select a project with `--project <name>`. Keep tokens out of logs and responses. The CLI can also reuse `BYTEDCLI_USER_CLOUD_JWT`; its existing auth chain handles other ByteCloud JWT variables and SDK credentials.

## Control plane, data region, and output

The default control plane is `cn`. `-e <env>` chooses the Agent Center control plane; a Tool's `region` or `vregion` chooses its data scope. Match the two using [region mapping](./regions.md). Do not assume a successful empty result means the data is absent until the scope and permissions are checked.

```bash
argos config show
argos config set env i18n-bd
argos tool list -e cn
argos tool metrics data -h -e cn
```

Use `--json` for machine-readable results. `tool --timeout` accepts seconds; `run --timeout` accepts milliseconds. Large Tool results may be written to `~/.sre-agent/tool-logs/` and stdout may show only the path; read the saved result before summarizing. Report partial failures and unsupported query types rather than inventing values.

## PowerShell JSON calls

PowerShell may reinterpret quotes in a native command's positional JSON argument. Build JSON and escape its double quotes before passing it to `argos`:

```powershell
$obj = @{ psm_list = @('my.service.api'); region = 'China-North'; keywords = @('error'); start = '2026-06-30T00:00:00Z'; end = '2026-06-30T01:00:00Z' }
$json = $obj | ConvertTo-Json -Compress -Depth 10
$arg = $json -replace '"', '\"'
& argos tool log search.keywords_stream $arg -e cn --json
```

For the high-frequency data Tools below, the CLI's shared Tool Client normalizes supported time inputs before live-schema validation:

- `log.search.keywords_stream` / `log.search_keywords_stream`: `start` / `end`.
- `metrics.data`, `measurement.data`, and `bosun.data`: `start_time` / `end_time`.

Those fields accept RFC3339 with a timezone, Unix seconds (up to 10 digits), Unix milliseconds (exactly 13 digits), or an Argos-FE-compatible relative expression beginning with `now`: `now`, `now-30m`, `now+1h`, `now/d`, or `now-1d/d`. Units are `s`, `m`, `h`, `d`, `w`, `M`, and `y`; the grammar is strict, so values such as `yesterday` or `now - 1h` are rejected. A start field rounded with `/unit` uses the beginning of the unit, while an end field uses the end. Both endpoints share one clock anchor; CLI rounding uses UTC, while SDK callers can supply an IANA timezone. The adapter emits canonical UTC RFC3339 and rejects ambiguous 11/12-digit timestamps, backwards ranges, invalid calendar values, leap seconds, and sub-millisecond precision that would be lost.

This compatibility is explicitly mapped by Tool and field; it does not rewrite similarly named fields on other Tools. For an unmapped Tool, follow its live schema exactly: for example, `log.error_log` still requires integer Unix seconds in `start` / `end`. A PowerShell `.ToString('o')` value commonly has seven fractional digits, so use one of the supported forms above for mapped fields and avoid passing it unchanged to a schema with narrower precision.

## Safe execution and evidence

- Run dependent calls in evidence order. Use bounded time windows and result limits; widen the search only when the prior result justifies it. Cursor pagination retains the same query parameters.
- On a validation error, correct the field from the Tool's live `-h` schema. Do not repeat the same failed request. On a permission error, explain the permission path rather than treating it as empty data.
- For a write Tool, check its target and intended effect against the user's request, follow the Tool's permissions and approval result, then query the object again to verify the outcome. Prepare a concrete reviewable action before asking for approval when the target or irreversible effect is unclear.
- Do not continue a failed workflow by claiming an action succeeded. Separate observed data, inferences, and missing evidence.
