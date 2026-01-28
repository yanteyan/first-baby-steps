//+------------------------------------------------------------------+
//|                                            RangeBreakoutEA.mq5   |
//|                                        Simple Range Breakout EA  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Range Breakout EA"
#property link      ""
#property version   "1.00"
#property strict

//--- Input Parameters
input group "=== Time Settings (UTC) ==="
input int      RangeStartHour    = 22;        // Range Start Hour (UTC)
input int      RangeStartMinute  = 0;         // Range Start Minute
input int      RangeEndHour      = 0;         // Range End Hour (UTC) - next day
input int      RangeEndMinute    = 0;         // Range End Minute

input group "=== Trading Settings ==="
input double   LotSize           = 0.01;      // Lot Size
input int      StopLossPips      = 50;        // Stop Loss in Pips
input int      TakeProfitPips    = 100;       // Take Profit in Pips
input int      BreakoutBuffer    = 5;         // Breakout Buffer in Pips
input int      MaxDailyTrades    = 2;         // Maximum Trades Per Day

input group "=== General Settings ==="
input int      MagicNumber       = 123456;    // Magic Number
input string   TradeComment      = "RangeBreakout"; // Trade Comment

//--- Global Variables
double RangeHigh = 0;
double RangeLow = 0;
bool RangeCalculated = false;
bool BreakoutTriggered = false;
datetime LastTradeDate = 0;
int TodayTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Range Breakout EA Initialized");
   Print("Range Time: ", RangeStartHour, ":", RangeStartMinute, " to ", RangeEndHour, ":", RangeEndMinute, " UTC");
   
   // Reset variables
   ResetDailyVariables();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("Range Breakout EA Removed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Get current time in UTC
   datetime currentTime = TimeGMT();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   int currentHour = timeStruct.hour;
   int currentMinute = timeStruct.min;
   
   // Check for new day and reset variables
   datetime today = StringToTime(TimeToString(currentTime, TIME_DATE));
   if(today != LastTradeDate)
   {
      ResetDailyVariables();
      LastTradeDate = today;
   }
   
   // Check if we are within the range time
   bool inRangeTime = IsWithinRangeTime(currentHour, currentMinute);
   
   if(inRangeTime)
   {
      // Calculate/Update the range
      CalculateRange();
   }
   else if(RangeCalculated && !BreakoutTriggered)
   {
      // We are outside range time - look for breakout
      CheckForBreakout();
   }
   
   // Draw range lines on chart
   DrawRangeLines();
}

//+------------------------------------------------------------------+
//| Check if current time is within range time                         |
//+------------------------------------------------------------------+
bool IsWithinRangeTime(int hour, int minute)
{
   int currentTimeMinutes = hour * 60 + minute;
   int rangeStartMinutes = RangeStartHour * 60 + RangeStartMinute;
   int rangeEndMinutes = RangeEndHour * 60 + RangeEndMinute;
   
   // Handle overnight range (22:00 to 00:00)
   if(rangeStartMinutes > rangeEndMinutes)
   {
      // Range spans midnight
      return (currentTimeMinutes >= rangeStartMinutes || currentTimeMinutes < rangeEndMinutes);
   }
   else
   {
      return (currentTimeMinutes >= rangeStartMinutes && currentTimeMinutes < rangeEndMinutes);
   }
}

//+------------------------------------------------------------------+
//| Calculate the high and low of the range                            |
//+------------------------------------------------------------------+
void CalculateRange()
{
   double currentHigh = iHigh(_Symbol, PERIOD_M1, 0);
   double currentLow = iLow(_Symbol, PERIOD_M1, 0);
   
   if(RangeHigh == 0 || currentHigh > RangeHigh)
      RangeHigh = currentHigh;
   
   if(RangeLow == 0 || currentLow < RangeLow)
      RangeLow = currentLow;
   
   RangeCalculated = true;
   
   Print("Range Updated - High: ", RangeHigh, " Low: ", RangeLow);
}

//+------------------------------------------------------------------+
//| Check for breakout and open trade                                  |
//+------------------------------------------------------------------+
void CheckForBreakout()
{
   if(TodayTrades >= MaxDailyTrades)
   {
      Print("Maximum daily trades reached");
      return;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bufferPoints = BreakoutBuffer * point * 10; // Convert pips to points
   
   // Check for bullish breakout (price breaks above range high)
   if(currentPrice > RangeHigh + bufferPoints)
   {
      if(OpenTrade(ORDER_TYPE_BUY))
      {
         BreakoutTriggered = true;
         Print("Bullish Breakout! Opened BUY at ", currentPrice);
      }
   }
   // Check for bearish breakout (price breaks below range low)
   else if(currentPrice < RangeLow - bufferPoints)
   {
      if(OpenTrade(ORDER_TYPE_SELL))
      {
         BreakoutTriggered = true;
         Print("Bearish Breakout! Opened SELL at ", currentPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Open a trade                                                       |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE orderType)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price, sl, tp;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - StopLossPips * point * 10;
      tp = price + TakeProfitPips * point * 10;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + StopLossPips * point * 10;
      tp = price - TakeProfitPips * point * 10;
   }
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = LotSize;
   request.type = orderType;
   request.price = price;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = ORDER_FILLING_IOC;
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED)
      {
         TodayTrades++;
         Print("Trade opened successfully. Ticket: ", result.order);
         return true;
      }
   }
   
   Print("Failed to open trade. Error: ", GetLastError(), " Retcode: ", result.retcode);
   return false;
}

//+------------------------------------------------------------------+
//| Reset daily variables                                              |
//+------------------------------------------------------------------+
void ResetDailyVariables()
{
   RangeHigh = 0;
   RangeLow = 0;
   RangeCalculated = false;
   BreakoutTriggered = false;
   TodayTrades = 0;
   
   Print("Daily variables reset");
}

//+------------------------------------------------------------------+
//| Draw range lines on chart                                          |
//+------------------------------------------------------------------+
void DrawRangeLines()
{
   if(!RangeCalculated)
      return;
   
   // Draw Range High Line
   if(ObjectFind(0, "RangeHigh") < 0)
   {
      ObjectCreate(0, "RangeHigh", OBJ_HLINE, 0, 0, RangeHigh);
      ObjectSetInteger(0, "RangeHigh", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, "RangeHigh", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "RangeHigh", OBJPROP_STYLE, STYLE_DASH);
   }
   else
   {
      ObjectSetDouble(0, "RangeHigh", OBJPROP_PRICE, RangeHigh);
   }
   
   // Draw Range Low Line
   if(ObjectFind(0, "RangeLow") < 0)
   {
      ObjectCreate(0, "RangeLow", OBJ_HLINE, 0, 0, RangeLow);
      ObjectSetInteger(0, "RangeLow", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "RangeLow", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "RangeLow", OBJPROP_STYLE, STYLE_DASH);
   }
   else
   {
      ObjectSetDouble(0, "RangeLow", OBJPROP_PRICE, RangeLow);
   }
}

//+------------------------------------------------------------------+
