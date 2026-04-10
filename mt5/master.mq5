//+------------------------------------------------------------------+
//|                     Master Signal Sender EA (MT5)                |
//+------------------------------------------------------------------+
#property strict

input string API_URL = "http://127.0.0.1:3000/signal";

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Master Signal Sender EA started.");
   Print("Make sure '", API_URL, "' is allowed in Tools -> Options -> Expert Advisors.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   static ulong lastDealTicket = 0;   // Duplicate prevention

   // Only process DEAL_ADD events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(trans.deal <= 0 || trans.deal == lastDealTicket)
      return;
   lastDealTicket = trans.deal;

   // --- Fetch reliable deal data from history ---
   if(!HistoryDealSelect(trans.deal))
   {
      Print("ERROR: Could not select deal ", trans.deal);
      return;
   }

   string symbol      = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   double volume      = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   ENUM_DEAL_TYPE  deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   ulong position_id = trans.position;   // May be 0 for close events

   string type   = (deal_type == DEAL_TYPE_BUY) ? "BUY" : "SELL";
   string action = (entry == DEAL_ENTRY_IN) ? "OPEN" : "CLOSE";

   // --- Get SL/TP (only relevant for OPEN) ---
   double sl = 0, tp = 0;
   if(action == "OPEN" && position_id > 0)
   {
      if(PositionSelectByTicket(position_id))
      {
         sl = PositionGetDouble(POSITION_SL);
         tp = PositionGetDouble(POSITION_TP);
      }
   }

   // --- Build JSON ---
   string json = StringFormat(
      "{\"symbol\":\"%s\",\"type\":\"%s\",\"lot\":%.2f,\"sl\":%.5f,\"tp\":%.5f,\"action\":\"%s\",\"position_id\":%I64u,\"deal_id\":%I64u}",
      symbol, type, volume, sl, tp, action, position_id, trans.deal
   );

   Print("Sending Signal: ", json);
   SendToAPI(json);
}

//+------------------------------------------------------------------+
//| Send HTTP POST                                                  |
//+------------------------------------------------------------------+
void SendToAPI(string json)
{
   char post[];
   char result[];
   string headers = "Content-Type: application/json\r\n";
   string response_headers;

   int len = StringLen(json);
   ArrayResize(post, len);
   for(int i = 0; i < len; i++)
      post[i] = (char)StringGetCharacter(json, i);

   ResetLastError();
   int res = WebRequest("POST", API_URL, headers, 5000, post, result, response_headers);

   if(res == -1)
   {
      int err = GetLastError();
      Print("❌ WebRequest failed. Error: ", err);
      if(err == 4014) Print("➡ Enable WebRequest in MT5 settings (Tools -> Options -> Expert Advisors)");
      else if(err == 4028) Print("➡ Check if API server is running at ", API_URL);
   }
   else
   {
      string response = CharArrayToString(result);
      Print("✅ Response: ", res, " | ", response);
   }
}