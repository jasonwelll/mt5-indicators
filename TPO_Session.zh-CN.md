# TPO Session MT5 1.06

适用于桌面版 MT5。支持合并字母分布、按子时段分列展开，以及独立选择 TPO / 成交量 POC 和价值区。不包含下单功能。

## 加载

在 MT5 导航器的「指标 → Codex」中刷新，加载 `TPO_Session_MT5`。无需删除现有 VBP、SMC、Supertrend、VWAP 或 IB；建议先放在单独的 US500 图表观察，避免多种分布叠在一起。

## 隐藏、恢复与移除

1. 临时隐藏：点击图表上的 `Hide TPO`，收起本实例的分布、价格线、标签和其他控制，只留下 `Show TPO` 恢复按钮。再次点击即可恢复，并保留当前展开、POC、价值区选择。其他指标与手工画线不受影响。v1.03 默认按钮位于右下方，距底部 8 像素，并为右侧价格轴预留 60 像素。窄图表自动排成两列或一列。
2. 保持默认隐藏：在输入中将 `InpVisible=false`。重新加载时也先隐藏。若同时设置 `InpShowControls=false`，连恢复按钮也不显示，此时需通过指标属性把 `InpVisible` 改回 true。
3. 从当前图表移除：按 `Ctrl+I`，在主图表下面单击 `TPO_Session_MT5` 这一行，再点「删除」。未选中具体指标时「属性／删除」会呈灰色。此操作不会卸载指标文件，也不影响其他图表；下次仍可从导航器重新添加。

升级后先在输入页保存自定义参数，再删除当前图表中的旧 TPO，刷新导航器并重新添加、加载原参数。名称应显示 `TPO Session v1.06`。无需关闭实盘图表或重启 MT5。旧参数可以继续加载，但会保留旧版的位置和颜色：请将 `InpPanelPosition` 改为 `Panel_Bottom_Right`、`InpControlY=8`，`InpSinglePrintColor` 选择浅绿色 RGB 102,204,153，或加载随附新版预设后恢复自己的其他参数。

不显示控制按钮：`InpShowControls=false`；不显示状态文字：`InpShowStatus=false`（新版默认）。这两个开关不会隐藏分布和价格标签。`InpPanelPosition=Panel_Bottom_Right` 默认右下；也可选 `Panel_Bottom_Left` 左下或 `Panel_Top_Left` 左上。`InpControlX` 是距所选左右边的距离（右侧另留价格轴空间），`InpControlY` 是距所选上下边的距离。隐藏后仅剩的恢复按钮仍靠右下，不会跳到原左侧分布上。截图中叠在按钮上的蓝色 `IB | ...` 是独立 IB 指标的状态信息：在 `IB_RTH_MT5` 中设置 `InpShowStatus=false` 即可，仅移除说明文字，保留 IBH、IBL、IBM 和价格。IB v1.01 的新加载默认也改为关闭该状态；已有图表中保存的 true 需要自行切换一次。

## 选择时段

在输入中设置 `InpSessionMode`：

| 选项 | 统计范围 |
| --- | --- |
| `RTH_Only` | 只统计 RTH；默认纽约 09:30–16:00 |
| `ETH_Only` | 只统计 ETH；默认纽约前日 16:00–当日 09:30 |
| `Separate_RTH_ETH` | 分别显示 ETH、RTH；每段有自己的 POC、VAH、VAL |
| `Full_Day` | 从 `InpFullDayStart` 起到次日同一时刻；默认纽约 00:00 |
| `Custom_Session` | 使用 `InpCustomStart`、`InpCustomEnd` |

上述时间均按 `InpSessionClock` 解释，默认 `New_York_Time`，也可以选择服务器时间或 UTC。时间格式统一为 `HH:MM`。结束时间小于或等于开始时间表示跨到次日；相同起止时间代表完整一天。

RTH 使用 `InpRTHStart` / `InpRTHEnd`；ETH 使用 `InpETHStart` / `InpETHEnd`。ETH 以结束日期归属，例如「ETH 2026.11.11」是前一日 16:00 到该日 09:30。全天和自定义模式按开始日期归属。

这里的 ETH 是可配置的 RTH 外时段，并非声称 CFD 与 CME 或股票交易所的盘前盘后时间完全相同。经纪商休市、维护和无报价时段不会生成虚构的 TPO。没有内置交易所假日、半日市日历，需要时自行调整。

