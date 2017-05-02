//+------------------------------------------------------------------+
//|                                                    CssLibCss.mq4 |
//|                                          Copyright 2017, Marco Z |
//|                                       https://github.com/mazmazz |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Marco Z"
#property link      "https://github.com/mazmazz"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
//--- plot Base
#property indicator_label1  "Base"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrMediumVioletRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
//--- plot Quote
#property indicator_label2  "Quote"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrTurquoise
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#include <LibCSS5.mqh>

enum CSS_INPUT {
    CSS_INPUT_CSS // CSS
    , CSS_INPUT_SUPERSLOPE // SuperSlope
};

CLibCSS CssInst;

input CSS_INPUT CalcMethod = CSS_INPUT_SUPERSLOPE; // CalcMethod: Also change Ma/AtrPeriod below.
input CSS_VERSION CssWeighList = CSS_VERSION_CSS; // CssWeighList: Ignored for SuperSlope.
input string CustomSymbolsToWeigh = "GBPNZD,EURNZD,GBPAUD,GBPCAD,GBPJPY,GBPCHF,CADJPY,EURCAD,EURAUD,USDCHF,GBPUSD,EURJPY,NZDJPY,AUDCHF,AUDJPY,USDJPY,EURUSD,NZDCHF,CADCHF,AUDNZD,NZDUSD,CHFJPY,AUDCAD,USDCAD,NZDCAD,AUDUSD,EURCHF,EURGBP"; // CustomSymbolsToWeigh: To use, set CssWeighList=None
input bool UseOnlySymbolOnChart = false;
input bool UseAllSymbols = false; 
input bool IgnoreFuture = true; // IgnoreFuture: If false, uses TMA instead of MA for slope. Ignored by SuperSlope
//input bool DoNotCache = true;
bool DoNotCache = true; // Hardcoded because caching is not properly supported (or needed?)
input int MaPeriod = 7; // MaPeriod: CSS=21, SuperSlope=7
input int AtrPeriod = 50; // AtrPeriod: CSS=100, SuperSlope=50
input double LevelCrossValue = 2.0; // LevelCrossValue: CSS=0.2, SuperSlope=2.0
input double DifferenceThreshold = 0.0;
input bool DisplayLevelCross = true;
input bool DisplaySignalLines = true;

string css3_SymbolsToWeigh = "AUDCAD,AUDCHF,AUDJPY,AUDNZD,AUDUSD,CADJPY,CHFJPY,EURAUD,EURCAD,EURJPY,EURNZD,EURUSD,GBPAUD,GBPCAD,GBPCHF,GBPJPY,GBPNZD,GBPUSD,NZDCHF,NZDJPY,NZDUSD,USDCAD,USDCHF,USDJPY";
string lib_SymbolsToWeigh = "GBPNZD,EURNZD,GBPAUD,GBPCAD,GBPJPY,GBPCHF,CADJPY,EURCAD,EURAUD,USDCHF,GBPUSD,EURJPY,NZDJPY,AUDCHF,AUDJPY,USDJPY,EURUSD,NZDCHF,CADCHF,AUDNZD,NZDUSD,CHFJPY,AUDCAD,USDCAD,NZDCAD,AUDUSD,EURCHF,EURGBP";

string SymbolCur;
string BaseCur;
string QuoteCur;
ENUM_TIMEFRAMES TimeFrameCur;

//--- indicator buffers
double         BaseBuffer[];
double         QuoteBuffer[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    SymbolCur = Symbol();
    BaseCur = SymbolManager::getSymbolBaseCurrency(SymbolCur);
    QuoteCur = SymbolManager::getSymbolQuoteCurrency(SymbolCur);
    TimeFrameCur = (ENUM_TIMEFRAMES)Period();
  
//--- indicator buffers mapping
    SetIndexBuffer(0,BaseBuffer);
    SetIndexBuffer(1,QuoteBuffer);
    ArraySetAsSeries(BaseBuffer, true);
    ArraySetAsSeries(QuoteBuffer, true);
   
   // display LevelCrossValue
    if(DisplayLevelCross) {
       IndicatorSetInteger(INDICATOR_LEVELS, 0, 2);
       IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, LevelCrossValue);
       IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, LevelCrossValue*-1);
       IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrLimeGreen);
       IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrCrimson);
       IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DASH);
       IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DASH);
       IndicatorSetInteger(INDICATOR_LEVELWIDTH, 0, 1);
       IndicatorSetInteger(INDICATOR_LEVELWIDTH, 1, 1);
    }
   
    IndicatorSetInteger(INDICATOR_DIGITS, 5);
   
    CssInst.calcMethod = CalcMethod == CSS_INPUT_SUPERSLOPE ? CSS_VERSION_SUPERSLOPE : CSS_VERSION_CSS;
    if(UseAllSymbols || CalcMethod == CSS_INPUT_SUPERSLOPE) { CssInst.symbolsToWeigh = ""; } 
    else {
        switch(CssWeighList) {
            case CSS_VERSION_3_8: CssInst.symbolsToWeigh = css3_SymbolsToWeigh; break;
            case CSS_VERSION_CSS: default: CssInst.symbolsToWeigh = lib_SymbolsToWeigh; break;
        }
    }
    CssInst.useOnlySymbolOnChart = UseOnlySymbolOnChart;
    CssInst.doNotCache = DoNotCache;
    
    CssInst.init();
    
    int size = ArraySize(CssInst.symbolNames);
    string debugList = "Symbols (" + size + "): ";
    for(int i = 0; i < size; i++) {
        debugList += CssInst.symbolNames[i] + ",";
    }
    Print(debugList);
    
    size = ArraySize(CssInst.currencyNames);
    debugList = "Currencies (" + size + "): ";
    for(int i = 0; i < size; i++) {
        debugList += CssInst.currencyNames[i] + "(" + CssInst.currencyOccurrences[i] + "), ";
    }
    Print(debugList);
    
    //---
    return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
//---
    int windowBars = ChartGetInteger(0,CHART_VISIBLE_BARS,0);
    int startBar = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR, 0) - windowBars;
    startBar = startBar < 0 ? 0 : startBar;

    for(int i=startBar; i < windowBars + startBar; i++) {
        double symbolCss = CssInst.getCSSCurrency(SymbolCur, BaseCur, TimeFrameCur, MaPeriod, AtrPeriod, i);
        double quoteCss = CssInst.getCSSCurrency(SymbolCur, QuoteCur, TimeFrameCur, MaPeriod, AtrPeriod, i);
        
        //if(symbolCss != 0 || quoteCss != 0) {
        //    Print("CSS values are nonzero");
        //}
        
        BaseBuffer[i]= symbolCss;
        QuoteBuffer[i]=quoteCss;
    }
//--- return value of prev_calculated for next call
    return(rates_total);
}
//+------------------------------------------------------------------+
