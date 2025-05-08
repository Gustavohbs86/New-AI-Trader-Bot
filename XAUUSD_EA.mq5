///////////////////////////////////////////////////////////////////////
//|                                                   XAUUSD_EA.mq5  |
//|     Exemplo de EA MQL5 que busca 100 candles via dukascopy-node  |
//|     e envia OHLCV ao modelo ONNX para obter sinal              |
///////////////////////////////////////////////////////////////////////

#include <WinAPI\shell32.mqh>    // ShellExecuteA
#include <Files\File.mqh>        // FileOpen, FileReadNumber, etc.

//=== Parâmetros de entrada ===
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;    // Timeframe para fetch
input string            InpInstrument  = "xauusd"; // Instrumento

//=== Protótipos ===
bool FetchDukascopyCSV(const string timeframe, const string outPath);
bool LoadCSVtoInputs(const string path, double &inputs[]);
int  PredictSignal(const double inputs[], double &tp, double &sl);

//+------------------------------------------------------------------+
//| Função de inicialização                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA XAUUSD iniciado. Timeframe: ", EnumToString(InpTimeframe));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Evento de tick                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   static bool first = true;
   if(!first) return;            // executa apenas uma vez
   first = false;

   // Converte ENUM_TIMEFRAMES em código string
   string tf;
   switch(InpTimeframe)
   {
      case PERIOD_M1:  tf = "m1";  break;
      case PERIOD_M5:  tf = "m5";  break;
      case PERIOD_M15: tf = "m15"; break;
      case PERIOD_H1:  tf = "h1";  break;
      default: tf = "m1";
   }

   // Define caminho para salvar CSV
   string csvPath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + InpInstrument + "_" + tf + ".csv";

   // 1) Buscar CSV via dukascopy-node
   if(!FetchDukascopyCSV(tf, csvPath))
   {
      Print("Falha ao obter dados Dukascopy para tf=", tf);
      return;
   }

   // 2) Carregar dados no array inputs
   double inputs[];
   if(!LoadCSVtoInputs(csvPath, inputs))
   {
      Print("Falha ao ler CSV Dukascopy: ", csvPath);
      return;
   }

   // 3) Enviar ao modelo ONNX e obter sinal
   double tp, sl;
   int signal = PredictSignal(inputs, tp, sl);
   PrintFormat("Sinal previsto: %d, TP=%.5f, SL=%.5f", signal, tp, sl);

   // Aqui você pode executar ordens com base no sinal
}

//+------------------------------------------------------------------+
//| Chama dukascopy-node e aguarda arquivo CSV                      |
//+------------------------------------------------------------------+
bool FetchDukascopyCSV(const string timeframe, const string outPath)
{
   datetime toTime   = TimeCurrent();
   datetime fromTime;

   if(timeframe == "m1")   fromTime = toTime - 100*60;
   else if(timeframe == "m5")   fromTime = toTime - 100*5*60;
   else if(timeframe == "m15")  fromTime = toTime - 100*15*60;
   else if(timeframe == "h1")   fromTime = toTime - 100*60*60;
   else                            fromTime = toTime - 100*60;

   string fromStr = TimeToString(fromTime, TIME_DATE|TIME_SECONDS) + "Z";
   string toStr   = TimeToString(toTime,   TIME_DATE|TIME_SECONDS) + "Z";

   // Monta comando Windows
   string cmd = StringFormat(
      "cmd.exe /C dukascopy-node -i %s -from %s -to %s -t %s -f csv > \"%s\"",
      InpInstrument, fromStr, toStr, timeframe, outPath
   );

   long result = ShellExecuteA(
      0,       // hwnd
      "open",
      "cmd.exe",
      StringSubstr(cmd, 8), // retira "cmd.exe /C "
      NULL,
      SW_HIDE
   );
   if(result <= 32)
      return(false);

   // Espera arquivo aparecer (timeout ~5s)
   for(int i=0; i<50; i++)
   {
      if(FileIsExist(outPath)) return(true);
      Sleep(100);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Lê CSV Dukascopy e preenche array inputs [100 x 5]              |
//+------------------------------------------------------------------+
bool LoadCSVtoInputs(const string path, double &inputs[])
{
   int fh = FileOpen(path, FILE_READ|FILE_CSV, ',');
   if(fh == INVALID_HANDLE)
      return(false);

   ArrayResize(inputs, 100*5);
   // pula header se houver
   FileReadString(fh);

   for(int i=0; i<100 && !FileIsEnding(fh); i++)
   {
      FileReadString(fh); // timestamp
      inputs[i*5+0] = FileReadNumber(fh); // open
      inputs[i*5+1] = FileReadNumber(fh); // high
      inputs[i*5+2] = FileReadNumber(fh); // low
      inputs[i*5+3] = FileReadNumber(fh); // close
      inputs[i*5+4] = FileReadNumber(fh); // volume
      FileReadLine(fh);  // resto da linha
   }
   FileClose(fh);
   return(true);
}

//+------------------------------------------------------------------+
//| Stub para função que envia dados ao modelo ONNX                  |
//+------------------------------------------------------------------+
int PredictSignal(const double inputs[], double &tp, double &sl)
{
   // TODO: Implemente a chamada ao ONNXRuntime, passando inputs[] e obtendo signal, tp, sl
   tp = 0.0;
   sl = 0.0;
   return(0);
}

//+------------------------------------------------------------------+

