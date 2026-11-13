# TPO v1.06 参数速查

## 进行中的 TPO 展开

无需等 RTH 结束。点击 `View: Merged` 切为 `View: Split`，或设 `InpExpanded=true`。

`InpAutoFitDeveloping=true` 是 v1.06 新增的默认值：最近一个正在形成的分布在展开时，若靠近右侧且空间不足，会自动向左留出已有字母列的宽度；不为尚未出现的列占位。前一个历史分布会止于这个显示边界，价格线及统计范围不变。设为 false 可恢复原来固定在时段开始位置的布局。

只有一个已有子时段时，展开与合并看起来相同。若想看到当前半小时，使用 `InpSubperiodUpdate=Developing_Subperiod`；`Closed_Subperiods_Only` 只加入已经结束的半小时，不必等整个 RTH 收盘。字母太多超出整个图宽时仍可能裁切；可改用 M5 或放大图表。

## XAUUSD 纽约全天

在指标输入页加载 `TPO_Session_XAUUSD_NY_Full_Day.set`，或设置：

- `InpSessionMode = Full_Day`
- `InpSessionClock = New_York_Time`
- `InpFullDayStart = 00:00`
- `InpServerClock = FTMO_US_DST`
- `InpStandardUTCMinutes = 120`

纽约 00:00 全天，冬令时是北京时间当日 13:00 至次日 13:00，夏令时是 12:00 至次日 12:00。指标自动换算；MT5 图表底部仍显示服务器时间。休市分钟不产生字母或成交量。

## 字母盘中出现还是收线出现

`InpSubperiodMinutes = 30` 控制每列覆盖的时间。

`InpSubperiodUpdate` 可选：

- `Developing_Subperiod`：默认盘中更新，当前半小时的字母随价格形成。
- `Closed_Subperiods_Only`：半小时结束才加入该列，POC、价值区同步只用结束的列。首半小时尚未结束时，当天没有首列。

这是 TPO 子时段的收线，不是主图 M5 K 线收线。

## 开盘和收盘

- `InpShowSessionOpen=true`：开盘价对应的一个字母默认橙色，其他同列字母保持原色。
- `InpSessionOpenColor`：开盘颜色，默认 RGB 255,140,0。
- `InpShowSessionClose=true`：统计时段结束后，在最后收盘价画小红色实心三角形。
- `InpSessionCloseColor`：三角形颜色，默认 RGB 230,55,65。
- `InpShowDevelopingClose=false`：默认未收盘不画三角形；改成 true 可显示盘中空心暂定标记，收盘后变实心。

这里是每段 RTH / ETH / 全天 / 自定义时段的开收盘，不是每 30 分钟的开收盘。价格来自该时段首末根可用 M1。收线显示模式下，暂定标记也只用已结束子时段数据。合并、展开、色块显示均支持；隐藏 TPO 会连同标记隐藏。

## 单打印

- `InpShowSinglePrints = true`：开启单打印高亮。
- `InpSinglePrintConfirmedOnly = true`：默认等待后一个子时段结束后确认。
- `InpSinglePrintIncludeTails = false`：默认不把上下端单字母尾部纳入。
- `InpSinglePrintColor`：已确认行、水平线及价格的颜色，默认浅绿色 RGB 102,204,153。
- `InpSinglePrintDevelopingColor`：待确认颜色；关闭 ConfirmedOnly 后可见，默认橙色。

本版识别每行仅有一个子时段访问的区域；后续回补会撤去高亮。单打印是时间统计，不代表真实逐价成交量缺口。

单打印线和价格默认开启：

- `InpShowSinglePrintLines = true`：显示单打印水平线。
- `InpShowSinglePrintPrices = true`：显示单打印价格。
- `InpSinglePrintLineMode = SP_Zone_Edges`：连续区域只画 SPH 上边界、SPL 下边界；只有一行时标 SP 中心价。`SP_Each_Price_Row` 为每一行单独画中心线。
- `InpSinglePrintExtension = Latest_Profile`：只延长最新 TPO 的单打印线。
- `InpSinglePrintLineStyle = STYLE_DOT`、`InpSinglePrintLineWidth = 1`：点线、宽度 1，可自行修改。

回补会同步撤掉失效区域的线和价格。若选只显示已收线子时段，回补也在收线后生效。POC / VA 的延长线开关不影响单打印线。

## 延长线

`InpPOCExtension` 控制 POC；`InpVAExtension` 同时控制 VAH、VAL。

- `Latest_Profile`：默认，只延长最近一个实际 profile。
- `All_Profiles`：延长所有已加载 profile。
- `Session_End`：止于各自统计时段结束。

最近一个包含形成中的时段。RTH/ETH 分开时，只延长二者中最新的一段。延长是水平射线，触价不自动停止。

## 移除左上角文字

截图中的蓝色 `IB | ...`：打开 `IB_RTH_MT5` 输入，设 `InpShowStatus = false`，不影响 IBH、IBL、IBM。

当前版本默认按钮位于右下方，`InpPanelPosition = Panel_Bottom_Right`，`InpControlX=8`、`InpControlY=8`。为价格轴预留空间；窄窗口自动换行。说明文字默认 `InpShowStatus = false`。按钮也不想显示时设 `InpShowControls = false`，分布与价格标签保留。

载入自己旧版 `.set` 会恢复旧位置与颜色，需要手动改以上位置参数及浅绿色；新版随附预设已使用右下和浅绿色。

## 切换周期保留选择

v1.05 修复图上按钮选择在 30m → 5m → 30m 往返后恢复输入默认值的问题。现在同一图表的展开/合并、POC 来源、价值区来源和隐藏状态会保留，时段统计继续从 M1 重算。

输入页的时段、行高、颜色等不应因切换周期改变。删除重加、修改输入或重新载入同周期模板时，则按输入值初始化；常用默认值可保存为 `.set`。升级文件不会自动替换当前已加载的旧版，需重新加载一次。

升级后在当前图表重新加载 TPO；先保存原参数，删除该图表中的旧 TPO，再从导航器刷新、添加新版。不要删除 EA 或其他指标。已有参数中保存的 IB ShowStatus=true 不会被文件更新自动覆盖，需要改为 false 一次。
