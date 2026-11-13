#property copyright "Independent MT5 implementation by Codex, 2026"
#property version "1.02"
#property description "Initial Balance from M1 quotes. New York RTH by default; configurable clock and duration. No trading."
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots 0
#include "IB_RTH_Core.mqh"
#include "IB_RTH_Objects.mqh"
#include "Chart_Visibility.mqh"

input group "Session - start and close use the selected clock"
input IBClock InpSessionClock=New_York_Time;
input int InpStartHour=9;
input int InpStartMinute=30;
input int InpIBMinutes=60;
input int InpSessionEndHour=16;
input int InpSessionEndMinute=0;
input bool InpWeekdaysOnly=true;
input group "Broker timestamp conversion"
input IBServerClock InpServerClock=FTMO_US_DST;
input int InpServerStandardUTCMinutes=120;
input group "Display"
input int InpHistoryDays=7;
input bool InpShowDeveloping=true;
input bool InpExtendToSessionEnd=true;
input bool InpShowMidpoint=true;
input bool InpShowPriceLabels=true;
input bool InpLabelHistory=false;
input bool InpShowStatus=false;
input color InpHighColor=C'235,90,100';
input color InpLowColor=C'0,155,125';
input color InpMidColor=C'65,135,210';
input int InpLineWidth=2;
input ENUM_LINE_STYLE InpHighLowStyle=STYLE_SOLID;
input ENUM_LINE_STYLE InpMidStyle=STYLE_DASH;
input int InpLabelFontSize=10;
input group "Chart visibility button (top right)"
input bool InpShowToggle=true;
input bool InpStartVisible=true;
input int InpButtonRight=16;
input int InpButtonTop=28;
input string InpInstanceTag="IB";

MqlRates Source[];
IBWindow Windows[];
IBRange Ranges[];
string Prefix="",ShortName="";
CVView View;
datetime CachedMinute=0,CachedDate=0,AsOf=0;
ulong LastRefresh=0;
bool Pending=true,DrawingDirty=true,Cleaned=false;
string State="Loading M1 history";

