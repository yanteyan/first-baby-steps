//+------------------------------------------------------------------+
//|                      YanTE_SMC_EA.mq5                             |
//|                 Smart Money Concept Framework                    |
//|                     MQL5 ONLY                                    |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade Trade;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
input double   InpRiskPercent = 1.0;        // Normal Risk (%)
input double   InpAplusRisk   = 5.0;        // A+ Risk (%)
input int      InpTP_Ratio    = 3;          // RR Target (1:3)
input int      InpBE_Ratio    = 2;          // Break-even at 1:2
input ENUM_TIMEFRAMES InpTF   = PERIOD_M15;

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
double min_lot, max_lot, lot_step;

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   min_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   max_lot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Tick                                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   SecureProfit();

   if(!HasOpenPosition())
      CheckForEntry();
}

//+------------------------------------------------------------------+
//| Check if symbol already has position                             |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Risk-based lot calculation                                       |
//+------------------------------------------------------------------+
double CalculateLot(double riskPercent, double slPoints)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney  = balance * (riskPercent / 100.0);

   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double valuePerPoint = tickValue / tickSize;
   double lot = riskMoney / (slPoints * valuePerPoint);

   lot = MathMax(min_lot, MathMin(lot, max_lot));
   lot = NormalizeDouble(lot / lot_step, 0) * lot_step;

   return lot;
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(bool buy, double slPrice, bool isAPlus)
{
   double entry = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double riskPoints = MathAbs(entry - slPrice) / _Point;
   if(riskPoints <= 0) return;

   double riskPercent = isAPlus ? InpAplusRisk : InpRiskPercent;
   double lot = CalculateLot(riskPercent, riskPoints);

   double tp = buy
      ? entry + (riskPoints * InpTP_Ratio * _Point)
      : entry - (riskPoints * InpTP_Ratio * _Point);

   Trade.SetDeviationInPoints(20);

   bool result = buy
      ? Trade.Buy(lot, _Symbol, entry, slPrice, tp)
      : Trade.Sell(lot, _Symbol, entry, slPrice, tp);

   if(result)
      Print("Trade opened | Lot:", lot);
   else
      Print("Trade failed: ", Trade.ResultComment());
}

//+------------------------------------------------------------------+
//| Break-even logic                                                 |
//+------------------------------------------------------------------+
void SecureProfit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double price     = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);

      double risk = MathAbs(openPrice - sl);
      if(risk <= 0) continue;

      ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(type == POSITION_TYPE_BUY &&
         price >= openPrice + (risk * InpBE_Ratio) &&
         sl < openPrice)
      {
         Trade.PositionModify(ticket, openPrice, tp);
         Print("BUY moved to BE");
      }

      if(type == POSITION_TYPE_SELL &&
         price <= openPrice - (risk * InpBE_Ratio) &&
         (sl > openPrice || sl == 0))
      {
         Trade.PositionModify(ticket, openPrice, tp);
         Print("SELL moved to BE");
      }
   }
}

//+------------------------------------------------------------------+
//| Entry logic (SAFE DEFAULT)                                       |
//+------------------------------------------------------------------+
void CheckForEntry()
{
   // Simple structure logic (placeholder but functional)
   double high1 = iHigh(_Symbol, InpTF, 1);
   double low1  = iLow(_Symbol, InpTF, 1);
   double close1 = iClose(_Symbol, InpTF, 1);

   double high2 = iHigh(_Symbol, InpTF, 2);
   double low2  = iLow(_Symbol, InpTF, 2);

   bool bullish = close1 > high2;
   bool bearish = close1 < low2;

   bool isAPlus = false; // later: HTF + session confluence

   if(bullish)
      ExecuteTrade(true, low1, isAPlus);

   if(bearish)
      ExecuteTrade(false, high1, isAPlus);
}
