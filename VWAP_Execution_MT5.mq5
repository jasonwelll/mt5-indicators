#property copyright "Independent MT5 implementation by Codex, 2026"
#property link "https://www.tradingview.com/support/solutions/43000502018-volume-weighted-average-price-vwap/"
#property version "1.01"
#property description "Session VWAP with optional deviation bands. Tick activity by default. No trading."
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots 11
#include "VWAP_Execution_Core.mqh"
#include "Chart_Visibility.mqh"

input group "Calculation"
input VWAnchor InpAnchor=Trading_Day;
input ENUM_APPLIED_PRICE InpPrice=PRICE_TYPICAL;
input VWVolume InpVolume=Tick_Activity;
input ENUM_TIMEFRAMES InpCalculationTimeframe=PERIOD_CURRENT;
input int InpResetHour=0;
input int InpResetMinute=0;
input datetime InpManualStart=0;
input int InpHistoryDays=5;
input group "Deviation bands"
input bool InpShowBand1=false;
input double InpBandMultiplier1=1.0;
input bool InpShowBand2=false;
input double InpBandMultiplier2=2.0;
input bool InpShowBand3=false;
input double InpBandMultiplier3=3.0;
input group "Appearance"
input color InpVWAPColor=C'0,130,210';
input color InpBandColor=C'110,135,155';
input int InpLineWidth=2;
input ENUM_LINE_STYLE InpBandStyle=STYLE_DASH;
input bool InpShowPriceLabel=true;
input group "Chart visibility button (top right)"
input bool InpShowToggle=true;
input bool InpStartVisible=true;
input int InpButtonRight=16;
input int InpButtonTop=28;
input string InpInstanceTag="VWAP";

double Main[],Upper1[],Lower1[],Upper2[],Lower2[],Upper3[],Lower3[];
double Deviation[],Weight[],Anchor[],Quality[];
VWKernel Kernel;
MqlRates Rates[];
VWPoint Points[];
ENUM_TIMEFRAMES CalcTF;
int CachedBars=-1,LastTotal=0;
datetime CachedLive=0,LastChartBar=0,LatestTime=0;
double LatestValue=EMPTY_VALUE;
string PriceName="",BaseName="",State="";
CVView View;
bool Pending=false,LabelDirty=true;

void ClearBar(const int i)
{
   Main[i]=EMPTY_VALUE; Upper1[i]=EMPTY_VALUE; Lower1[i]=EMPTY_VALUE;
   Upper2[i]=EMPTY_VALUE; Lower2[i]=EMPTY_VALUE; Upper3[i]=EMPTY_VALUE; Lower3[i]=EMPTY_VALUE;
   Deviation[i]=EMPTY_VALUE; Weight[i]=0; Anchor[i]=0; Quality[i]=0;
}

void WritePoint(const int i,const VWPoint &p)
{
   ClearBar(i); Weight[i]=p.weight; Anchor[i]=(double)p.anchor; Quality[i]=p.quality;
   if(!p.valid) return;
   Main[i]=p.mean; Deviation[i]=p.deviation;
   Upper1[i]=p.mean+p.deviation*InpBandMultiplier1; Lower1[i]=p.mean-p.deviation*InpBandMultiplier1;
   Upper2[i]=p.mean+p.deviation*InpBandMultiplier2; Lower2[i]=p.mean-p.deviation*InpBandMultiplier2;
   Upper3[i]=p.mean+p.deviation*InpBandMultiplier3; Lower3[i]=p.mean-p.deviation*InpBandMultiplier3;
}