void SetInt(const string name,const ENUM_OBJECT_PROPERTY_INTEGER prop,const long value)
{ if(ObjectGetInteger(0,name,prop)!=value) ObjectSetInteger(0,name,prop,value); }
void SetText(const string name,const ENUM_OBJECT_PROPERTY_STRING prop,const string value)
{ if(ObjectGetString(0,name,prop)!=value) ObjectSetString(0,name,prop,value); }
void MovePoint(const string name,const int point,const datetime time,const double price)
{
   if(ObjectGetInteger(0,name,OBJPROP_TIME,point)!=(long)time || ObjectGetDouble(0,name,OBJPROP_PRICE,point)!=price)
      ObjectMove(0,name,point,time,price);
}
void BasicObject(const string name,const color shade)
{
   SetInt(name,OBJPROP_COLOR,shade); SetInt(name,OBJPROP_SELECTABLE,false);
   SetInt(name,OBJPROP_SELECTED,false); SetInt(name,OBJPROP_HIDDEN,false);
   SetInt(name,OBJPROP_BACK,false);
   View.Object(name);
}
void Line(const string name,const datetime start,const datetime end,const double price,const color shade,
          const ENUM_LINE_STYLE style,const int width,const string tip)
{
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_TREND,0,start,price,end,price)) return;
   MovePoint(name,0,start,price); MovePoint(name,1,end,price); BasicObject(name,shade);
   SetInt(name,OBJPROP_RAY_LEFT,false); SetInt(name,OBJPROP_RAY_RIGHT,false);
   SetInt(name,OBJPROP_WIDTH,width); SetInt(name,OBJPROP_STYLE,style);
   SetText(name,OBJPROP_TOOLTIP,tip);
}
datetime VisibleRight()
{
   int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR);
   int visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   int shift=first-visible+3;
   datetime t=iTime(_Symbol,_Period,MathMax(0,shift));
   return t+MathMax(0,-shift)*PeriodSeconds(_Period);
}
void Label(const string name,const datetime time,const double price,const color shade,const string text,
           const ENUM_ANCHOR_POINT anchor,const string tip)
{
   if(ObjectFind(0,name)<0 && !ObjectCreate(0,name,OBJ_TEXT,0,time,price)) return;
   MovePoint(name,0,time,price); BasicObject(name,shade);
   SetInt(name,OBJPROP_ANCHOR,anchor); SetInt(name,OBJPROP_FONTSIZE,InpLabelFontSize);
   SetText(name,OBJPROP_FONT,"Arial"); SetText(name,OBJPROP_TEXT,text); SetText(name,OBJPROP_TOOLTIP,tip);
}
bool Wanted(const string name,string &keep[])
{
   for(int i=0;i<ArraySize(keep);i++) if(keep[i]==name) return true;
   return false;
}
void Keep(string &names[],const string name)
{ int n=ArraySize(names); ArrayResize(names,n+1); names[n]=name; }
string ClockName()
{ return InpSessionClock==New_York_Time?"NY":InpSessionClock==Broker_Server_Time?"Server":"UTC"; }
void Render()
{
   if(Prefix=="") return;
   string keep[];
   Keep(keep,Prefix+"Toggle");
   datetime right=VisibleRight(); int latest=-1;
   for(int i=0;i<ArraySize(Ranges);i++) if(Ranges[i].valid) latest=i;
   for(int i=0;i<ArraySize(Ranges);i++)
   {
      IBRange r=Ranges[i]; IBWindow w=Windows[i];
      if(!r.valid || (!r.complete && !InpShowDeveloping)) continue;
      datetime end=InpExtendToSessionEnd?w.close:MathMin(AsOf,w.finish);
      if(end<=w.start) end=w.start+1;
      string key=Prefix+IntegerToString((long)w.date)+"_";
      string tip="IB RTH "+_Symbol+" | "+TimeToString(w.date,TIME_DATE)+" | "+ClockName()+
         StringFormat(" %02d:%02d + %d min",InpStartHour,InpStartMinute,InpIBMinutes)+
         " | Server "+TimeToString(w.start,TIME_MINUTES)+"-"+TimeToString(w.finish,TIME_MINUTES)+
         " | "+(r.complete?"Fixed":"Developing")+" | M1 bars: "+IntegerToString(r.bars);
      string roles[]={"IBH","IBL","IBM"};
      double prices[]={r.high,r.low,r.middle};
      color shades[]={InpHighColor,InpLowColor,InpMidColor};
      for(int j=0;j<3;j++)
      {
         if(j==2 && !InpShowMidpoint) continue;
         string name=key+roles[j];
         Line(name,w.start,end,prices[j],shades[j],j==2?InpMidStyle:InpHighLowStyle,j==2?1:InpLineWidth,tip);
         Keep(keep,name);
         if(InpShowPriceLabels && (InpLabelHistory || i==latest))
         {
            datetime edge=MathMax(w.start,MathMin(end,right));
            string text=roles[j]+" "+DoubleToString(prices[j],_Digits)+(r.complete?"":" *");
            if(InpLabelHistory) text=TimeToString(w.date,TIME_DATE)+" "+text;
            Label(name+"_T",edge,prices[j],shades[j],text,j==1?ANCHOR_RIGHT_UPPER:ANCHOR_RIGHT_LOWER,tip);
            Keep(keep,name+"_T");
         }
      }
   }
   if(InpShowStatus)
   {
      string name=Prefix+"Status";
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      BasicObject(name,InpMidColor); SetInt(name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      SetInt(name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); SetInt(name,OBJPROP_XDISTANCE,8);
      SetInt(name,OBJPROP_YDISTANCE,24); SetInt(name,OBJPROP_FONTSIZE,9);
      SetText(name,OBJPROP_FONT,"Arial");
      string state=State;
      if(state=="" && latest>=0) state=TimeToString(Windows[latest].date,TIME_DATE)+" "+
         (Ranges[latest].complete?"Fixed":"Developing *");
      SetText(name,OBJPROP_TEXT,"IB | "+ClockName()+StringFormat(" %02d:%02d + %d min | ",InpStartHour,InpStartMinute,InpIBMinutes)+state);
      SetText(name,OBJPROP_TOOLTIP,"Initial Balance from available broker M1 quotes. * = developing. "+
         "No exchange holiday or early-close calendar. "+(Pending?"Retrying history download.":""));
      Keep(keep,name);
   }
   // Remove only obsolete objects owned by this particular indicator instance.
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,Prefix)==0 && !Wanted(name,keep)) ObjectDelete(0,name);
   }
   DrawingDirty=false; ChartRedraw(0);
}
void ApplyVisibility()
{
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,Prefix)==0 && name!=Prefix+"Toggle") View.Object(name);
   }
   View.Draw(); ChartRedraw(0);
}

