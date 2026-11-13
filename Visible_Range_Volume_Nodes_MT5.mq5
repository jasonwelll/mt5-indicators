// This Source Code Form is subject to the Mozilla Public License, v. 2.0.
// https://mozilla.org/MPL/2.0/
// Original calculation: Visible Range Volume Nodes, Crypto_Imperija.
// Independent MQL5 port and retained renderer: Codex, 2026.
#property copyright "Original: Crypto_Imperija; MQL5 adaptation: Codex"
#property link "https://www.tradingview.com/script/VoKAfPNW-Visible-Range-Volume-Nodes/"
#property version "1.02"
#property description "Visible-range bar-volume estimate. Tick and real volume are explicit, never silently substituted."
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots 6
#include "VP_Nodes_Core.mqh"
#include "VP_Objects.mqh"
#include "Chart_Visibility.mqh"

enum VPVolume { Tick_Volume=0,Real_Trade_Volume=1 };
enum VPSide { Left_Side=0,Right_Side=1 };
enum VPDirection { Extend_Right=0,Extend_Left=1 };
input group "Volume Profile"
input VPVolume InpVolumeSource=Tick_Volume;
input int InpRows=200;
input int InpMaxLookback=5000;
input VPSide InpPanelSide=Left_Side;
input VPDirection InpDirection=Extend_Right;
input double InpWidthPercent=31.0;
input int InpPaddingPixels=8;
input group "POC and Value Area"
input double InpValueAreaPercent=70.0;
input bool InpShowPOC=true;
input int InpPOCWidth=2;
input ENUM_LINE_STYLE InpPOCStyle=STYLE_SOLID;
input bool InpShowVA=true;
input int InpVAWidth=1;
input ENUM_LINE_STYLE InpVAStyle=STYLE_DASH;
input group "HVN and LVN Zones"
input bool InpShowHVN=true;
input bool InpShowLVN=true;
input group "Labels"
input bool InpShowLabels=true;
input bool InpShowPrices=true;
input int InpFontSize=9;
input bool InpShowStatus=true;
input group "Colors"
input color InpBullColor=C'220,224,230';
input color InpBearColor=C'0,92,255';
input color InpHVNColor=C'0,92,255';
input color InpLVNColor=clrWhite;
input color InpPOCColor=clrWhite;
input color InpVAColor=clrWhite;
input bool InpAutoContrast=true;
input group "Update"
input int InpRefreshMilliseconds=500;
input group "Chart visibility button (top right)"
input bool InpShowToggle=true;
input bool InpStartVisible=true;
input int InpButtonRight=16;
input int InpButtonTop=28;
input string InpInstanceTag="VBP";

double POCBuffer[],VAHBuffer[],VALBuffer[],VolumeBuffer[],CountBuffer[],SourceBuffer[];
VPProfile Profile;
string Prefix="";
CVView View;
bool ViewDirty=true,DataDirty=true,Busy=false;
bool CleanupPending=true;
ulong LastRefresh=0,Frame=0;
bool DrawingChanged=false;
datetime LeftTime=0,RightTime=0;
color Background=clrBlack,Foreground=clrWhite;
int ChartWidth=0,ChartHeight=0;
int LastFirst=-1,LastVisible=-1;
double LastMin=0,LastMax=0;

struct VPObject
{
   string name,text,tooltip;
   bool initialized;
   ulong seen;
   int x,y,w,h,font,style,width;
   color tint;
   datetime first,last;
   double high,low;
};
VPObject Drawings[];
struct VPLabel { string id,text; double price; color tint; int y; };
VPLabel Labels[];

color Blend(const color fg,const int transparency)
{
   double a=(100.0-VPClamp(transparency,0,100))/100;
   uint f=(uint)fg,b=(uint)Background;
   int r=(int)MathRound((f&255)*a+(b&255)*(1-a));
   int g=(int)MathRound(((f>>8)&255)*a+((b>>8)&255)*(1-a));
   int blue=(int)MathRound(((f>>16)&255)*a+((b>>16)&255)*(1-a));
   return (color)(r|(g<<8)|(blue<<16));
}
double Luminance(const color c)
{
   uint n=(uint)c; return (n&255)*0.2126+((n>>8)&255)*0.7152+((n>>16)&255)*0.0722;
}
color Contrast(const color c)
{
   return InpAutoContrast && MathAbs(Luminance(c)-Luminance(Background))<65?Foreground:c;
}

