# Region and control-plane mapping

`-e/--env` selects the Argos CLI control plane; a Tool's `region` or `vregion` selects a data area. They must match. The CLI currently supports `cn`, `boe`, `i18n`, `i18n-bd`, `eu-ttp`, `us-ttp`, `sandbox`, and `dev`; available data areas vary by control plane. Prefer the environment explicitly supplied by the user or the returned Argos URL/object, then use the mapping below. Do not substitute a region for `-e`.

## Table of Contents

- 控制面：[cn](#cn-国内站) · [boe](#boe-测试环境) · [i18n](#i18n-海外站) · [i18n-bd](#i18n-bd-海外-bd-站--lark) · [eu-ttp](#eu-ttp-欧洲-ttp-合规) · [us-ttp](#us-ttp-美国-ttp)
- [日志查询的区域选择与组合](#日志查询的区域选择与组合)

| Control plane | CLI flag | Typical scope |
| --- | --- | --- |
| CN | `-e cn` (default) | China-North, China-East |
| BOE | `-e boe` | Test regions |
| International | `-e i18n` | Singapore-Central, US-East |
| International BD | `-e i18n-bd` | BD/Lark and configured international data areas |
| EU-TTP | `-e eu-ttp` | EU-TTP data areas |
| US-TTP | `-e us-ttp` | US-TTP and US-TTP2 |

The table below is a routing aid, not a substitute for live object metadata. If a region is missing or access fails, inspect the current Tool response before trying another control plane.

---

## cn (国内站)

| Region | Alias | MS Zone |
|--------|-------|---------|
| China-North | cn | CN |
| China-East | China-East | China-East |
| China-Aggregation | cn_ag | CN_AG |
| China-Pay | China-Pay | China-Pay |
| China-Pay2 | China-Pay2 | China-Pay2 |
| China-HKPay | China-HKPay | China-HKPay |
| China-Fintech | China-Fintech | China-Fintech |
| China-Enterprise | China-Enterprise | CN_TOB |
| China-North3 | China-North3 | China-North3 |
| China-North5 | China-North5 | China-North5 |
| China-North6 | China-North6 | China-North6 |
| ChinaSinf-East | ChinaSinf-East | ChinaSinf-East |
| ChinaSinf-North | ChinaSinf-North | ChinaSinf-North |
| Aliyun_NC2 | Aliyun_NC2 | Aliyun_NC2 |
| China-PPE | ppe | China-PPE |
| China-East-PPE | China-East-PPE | China-East-PPE |
| China-Pay2-PPE | China-Pay2-PPE | China-Pay2-PPE |
| ChinaSinf-North-PPE | ChinaSinf-North-PPE | ChinaSinf-North |

## boe (测试环境)

| Region | Alias | MS Zone |
|--------|-------|---------|
| China-BOE | boe | BOE |
| China-BOE2 | China-BOE2 | China-BOE2 |
| US-BOE | boei18n | BOEi18n |
| ChinaSinf-BOE | ChinaSinf-BOE | ChinaSinf-BOE |

## i18n (海外站)

| Region | Alias | MS Zone |
|--------|-------|---------|
| Singapore-Central | sg | SGALI |
| US-East | US-East | MVAALI |
| US-West | US-West | US-West |
| US-SouthWest | US-SouthWest | US-SouthWest |
| Europe-Central | Europe-Central | Europe-Central |
| EasternEuro-TT | EasternEuro-TT | EasternEuro-TT |
| Asia-SouthEast | Asia-SouthEast | Asia-SouthEast |
| Australia-SouthEast | Australia-SouthEast | Australia-SouthEast |
| ID-Compliance | ID-Compliance | ID-Compliance |
| ID-Compliance2 | ID-Compliance2 | ID-Compliance2 |
| MY-Compliance | MY-Compliance | MY-Compliance |
| Singapore-Compliance | compliance-sg | SGCOMPLIANCE |
| I18N-BGE | I18N-BGE | I18N-BGE |
| Singapore-PPE | ppe-sig | SG |
| US-PPE | ppe-va | US-PPE |
| US-East-PPE | US-East-PPE | US-East-PPE |
| ID-Compliance-PPE | ID-Compliance-PPE | ID-Compliance-PPE |
| ID-Compliance2-PPE | ID-Compliance2-PPE | ID-Compliance2-PPE |
| MY-Compliance-PPE | MY-Compliance-PPE | MY-Compliance-PPE |
| MY-PPE | MY-PPE | MY-PPE |
| MY2-PPE | MY2-PPE | MY2-PPE |
| MY3-PPE | MY3-PPE | MY3-PPE |

## i18n-bd (海外 BD 站 / Lark)

| Region | Alias | MS Zone |
|--------|-------|---------|
| Singapore-Common | Singapore-Common | SGCOMM1 |
| Singapore-SaaS | Singapore-SaaS | SGSAAS1LARKIDC |
| US-EE | va | VA |
| US-Central | US-Central | US-Central |
| US-WestBD | US-WestBD | US-WestBD |
| US-EastBD | US-EastBD | US-EastBD |
| US-TTP3 | US-TTP3 | US-TTP3 |
| US-TTP4 | US-TTP4 | US-TTP4 |
| US-Compliance | US-Compliance | US-Compliance |
| Europe-WestBD | Europe-WestBD | Europe-WestBD |
| Asia-South | Asia-South | Asia-South |
| Asia-SaaS | Asia-SaaS | Asia-SaaS |
| Asia-NorthEast | Asia-NorthEast | Asia-NorthEast |
| Asia-EastBD | Asia-EastBD | Asia-EastBD |
| Asia-Enterprise | Asia-Enterprise | Asia-Enterprise |
| Asia-CIS | Asia-CIS | Asia-CIS |
| Australia-SouthEastBD | Australia-SouthEastBD | Australia-SouthEastBD |
| Asia-SouthEastBD | Asia-SouthEastBD | Asia-SouthEastBD |
| SouthAmerica-East | SouthAmerica-East | SouthAmerica-East |
| MiddleEast-South | MiddleEast-South | MiddleEast-South |
| Africa-South | Africa-South | Africa-South |
| ID-CentralBD | ID-CentralBD | ID-CentralBD |
| Singapore-SaaS-PPE | Singapore-SaaS-PPE | Singapore-SaaS-PPE |
| US-Compliance-PPE | US-Compliance-PPE | US-Compliance-PPE |
| US-TTP3-PPE | US-TTP3-PPE | US-TTP3-PPE |
| Asia-SouthEastBD-PPE | Asia-SouthEastBD-PPE | Asia-SouthEastBD-PPE |
| Asia-CIS-PPE | Asia-CIS-PPE | Asia-CIS-PPE |
| Asia-SaaS-PPE | Asia-SaaS-PPE | Asia-SaaS-PPE |

## eu-ttp (欧洲 TTP 合规)

| Region | Alias | MS Zone |
|--------|-------|---------|
| EU-Compliance | EU-Compliance | EU-Compliance |
| EU-Compliance2 | EU-Compliance2 | EU-Compliance2 |
| EU-TTP | EU-TTP | EU-TTP |
| EU-TTP2 | EU-TTP2 | EU-TTP2 |
| US-EastRed | useast-red | USEASTRED |
| EU-TTP-PPE | EU-TTP-PPE | EU-TTP-PPE |
| EU-TTP2-PPE | EU-TTP2-PPE | EU-TTP2-PPE |
| US-EastRed-PPE | US-EastRed-PPE | US-EastRed-PPE |

## us-ttp (美国 TTP)

| Region | Alias | MS Zone |
|--------|-------|---------|
| US-TTP | US-TTP | US-TTP |
| US-TTP2 | US-TTP2 | US-TTP2 |
| US-TTP-PPE | US-TTP-PPE | US-TTP-PPE |
| US-TTP2-PPE | US-TTP2-PPE | US-TTP2-PPE |

## 日志查询的区域选择与组合

只组合 StreamLog 同组 region，不确定时逐 region 查询。非 CN 控制面通过 CLI 的 `-e`/`--site` 指定；不要只设置数据 region 而沿用默认 CN 控制面。US-TTP 由 CLI 强制非索引查询，其他控制面默认按元数据选择索引；自动索引被拒绝时可降级，强制 `on` 不降级。

US-TTP 内同组区域示例：

```bash
argos tool log search.keywords_stream '{"psm_list":["my.service.api"],"region":"US-TTP|US-TTP2","keywords":["request-id"],"start":"2026-06-30T03:00:00Z","end":"2026-06-30T03:30:00Z"}' -e us-ttp --paginate --json
```

日志 PPE 查询使用对应的非 PPE region。只有用户原查询明确指定 IDC 时才加 `_idc`；否则由 StreamLog 根据 region 路由。