`InpWeekdaysOnly=true` 默认跳过周末日期，但保留通向周一的周日 ETH，以及从周五开始的 ETH。纽约夏令时自动换算。跨越服务器夏令时回拨/跳时的窗口会跳过，避免历史时间歧义。

全天模式若要纳入周日晚间等周末报价，请将 `InpWeekdaysOnly=false`；随附的全天预设已经这样设置。自定义全天起点也可能让周一交易日从周日开始，此时同样应关闭日期过滤。

### XAUUSD 全天和时区

黄金 CFD 可使用 `TPO_Session_XAUUSD_NY_Full_Day.set`：`Full_Day`、`New_York_Time`、`InpFullDayStart=00:00`、30 分钟子时段、行高 2.0、Tick Volume、不过滤周末日期。有报价才计入，休市或维护分钟不填充。

| 自定义全天起点（纽约时间） | 北京时间冬令时 | 北京时间夏令时 |
| --- | --- | --- |
| `00:00`（纽约自然日） | 当日 13:00 至次日 13:00 | 当日 12:00 至次日 12:00 |
| `17:00`（另一种日切分方式，需自行选择） | 次日 06:00 至后日 06:00 | 次日 05:00 至后日 05:00 |

表中“当日”以纽约起始日期为基准。17:00 是可选统计锚点，不代表 FTMO XAUUSD 开市、换日或保证每日有完整 24 小时报价；实际交易时间应查看本品种规格。本指标不把黄金 CFD 等同美股 RTH。

