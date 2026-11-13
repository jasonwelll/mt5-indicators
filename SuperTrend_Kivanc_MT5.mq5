// This Source Code Form is subject to the Mozilla Public License, v. 2.0.
// https://mozilla.org/MPL/2.0/
// Original: KivancOzbilgic's Supertrend, publication r6dAP7yi, version 3.
// Source credits everget (Alex Orekhov). Independent MQL5 port: Codex, 2026.
#property copyright "KivancOzbilgic; independent MQL5 adaptation by Codex"
#property link "https://www.tradingview.com/script/r6dAP7yi/"
#property version "1.11"
#property description "Kivanc Supertrend: RMA/SMA ATR, price sources, confirmed signals and optional live preview. No trading."
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots 10
#include "SuperTrend_KO_Core.mqh"
#include "Chart_Visibility.mqh"

enum STTiming { Close_Confirmed=0,Intrabar_Preview=1 };
enum STLineMode { Straight_Breaks=0,Staircase_Breaks=1 };
input group "Calculation"
input int InpATRPeriod=10;
input STPrice InpSource=Source_HL2;
input double InpMultiplier=3.0;
input STATRMethod InpATRMethod=ATR_RMA;
input ENUM_TIMEFRAMES InpCalculationTimeframe=PERIOD_CURRENT;
input int InpHistoryBars=20000;
input group "Signals"
input STTiming InpSignalTiming=Close_Confirmed;
input bool InpShowSignals=true;
input bool InpShowMarkers=true;
input int InpMaxLabels=200;
input bool InpPopupAlerts=false;
input group "Appearance"
input bool InpHighlight=true;
input color InpUpColor=C'0,170,110';
input color InpDownColor=C'235,70,95';
input int InpLineWidth=2;
input int InpFillTransparency=90;
input int InpLabelSize=8;
input group "Line display"
input STLineMode InpLineMode=Staircase_Breaks;
input bool InpShowPriceLabel=true;
input bool InpShowPriceLine=true;
input group "Chart visibility button (top right)"
input bool InpShowToggle=true;
input bool InpStartVisible=true;
input int InpButtonRight=16;
input int InpButtonTop=28;
input string InpInstanceTag="ST";

double Up[],Down[],Buy[],Sell[],FillUpA[],FillUpB[],FillDownA[],FillDownB[],Trend[],Signal[],Line[],ATR[];
STKernel Kernel;
MqlRates SourceRates[];
STPoint Points[];
ENUM_TIMEFRAMES CalcTF;
int CachedBars=-1,LastTotal=0;
datetime CachedLive=0,LastChartBar=0,LastAlertBar=0;
bool Pending=false,ThemeReady=false;
string Prefix="";
CVView View;
color LastBackground=clrNONE;
color HiddenColors[6][2];
bool ColorsHidden=false;
ulong LabelFrame=0;
struct STLabel { string name; datetime time; double price; int side; ulong seen; };
STLabel Labels[];
datetime DisplayTimes[];
bool DisplayDirty=true;
ulong DrawingFrame=0;
struct STDrawing
{
   string name;
   datetime first,last;
   double a,b;
   int side;
   bool initialized;
   ulong seen;
};
STDrawing Drawings[];