bool LoadSource(const bool force)
{
   MqlRates live[];
   if(CopyRates(_Symbol,CalcTF,0,1,live)!=1) return false;
   int bars=Bars(_Symbol,CalcTF);
   if(force || bars!=CachedBars || live[0].time!=CachedLive || ArraySize(Points)==0)
   {
      datetime limit=live[0].time-InpHistoryDays*86400;
      datetime start=VWAnchorTime(limit,InpAnchor,InpResetHour*60+InpResetMinute,InpManualStart);
      if(InpAnchor==Manual_Start)
      {
         if(InpManualStart<limit) { State="Anchor outside history limit"; return false; }
         start=InpManualStart;
         if(start>live[0].time) { State="Waiting for anchor"; return false; }
      }
      int first=iBarShift(_Symbol,CalcTF,start,false);
      int ceiling=(InpHistoryDays+8)*86400/PeriodSeconds(CalcTF)+2;
      int wanted=MathMin(bars,MathMin(ceiling,first>=0?first+1:bars));
      int count=CopyRates(_Symbol,CalcTF,0,wanted,Rates);
      if(count<1 || count!=wanted) return false;
      ArraySetAsSeries(Rates,false); ArrayResize(Points,count);
      Kernel.Reset(InpAnchor,InpVolume,InpPrice,InpResetHour*60+InpResetMinute,InpManualStart);
      for(int i=0;i<count-1;i++) Points[i]=Kernel.Step(Rates[i]);
      Points[count-1]=Kernel.Step(Rates[count-1],false);
      CachedBars=bars; CachedLive=live[0].time;
   }
   else
   {
      int last=ArraySize(Points)-1;
      Rates[last]=live[0]; Points[last]=Kernel.Step(live[0],false);
   }
   return true;
}

void SetState(const string value)
{
   if(State==value) return;
   State=value;
   IndicatorSetString(INDICATOR_SHORTNAME,BaseName+(State==""?"":" ["+State+"]"));
}

void PriceLabel()
{
   if(!LabelDirty) return;
   LabelDirty=false;
   int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
   int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   int shift=first-visible+1;
   if(!InpShowPriceLabel || LatestValue==EMPTY_VALUE || Pending || LastTotal<1 || shift>0)
   { if(ObjectFind(0,PriceName)>=0) ObjectDelete(0,PriceName); return; }
   datetime edge=LatestTime+MathMax(1,-shift-2)*PeriodSeconds(_Period);
   if(ObjectFind(0,PriceName)<0)
   {
      if(!ObjectCreate(0,PriceName,OBJ_ARROW_RIGHT_PRICE,0,edge,LatestValue)) return;
      ObjectSetInteger(0,PriceName,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,PriceName,OBJPROP_HIDDEN,false);
      ObjectSetInteger(0,PriceName,OBJPROP_COLOR,InpVWAPColor);
      ObjectSetInteger(0,PriceName,OBJPROP_WIDTH,1);
      ObjectSetInteger(0,PriceName,OBJPROP_BACK,false);
      View.Object(PriceName);
   }
   ObjectMove(0,PriceName,0,edge,LatestValue);
   ObjectSetString(0,PriceName,OBJPROP_TOOLTIP,"VWAP "+DoubleToString(LatestValue,_Digits)+
      (InpVolume==Tick_Activity?" | Tick activity":" | Real volume")+(State==""?"":" | "+State));
}