MT5 底部时间轴保留服务器时间；`InpSessionClock` 仅设置指标统计时区，不改变平台时间轴或电脑时区。FTMO 默认使用 `InpServerClock=FTMO_US_DST`，`InpStandardUTCMinutes=120`，自动从服务器时间换算至纽约。纽约夏令时自动处理，不要在冬夏切换时把 00:00 手动改一小时。参考：[FTMO 2026-10-29 服务器时间说明](https://ftmo.com/en/blog/trading-updates/trading-update-29-oct-2026/)、[NIST 夏令时规则](https://www.nist.gov/pml/time-and-frequency-division/popular-links/daylight-saving-time-dst)。

## TPO 开盘和收盘标记

开收盘以每段所选统计时段为单位：RTH、ETH、全天或自定义时段各自标记，不是每根主图 K 线或每个 30 分钟子时段的开收盘。

- `InpShowSessionOpen=true`：将本时段首根可用 M1 的开盘价所在 TPO 字母标成橙色。只改开盘价对应的一个字母，不将整列 A 全部染色。若该字母也是 POC、价值区或单打印行，橙色优先；其他价格线不变。
- `InpSessionOpenColor`：开盘字母颜色，默认 RGB 255,140,0。合并、展开都保留；行高不足以显示字母时，改为对应色块。
- `InpShowSessionClose=true`：在本时段最后一根可用 M1 的收盘价画小红色实心三角形，朝向该价格对应的最后子时段字母。价格使用实际 M1 收盘价，不强制吸附到价格行中心。
- `InpSessionCloseColor`：收盘三角形颜色，默认 RGB 230,55,65。
- `InpShowDevelopingClose=false`：默认不提前画本时段的收盘三角形。改为 true 时，形成中时段显示红色空心三角形，代表目前纳入统计的最后价格；时段结束后变实心。

只显示已收线子时段时，开盘字母也要等首列出现；暂定收盘使用最后一个已结束子时段内最后一根 M1 的收盘价。整段结束后，最终标记纳入最后一个不足完整长度的子时段。

本版从经纪商可用 M1 行情取首根开盘和末根收盘。休市、缺报价或交易提前结束时，取实际可用的首末根，不补造指定时刻的价格，也不把 CFD 报价称为交易所官方结算价或收盘竞价。若首个报价较晚而对应 B 等后续字母，就标该实际字母。三角形跟随合并/展开布局；列数过多、空间不足时靠本段可见右沿显示，保持实际收盘价，不跨到下一段分布上。隐藏或移除 TPO 会一起清理这些标记。

## 单打印（Single Prints）

`InpShowSinglePrints=true` 开启高亮；合并、展开和字母过小时的色块模式均支持。已确认单打印默认浅绿色 RGB 102,204,153（#66CC99），字母/色块、单打印线和单打印价格标签共享 `InpSinglePrintColor`。

本版按“一个价格行仅被一个子时段访问一次”识别。默认 `InpSinglePrintIncludeTails=false`：只取最低与最高多字母行之间的单字母行，排除分布上下端尾部。没有多字母区域的初始分布不会整列被当成已确认单打印。这里是逐行计数定义，不是 Sierra 的突破边界首个 single 扩展算法的 1:1 复制。

`InpSinglePrintConfirmedOnly=true` 默认等待紧随其后的一个子时段结束，且该子时段确有数据。例：B 中形成的单打印，需等 C 结束后才以已确认颜色显示。若改为 false，尚待确认的行使用 `InpSinglePrintDevelopingColor`（默认橙色）。开启 `InpSinglePrintIncludeTails` 会纳入尾部单字母行，但最后一个子时段因没有后继子时段，不能标为已确认。

之后的子时段重新访问该价格行，会移除其单打印高亮。“已确认”只说明后一个子时段已结束，并不保证以后不会回补，也不是买卖信号。行高、子时段长度和 M1 数据会影响结果；它表示时间上的单次访问，不是逐价成交量缺口。高亮优先于 POC/价值区字母颜色，POC 和 VA 价格线仍保留各自颜色。

### 单打印水平线和价格

`InpShowSinglePrintLines=true` 默认画出水平线；`InpShowSinglePrintPrices=true` 默认显示价格。默认 `InpSinglePrintLineMode=SP_Zone_Edges`：把连续且确认状态相同的单字母行合为区域，用 `SPH` 标上边界、`SPL` 标下边界。边界使用价格行外侧，与 VAH/VAL 的边界规则一致。若区域只有一行，则画一条行中心线并标 `SP`，与 POC 的行中心规则一致。

`SP_Each_Price_Row` 可为每个单字母价格行单独画中心线及价格；行距小的时候标签可能密集，默认区域边界模式更简洁。`InpSinglePrintLineStyle` / `InpSinglePrintLineWidth` 控制样式和宽度，默认 1 像素点线。

`InpSinglePrintExtension=Latest_Profile` 默认仅将最新 profile 的单打印线延长至右侧；历史 profile 止于各自时段结束。也可选 `All_Profiles` 全部延长，或 `Session_End` 全部止于本时段结束。该选项独立于 POC 和价值区的延长线。

单打印总开关关闭时，高亮、线和价格一起关闭。仅关 `InpShowSinglePrintLines` 会保留高亮；仅关 `InpShowSinglePrintPrices` 会保留线。`InpShowLabels=false` 这个全局价格标签开关也会隐藏单打印价格。

待确认单打印只在 `InpSinglePrintConfirmedOnly=false` 时画线，标 `*` 并使用待确认颜色。回补后会同步删除失效的本时段单打印线、价格，区域被部分回补时只保留剩余区域。收线更新模式则等该子时段结束后再处理回补。跨到其他交易日的触价不会自动停止历史延长线；它仍是该历史 profile 的统计结果。

## POC、VAH、VAL 延长线

`InpPOCExtension` 与 `InpVAExtension` 分别控制 POC 与 VAH/VAL：

| 选项 | 行为 |
| --- | --- |
| `Session_End` | 只画到本统计时段结束，不向右延长 |
| `Latest_Profile`（默认） | 只把最近一个实际存在的 profile 向右延长，历史 profile 仍止于各自结束时间 |
| `All_Profiles` | 所有已加载的 profile 均向右延长 |

“最近一个”按开始时间排序，包含正在形成的时段；分开 ETH/RTH 时只延长两者中最新的一段，不是每种时段各延长一个。右延长采用水平射线，滚动至区间右侧仍保留，价格触碰后不自动停止。改变 POC / VA 的统计依据也会同步改变延长线。若希望隐藏价格线本身，用 `InpShowPOC=false` / `InpShowValueArea=false`。

## 30 分钟盘中显示或收线显示

`InpSubperiodUpdate=Developing_Subperiod`（默认）：当前 A/B/C 子时段盘中更新，M1 高低和活动量变化会计入当前列，刷新周期约一秒。

`InpSubperiodUpdate=Closed_Subperiods_Only`：只纳入已结束的子时段。以纽约 RTH 09:30 开始、30 分钟为例，09:30–09:59 不显示当天首列；10:00 才出现 A，10:30 出现 B。这里等待的是配置的 TPO 子时段收线，与主图使用 M5 或 M30 无关。POC、VAH、VAL 和成交量 POC 同步排除未结束子时段，避免字母和价格线使用不同数据范围。整个时段收盘时会纳入最后一个不足完整长度的子时段。历史回补或修订仍可能改变结果，不能保证永不变化。

## 展开与 POC 开关

图表上有四个按钮：

| 按钮 | 功能 |
| --- | --- |
| `Hide TPO` / `Show TPO` | 隐藏本实例 / 恢复本实例，保留参数和当前选择 |
| `View: Merged` / `View: Split` | 合并字母分布 / 每个子时段保留独立一列 |
| `POC: Volume` / `POC: TPO` | 成交量控制点 / TPO 控制点，同时改变高亮行 |
| `VA: TPO` / `VA: Volume` | 独立选择 VAH、VAL 和价值区字母颜色的统计依据 |

按钮即时生效。v1.05 在同一图表切换周期或品种时，保留本实例的隐藏、展开、POC 来源和价值区来源选择；价格数据仍按当前品种重新读取，不沿用旧缓存。输入页的时段、行高、颜色等参数由 MT5 保留，按钮不会改写输入值。

删除后重新添加、修改输入或重新应用同周期模板时，以输入中的 `InpVisible`、`InpExpanded`、`InpPOCUseVolume`、`InpValueAreaUseVolume` 为准。长期默认值请在输入页设置并保存 `.set`。状态按实例隔离，使用不可见的图表对象保存，删除指标时同步清理。隐藏期间暂停本实例的行情重算，恢复后读取最新数据。

POC 开关只选择控制点，不把字母分布变成成交量柱。字母始终按 TPO 统计。切换 POC 不会自动改变 VAH、VAL；两种依据可以自由组合。图上明确标注 `VP POC (Tick)` / `TPO POC`，VAH/VAL 也有各自的依据及 RTH/ETH 标签。

展开保留真实子时段顺序及空列。A 对应所选时段的第一个子时段，B 对应第二个，依次至 Z、a–z，超过 52 列使用 A2 等后缀。所有日段的 A 都从各自时段开始计算。

进行中的 TPO 无需等 RTH 结束即可展开。v1.06 新增 `InpAutoFitDeveloping=true`：当最近一个未完成分布靠近右边缘时，展开模式按已纳入的子时段列数自动向左留出宽度；前一个历史分布以新边界为右界，避免两段字母叠在一起。POC、VAH、VAL、时间锚点及价格线不改变。设为 false 可恢复固定在时段开始位置的绘图。只有一个子时段时，展开与合并可能看起来相同。

若列数仍超过可用的整个图宽，会裁去超出显示区域的字母列，并在展开按钮的悬停提示和可选状态栏提示 `Columns clipped`，不改变统计。此时可放大时间轴、改用 M5 图，或只显示一个 profile。纵向行间距小于字体高度时用色块代替字母，并提示 `Blocks`；可放大纵轴或增加价格行高。

## 默认设置与常用调整

| 输入 | 默认值 / 含义 |
| --- | --- |
| `InpSessionMode` | `RTH_Only` |
| `InpSubperiodMinutes` | 30，每 30 分钟一个字母；允许 5–240 |
| `InpPriceRowSize` | 2.0，实际报价单位；US500 为指数点，黄金为美元，不是 MT5 最小 point 的个数 |
| `InpMaximumRows` | 500，超过则提示增加行高，不截断价格范围 |
| `InpValueAreaPercent` | 70% |
| `InpVolumeSource` | `TP_Tick_Volume` |
| `InpPOCUseVolume` | true，默认高亮同一时段的成交量 POC |
| `InpValueAreaUseVolume` | false，默认 VAH/VAL 使用 TPO |
| `InpExpanded` | false，合并显示 |
| `InpVisible` | true，显示本实例；false 默认隐藏 |
| `InpProfiles` | 3，最近 3 个有数据且历史覆盖完整的时段，不是 3 个交易日；范围 1–10 |
| `InpLookbackDays` | 14，搜索最近 14 个日历日的时段 |
| `InpFontSize` | 10 |
| `InpShowLabels` | true，显示价格数值 |
| `InpServerClock` | `FTMO_US_DST`，冬令 UTC+2 / 美国夏令 UTC+3 |

US500 可先用行高 2.0，再按需要试 1.0；黄金也可按自己的观察粒度调整。更小的行高不代表更准确的原始成交量。

如果想要传统 TPO，使用 `POC: TPO` 和 `VA: TPO`。如果希望 POC、VAH、VAL 全部按同段成交量计算，两个按钮都选 `Volume`。

`TPO_Session_US_RTH_Default.set` 与默认一致；另外提供 RTH/ETH 分开和全天预设。输入页可加载这些 `.set` 文件。

## 统计方法和数据边界

统一读取本品种的 M1 历史，图表显示 M5 或 M30 不会改变所选时段的统计。每个子时段在一个价格行中最多贡献一个 TPO；使用 M1 高低区间覆盖这些行。此方法不能还原分钟内部跳价路径。

成交量按每根 M1 的高低区间均匀分配到价格行，平价 bar 分配到其价格所在行。FTMO CFD 默认是 Tick Volume，即报价活动量；不是 CME 集中成交量，也不是逐价真实成交或买卖主动方向。选择 Real Volume 但数据缺失时不改用 Tick 或 TPO 冒充，显示 `Volume unavailable`。部分 bar 缺量会提示 `Partial volume`。

POC 是活动量最大的价格行中心；并列时选择最靠近整个分布中央的行，仍并列则取较低行。价值区从各自 POC 向相邻较大活动量一侧扩展，相等时同时纳入两侧，直至达到目标比例。VAH、VAL 使用所选价格行的外侧边界。

当前未完成时段标 `*`，其范围、POC、价值区会随数据发展。滚动、缩放和展开不重新选择统计范围；修改时段、价格行高、子时段或数据源则会重算。这里的成交量 POC 可能与现有「可见范围 VBP」不同，因为统计时段、价格分行和数据粒度不相同。

加载中保留上一幅绘图并显示等待状态；M1 历史未覆盖时段开始时，不发布不完整时段的结果。没有报价的分钟不插入成交。历史修订、首分钟真实数据是否完整及服务器数据质量仍由经纪商决定。该版本不是 Sierra Chart 完整功能的 1:1 移植，也不含自动多日合并、单日任意拆段、单打印警报或下单逻辑。

## 文件与验证

2026-11-13：v1.06 修复形成中分布在压缩 M30 视图靠近右边缘时不显示或裁切的问题，新增默认开启的 `InpAutoFitDeveloping`。两份程序编译为 0 errors / 0 warnings；隔离 MT5 原生完整测试 162 项通过、0 项失败。专门用尚未结束的 RTH 比较旧版失败与新版成功，验证展开不必等待整个时段结束，且不改变 POC。测试记录见 `VERIFICATION.md`。

主文件为 `TPO_Session_MT5.mq5` / `.ex5`；附带三个计算头文件。图形使用 MetaQuotes 标准库 Canvas。删除指标时仅清理该实例绘图，多实例和手工画线隔离。

`TPO_Session_SelfTest.mq5` 是隔离环境自测脚本，使用自定义合成行情验证算法和原生图表交互；不代表实盘行情或交易绩效测试。结果与截图保存在 `verification` 子目录。

2026-11-12：v1.05 主指标和测试脚本均编译为 0 errors / 0 warnings；隔离 MT5 原生测试 153 项通过、0 项失败。覆盖时段边界、ETH 日期归属、两种 POC、独立价值区、展开开关、实时画布坐标、跨周期一致性、换品种缓存重置、模板恢复、多实例清理、单打印确认和回补、尾部过滤、盘中/收线模式、最后不足完整长度子时段、延长线范围，以及隐藏/控制面板位置。开收盘标记验证首末根 M1 的范围、仅一个开盘字母变色、收盘三角形价格坐标、合并和展开、独立显隐、盘中空心与收盘实心切换，以及列数拥挤时三角形保留在本段分布内。v1.05 新增实际 M30 → M5 → M30 往返，验证按钮和隐藏状态保留、各实例输入识别与状态隔离、移除前方实例后恢复、模板空白记录清理、删除后重新添加按输入初始化。未在你的实盘图表上执行这些测试。最新结果见 `verification/TPO_Session_test_results.txt`。

复用了现有 `VP_Nodes_Core.mqh` 的分钟成交量分配器，其 MPL-2.0 许可及原始署名随源码保留，见 `LICENSE-MPL-2.0.txt`。原始参考为 Crypto_Imperija 的 [Visible Range Volume Nodes](https://www.tradingview.com/script/VoKAfPNW-Visible-Range-Volume-Nodes/)。TPO 时段、字母统计、独立 POC/VA 和显示部分是本地实现。

参考：[Sierra Chart TPO 功能说明](https://www.sierrachart.com/index.php?page=doc/StudiesReference/TimePriceOpportunityCharts.html)、[MetaQuotes Canvas 标准库](https://www.mql5.com/en/docs/standardlibrary/canvasgraphics/ccanvas)。