int Slot(const string id,const ENUM_OBJECT type,const bool back)
{
   string name=Prefix+id;
   int lo=0,hi=ArraySize(Drawings);
   while(lo<hi)
   {
      int mid=(lo+hi)/2;
      if(StringCompare(Drawings[mid].name,name)<0) lo=mid+1; else hi=mid;
   }
   int count=ArraySize(Drawings);
   if(lo==count || Drawings[lo].name!=name)
   {
      ArrayResize(Drawings,count+1,600);
      for(int i=count;i>lo;i--) Drawings[i]=Drawings[i-1];
      ZeroMemory(Drawings[lo]); Drawings[lo].name=name;
   }
   Drawings[lo].seen=Frame;
   if(!Drawings[lo].initialized)
   {
      bool ok=type==OBJ_TREND || type==OBJ_RECTANGLE?ObjectCreate(0,name,type,0,0,0,0,0):
                                                               ObjectCreate(0,name,type,0,0,0);
      if(!ok) return -1;
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,back);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"Volume Nodes");
      View.Object(name);
      DrawingChanged=true;
   }
   return lo;
}
void EndFrame()
{
   for(int i=ArraySize(Drawings)-1;i>=0;i--)
      if(Drawings[i].seen!=Frame)
      { ObjectDelete(0,Drawings[i].name); ArrayRemove(Drawings,i,1); DrawingChanged=true; }
   if(DrawingChanged) ChartRedraw(0);
}
void Tip(const int i,const string tooltip)
{
   if(!Drawings[i].initialized || Drawings[i].tooltip!=tooltip)
   { ObjectSetString(0,Drawings[i].name,OBJPROP_TOOLTIP,tooltip); Drawings[i].tooltip=tooltip; }
}
void PixelBox(const string id,const int x,const int y,const int w,const int h,const color c,const string tip)
{
   if(w<1 || h<1 || x<0 || y<0) return;
   int i=Slot(id,OBJ_RECTANGLE_LABEL,true); if(i<0) return;
   VPObject old=Drawings[i]; string n=old.name;
   if(!old.initialized)
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,n,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,n,OBJPROP_WIDTH,1);
   }
   if(!old.initialized || old.x!=x) { ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); DrawingChanged=true; }
   if(!old.initialized || old.y!=y) { ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y); DrawingChanged=true; }
   if(!old.initialized || old.w!=w) { ObjectSetInteger(0,n,OBJPROP_XSIZE,w); DrawingChanged=true; }
   if(!old.initialized || old.h!=h) { ObjectSetInteger(0,n,OBJPROP_YSIZE,h); DrawingChanged=true; }
   if(!old.initialized || old.tint!=c)
   { ObjectSetInteger(0,n,OBJPROP_BGCOLOR,c); ObjectSetInteger(0,n,OBJPROP_COLOR,c); DrawingChanged=true; }
   Tip(i,tip);
   Drawings[i].x=x; Drawings[i].y=y; Drawings[i].w=w; Drawings[i].h=h;
   Drawings[i].tint=c; Drawings[i].initialized=true;
}
void Text(const string id,const int x,const int y,const string text,const color c,const int size,const bool bottom=false)
{
   int i=Slot(id,OBJ_LABEL,false); if(i<0) return;
   VPObject old=Drawings[i]; string n=old.name;
   if(!old.initialized)
   {
      ObjectSetInteger(0,n,OBJPROP_CORNER,bottom?CORNER_LEFT_LOWER:CORNER_LEFT_UPPER);
      ObjectSetInteger(0,n,OBJPROP_ANCHOR,bottom?ANCHOR_LEFT_LOWER:ANCHOR_LEFT_UPPER);
      ObjectSetString(0,n,OBJPROP_FONT,"Arial");
   }
   if(!old.initialized || old.x!=x) { ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); DrawingChanged=true; }
   if(!old.initialized || old.y!=y) { ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y); DrawingChanged=true; }
   if(!old.initialized || old.font!=size) { ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size); DrawingChanged=true; }
   if(!old.initialized || old.text!=text) { ObjectSetString(0,n,OBJPROP_TEXT,text); DrawingChanged=true; }
   if(!old.initialized || old.tint!=c) { ObjectSetInteger(0,n,OBJPROP_COLOR,c); DrawingChanged=true; }
   Tip(i,"Volume Nodes: "+text);
   Drawings[i].x=x; Drawings[i].y=y; Drawings[i].font=size; Drawings[i].text=text;
   Drawings[i].tint=c; Drawings[i].initialized=true;
}
void PriceObject(const string id,const double high,const double low,const color c,const bool box,
                 const int width=1,const ENUM_LINE_STYLE style=STYLE_SOLID)
{
   int i=Slot(id,box?OBJ_RECTANGLE:OBJ_TREND,box); if(i<0) return;
   VPObject old=Drawings[i]; string n=old.name;
   if(!old.initialized)
   {
      if(box) ObjectSetInteger(0,n,OBJPROP_FILL,true);
      else { ObjectSetInteger(0,n,OBJPROP_RAY_LEFT,false); ObjectSetInteger(0,n,OBJPROP_RAY_RIGHT,false); }
   }
   if(!old.initialized || old.first!=LeftTime || old.high!=high)
   { ObjectMove(0,n,0,LeftTime,high); DrawingChanged=true; }
   if(!old.initialized || old.last!=RightTime || old.low!=low)
   { ObjectMove(0,n,1,RightTime,low); DrawingChanged=true; }
   if(!old.initialized || old.tint!=c) { ObjectSetInteger(0,n,OBJPROP_COLOR,c); DrawingChanged=true; }
   if(!old.initialized || old.style!=(int)style) { ObjectSetInteger(0,n,OBJPROP_STYLE,style); DrawingChanged=true; }
   if(!old.initialized || old.width!=width) { ObjectSetInteger(0,n,OBJPROP_WIDTH,width); DrawingChanged=true; }
   Tip(i,"Volume Nodes: "+id+" "+DoubleToString(high,_Digits)+(box?" - "+DoubleToString(low,_Digits):""));
   Drawings[i].first=LeftTime; Drawings[i].last=RightTime; Drawings[i].high=high; Drawings[i].low=low;
   Drawings[i].tint=c; Drawings[i].style=(int)style; Drawings[i].width=width; Drawings[i].initialized=true;
}
bool PriceY(const double price,int &y)
{
   int x=0; return ChartTimePriceToXY(0,0,RightTime,price,x,y);
}
void QueueLabel(const string id,const string title,const double price,const color c)
{
   if(!InpShowLabels) return;
   int y=0; if(!PriceY(price,y) || y<0 || y>=ChartHeight) return;
   int n=ArraySize(Labels); ArrayResize(Labels,n+1);
   Labels[n].id=id; Labels[n].text=title+(InpShowPrices?" "+DoubleToString(price,_Digits):"");
   Labels[n].price=price; Labels[n].tint=Contrast(c); Labels[n].y=y;
}
void RenderLabels(const int panelLeft,const int panelWidth)
{
   int n=ArraySize(Labels),spacing=InpFontSize+8;
   for(int i=0;i<n-1;i++)
      for(int j=i+1;j<n;j++) if(Labels[j].y<Labels[i].y) { VPLabel l=Labels[i]; Labels[i]=Labels[j]; Labels[j]=l; }
   for(int i=0;i<n;i++) Labels[i].y=MathMax(i==0?24:Labels[i-1].y+spacing,Labels[i].y-spacing/2);
   if(n>0 && Labels[n-1].y>ChartHeight-38)
   {
      Labels[n-1].y=ChartHeight-38;
      for(int i=n-2;i>=0;i--) Labels[i].y=MathMin(Labels[i].y,Labels[i+1].y-spacing);
   }
   int x=InpPanelSide==Left_Side?panelLeft+panelWidth+8:MathMax(8,panelLeft-132);
   for(int i=0;i<n;i++) if(Labels[i].y>=20) Text(Labels[i].id,x,Labels[i].y,Labels[i].text,Labels[i].tint,InpFontSize);
}
void Status(const string message)
{
   if(InpShowStatus) Text("Status",8,16,message,Foreground,8,true);
}
void Buffers()
{
   if(ArraySize(POCBuffer)<1) return;
   POCBuffer[0]=Profile.valid?Profile.poc:EMPTY_VALUE;
   VAHBuffer[0]=Profile.valid?Profile.vah:EMPTY_VALUE;
   VALBuffer[0]=Profile.valid?Profile.val:EMPTY_VALUE;
   VolumeBuffer[0]=Profile.valid?Profile.total:0;
   CountBuffer[0]=Profile.barCount; SourceBuffer[0]=(double)InpVolumeSource;
}
void Render(const bool truncated)
{
   Frame++; DrawingChanged=false; ArrayFree(Labels);
   if(Profile.valid)
   {
      int available=MathMax(100,ChartWidth-75);
      int panelWidth=MathMax(30,(int)MathRound(available*InpWidthPercent/100));
      int left=InpPanelSide==Left_Side?InpPaddingPixels:MathMax(0,available-InpPaddingPixels-panelWidth);
      for(int k=0;k<ArraySize(Profile.hvn)+ArraySize(Profile.lvn);k++)
      {
         bool isHVN=k<ArraySize(Profile.hvn);
         int index=isHVN?k:k-ArraySize(Profile.hvn),lower,upper;
         int row=isHVN?Profile.hvn[index]:Profile.lvn[index];
         Profile.Bounds(row,isHVN,lower,upper);
         double bottom=Profile.low+lower*Profile.step,top=Profile.low+(upper+1)*Profile.step;
         color c=isHVN?InpHVNColor:Contrast(InpLVNColor);
         string id=(isHVN?"HVN":"LVN")+IntegerToString(index);
         PriceObject(id,top,bottom,Blend(c,90),true);
         QueueLabel(id+"Label",isHVN?"HVN":"LVN",(top+bottom)/2,c);
      }
      for(int row=0;row<ArraySize(Profile.bins);row++)
      {
         if(Profile.bins[row]<=0) continue;
         int top=0,bottom=0;
         if(!PriceY(Profile.low+(row+0.85)*Profile.step,top) || !PriceY(Profile.low+(row+0.15)*Profile.step,bottom)) continue;
         top=MathMax(20,top); bottom=MathMin(ChartHeight-28,bottom);
         if(bottom<top) continue;
         double relative=Profile.bins[row]/Profile.maxRaw;
         int width=MathMax(1,(int)MathRound(relative*panelWidth));
         int transparency=72-(int)MathRound(relative*20);
         if(!VPFar(row,Profile.hvn,3) || !VPFar(row,Profile.lvn,3)) transparency=2;
         if(row==Profile.pocRow) transparency=0;
         int bearish=Profile.bear[row]<=0?0:Profile.bull[row]<=0?width:
                     width==1?(Profile.bear[row]>=Profile.bull[row]?1:0):
                     VPClamp((int)MathRound(width*Profile.bear[row]/Profile.bins[row]),1,width-1);
         int bullish=width-bearish;
         int bx=InpDirection==Extend_Right?left:left+panelWidth-bearish;
         int ux=InpDirection==Extend_Right?left+bearish:left+panelWidth-width;
         string id="Row"+IntegerToString(row);
         string tip="Volume Nodes: "+DoubleToString(Profile.low+row*Profile.step,_Digits)+" - "+
                    DoubleToString(Profile.low+(row+1)*Profile.step,_Digits)+"\n"+
                    (InpVolumeSource==Tick_Volume?"Tick activity: ":"Trade volume: ")+DoubleToString(Profile.bins[row],2)+
                    "\nUp/down split uses candle direction";
         PixelBox(id+"Bear",bx,top,bearish,MathMax(1,bottom-top),Blend(Contrast(InpBearColor),transparency),tip);
         PixelBox(id+"Bull",ux,top,bullish,MathMax(1,bottom-top),Blend(Contrast(InpBullColor),transparency),tip);
      }
      if(InpShowPOC)
      {
         PriceObject("POC",Profile.poc,Profile.poc,Contrast(InpPOCColor),false,InpPOCWidth,InpPOCStyle);
         QueueLabel("POCLabel","POC",Profile.poc,InpPOCColor);
      }
      if(InpShowVA)
      {
         PriceObject("VAH",Profile.vah,Profile.vah,Blend(Contrast(InpVAColor),20),false,InpVAWidth,InpVAStyle);
         PriceObject("VAL",Profile.val,Profile.val,Blend(Contrast(InpVAColor),20),false,InpVAWidth,InpVAStyle);
         QueueLabel("VAHLabel","VAH",Profile.vah,InpVAColor); QueueLabel("VALLabel","VAL",Profile.val,InpVAColor);
      }
      RenderLabels(left,panelWidth);
   }
   string status="VP "+_Symbol+" "+StringSubstr(EnumToString(_Period),7)+" | "+(InpVolumeSource==Tick_Volume?"Tick volume":"Real volume");
   if(!Profile.valid) status=InpVolumeSource==Real_Trade_Volume?"VP | No real volume":"VP | No tick volume";
   status+=" | "+IntegerToString(Profile.barCount)+" bars | "+IntegerToString(InpRows)+" rows";
   if(InpVolumeSource==Real_Trade_Volume && Profile.valid && Profile.positiveBars<Profile.barCount) status+=" | Partial";
   if(truncated) status+=" | Clipped";
   Status(status); EndFrame();
}
void Refresh()
{
   if(Busy || (!ViewDirty && !DataDirty)) return;
   ulong now=GetTickCount64();
   if(LastRefresh>0 && now-LastRefresh<(ulong)InpRefreshMilliseconds) return;
   Busy=true; LastRefresh=now;
   ChartWidth=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS);
   ChartHeight=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   Background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND); Foreground=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND);
   int first=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR),visible=(int)ChartGetInteger(0,CHART_VISIBLE_BARS);
   LastFirst=first; LastVisible=visible;
   LastMin=ChartGetDouble(0,CHART_PRICE_MIN,0); LastMax=ChartGetDouble(0,CHART_PRICE_MAX,0);
   int newest,oldest; bool truncated;
   if(!VPWindow(first,visible,Bars(_Symbol,_Period),InpMaxLookback,newest,oldest,truncated))
   {
      Profile.Reset(); Buffers(); Frame++; DrawingChanged=false;
      Status("VP | Visible range outside available lookback history"); EndFrame();
      ViewDirty=false; DataDirty=false; Busy=false; return;
   }
   MqlRates rates[]; int wanted=oldest-newest+1;
   if(CopyRates(_Symbol,_Period,newest,wanted,rates)!=wanted)
   { Busy=false; return; }
   ArraySetAsSeries(rates,false);
   LeftTime=rates[0].time; RightTime=rates[wanted-1].time;
   if(RightTime<=LeftTime) RightTime=LeftTime+PeriodSeconds(_Period);
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tick<=0) tick=_Point;
   Profile.Build(rates,InpRows,InpValueAreaPercent,tick,InpVolumeSource==Real_Trade_Volume,InpShowHVN,InpShowLVN);
   Buffers(); Render(truncated); ViewDirty=false; DataDirty=false; Busy=false;
}
void ApplyVisibility()
{
   for(int i=0;i<ArraySize(Drawings);i++) View.Object(Drawings[i].name);
   View.Draw(); ChartRedraw(0);
}

