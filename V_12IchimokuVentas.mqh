//+------------------------------------------------------------------+
//|      EA Ichimoku Solo Ventas - Filtro Nube + Trailing Dinámico   |
//+------------------------------------------------------------------+
#property strict

input double Lote = 0.01;
input double SL_USD = 1.0;
input double TP_USD = 4.0;
input double TrailingStart = 1.0;   // activar trailing a +3 USD
input double TrailingStep = 1.0;    // trailing de 1 USD
input int    MaxTrades = 8;

datetime ultimaVelaOperada = 0;     // control: 1 operación por vela

//--------------------------------------------------------------------
// Calcular valor pip aproximado
double ValorPip()
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if(tickValue <= 0) tickValue = 0.0001;
   return tickValue * Lote * 100000 / 10.0;
}

//--------------------------------------------------------------------
// Contar trades del símbolo actual
int ContarOperaciones()
{
   int c = 0;
   for(int i=0; i<OrdersTotal(); i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol())
            c++;
   return c;
}

//--------------------------------------------------------------------
void OnTick()
{
   //--- evitar sobreoperación
   if(ContarOperaciones() >= MaxTrades) return;

   datetime tiempoVela = iTime(NULL, 0, 0);
   if(tiempoVela == ultimaVelaOperada) return; // solo 1 trade por vela

   //--- valores Ichimoku
   double tenkan0 = iIchimoku(NULL,0,9,26,52,MODE_TENKANSEN,0);
   double kijun0  = iIchimoku(NULL,0,9,26,52,MODE_KIJUNSEN,0);
   double senkouA = iIchimoku(NULL,0,9,26,52,MODE_SENKOUSPANA,26);
   double senkouB = iIchimoku(NULL,0,9,26,52,MODE_SENKOUSPANB,26);

   //--- Filtro: precio por debajo de la nube
   double nubeAlta = MathMax(senkouA, senkouB);
   double nubeBaja = MathMin(senkouA, senkouB);
   bool debajoNube = (Bid < nubeBaja);

   //--- Tendencia bajista (Tenkan < Kijun)
   bool tendenciaBajista = (tenkan0 < kijun0);

   //--- Rebote en Tenkan-Sen
   double close1 = iClose(NULL,0,1); // cierre anterior
   bool reboteTenkan = (close1 > tenkan0 && Ask >= tenkan0);

   //--- condiciones de venta
   if(debajoNube && tendenciaBajista && reboteTenkan)
   {
      double pipValue = ValorPip();
      if(pipValue <= 0) pipValue = 1;
      double sl_pips = SL_USD / pipValue / Point;
      double tp_pips = TP_USD / pipValue / Point;

      double sl = Ask + sl_pips * Point;
      double tp = Ask - tp_pips * Point;

      int ticket = OrderSend(Symbol(), OP_SELL, Lote, Bid, 3, sl, tp, "Sell Tenkan Rebound", 22346, 0, clrRed);
      if(ticket > 0)
      {
         Print("Venta abierta en rebote Tenkan, precio:", DoubleToString(Bid, Digits));
         ultimaVelaOperada = tiempoVela;
      }
      else
         Print("Error al abrir venta: ", GetLastError());
   }

   //-----------------------------------------------------------------
   // Trailing dinámico
   //-----------------------------------------------------------------
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()!=Symbol()) continue;
         if(OrderType()!=OP_SELL) continue;

         double profitUSD = OrderProfit() + OrderSwap() + OrderCommission();

         if(profitUSD >= TrailingStart)
         {
            double pipValue2 = MarketInfo(Symbol(), MODE_TICKVALUE);
            if(pipValue2<=0) pipValue2=0.0001;
            double newStop = Ask + (TrailingStep / pipValue2) * Point * 10;

            if(newStop < OrderStopLoss() || OrderStopLoss()==0)
            {
               bool mod = OrderModify(OrderTicket(), OrderOpenPrice(), newStop, OrderTakeProfit(), 0, clrBlue);
               if(mod)
                  Print("Trailing Stop actualizado: ", DoubleToString(newStop, Digits));
               else
                  Print("Error trailing: ", GetLastError());
            }
         }
      }
   }
}
