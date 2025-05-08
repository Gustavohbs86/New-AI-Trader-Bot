//+------------------------------------------------------------------+
//|                                             New_AI_Trader.mq5    |
//|                          Copyright 2025, Forex Bot Project       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Forex Bot Project"
#property link      ""
#property version   "1.0"
#property strict

#include <Trade\Trade.mqh>
#include <ONNX\ONNX.mqh> // Biblioteca para IA com modelo ONNX

// Parâmetros de Entrada
input ENUM_TIMEFRAMES Timeframe = PERIOD_H1;  // Timeframe principal do EA
input double ATR_Multiplier = 1.5;            // Multiplicador para ajuste do Trailing Stop com ATR
input bool EnableLogs = true;                 // Ativar/Desativar logs detalhados
input int RsiPeriod = 14;                     // Período do RSI
input double RsiOverbought = 65.0;            // Nível de sobrecompra ajustado
input double RsiOversold = 35.0;              // Nível de sobrevenda ajustado
input int MaFastPeriod = 9;                   // Média Móvel Rápida ajustada
input int MaSlowPeriod = 21;                  // Média Móvel Lenta ajustada
input string ModelPath = "model.onnx";        // Caminho para o modelo ONNX

// Variáveis globais
CTrade trade;                                 // Objeto de negociação
int atrHandle;                                // Handle do indicador ATR
double atrBuffer[];                           // Buffer para valores do ATR
string PanelName = "InfoPanel";               // Nome do painel de informações
CONNXRuntime onnxModel;                       // Objeto para carregar o modelo ONNX

//+------------------------------------------------------------------+
//| Função para registrar logs detalhados                            |
//+------------------------------------------------------------------+
void LogDetails(string message) {
   if (EnableLogs) {
      Print(message);
   }
}

//+------------------------------------------------------------------+
//| Função para atualizar indicadores                                |
//+------------------------------------------------------------------+
bool UpdateIndicators() {
   // Atualizar os valores do ATR
   if (CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
      LogDetails("Falha ao atualizar ATR: " + IntegerToString(GetLastError()));
      return false;
   }
   LogDetails("Indicadores atualizados com sucesso.");
   return true;
}

//+------------------------------------------------------------------+
//| Função para carregar modelo ONNX                                 |
//+------------------------------------------------------------------+
bool LoadModel() {
   if (!onnxModel.Load(ModelPath)) {
      LogDetails("Erro ao carregar o modelo ONNX: " + ModelPath);
      return false;
   }
   LogDetails("Modelo ONNX carregado com sucesso: " + ModelPath);
   return true;
}

//+------------------------------------------------------------------+
//| Função para coletar os dados dos últimos 100 candles             |
//+------------------------------------------------------------------+
void GetLast100Candles(double &inputs[]) {
   ArrayResize(inputs, 500); // 100 candles * 5 valores (OHLCV)
   for (int i = 0; i < 100; i++) {
      inputs[i * 5] = iOpen(_Symbol, Timeframe, i);
      inputs[i * 5 + 1] = iHigh(_Symbol, Timeframe, i);
      inputs[i * 5 + 2] = iLow(_Symbol, Timeframe, i);
      inputs[i * 5 + 3] = iClose(_Symbol, Timeframe, i);
      inputs[i * 5 + 4] = iVolume(_Symbol, Timeframe, i);
   }
   LogDetails("Dados dos últimos 100 candles coletados.");
}

//+------------------------------------------------------------------+
//| Função para prever sinal usando modelo ONNX                      |
//+------------------------------------------------------------------+
int PredictSignal(const double &inputs[], double &tp, double &sl) {
   double output[3]; // 3 possíveis saídas: [Nada, Compra, Venda]

   if (!onnxModel.Predict(inputs, ArraySize(inputs), output, ArraySize(output))) {
      LogDetails("Erro ao executar previsão com o modelo ONNX.");
      return 0;
   }

   // Interpretar a saída do modelo
   int decision = ArrayMaximum(output, 0, ArraySize(output)); // Índice da maior probabilidade
   tp = NormalizeDouble(200.0, _Digits);  // Exemplo de Take Profit
   sl = NormalizeDouble(100.0, _Digits);  // Exemplo de Stop Loss

   LogDetails("Previsão da IA: " + IntegerToString(decision) +
              ", TP: " + DoubleToString(tp, _Digits) +
              ", SL: " + DoubleToString(sl, _Digits));
   return decision;
}

//+------------------------------------------------------------------+
//| Função principal chamada a cada tick                            |
//+------------------------------------------------------------------+
void OnTick() {
   if (!UpdateIndicators()) return;

   double inputs[];
   double tp = 0, sl = 0;
   GetLast100Candles(inputs);

   int signal = PredictSignal(inputs, tp, sl); // Prever o sinal com a IA

   // Abrir ordens com base no sinal
   if (signal == 1 || signal == 2) { // 1 = Compra, 2 = Venda
      double price = (signal == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      datetime currentTime = TimeCurrent();

      if (!PositionSelect(_Symbol)) {
         double lotSize = 0.1; // Tamanho fixo do lote para simplificar
         if (signal == 1) {
            trade.Buy(lotSize, _Symbol, 0, tp, sl, "Compra pela IA");
         } else if (signal == 2) {
            trade.Sell(lotSize, _Symbol, 0, tp, sl, "Venda pela IA");
         }

         LogDetails((signal == 1) ? "Ordem de Compra enviada" : "Ordem de Venda enviada");
      }
   }
}

//+------------------------------------------------------------------+
//| Função de inicialização do EA                                    |
//+------------------------------------------------------------------+
int OnInit() {
   LogDetails("Inicializando New AI Trader...");

   // Configuração do ATR
   atrHandle = iATR(_Symbol, Timeframe, 14);
   if (atrHandle == INVALID_HANDLE) {
      LogDetails("Erro ao criar indicador ATR: " + IntegerToString(GetLastError()));
      return INIT_FAILED;
   }
   ArraySetAsSeries(atrBuffer, true);

   // Carregar o modelo ONNX
   if (!LoadModel()) return INIT_FAILED;

   LogDetails("EA inicializado com sucesso!");
   return INIT_SUCCEEDED;
}