int Calculate(const int total,const int previous,const datetime &time[])
{
   if(total<1) return 0;
   bool rebuild=previous==0 || total!=LastTotal || time[total-1]!=LastChartBar ||
      CachedLive!=iTime(_Symbol,CalcTF,0) || CachedBars!=Bars(_Symbol,CalcTF);
   string oldState=State; State="";
   if(!LoadSource(previous==0 || Pending))
   {
      string message=State==""?"Loading history":State; State=oldState; SetState(message);
      bool waiting=message=="Loading history";
      Pending=waiting; LatestValue=EMPTY_VALUE; LabelDirty=true;
      for(int i=0;i<total;i++) ClearBar(i);
      // Keep the indicator unready so CopyBuffer can retry after asynchronous history loading.
      LastTotal=total; LastChartBar=time[total-1]; return waiting?0:total;
   }
   State=oldState;
   if(Pending) rebuild=true;
   Pending=false;
   int start=rebuild?0:total-1,last=ArraySize(Points)-1,mapped=-1;
   int sourceSeconds=PeriodSeconds(CalcTF),chartSeconds=PeriodSeconds(_Period);
   if(start>0) mapped=last-1;
   for(int i=start;i<total;i++)
   {
      ClearBar(i);
      datetime cutoff=i==total-1?Rates[last].time+sourceSeconds:time[i]+chartSeconds;
      while(mapped+1<=last && Rates[mapped+1].time<cutoff) mapped++;
      if(mapped<0 || Rates[mapped].time<time[i]) continue;
      WritePoint(i,Points[mapped]);
   }
   VWPoint latest=Points[last];
   SetState(latest.quality==3?"Incomplete anchor history":latest.quality==0?"No selected volume":
      latest.quality==2?"Partial volume":"");
   LatestValue=Main[total-1]; LatestTime=time[total-1]; LabelDirty=true;
   LastTotal=total; LastChartBar=time[total-1]; return total;
}
void ApplyVisibility()
{
   for(int i=0;i<7;i++)
   {
      bool show=i==0 || ((i==1 || i==2) && InpShowBand1) || ((i==3 || i==4) && InpShowBand2) ||
         ((i==5 || i==6) && InpShowBand3);
      PlotIndexSetInteger(i,PLOT_DRAW_TYPE,View.visible && show?DRAW_LINE:DRAW_NONE);
   }
   if(ObjectFind(0,PriceName)>=0) View.Object(PriceName);
   View.Draw(); ChartRedraw(0);
}

