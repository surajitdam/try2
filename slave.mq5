//+------------------------------------------------------------------+
//|            Production Client Trade Copier EA (MT5)              |
//+------------------------------------------------------------------+
#property strict

input string API_URL = "http://127.0.0.1:3000/signal/latest";
input double LotMultiplier = 1.0;
input int MAGIC = 12345;

//--- mapping structure
struct TradeMap
{
   ulong master_id;
   ulong client_ticket;
};

TradeMap mappings[];
int mapCount = 0;

ulong lastDealID = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Production Client EA Started");

   LoadMappings();
   EventSetTimer(5);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   SaveMappings();
   EventKillTimer();
}

//+------------------------------------------------------------------+
void OnTimer()
{
   FetchSignal();
}

//+------------------------------------------------------------------+
// FETCH SIGNAL
//+------------------------------------------------------------------+
void FetchSignal()
{
   char result[];
   char post[];
   string headers;
   string response_headers;

   ResetLastError();

   int res = WebRequest("GET", API_URL, headers, 5000, post, result, response_headers);

   if(res < 200 || res >= 300)
   {
      Print("HTTP Error: ", res, " | ", GetLastError());
      return;
   }

   string response = CharArrayToString(result);

   if(response == "" || response == "null")
      return;

   ProcessSignal(response);
}

//+------------------------------------------------------------------+
// SIMPLE JSON PARSER (SAFE ENOUGH)
//+------------------------------------------------------------------+
string GetValue(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return "";

   pos += StringLen(search);

   while(StringGetCharacter(json, pos) == ' ')
      pos++;

   if(StringGetCharacter(json, pos) == '\"')
   {
      pos++;
      int end = StringFind(json, "\"", pos);
      return StringSubstr(json, pos, end - pos);
   }
   else
   {
      int end1 = StringFind(json, ",", pos);
      int end2 = StringFind(json, "}", pos);

      int end = (end1 < end2 && end1 != -1) ? end1 : end2;

      return StringSubstr(json, pos, end - pos);
   }
}

//+------------------------------------------------------------------+
// PROCESS SIGNAL
//+------------------------------------------------------------------+
void ProcessSignal(string json)
{
   string symbol = GetValue(json, "symbol");
   string type = GetValue(json, "type");
   string action = GetValue(json, "action");
   ulong position_id = (ulong)StringToInteger(GetValue(json, "position_id"));
   ulong deal_id = (ulong)StringToInteger(GetValue(json, "deal_id"));
   double lot = StringToDouble(GetValue(json, "lot"));
   double sl = StringToDouble(GetValue(json, "sl"));
   double tp = StringToDouble(GetValue(json, "tp"));

   if(deal_id == lastDealID)
      return;

   lastDealID = deal_id;

   if(action == "OPEN")
      OpenTrade(symbol, type, lot, sl, tp, position_id);
   else if(action == "CLOSE")
      CloseTrade(position_id);
}

//+------------------------------------------------------------------+
// OPEN TRADE
//+------------------------------------------------------------------+
void OpenTrade(string symbol, string type, double lot, double sl, double tp, ulong master_id)
{
   if(!SymbolSelect(symbol, true))
   {
      Print("Symbol not available: ", symbol);
      return;
   }

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   double finalLot = lot * LotMultiplier;
   finalLot = MathMax(minLot, MathMin(maxLot, finalLot));
   finalLot = NormalizeDouble(finalLot / step, 0) * step;

   MqlTradeRequest req;
   MqlTradeResult res;

   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_DEAL;
   req.symbol = symbol;
   req.volume = finalLot;
   req.magic = MAGIC;
   req.type = (type == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = (req.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                            : SymbolInfoDouble(symbol, SYMBOL_BID);
   req.deviation = 10;

   if(sl > 0) req.sl = sl;
   if(tp > 0) req.tp = tp;

   if(!OrderSend(req, res))
   {
      Print("Open failed: ", GetLastError());
      return;
   }

   Print("Opened trade: ", res.order);

   AddMapping(master_id, res.order);
}

//+------------------------------------------------------------------+
// CLOSE TRADE
//+------------------------------------------------------------------+
void CloseTrade(ulong master_id)
{
   for(int i=0; i<mapCount; i++)
   {
      if(mappings[i].master_id == master_id)
      {
         ulong ticket = mappings[i].client_ticket;

         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);

            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            MqlTradeRequest req;
            MqlTradeResult res;

            ZeroMemory(req);
            ZeroMemory(res);

            req.action = TRADE_ACTION_DEAL;
            req.position = ticket;
            req.symbol = symbol;
            req.volume = volume;
            req.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            req.price = (req.type == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK)
                                                    : SymbolInfoDouble(symbol, SYMBOL_BID);

            if(!OrderSend(req, res))
            {
               Print("Close failed: ", GetLastError());
               return;
            }

            Print("Closed trade: ", ticket);

            RemoveMapping(i);
         }
         return;
      }
   }
}

//+------------------------------------------------------------------+
// ADD MAPPING
//+------------------------------------------------------------------+
void AddMapping(ulong master_id, ulong ticket)
{
   TradeMap t;
   t.master_id = master_id;
   t.client_ticket = ticket;

   ArrayResize(mappings, mapCount + 1);
   mappings[mapCount] = t;
   mapCount++;

   GlobalVariableSet("map_" + IntegerToString(master_id), (double)ticket);
}

//+------------------------------------------------------------------+
// REMOVE MAPPING
//+------------------------------------------------------------------+
void RemoveMapping(int index)
{
   ulong master_id = mappings[index].master_id;

   for(int i=index; i<mapCount-1; i++)
      mappings[i] = mappings[i+1];

   mapCount--;
   ArrayResize(mappings, mapCount);

   GlobalVariableDel("map_" + IntegerToString(master_id));
}

//+------------------------------------------------------------------+
// LOAD MAPPINGS
//+------------------------------------------------------------------+
void LoadMappings()
{
   for(int i=0; i<GlobalVariablesTotal(); i++)
   {
      string name = GlobalVariableName(i);

      if(StringFind(name, "map_") == 0)
      {
         ulong master_id = (ulong)StringToInteger(StringSubstr(name, 4));
         ulong ticket = (ulong)GlobalVariableGet(name);

         AddMapping(master_id, ticket);
      }
   }
}

//+------------------------------------------------------------------+
// SAVE MAPPINGS (optional)
//+------------------------------------------------------------------+
void SaveMappings()
{
   // Already saved via GlobalVariableSet
}