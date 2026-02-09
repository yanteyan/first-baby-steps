//+------------------------------------------------------------------+
//|                                            YanTE_SMC_EA_Cent.mq5 |
//|                                   Smart Money Concept Framework  |
//|                     Converted for Exness Cent Accounts (USC)     |
//+------------------------------------------------------------------+
#property strict

#include <Trade/Trade.mqh>
CTrade Trade;

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
// IMPORTANT: On Exness Cent, 1 USD = 100 USC. 
// If your balance is $100, your terminal shows 10,000. 
// You MUST input 10000.0 below, not 100.
input double   InpStartBalance = 10000.0;   // Start Balance (IN CENTS - check terminal)
input double   InpProfitRisk   = 2.0;       // Risk (%) of Accumulated Profit
input double   InpMinRiskLot   = 0.01;      // Minimum lot (Cent Lot)
input int      InpTP_Ratio     = 3;         // RR Target (1:3)
input int      InpBE_Ratio     = 2;         // Break-even at 1:2
input ENUM_TIMEFRAMES InpTF    = PERIOD_M15;

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

   if(InpStartBalance <= 0) {
      Print("Error: Start Balance must be greater than 0. Enter your Balance in CENTS.");
      return INIT_FAILED;
   }
   
   // Exness Specific: Set filling type to prevent 'Unsupported Filling' errors
   Trade.SetTypeFilling(ORDER_FILLING_IOC); 

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
//| Risk-based lot calculation (Risking % of Accumulated Profit)     |
//+------------------------------------------------------------------+
double CalculateLot(double slPoints)
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Logic remains same, but calculation relies on Balance being in Cents
   double accumulatedProfit = currentEquity - InpStartBalance;
   double riskMoney = 0;

   // If we have profit, risk the percentage of that profit
   if(accumulatedProfit > 0) 
   {
      riskMoney = accumulatedProfit * (InpProfitRisk / 100.0);
      // Print("Current Profit (USC): ", accumulatedProfit, " | Risking (USC): ", riskMoney);
   } 
   else 
   {
      // If no profit (account is at or below start balance), use minimum lots
      // Print("No accumulated profit. Using minimum risk.");
      return InpMinRiskLot;
   }

   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(slPoints <= 0 || tickValue <= 0) return InpMinRiskLot;

   double valuePerPoint = tickValue / tickSize;
   double lot = riskMoney / (slPoints * valuePerPoint);

   // Constraints
   lot = MathMax(min_lot, MathMin(lot, max_lot));
   lot = NormalizeDouble(lot / lot_step, 0) * lot_step;

   return lot;
}

//+------------------------------------------------------------------+
//| Execute trade                                                    |
//+------------------------------------------------------------------+
void ExecuteTrade(bool buy, double slPrice)
{
   double entry = buy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double riskPoints = MathAbs(entry - slPrice) / _Point;
   if(riskPoints <= 0) return;

   // Modified lot calculation call
   double lot = CalculateLot(riskPoints);

   double tp = buy
      ? entry + (riskPoints * InpTP_Ratio * _Point)
      : entry - (riskPoints * InpTP_Ratio * _Point);

   Trade.SetDeviationInPoints(20);

   bool result = buy
      ? Trade.Buy(lot, _Symbol, entry, slPrice, tp)
      : Trade.Sell(lot, _Symbol, entry, slPrice, tp);

   if(result)
      Print("Trade opened | Lot: ", lot, " | Profit Risking: ", InpProfitRisk, "%");
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
   double high1 = iHigh(_Symbol, InpTF, 1);
   double low1  = iLow(_Symbol, InpTF, 1);
   double close1 = iClose(_Symbol, InpTF, 1);

   double high2 = iHigh(_Symbol, InpTF, 2);
   double low2  = iLow(_Symbol, InpTF, 2);

   bool bullish = close1 > high2;
   bool bearish = close1 < low2;

   if(bullish)
      ExecuteTrade(true, low1);

   if(bearish)
      ExecuteTrade(false, high1);
}