bool RefreshSource()
{
   MqlRates latest[];
   if(CopyRates(_Symbol,PERIOD_M1,0,1,latest)!=1) return false;
   datetime utc=0;
   if(!IBServerToUTC(latest[0].time,InpServerClock,InpServerStandardUTCMinutes,utc)) return false;
   datetime date=IBDay(IBUTCToLocal(utc,InpSessionClock,InpServerClock,InpServerStandardUTCMinutes));
   datetime clock=TimeCurrent();
   // A quiet/disconnected market must not advance the range past the available quotes.
   AsOf=clock>=latest[0].time && clock<latest[0].time+60?clock:latest[0].time+59;
   if(Pending || latest[0].time!=CachedMinute || date!=CachedDate || ArraySize(Source)==0)
   {
      IBWindow oldest;
      if(!IBMakeWindow(date-InpHistoryDays*86400,InpSessionClock,InpServerClock,InpServerStandardUTCMinutes,
         InpStartHour*60+InpStartMinute,InpIBMinutes,InpSessionEndHour*60+InpSessionEndMinute,oldest))
         return false;
      int copied=CopyRates(_Symbol,PERIOD_M1,oldest.start-86400,latest[0].time,Source);
      if(copied<1 || !SeriesInfoInteger(_Symbol,PERIOD_M1,SERIES_SYNCHRONIZED)) return false;
      ArraySetAsSeries(Source,false);
      if(Source[copied-1].time!=latest[0].time) return false;
      CachedMinute=latest[0].time; CachedDate=date;
   }
   else Source[ArraySize(Source)-1]=latest[0];
   ArrayResize(Windows,0); ArrayResize(Ranges,0);
   int incomplete=0;
   for(int day=InpHistoryDays;day>=0;day--)
   {
      datetime localDate=date-day*86400;
      if(InpWeekdaysOnly && !IBWeekday(localDate)) continue;
      IBWindow w;
      if(!IBMakeWindow(localDate,InpSessionClock,InpServerClock,InpServerStandardUTCMinutes,
         InpStartHour*60+InpStartMinute,InpIBMinutes,InpSessionEndHour*60+InpSessionEndMinute,w)) continue;
      IBRange r=IBMeasure(Source,w,AsOf);
      if(r.bars>0 && !r.covered) incomplete++;
      if(!r.valid) continue;
      int n=ArraySize(Windows); ArrayResize(Windows,n+1); ArrayResize(Ranges,n+1);
      Windows[n]=w; Ranges[n]=r;
   }
   State=ArraySize(Ranges)==0?"No IB data in the selected window":incomplete>0?"Oldest session: incomplete M1 history":"";
   Pending=false; DrawingDirty=true; return true;
}
void Refresh(const bool force=false)
{
   ulong now=GetTickCount64();
   if(!force && now-LastRefresh<1000) return;
   LastRefresh=now;
   if(!RefreshSource())
   {
      Pending=true; State="Loading M1 history"; DrawingDirty=true;
   }
   if(DrawingDirty) Render();
}
int OnInit()
{
   int start=InpStartHour*60+InpStartMinute,end=InpSessionEndHour*60+InpSessionEndMinute;
   int span=(end-start+1440)%1440; if(span==0) span=1440;
   if(InpStartHour<0 || InpStartHour>23 || InpStartMinute<0 || InpStartMinute>59 ||
      InpSessionEndHour<0 || InpSessionEndHour>23 || InpSessionEndMinute<0 || InpSessionEndMinute>59 ||
      InpIBMinutes<1 || InpIBMinutes>span || InpHistoryDays<0 || InpHistoryDays>30 ||
      InpServerStandardUTCMinutes<-720 || InpServerStandardUTCMinutes>840 ||
      (int)InpSessionClock<0 || (int)InpSessionClock>2 || (int)InpServerClock<0 || (int)InpServerClock>2 ||
      InpLineWidth<1 || InpLineWidth>5 || InpLabelFontSize<7 || InpLabelFontSize>24 ||
      PeriodSeconds(_Period)>=86400 || InpButtonRight<0 || InpButtonRight>10000 ||
      InpButtonTop<0 || InpButtonTop>10000)
   {
      Print("IB RTH: use an intraday chart, valid clock times, IB duration <= session length, history 0..30 days.");
      return INIT_PARAMETERS_INCORRECT;
   }
   Prefix="IBR_"+IntegerToString(GetTickCount64())+"_"+IntegerToString(GetMicrosecondCount())+"_";
   View.Init(Prefix,"IB",InpInstanceTag,InpShowToggle,InpStartVisible,InpButtonRight,InpButtonTop);
   ShortName="IB RTH v1.02 ["+ClockName()+StringFormat(" %02d:%02d / %dm",InpStartHour,InpStartMinute,InpIBMinutes)+"] ["+Prefix+"]";
   IndicatorSetString(INDICATOR_SHORTNAME,ShortName); IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   EventSetTimer(1); return INIT_SUCCEEDED;
}
int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],const double &high[],
   const double &low[],const double &close[],const long &ticks[],const long &volume[],const int &spread[])
{ Refresh(previous==0); return total; }
void OnTimer()
{
   if(View.Click(-1,"")) ApplyVisibility();
   View.Draw();
   if(!Cleaned) { IBCleanOrphans(0,Prefix); Cleaned=true; }
   Refresh();
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(View.Click(id,sparam)) { ApplyVisibility(); return; }
   if(id==CHARTEVENT_CHART_CHANGE) { View.Draw(); Render(); }
}
void OnDeinit(const int reason)
{
   EventKillTimer();
   View.Finish(reason);
   if(Prefix!="") ObjectsDeleteAll(0,Prefix);
   ChartRedraw(0);
}
