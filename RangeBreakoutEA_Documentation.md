# Range Breakout EA Documentation

## Overview

The **Range Breakout EA** is a simple MetaTrader 5 Expert Advisor that identifies a price range during a specified time window and trades breakouts from that range.

---

## Strategy Logic

### 1. Range Formation Phase (22:00 - 00:00 UTC)
- The EA monitors price action during the **pre-market session** (22:00 to 00:00 UTC)
- It continuously tracks the **highest high** and **lowest low** during this period
- Visual horizontal lines are drawn on the chart showing the range boundaries

### 2. Breakout Detection Phase (After 00:00 UTC)
Once the range is established, the EA waits for price to break out:

| Breakout Type | Condition | Trade Action |
|---------------|-----------|--------------|
| **Bullish** | Price > Range High + Buffer | Open **BUY** |
| **Bearish** | Price < Range Low - Buffer | Open **SELL** |

### 3. Trade Management
- **Stop Loss**: Placed at a fixed pip distance from entry
- **Take Profit**: Placed at a fixed pip distance from entry
- Trades are limited to a max number per day

---

## Input Parameters

### Time Settings (UTC)
| Parameter | Default | Description |
|-----------|---------|-------------|
| `RangeStartHour` | 22 | Hour when range calculation starts |
| `RangeStartMinute` | 0 | Minute when range calculation starts |
| `RangeEndHour` | 0 | Hour when range calculation ends |
| `RangeEndMinute` | 0 | Minute when range calculation ends |

### Trading Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `LotSize` | 0.01 | Fixed lot size for trades |
| `StopLossPips` | 50 | Stop loss distance in pips |
| `TakeProfitPips` | 100 | Take profit distance in pips |
| `BreakoutBuffer` | 5 | Extra pips beyond range to confirm breakout |
| `MaxDailyTrades` | 2 | Maximum trades per day |

### General Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| `MagicNumber` | 123456 | Unique identifier for EA trades |
| `TradeComment` | "RangeBreakout" | Comment added to trades |

---

## Visual Indicators

The EA draws two horizontal lines on your chart:

- 🟢 **Green dashed line** — Range High
- 🔴 **Red dashed line** — Range Low

These lines update in real-time during the range formation phase.

---

## How to Install

1. Copy `RangeBreakoutEA.mq5` to your MetaTrader 5 `Experts` folder:
   ```
   [MT5 Installation]/MQL5/Experts/
   ```

2. Open MetaEditor and **compile** the EA (press F7)

3. In MetaTrader 5:
   - Open the **Navigator** panel (Ctrl+N)
   - Find the EA under **Expert Advisors**
   - Drag it onto your desired chart

4. Enable **Auto Trading** (Ctrl+E) on the toolbar

---

## Recommended Settings

| Symbol Type | Timeframe | Notes |
|-------------|-----------|-------|
| Forex Pairs | M1 - M15 | Best for major pairs (EURUSD, GBPUSD) |
| Indices | M5 - H1 | Works well with US30, NAS100 |
| Gold (XAUUSD) | M5 | Adjust SL/TP for volatility |

> ⚠️ **Warning**: Always test on a demo account first!

---

## Risk Disclaimer

This EA is provided for **educational purposes only**. Trading involves substantial risk of loss. Past performance is not indicative of future results. Always use proper risk management and never trade with money you cannot afford to lose.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.00 | 2026-01-28 | Initial release |