int DrawingSlot(const string id,const ENUM_OBJECT type)
{
   string name=Prefix+id; int lo=0,hi=ArraySize(Drawings);
   while(lo<hi)
   { int mid=(lo+hi)/2; if(StringCompare(Drawings[mid].name,name)<0) lo=mid+1; else hi=mid; }
   int n=ArraySize(Drawings);
   if(lo==n || Drawings[lo].name!=name)
   {
      ArrayResize(Drawings,n+1,500);
      for(int i=n;i>lo;i--) Drawings[i]=Drawings[i-1];
      ZeroMemory(Drawings[lo]); Drawings[lo].name=name;
   }
   Drawings[lo].seen=DrawingFrame;
   if(!Drawings[lo].initialized)
   {
      bool ok=type==OBJ_TREND?ObjectCreate(0,name,type,0,0,0,0,0):ObjectCreate(0,name,type,0,0,0);
      if(!ok) return -1;
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      if(type==OBJ_TREND)
      { ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false); ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,id=="PRICE_LINE"); }
      ObjectSetInteger(0,name,OBJPROP_WIDTH,id=="PRICE_LINE"?1:InpLineWidth);
      ObjectSetInteger(0,name,OBJPROP_STYLE,id=="PRICE_LINE"?STYLE_DOT:STYLE_SOLID);
      View.Object(name);
   }
   return lo;
}
bool Drawing(const string id,const datetime first,const double a,const datetime last,const double b,
             const int side,const bool priceLabel=false)
{
   int i=DrawingSlot(id,priceLabel?OBJ_ARROW_RIGHT_PRICE:OBJ_TREND); if(i<0) return false;
   STDrawing old=Drawings[i];
   bool changed=!old.initialized || old.first!=first || old.last!=last || old.a!=a || old.b!=b || old.side!=side;
   if(!old.initialized || old.first!=first || old.a!=a) ObjectMove(0,old.name,0,first,a);
   if(!priceLabel && (!old.initialized || old.last!=last || old.b!=b)) ObjectMove(0,old.name,1,last,b);
   if(!old.initialized || old.side!=side) ObjectSetInteger(0,old.name,OBJPROP_COLOR,side==1?InpUpColor:InpDownColor);
   if(changed) ObjectSetString(0,old.name,OBJPROP_TOOLTIP,"Supertrend "+(InpSignalTiming==Close_Confirmed?"confirmed":"preview")+
      " reference | "+DoubleToString(a,_Digits));
   Drawings[i].first=first; Drawings[i].last=last; Drawings[i].a=a; Drawings[i].b=b;
   Drawings[i].side=side; Drawings[i].initialized=true; return changed;
}
void RenderDisplay()
{
   if(!DisplayDirty || LastTotal<1 || ArraySize(DisplayTimes)!=LastTotal) return;
   DisplayDirty=false; DrawingFrame++; bool changed=false;
   int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR),visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   int start=MathMax(0,LastTotal-2-first),end=MathMin(LastTotal-1,start+MathMax(1,visible)+3);
   int seconds=PeriodSeconds(_Period);
   if(InpLineMode==Staircase_Breaks)
      for(int i=start;i<=end;i++)
      {
         if(Line[i]==EMPTY_VALUE || Trend[i]==EMPTY_VALUE) continue;
         datetime right=i+1<LastTotal?DisplayTimes[i+1]:DisplayTimes[i]+seconds;
         changed=Drawing("STEP_H_"+IntegerToString(DisplayTimes[i]),DisplayTimes[i],Line[i],right,Line[i],(int)Trend[i]) || changed;
         // A reversal starts a new run: never bridge the two colored tracks.
         if(i>0 && Line[i-1]!=EMPTY_VALUE && Trend[i-1]==Trend[i] && Line[i-1]!=Line[i])
            changed=Drawing("STEP_V_"+IntegerToString(DisplayTimes[i]),DisplayTimes[i],Line[i-1],DisplayTimes[i],Line[i],(int)Trend[i]) || changed;
      }
   int last=LastTotal-1,rightShift=first-visible+1;
   if(rightShift<=0 && Line[last]!=EMPTY_VALUE && Trend[last]!=EMPTY_VALUE)
   {
      datetime edge=DisplayTimes[last]+MathMax(0,-rightShift-2)*seconds;
      if(InpShowPriceLabel) changed=Drawing("PRICE_LABEL",edge,Line[last],0,0,(int)Trend[last],true) || changed;
      if(InpShowPriceLine) changed=Drawing("PRICE_LINE",DisplayTimes[last],Line[last],DisplayTimes[last]+seconds,Line[last],(int)Trend[last]) || changed;
   }
   for(int i=ArraySize(Drawings)-1;i>=0;i--)
      if(Drawings[i].seen!=DrawingFrame) { ObjectDelete(0,Drawings[i].name); ArrayRemove(Drawings,i,1); changed=true; }
   if(changed) ChartRedraw(0);
}