int OnInit()
{
   CalcTF=InpCalculationTimeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:InpCalculationTimeframe;
   int seconds=PeriodSeconds(CalcTF),chartSeconds=PeriodSeconds(_Period);
   if(seconds<=0 || seconds>=86400 || chartSeconds>=86400 || seconds>chartSeconds || chartSeconds%seconds!=0 ||
      InpResetHour<0 || InpResetHour>23 || InpResetMinute<0 || InpResetMinute>59 ||
      InpHistoryDays<1 || InpHistoryDays>90 || InpLineWidth<1 || InpLineWidth>5 ||
      !MathIsValidNumber(InpBandMultiplier1) || InpBandMultiplier1<=0 || InpBandMultiplier1>20 ||
      !MathIsValidNumber(InpBandMultiplier2) || InpBandMultiplier2<=0 || InpBandMultiplier2>20 ||
      !MathIsValidNumber(InpBandMultiplier3) || InpBandMultiplier3<=0 || InpBandMultiplier3>20 ||
      (InpAnchor==Manual_Start?(InpManualStart<=0 || (long)InpManualStart%seconds!=0):
       (InpResetHour*3600+InpResetMinute*60)%seconds!=0) || InpButtonRight<0 || InpButtonRight>10000 ||
      InpButtonTop<0 || InpButtonTop>10000)
   {
      Print("VWAP: use an intraday calculation timeframe <= chart timeframe; align the anchor to source bars and check parameters.");
      return INIT_PARAMETERS_INCORRECT;
   }
   SetIndexBuffer(0,Main,INDICATOR_DATA);
   SetIndexBuffer(1,Upper1,INDICATOR_DATA); SetIndexBuffer(2,Lower1,INDICATOR_DATA);
   SetIndexBuffer(3,Upper2,INDICATOR_DATA); SetIndexBuffer(4,Lower2,INDICATOR_DATA);
   SetIndexBuffer(5,Upper3,INDICATOR_DATA); SetIndexBuffer(6,Lower3,INDICATOR_DATA);
   SetIndexBuffer(7,Deviation,INDICATOR_DATA); SetIndexBuffer(8,Weight,INDICATOR_DATA);
   SetIndexBuffer(9,Anchor,INDICATOR_DATA); SetIndexBuffer(10,Quality,INDICATOR_DATA);
   ArraySetAsSeries(Main,false); ArraySetAsSeries(Upper1,false); ArraySetAsSeries(Lower1,false);
   ArraySetAsSeries(Upper2,false); ArraySetAsSeries(Lower2,false); ArraySetAsSeries(Upper3,false); ArraySetAsSeries(Lower3,false);
   ArraySetAsSeries(Deviation,false); ArraySetAsSeries(Weight,false); ArraySetAsSeries(Anchor,false); ArraySetAsSeries(Quality,false);
   string labels[]={"VWAP","Upper 1","Lower 1","Upper 2","Lower 2","Upper 3","Lower 3",
                    "Weighted deviation","Cumulative weight","Anchor (server time)","Quality (1=complete,2=partial,3=history)"};
   for(int i=0;i<11;i++)
   {
      bool show=i==0 || ((i==1 || i==2) && InpShowBand1) || ((i==3 || i==4) && InpShowBand2) ||
         ((i==5 || i==6) && InpShowBand3);
      PlotIndexSetInteger(i,PLOT_DRAW_TYPE,show?DRAW_LINE:DRAW_NONE);
      PlotIndexSetString(i,PLOT_LABEL,labels[i]); PlotIndexSetDouble(i,PLOT_EMPTY_VALUE,EMPTY_VALUE);
      PlotIndexSetInteger(i,PLOT_LINE_COLOR,i==0?InpVWAPColor:InpBandColor);
      PlotIndexSetInteger(i,PLOT_LINE_WIDTH,i==0?InpLineWidth:1);
      PlotIndexSetInteger(i,PLOT_LINE_STYLE,i==0?STYLE_SOLID:InpBandStyle);
      PlotIndexSetInteger(i,PLOT_SHOW_DATA,i==0 || show);
   }
   string anchor=InpAnchor==Trading_Day?"Day":InpAnchor==Trading_Week?"Week":"Manual";
   BaseName="VWAP Execution v1.01 ["+anchor+" | "+(InpVolume==Tick_Activity?"Tick":"Real")+" | "+EnumToString(CalcTF)+"]";
   IndicatorSetString(INDICATOR_SHORTNAME,BaseName); IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   string prefix="VWAPEX_"+IntegerToString(GetTickCount64())+"_"+IntegerToString(GetMicrosecondCount())+"_";
   PriceName=prefix+"PRICE";
   BaseName+=" ["+prefix+"]";
   IndicatorSetString(INDICATOR_SHORTNAME,BaseName);
   View.Init(prefix,"VWAP",InpInstanceTag,InpShowToggle,InpStartVisible,InpButtonRight,InpButtonTop);
   if(!View.visible) for(int i=0;i<7;i++) PlotIndexSetInteger(i,PLOT_DRAW_TYPE,DRAW_NONE);
   EventSetTimer(1); return INIT_SUCCEEDED;
}

int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],const double &high[],
                const double &low[],const double &close[],const long &ticks[],const long &volume[],const int &spread[])
{
   ArraySetAsSeries(time,false); return Calculate(total,previous,time);
}

void OnTimer()
{
   if(View.Click(-1,"")) ApplyVisibility();
   View.Draw();
   if(Pending)
   {
      datetime times[]; int n=CopyTime(_Symbol,_Period,0,Bars(_Symbol,_Period),times);
      if(n>0 && n==ArraySize(Main)) { ArraySetAsSeries(times,false); Calculate(n,LastTotal,times); }
   }
   PriceLabel();
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(View.Click(id,sparam)) { ApplyVisibility(); return; }
   if(id==CHARTEVENT_CHART_CHANGE) { View.Draw(); LabelDirty=true; PriceLabel(); }
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   View.Finish(reason);
   if(PriceName!="") ObjectDelete(0,PriceName);
}