int OnInit()
{
   if(InpRows<40 || InpRows>220 || InpMaxLookback<1 || InpMaxLookback>20000 ||
      InpValueAreaPercent<1 || InpValueAreaPercent>100 || InpWidthPercent<5 || InpWidthPercent>45 ||
      InpPaddingPixels<0 || InpPaddingPixels>500 || InpFontSize<6 || InpFontSize>16 ||
      InpPOCWidth<1 || InpPOCWidth>5 || InpVAWidth<1 || InpVAWidth>5 || InpRefreshMilliseconds<100 ||
      InpButtonRight<0 || InpButtonRight>10000 || InpButtonTop<0 || InpButtonTop>10000)
      return INIT_PARAMETERS_INCORRECT;
   Prefix="VPN_"+IntegerToString(GetTickCount64())+"_"+IntegerToString(GetMicrosecondCount())+"_";
   View.Init(Prefix,"VBP",InpInstanceTag,InpShowToggle,InpStartVisible,InpButtonRight,InpButtonTop);
   ArrayFree(Drawings); ArrayFree(Labels);
   ViewDirty=true; DataDirty=true; Busy=false; CleanupPending=true;
   LastRefresh=0; Frame=0; DrawingChanged=false;
   LeftTime=0; RightTime=0; LastFirst=-1; LastVisible=-1; LastMin=0; LastMax=0;
   SetIndexBuffer(0,POCBuffer,INDICATOR_DATA); SetIndexBuffer(1,VAHBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,VALBuffer,INDICATOR_DATA); SetIndexBuffer(3,VolumeBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,CountBuffer,INDICATOR_DATA); SetIndexBuffer(5,SourceBuffer,INDICATOR_DATA);
   ArraySetAsSeries(POCBuffer,true); ArraySetAsSeries(VAHBuffer,true); ArraySetAsSeries(VALBuffer,true);
   ArraySetAsSeries(VolumeBuffer,true); ArraySetAsSeries(CountBuffer,true); ArraySetAsSeries(SourceBuffer,true);
   string names[]={"Visible POC","Visible VAH","Visible VAL","Profile volume","Profile bars","Volume source (0=Tick, 1=Real)"};
   for(int i=0;i<6;i++) { PlotIndexSetInteger(i,PLOT_DRAW_TYPE,DRAW_NONE); PlotIndexSetString(i,PLOT_LABEL,names[i]); }
   IndicatorSetString(INDICATOR_SHORTNAME,"VP Nodes MT5 v1.02 ["+(InpVolumeSource==Tick_Volume?"Tick":"Real")+"] ["+Prefix+"]");
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   Profile.Reset(); EventSetMillisecondTimer(InpRefreshMilliseconds);
   return INIT_SUCCEEDED;
}
int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],
                const double &high[],const double &low[],const double &close[],const long &ticks[],
                const long &volume[],const int &spread[])
{
   if(previous==0)
   {
      ArrayInitialize(POCBuffer,EMPTY_VALUE); ArrayInitialize(VAHBuffer,EMPTY_VALUE); ArrayInitialize(VALBuffer,EMPTY_VALUE);
      ArrayInitialize(VolumeBuffer,EMPTY_VALUE); ArrayInitialize(CountBuffer,EMPTY_VALUE); ArrayInitialize(SourceBuffer,EMPTY_VALUE);
   }
   else for(int i=1;i<=MathMin(total-previous,total-1);i++)
   { POCBuffer[i]=EMPTY_VALUE; VAHBuffer[i]=EMPTY_VALUE; VALBuffer[i]=EMPTY_VALUE;
     VolumeBuffer[i]=EMPTY_VALUE; CountBuffer[i]=EMPTY_VALUE; SourceBuffer[i]=EMPTY_VALUE; }
   DataDirty=true; Refresh(); return total;
}
void OnTimer()
{
   if(View.Click(-1,"")) ApplyVisibility();
   View.Draw();
   if(CleanupPending) CleanupPending=!VPCleanOrphans(ChartID(),Prefix);
   // Some programmatic theme/scale changes do not deliver CHART_CHANGE.
   if(ChartWidth!=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS) ||
      ChartHeight!=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0) ||
      Background!=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND) ||
      Foreground!=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND) ||
      LastFirst!=(int)ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR) ||
      LastVisible!=(int)ChartGetInteger(0,CHART_VISIBLE_BARS) ||
      LastMin!=ChartGetDouble(0,CHART_PRICE_MIN,0) || LastMax!=ChartGetDouble(0,CHART_PRICE_MAX,0)) ViewDirty=true;
   Refresh();
}
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(View.Click(id,sparam)) { ApplyVisibility(); return; }
   if(id==CHARTEVENT_CHART_CHANGE) { View.Draw(); ViewDirty=true; Refresh(); }
}
void OnDeinit(const int reason)
{
   EventKillTimer(); View.Finish(reason); if(Prefix!="") ObjectsDeleteAll(0,Prefix);
   ArrayFree(Drawings); ArrayFree(Labels); Profile.Reset(); Prefix="";
}
