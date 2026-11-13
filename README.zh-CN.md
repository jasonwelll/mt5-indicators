# MT5 指标（Codex 移植）

一套独立移植到 MetaTrader 5 的图表指标。这不是券商、LuxAlgo 或 TradingView 的官方产品，也不构成交易建议。

## 包含的指标

| 指标 | 版本 | 说明 | 许可 |
| --- | --- | --- | --- |
| `SMC_Pro_Neon_MT5` | 1.12 | 聪明钱结构：BOS / CHoCH、订单块、EQH / EQL 等 | [CC BY-NC-SA 4.0](LICENSE-SMC.md) |
| `Visible_Range_Volume_Nodes_MT5` | 1.02 | 可视范围成交量节点：POC、价值区、HVN / LVN | [MPL 2.0](LICENSE-MPL-2.0.txt) |
| `SuperTrend_Kivanc_MT5` | 1.11 | Kivanc 超级趋势 | [MPL 2.0](LICENSE-MPL-2.0.txt) |
| `VWAP_Execution_MT5` | 1.01 | 会话 VWAP，可选偏离带 | MIT |
| `IB_RTH_MT5` | 1.02 | 开盘区间，默认按纽约常规交易时段 | MIT |
| `TPO_Session_MT5` | 1.06 | 会话 TPO 分布：字母、POC、价值区、单打印 | MIT |

SMC、成交量节点、SuperTrend、VWAP 和 IB 在图表右上角有一个 `Hide` / `Show` 按钮，可临时隐藏图形而不停止计算。按钮按加载顺序自动排开。参数在输入窗口的 `Chart visibility button (top right)` 分组里。`TPO_Session_MT5` 使用自己的 `Hide TPO` / `Show TPO` 控制，不参与这组统一按钮。更细的用法见 [TPO_Session.zh-CN.md](TPO_Session.zh-CN.md)。

本仓库不包含交易系统（EA）。

## 安装

1. 在 MT5 中选择「文件 → 打开数据文件夹」。
2. 进入 `MQL5/Indicators/`，新建 `Codex` 文件夹（如果还没有）。
3. 把本仓库里的 `.mq5`、配套 `.mqh`，以及可选的 `.ex5` 都放到这个文件夹。源码和头文件必须在同一目录。
4. 回到 MT5，在「导航器」的「指标」上右键刷新，把指标拖到图表即可。
5. 若要改源码，用 MetaEditor 打开对应 `.mq5` 后编译。不需要启用「算法交易」。

已经加载过旧版的图表，可按 `Ctrl+I`，选中指标后「编辑」，确认参数；如版本号未更新，先保存 `.set` 预设，再移除并重新添加一次。

## 许可与署名

这个仓库里的文件不是单一许可，请按文件遵守。

**`SMC_Pro_Neon_MT5` 及其核心头文件**是对 [LuxAlgo Smart Money Concepts（Jlubin782 于 2026 年 5 月更新的公开脚本）](https://www.tradingview.com/script/WVf1sjBU-LuxAlgo-Smart-Money-Concepts-Updated-by-J-Lubin-5-2026/) 的独立 MQL5 移植，沿用原脚本的 **CC BY-NC-SA 4.0**：必须保留署名、仅限非商业使用，修改后须以相同许可再分享。因此这一份 SMC **不能作为付费商品出售**。详见 [LICENSE-SMC.md](LICENSE-SMC.md)。这不是官方 LuxAlgo 或 Jlubin782 的 MT5 版本。

**`SuperTrend_Kivanc_MT5`** 基于 [KivancOzbilgic 的 Supertrend](https://www.tradingview.com/script/r6dAP7yi/)（并保留 everget / Alex Orekhov 的贡献说明），按 **Mozilla Public License 2.0** 提供。

**`Visible_Range_Volume_Nodes_MT5`** 基于 [Crypto_Imperija 的 Visible Range Volume Nodes](https://www.tradingview.com/script/VoKAfPNW-Visible-Range-Volume-Nodes/)，按 **Mozilla Public License 2.0** 提供。

**`VWAP_Execution_MT5`、`IB_RTH_MT5`、`TPO_Session_MT5` 以及共用的 `Chart_Visibility.mqh`** 为独立实现，按 **MIT** 许可。`TPO_Session_MT5` 会复用已有的 `VP_Nodes_Core.mqh` 分钟成交量分配器，该头文件仍按 **MPL 2.0** 提供，并保留 Crypto_Imperija 的原始署名。

完整条文见仓库中的许可文件。软件按原样提供，不作任何担保。

## 免责声明

这些指标只用于看图，不会下单。过往形态不代表未来结果。使用前请自行验证，风险自负。