color STBlend(const color ink,const color background)
{
   double a=(100.0-InpFillTransparency)/100; uint i=(uint)ink,b=(uint)background;
   int r=(int)MathRound((i&255)*a+(b&255)*(1-a));
   int g=(int)MathRound(((i>>8)&255)*a+((b>>8)&255)*(1-a));
   int blue=(int)MathRound(((i>>16)&255)*a+((b>>16)&255)*(1-a));
   return (color)(r|(g<<8)|(blue<<16));
}
void Theme()
{
   color background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   if(ThemeReady && background==LastBackground) return;
   for(int i=4;i<6;i++)
      for(int c=0;c<2;c++)
      {
         color shade=STBlend(i==4?InpUpColor:InpDownColor,background);
         if(ColorsHidden) HiddenColors[i][c]=shade;
         else PlotIndexSetInteger(i,PLOT_LINE_COLOR,c,shade);
      }
   LastBackground=background; ThemeReady=true;
}
void PlotVisibility()
{
   if(ColorsHidden==!View.visible) return;
   // Keep the two-buffer filling plots intact so CopyBuffer indices stay stable.
   for(int i=0;i<6;i++)
      for(int c=0;c<(i<4?1:2);c++)
      {
         if(!View.visible) HiddenColors[i][c]=(color)PlotIndexGetInteger(i,PLOT_LINE_COLOR,c);
         PlotIndexSetInteger(i,PLOT_LINE_COLOR,c,View.visible?HiddenColors[i][c]:clrNONE);
      }
   ColorsHidden=!View.visible;
}
void ClearBar(const int i)
{
   Up[i]=EMPTY_VALUE; Down[i]=EMPTY_VALUE; Buy[i]=EMPTY_VALUE; Sell[i]=EMPTY_VALUE;
   FillUpA[i]=0; FillUpB[i]=0; FillDownA[i]=0; FillDownB[i]=0;
   Trend[i]=EMPTY_VALUE; Signal[i]=0; Line[i]=EMPTY_VALUE; ATR[i]=EMPTY_VALUE;
}
void WritePoint(const int i,const STPoint &p,const int event,const bool confirmed)
{
   ClearBar(i); if(!p.valid) return;
   Trend[i]=p.direction; Line[i]=p.line; ATR[i]=p.atr;
   Signal[i]=confirmed?event:0;
   if(p.direction==1) Up[i]=p.lower; else Down[i]=p.upper;
   if(InpHighlight)
   {
      if(p.direction==1) { FillUpA[i]=p.mid; FillUpB[i]=p.lower; }
      else { FillDownA[i]=p.mid; FillDownB[i]=p.upper; }
   }
   if(InpShowMarkers && (confirmed || InpSignalTiming==Intrabar_Preview))
   { if(event==1) Buy[i]=p.line; else if(event==-1) Sell[i]=p.line; }
}
bool LoadSource(const bool force)
{
   MqlRates latest[]; int bars=Bars(_Symbol,CalcTF);
   int fetched=CopyRates(_Symbol,CalcTF,0,2,latest);
   if(fetched<1) return false;
   MqlRates live=latest[fetched-1];
   if(force || CachedBars!=bars || CachedLive!=live.time || ArraySize(Points)<1)
   {
      int wanted=MathMin(bars,InpHistoryBars);
      if(wanted<1 || CopyRates(_Symbol,CalcTF,0,wanted,SourceRates)!=wanted) return false;
      ArraySetAsSeries(SourceRates,false); ArrayResize(Points,wanted);
      Kernel.Reset(InpATRPeriod,InpMultiplier,InpATRMethod,InpSource);
      for(int i=0;i<wanted-1;i++) Points[i]=Kernel.Step(SourceRates[i]);
      Points[wanted-1]=Kernel.Step(SourceRates[wanted-1],false);
      CachedBars=bars; CachedLive=live.time;
   }
   else
   {
      int i=ArraySize(Points)-1; SourceRates[i]=live;
      Points[i]=Kernel.Step(live,false);
   }
   return true;
}
void Label(const datetime time,const double price,const int side)
{
   string name=Prefix+IntegerToString(time); int slot=-1;
   for(int i=0;i<ArraySize(Labels);i++) if(Labels[i].name==name) { slot=i; break; }
   bool fresh=slot<0;
   if(fresh)
   {
      slot=ArraySize(Labels); ArrayResize(Labels,slot+1); ZeroMemory(Labels[slot]); Labels[slot].name=name;
      if(!ObjectCreate(0,name,OBJ_TEXT,0,time,price)) { ArrayResize(Labels,slot); return; }
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpLabelSize); ObjectSetString(0,name,OBJPROP_FONT,"Arial");
      View.Object(name);
   }
   if(fresh || Labels[slot].price!=price || Labels[slot].time!=time) ObjectMove(0,name,0,time,price);
   if(fresh || Labels[slot].side!=side)
   {
      ObjectSetString(0,name,OBJPROP_TEXT,side==1?" Buy":" Sell");
      ObjectSetInteger(0,name,OBJPROP_COLOR,side==1?InpUpColor:InpDownColor);
      ObjectSetInteger(0,name,OBJPROP_ANCHOR,side==1?ANCHOR_LEFT_UPPER:ANCHOR_LEFT_LOWER);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"Supertrend "+(side==1?"Buy":"Sell")+" | "+TimeToString(time)+" | "+DoubleToString(price,_Digits));
   }
   Labels[slot].time=time; Labels[slot].price=price; Labels[slot].side=side; Labels[slot].seen=LabelFrame;
}
void RenderLabels(const datetime &time[],const int total,const int liveEvent)
{
   LabelFrame++; int used=0;
   if(InpShowSignals)
      for(int i=total-1;i>=0 && used<InpMaxLabels;i--)
      {
         int event=(int)Signal[i];
         if(i==total-1 && InpSignalTiming==Intrabar_Preview) event=liveEvent;
         if(event==0 || Line[i]==EMPTY_VALUE) continue;
         Label(time[i],Line[i],event); used++;
      }
   for(int i=ArraySize(Labels)-1;i>=0;i--)
      if(Labels[i].seen!=LabelFrame) { ObjectDelete(0,Labels[i].name); ArrayRemove(Labels,i,1); }
}
int Calculate(const int total,const int previous,const datetime &time[])
{
   if(total<1) return 0;
   bool sourceMoved=CachedLive!=iTime(_Symbol,CalcTF,0) || CachedBars!=Bars(_Symbol,CalcTF);
   bool rebuild=previous==0 || total!=LastTotal || time[total-1]!=LastChartBar || sourceMoved;
   if(!LoadSource(previous==0))
   {
      Pending=true;
      if(previous==0 && LastTotal==0) for(int i=0;i<total;i++) ClearBar(i);
      return LastTotal==total?LastTotal:previous;
   }
   Pending=false;
   int start=rebuild?0:total-1,last=ArraySize(Points)-1,liveEvent=0;
   bool same=CalcTF==(ENUM_TIMEFRAMES)_Period;
   int mapped=-1,previousMapped=-1;
   if(start>0)
   {
      datetime cutoff=time[start-1]+PeriodSeconds(_Period);
      previousMapped=same?-1:STClosedIndex(SourceRates,cutoff);
      if(!same) mapped=previousMapped;
   }
   for(int i=start;i<total;i++)
   {
      bool closed=i<total-1; ClearBar(i);
      if(same)
      {
         if(start==total-1) mapped=last;
         else
         {
            while(mapped+1<=last && SourceRates[mapped+1].time<=time[i]) mapped++;
            if(mapped<0 || SourceRates[mapped].time!=time[i]) continue;
         }
         STPoint p=Points[mapped];
         if(!closed && InpSignalTiming==Close_Confirmed)
         {
            // Hold the last confirmed state on the unfinished candle.
            if(mapped<1) continue;
            WritePoint(i,Points[mapped-1],0,false);
         }
         else
         {
            WritePoint(i,p,p.signal,closed);
            if(!closed) liveEvent=p.signal;
         }
      }
      else
      {
         datetime cutoff=closed?time[i]+PeriodSeconds(_Period):time[i];
         mapped=STClosedIndex(SourceRates,cutoff,mapped);
         if(mapped>=0)
         {
            int event=mapped!=previousMapped?Points[mapped].signal:0;
            WritePoint(i,Points[mapped],event,closed);
         }
         if(!closed && InpSignalTiming==Intrabar_Preview && SourceRates[last].time<=time[i])
         { WritePoint(i,Points[last],Points[last].signal,false); liveEvent=Points[last].signal; }
      }
      previousMapped=mapped;
   }
   if(rebuild || InpSignalTiming==Intrabar_Preview) RenderLabels(time,total,liveEvent);
   if(InpPopupAlerts && total>1)
   {
      if(LastAlertBar!=0 && LastAlertBar!=time[total-2] && Signal[total-2]!=0)
         Alert(_Symbol," ",EnumToString(CalcTF)," Supertrend ",Signal[total-2]>0?"Buy":"Sell"," (closed)");
      LastAlertBar=time[total-2];
   }
   if(rebuild) ArrayCopy(DisplayTimes,time);
   if(rebuild || InpSignalTiming==Intrabar_Preview) DisplayDirty=true;
   LastTotal=total; LastChartBar=time[total-1]; return total;
}
void ApplyVisibility()
{
   PlotVisibility();
   for(int i=0;i<ArraySize(Drawings);i++) View.Object(Drawings[i].name);
   for(int i=0;i<ArraySize(Labels);i++) View.Object(Labels[i].name);
   DisplayDirty=true; RenderDisplay(); View.Draw(); ChartRedraw(0);
}
int OnInit()
{
   CalcTF=InpCalculationTimeframe==PERIOD_CURRENT?(ENUM_TIMEFRAMES)_Period:InpCalculationTimeframe;
   if(InpATRPeriod<1 || InpATRPeriod>5000 || !MathIsValidNumber(InpMultiplier) || InpMultiplier<=0 || InpMultiplier>100 ||
      InpHistoryBars<InpATRPeriod+2 || InpHistoryBars>100000 || InpLineWidth<1 || InpLineWidth>5 ||
      InpFillTransparency<0 || InpFillTransparency>100 || InpLabelSize<6 || InpLabelSize>16 || InpMaxLabels<0 || InpMaxLabels>1000 ||
      PeriodSeconds(CalcTF)<PeriodSeconds(_Period) || InpButtonRight<0 || InpButtonRight>10000 ||
      InpButtonTop<0 || InpButtonTop>10000) return INIT_PARAMETERS_INCORRECT;
   Prefix="STKO_"+IntegerToString(GetTickCount64())+"_"+IntegerToString(GetMicrosecondCount())+"_";
   View.Init(Prefix,"ST",InpInstanceTag,InpShowToggle,InpStartVisible,InpButtonRight,InpButtonTop);
   SetIndexBuffer(0,Up,INDICATOR_DATA); SetIndexBuffer(1,Down,INDICATOR_DATA);
   SetIndexBuffer(2,Buy,INDICATOR_DATA); SetIndexBuffer(3,Sell,INDICATOR_DATA);
   SetIndexBuffer(4,FillUpA,INDICATOR_DATA); SetIndexBuffer(5,FillUpB,INDICATOR_DATA);
   SetIndexBuffer(6,FillDownA,INDICATOR_DATA); SetIndexBuffer(7,FillDownB,INDICATOR_DATA);
   SetIndexBuffer(8,Trend,INDICATOR_DATA); SetIndexBuffer(9,Signal,INDICATOR_DATA);
   SetIndexBuffer(10,Line,INDICATOR_DATA); SetIndexBuffer(11,ATR,INDICATOR_DATA);
   // Chronological buffers match the terminal's ascending time array explicitly.
   ArraySetAsSeries(Up,false); ArraySetAsSeries(Down,false); ArraySetAsSeries(Buy,false); ArraySetAsSeries(Sell,false);
   ArraySetAsSeries(FillUpA,false); ArraySetAsSeries(FillUpB,false); ArraySetAsSeries(FillDownA,false); ArraySetAsSeries(FillDownB,false);
   ArraySetAsSeries(Trend,false); ArraySetAsSeries(Signal,false); ArraySetAsSeries(Line,false); ArraySetAsSeries(ATR,false);
   string labels[]={"Up Trend","Down Trend","Buy Begins","Sell Begins","Up Highlight","Down Highlight","Direction (1/-1)","Confirmed signal (1/-1/0)","Supertrend","ATR"};
   for(int i=0;i<10;i++)
   {
      PlotIndexSetString(i,PLOT_LABEL,labels[i]);
      PlotIndexSetInteger(i,PLOT_DRAW_TYPE,i<2?(InpLineMode==Staircase_Breaks?DRAW_NONE:DRAW_LINE):i<4?DRAW_ARROW:i<6?DRAW_FILLING:DRAW_NONE);
      // DRAW_FILLING skips paired zeros, but bridges values marked as empty.
      PlotIndexSetDouble(i,PLOT_EMPTY_VALUE,EMPTY_VALUE);
      if(i==4 || i==5) PlotIndexSetInteger(i,PLOT_COLOR_INDEXES,2);
      if(i<4) PlotIndexSetInteger(i,PLOT_LINE_COLOR,i%2==0?InpUpColor:InpDownColor);
      if(i<2) PlotIndexSetInteger(i,PLOT_LINE_WIDTH,InpLineWidth);
      if(i==2 || i==3) { PlotIndexSetInteger(i,PLOT_ARROW,159); PlotIndexSetInteger(i,PLOT_LINE_WIDTH,2); }
   }
   PlotVisibility();
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   IndicatorSetString(INDICATOR_SHORTNAME,"Supertrend KO MT5 v1.11 ["+EnumToString(CalcTF)+" "+(InpSignalTiming==Close_Confirmed?"Closed":"Preview")+"] ["+Prefix+"]");
   // Defer synchronous chart reads until after template/indicator initialization.
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
   Theme();
   if(Pending)
   {
      datetime times[]; int total=CopyTime(_Symbol,_Period,0,Bars(_Symbol,_Period),times);
      if(total>0) { ArraySetAsSeries(times,false); Calculate(total,LastTotal,times); }
   }
   RenderDisplay();
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(View.Click(id,sparam)) { ApplyVisibility(); return; }
   if(id==CHARTEVENT_CHART_CHANGE) { View.Draw(); Theme(); DisplayDirty=true; RenderDisplay(); }
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   View.Finish(reason);
   for(int i=0;i<ArraySize(Labels);i++) ObjectDelete(0,Labels[i].name);
   for(int i=0;i<ArraySize(Drawings);i++) ObjectDelete(0,Drawings[i].name);
}
