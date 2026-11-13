# MT5 Indicators (Codex ports)

Independent MetaTrader 5 chart indicators. These are not official products of any broker, LuxAlgo, or TradingView, and they are not trading advice.

## Indicators

| Indicator | Version | What it shows | License |
| --- | --- | --- | --- |
| `SMC_Pro_Neon_MT5` | 1.12 | Smart-money structure: BOS / CHoCH, order blocks, EQH / EQL, and related marks | [CC BY-NC-SA 4.0](LICENSE-SMC.md) |
| `Visible_Range_Volume_Nodes_MT5` | 1.02 | Visible-range volume nodes: POC, value area, HVN / LVN | [MPL 2.0](LICENSE-MPL-2.0.txt) |
| `SuperTrend_Kivanc_MT5` | 1.11 | Kivanc Supertrend | [MPL 2.0](LICENSE-MPL-2.0.txt) |
| `VWAP_Execution_MT5` | 1.01 | Session VWAP with optional deviation bands | MIT |
| `IB_RTH_MT5` | 1.02 | Initial Balance, New York RTH by default | MIT |

Each indicator has a top-right `Hide` / `Show` button that hides drawings without stopping calculation. Buttons stack automatically when several of these indicators are loaded. Related inputs are in the `Chart visibility button (top right)` group.

This repository does not include TPO or any expert advisor.

[中文说明](README.zh-CN.md)

## Install

1. In MT5, choose **File → Open Data Folder**.
2. Open `MQL5/Indicators/` and create a `Codex` folder if it does not exist.
3. Copy the `.mq5` files, their matching `.mqh` headers, and optionally the `.ex5` binaries into that folder. Source files and headers must stay in the same directory.
4. In the Navigator, right-click **Indicators** and refresh, then drop an indicator onto a chart.
5. To edit source, open the `.mq5` file in MetaEditor and compile. Algorithmic trading does not need to be enabled.

On charts that already have an older build, press `Ctrl+I`, select the indicator, and choose **Edit**. If the version number does not update, save your `.set` preset, remove the indicator, and add it again.

## Licenses and attribution

Files in this repository are not under a single license. Follow the license that applies to each file.

**`SMC_Pro_Neon_MT5` and its core header** are an independent MQL5 adaptation of [LuxAlgo Smart Money Concepts (public script updated by Jlubin782 in May 2026)](https://www.tradingview.com/script/WVf1sjBU-LuxAlgo-Smart-Money-Concepts-Updated-by-J-Lubin-5-2026/). That Pine source is **CC BY-NC-SA 4.0**, and this port uses the same license: keep attribution, do not use it commercially, and share adaptations under the same terms. The SMC files **must not be sold as a paid product**. See [LICENSE-SMC.md](LICENSE-SMC.md). This is not an official LuxAlgo or Jlubin782 MT5 release.

**`SuperTrend_Kivanc_MT5`** is based on [KivancOzbilgic's Supertrend](https://www.tradingview.com/script/r6dAP7yi/), with credit retained for everget (Alex Orekhov), and is provided under the **Mozilla Public License 2.0**.

**`Visible_Range_Volume_Nodes_MT5`** is based on [Crypto_Imperija's Visible Range Volume Nodes](https://www.tradingview.com/script/VoKAfPNW-Visible-Range-Volume-Nodes/) and is provided under the **Mozilla Public License 2.0**.

**`VWAP_Execution_MT5`, `IB_RTH_MT5`, and the shared `Chart_Visibility.mqh` helper** are independent implementations under the **MIT License**.

See the license files in this repository for the full terms. The software is provided as is, without warranty.

## Disclaimer

These indicators are for charting only and do not place trades. Past structure does not predict future results. Verify them yourself before use, and use them at your own risk.
