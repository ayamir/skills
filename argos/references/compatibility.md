# 兼容 Tool 与旧请求形状

能力卡片只推荐一个默认 Tool。以下旧 Tool 仍可调用，主要用于继续执行已有脚本或在已知请求形状无法迁移时使用。新关键词检索请使用[日志能力](./log.md)中的 `log.search.keywords_stream`。

## 旧关键词查询

`log.key_word_v2` 使用 `keyword_filter_include`，适合现有脚本尚未迁移的输入；它不提供与 `search.keywords_stream` 相同的显式 cursor 流程。

```bash
argos tool log key_word_v2 '{"psm_list":["my.service.api"],"region":"China-North","keyword_filter_include":{"words":["error"],"operator":"AND","case_sensitive":true},"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z","limit":200}' --json
```

`log.search.keywords` 使用单个 `psm`，没有结构化 `kv_filters` 或显式 cursor。仅在继续旧请求时使用。

```bash
argos tool log search.keywords '{"psm":"my.service.api","region":"China-North","keywords":["error"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' --json
```

| 语义 | 当前首选 | 旧高级 | 旧简化 |
| --- | --- | --- | --- |
| 命令 | `log.search.keywords_stream` | `log.key_word_v2` | `log.search.keywords` |
| PSM | `psm_list` 数组 | `psm_list` 数组 | `psm` 字符串 |
| 包含词 | `keywords` | `keyword_filter_include.words` | `keywords` |
| 结构化过滤 | `kv_filters` | `kv_filters` | 无 |
| 分页 | 返回 cursor | 内部拉取 | 无显式 cursor |

Tool 名称与 schema 以当前控制面的 `argos tool list` 和目标 Tool 的 `-h` 为最终依据。不要为了绕过权限或将失败伪装为成功而切换旧 Tool。
