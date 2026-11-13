// Original: LuxAlgo Smart Money Concepts, updated by Jlubin782 (May 2026).
// Independent MQL5 adaptation, CC BY-NC-SA 4.0. See LICENSE.md.
#property copyright "LuxAlgo; Jlubin782; independent MQL5 adaptation"
#property link "https://www.tradingview.com/script/WVf1sjBU-LuxAlgo-Smart-Money-Concepts-Updated-by-J-Lubin-5-2026/"
#property version "1.12"
#property description "SMC Pro Neon - confirmed closed bars. Independent, non-commercial port."
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots 4
#property indicator_type1 DRAW_COLOR_CANDLES
#property indicator_label1 "Trend Open;Trend High;Trend Low;Trend Close"
#property indicator_color1 clrAqua,clrDeepPink
#property indicator_type2 DRAW_NONE
#property indicator_label2 "SMC Event Mask"
#property indicator_type3 DRAW_NONE
#property indicator_label3 "Internal Bias"
#property indicator_type4 DRAW_NONE
#property indicator_label4 "Swing Bias"

#include "SMCPro_Core.mqh"
#include "Chart_Visibility.mqh"

enum SMCMode { Historical=0,Present=1 };
enum SMCFilter { All_Structures=0,BOS_Only=1,CHoCH_Only=2 };
enum SMCTheme { Futuristic_Neon=0,Modern_Professional=1,Minimal_Clean=2 };
enum SMCBullAccent { Neon_Cyan=0,Lime_Green=1,Electric_Blue=2 };
enum SMCBearAccent { Hot_Pink=0,Cyberpunk_Purple=1 };
enum SMCVolFilter { ATR_Filter=0,Cumulative_Mean_Range=1 };
enum SMCMitigation { High_Low=0,Close_Price=1 };
enum SMCLabelSize { Tiny=8,Small=10,Normal=12 };

input group "General Settings"
input SMCMode InpMode=Historical;
input bool InpColorCandles=false;
input bool InpSwingPointLabels=false;
input bool InpStrongWeak=true;
input int InpHistoryBars=10000;
input int InpMaxMarks=500;
input group "Internal Structure"
input bool InpInternal=true;
input SMCFilter InpInternalBull=All_Structures;
input SMCFilter InpInternalBear=All_Structures;
input bool InpConfluence=false;
input SMCLabelSize InpInternalSize=Tiny;
input group "Swing Structure"
input bool InpSwing=true;
input SMCFilter InpSwingBull=All_Structures;
input SMCFilter InpSwingBear=All_Structures;
input int InpSwingLength=50;
input SMCLabelSize InpSwingSize=Small;
input group "Order Blocks"
input bool InpInternalOB=true;
input int InpInternalOBCount=5;
input bool InpSwingOB=false;
input int InpSwingOBCount=5;
input SMCVolFilter InpOBFilter=ATR_Filter;
input SMCMitigation InpOBMitigation=High_Low;
input group "Equal Highs / Lows"
input bool InpEqual=true;
input int InpEqualLength=3;
input double InpEqualThreshold=0.1;
input SMCLabelSize InpEqualSize=Tiny;
input group "Fair Value Gaps (closed source candles)"
input bool InpFVG=false;
input bool InpAutoFVG=true;
input ENUM_TIMEFRAMES InpFVGTimeframe=PERIOD_CURRENT;
input int InpFVGExtend=1;
input group "MTF Highs / Lows"
input bool InpDaily=false;
input ENUM_LINE_STYLE InpDailyStyle=STYLE_SOLID;
input bool InpWeekly=false;
input ENUM_LINE_STYLE InpWeeklyStyle=STYLE_SOLID;
input bool InpMonthly=false;
input ENUM_LINE_STYLE InpMonthlyStyle=STYLE_SOLID;
input group "Premium / Discount"
input bool InpZones=false;
input group "Visual Theme"
input SMCTheme InpTheme=Futuristic_Neon;
input SMCBullAccent InpBullAccent=Neon_Cyan;
input SMCBearAccent InpBearAccent=Hot_Pink;
input bool InpSoftClouds=true;
input bool InpGradient=true;
input bool InpCustomColors=false;
input color InpCustomBull=C'0,255,213';
input color InpCustomBear=C'255,58,140';
input group "Advanced / Alerts"
input int InpATRLength=200;
input bool InpPopupAlerts=false;
input string InpInstanceTag="SMC";
input group "Chart visibility button (top right)"
input bool InpShowToggle=true;
input bool InpStartVisible=true;
input int InpButtonRight=16;
input int InpButtonTop=28;

double OpenBuffer[],HighBuffer[],LowBuffer[],CloseBuffer[],ColorBuffer[];
double EventBuffer[],InternalBuffer[],SwingBuffer[];
SMCProEngine Engine;
SMCConfig Config;
string Prefix;
bool Visible=true;
bool ViewCleaned=false;
datetime LastOpen=0,LastAlert=0;
int LastTotal=0;
bool PendingMTF=false;
color BullColor,BearColor,AccentColor,NeutralColor,Background;
ulong LastMTFAttempt=0;
double LastLiveHigh=EMPTY_VALUE,LastLiveLow=EMPTY_VALUE;

struct SMCDrawing
{
   string name,text,tooltip;
   ENUM_OBJECT type;
   datetime begin,end;
   double first,second;
   color tint;
   int style,font;
   bool initialized,above;
   ulong seen;
};
SMCDrawing Drawings[];
ulong DrawingFrame=0;
bool DrawingChanged=false;

string ViewIdentity()
{
   uint hash=2166136261;
   for(int i=0;i<StringLen(InpInstanceTag);i++)
      hash=(hash^(uint)StringGetCharacter(InpInstanceTag,i))*16777619;
   return IntegerToString(hash);
}

void RestoreViewState()
{
   Visible=InpStartVisible;
   int matches=0; bool saved=Visible,compatible=false;
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i);
      if(StringFind(name,"SMCP_")!=0 || StringLen(name)<9 ||
         StringSubstr(name,StringLen(name)-9)!="ViewState" ||
         ObjectGetInteger(0,name,OBJPROP_TYPE)!=OBJ_LABEL) continue;
      string fields[];
      if(StringSplit(ObjectGetString(0,name,OBJPROP_TOOLTIP),'|',fields)!=4 ||
         fields[0]!=IntegerToString(ChartID()) || fields[1]!=ViewIdentity()) continue;
      matches++; compatible=fields[2]==IntegerToString((int)InpStartVisible);
      saved=fields[3]=="1";
      ObjectDelete(0,name);
   }
   // Give identical instances different tags to retain their individual view state.
   if(matches==1 && compatible) Visible=saved;
}

void SaveViewState()
{
   string name=Prefix+"ViewState";
   if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0)) return;
   ObjectSetString(0,name,OBJPROP_TEXT,"");
   ObjectSetString(0,name,OBJPROP_TOOLTIP,IntegerToString(ChartID())+"|"+ViewIdentity()+"|"+
      IntegerToString((int)InpStartVisible)+"|"+IntegerToString((int)Visible));
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

void VisibilityButton()
{
   CVButton(Prefix+"Toggle","SMC",InpInstanceTag,Visible,InpShowToggle,InpButtonRight,InpButtonTop);
}

void ToggleVisibility()
{
   ObjectSetInteger(0,Prefix+"Toggle",OBJPROP_STATE,false);
   Visible=!Visible;
   for(int k=0;k<ArraySize(Drawings);k++)
      ObjectSetInteger(0,Drawings[k].name,OBJPROP_TIMEFRAMES,Visible?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
   int first=MathMax(0,LastTotal-1-InpHistoryBars);
   for(int k=0;k<ArraySize(Engine.bars) && first+k<ArraySize(OpenBuffer);k++)
   {
      int at=first+k;
      OpenBuffer[at]=Visible && InpColorCandles?Engine.bars[k].open:EMPTY_VALUE;
      HighBuffer[at]=Visible && InpColorCandles?Engine.bars[k].high:EMPTY_VALUE;
      LowBuffer[at]=Visible && InpColorCandles?Engine.bars[k].low:EMPTY_VALUE;
      CloseBuffer[at]=Visible && InpColorCandles?Engine.bars[k].close:EMPTY_VALUE;
   }
   if(Visible && LastOpen>0) Render(LastOpen);
   VisibilityButton();
   ChartRedraw(0);
}

color Blend(const color fg,const int transparency)
{
   double opacity=(100.0-MathMax(0,MathMin(transparency,100)))/100.0;
   uint f=(uint)fg,b=(uint)Background;
   int r=(int)MathRound((f&255)*opacity+(b&255)*(1-opacity));
   int g=(int)MathRound(((f>>8)&255)*opacity+((b>>8)&255)*(1-opacity));
   int bl=(int)MathRound(((f>>16)&255)*opacity+((b>>16)&255)*(1-opacity));
   return (color)(r|(g<<8)|(bl<<16));
}

void ResolveTheme()
{
   BullColor=InpBullAccent==Neon_Cyan?C'0,255,213':
             InpBullAccent==Lime_Green?C'57,255,20':C'0,212,255';
   BearColor=InpBearAccent==Hot_Pink?C'255,58,140':C'181,55,242';
   if(InpTheme==Modern_Professional) { BullColor=C'41,98,255'; BearColor=C'255,82,82'; }
   if(InpTheme==Minimal_Clean) { BullColor=C'178,181,190'; BearColor=C'93,96,107'; }
   if(InpCustomColors) { BullColor=InpCustomBull; BearColor=InpCustomBear; }
   AccentColor=InpTheme==Futuristic_Neon?C'0,212,255':
               InpTheme==Modern_Professional?C'74,144,226':C'135,139,148';
   NeutralColor=InpTheme==Futuristic_Neon?C'170,175,200':C'135,139,148';
   Background=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
}

void SetObjectCommon(const string name,const bool back)
{
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,back);
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,Visible?OBJ_ALL_PERIODS:OBJ_NO_PERIODS);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,"SMC Pro");
}

int DrawingSlot(const string name,const ENUM_OBJECT type,const bool back)
{
   int left=0,right=ArraySize(Drawings);
   while(left<right)
   {
      int mid=(left+right)/2;
      if(StringCompare(Drawings[mid].name,name)<0) left=mid+1;
      else right=mid;
   }
   int count=ArraySize(Drawings);
   if(left==count || Drawings[left].name!=name)
   {
      ArrayResize(Drawings,count+1,2048);
      for(int k=count;k>left;k--) Drawings[k]=Drawings[k-1];
      ZeroMemory(Drawings[left]);
      Drawings[left].name=name;
   }
   Drawings[left].seen=DrawingFrame;
   if(!Drawings[left].initialized)
   {
      bool created=type==OBJ_TEXT?ObjectCreate(0,name,type,0,0,0):
                                  ObjectCreate(0,name,type,0,0,0,0,0);
      if(!created) return -1;
      Drawings[left].type=type;
      SetObjectCommon(name,back);
      DrawingChanged=true;
   }
   return left;
}

void EndDrawingFrame()
{
   // Retain matching objects; delete only drawings absent from this snapshot.
   for(int k=ArraySize(Drawings)-1;k>=0;k--)
      if(Drawings[k].seen!=DrawingFrame)
      {
         ObjectDelete(0,Drawings[k].name);
         ArrayRemove(Drawings,k,1);
         DrawingChanged=true;
      }
   if(DrawingChanged) ChartRedraw(0);
}

void DrawLine(const string id,const datetime begin,const double first,
              const datetime end,const double second,const color c,const ENUM_LINE_STYLE style)
{
   string name=Prefix+id;
   int slot=DrawingSlot(name,OBJ_TREND,false);
   if(slot<0) return;
   SMCDrawing old=Drawings[slot];
   if(!old.initialized)
   {
      ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
      ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   }
   if(!old.initialized || old.begin!=begin || old.first!=first)
   { ObjectMove(0,name,0,begin,first); DrawingChanged=true; }
   if(!old.initialized || old.end!=end || old.second!=second)
   { ObjectMove(0,name,1,end,second); DrawingChanged=true; }
   if(!old.initialized || old.tint!=c)
   { ObjectSetInteger(0,name,OBJPROP_COLOR,c); DrawingChanged=true; }
   if(!old.initialized || old.style!=(int)style)
   { ObjectSetInteger(0,name,OBJPROP_STYLE,style); DrawingChanged=true; }
   Drawings[slot].begin=begin; Drawings[slot].end=end;
   Drawings[slot].first=first; Drawings[slot].second=second;
   Drawings[slot].tint=c; Drawings[slot].style=(int)style;
   Drawings[slot].initialized=true;
}

void DrawText(const string id,const datetime when,const double price,const string text,
              const color c,const int font,const bool above)
{
   string name=Prefix+id;
   int slot=DrawingSlot(name,OBJ_TEXT,false);
   if(slot<0) return;
   SMCDrawing old=Drawings[slot];
   if(!old.initialized) ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   if(!old.initialized || old.begin!=when || old.first!=price)
   { ObjectMove(0,name,0,when,price); DrawingChanged=true; }
   if(!old.initialized || old.text!=text)
   {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_TOOLTIP,"SMC Pro: "+text);
      DrawingChanged=true;
   }
   if(!old.initialized || old.font!=font)
   { ObjectSetInteger(0,name,OBJPROP_FONTSIZE,font); DrawingChanged=true; }
   if(!old.initialized || old.tint!=c)
   { ObjectSetInteger(0,name,OBJPROP_COLOR,c); DrawingChanged=true; }
   if(!old.initialized || old.above!=above)
   { ObjectSetInteger(0,name,OBJPROP_ANCHOR,above?ANCHOR_LOWER:ANCHOR_UPPER); DrawingChanged=true; }
   Drawings[slot].begin=when; Drawings[slot].first=price; Drawings[slot].text=text;
   Drawings[slot].font=font; Drawings[slot].tint=c; Drawings[slot].above=above;
   Drawings[slot].initialized=true;
}

void DrawBox(const string id,const datetime begin,const datetime end,
             const double top,const double bottom,const color c,const int transparency)
{
   string name=Prefix+id;
   int slot=DrawingSlot(name,OBJ_RECTANGLE,true);
   if(slot<0) return;
   SMCDrawing old=Drawings[slot];
   double hi=MathMax(top,bottom),lo=MathMin(top,bottom);
   color tint=Blend(c,transparency);
   if(!old.initialized)
   {
      ObjectSetInteger(0,name,OBJPROP_FILL,true);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   }
   if(!old.initialized || old.begin!=begin || old.first!=hi)
   { ObjectMove(0,name,0,begin,hi); DrawingChanged=true; }
   if(!old.initialized || old.end!=end || old.second!=lo)
   { ObjectMove(0,name,1,end,lo); DrawingChanged=true; }
   if(!old.initialized || old.tint!=tint)
   { ObjectSetInteger(0,name,OBJPROP_COLOR,tint); DrawingChanged=true; }
   string kind=StringFind(id,"IOB")==0?"Internal order block":
               StringFind(id,"SOB")==0?"Swing order block":StringFind(id,"FVG")==0?"FVG":id;
   string tooltip="SMC Pro: "+kind+"\nHigh: "+DoubleToString(hi,_Digits)+"\nLow: "+DoubleToString(lo,_Digits);
   if(!old.initialized || old.tooltip!=tooltip) ObjectSetString(0,name,OBJPROP_TOOLTIP,tooltip);
   Drawings[slot].begin=begin; Drawings[slot].end=end;
   Drawings[slot].first=hi; Drawings[slot].second=lo;
   Drawings[slot].tint=tint; Drawings[slot].tooltip=tooltip; Drawings[slot].initialized=true;
}

void RenderBlocks(SMCBlock &blocks[],const int count,const bool internal,const datetime end)
{
   int opacity=(InpSoftClouds?87:75)+(internal?1:-6);
   for(int k=0;k<MathMin(count,ArraySize(blocks));k++)
      DrawBox((internal?"IOB":"SOB")+IntegerToString(blocks[k].time)+"_"+IntegerToString(blocks[k].bias),blocks[k].time,end,
              blocks[k].high,blocks[k].low,blocks[k].bias==1?BullColor:BearColor,opacity);
}

void RenderMTF(const ENUM_TIMEFRAMES tf,const string label,const ENUM_LINE_STYLE style,
               const datetime lastOpen,const datetime end)
{
   if(PeriodSeconds(_Period)>PeriodSeconds(tf)) return;
   // The source uses current H/L when the chart itself is this timeframe.
   int shift=_Period==tf?0:1;
   MqlRates p[];
   if(CopyRates(_Symbol,tf,shift,1,p)!=1)
   {
      if(!SeriesInfoInteger(_Symbol,tf,SERIES_SYNCHRONIZED)) PendingMTF=true;
      return;
   }
   datetime highTime=p[0].time,lowTime=p[0].time;
   if(shift==1)
   {
      datetime stop=iTime(_Symbol,tf,0);
      int a=iBarShift(_Symbol,_Period,p[0].time,false),b=iBarShift(_Symbol,_Period,stop,false);
      if(a>=0 && b>=0)
      {
         int count=a-b;
         int hi=iHighest(_Symbol,_Period,MODE_HIGH,count,b+1);
         int lo=iLowest(_Symbol,_Period,MODE_LOW,count,b+1);
         if(hi>=0) highTime=iTime(_Symbol,_Period,hi);
         if(lo>=0) lowTime=iTime(_Symbol,_Period,lo);
      }
   }
   DrawLine(label+"H",highTime,p[0].high,end,p[0].high,AccentColor,style);
   DrawLine(label+"L",lowTime,p[0].low,end,p[0].low,AccentColor,style);
   DrawText(label+"HT",end,p[0].high,"P"+label+"H",AccentColor,9,true);
   DrawText(label+"LT",end,p[0].low,"P"+label+"L",AccentColor,9,false);
}

void Render(const datetime lastOpen)
{
   if(!Visible) return;
   DrawingFrame++;
   DrawingChanged=false;
   ResolveTheme();
   int seconds=PeriodSeconds(_Period);
   datetime end=lastOpen+20*seconds;
   for(int k=0;k<ArraySize(Engine.marks);k++)
   {
      SMCMark m=Engine.marks[k];
      color c=m.bias==1?BullColor:BearColor;
      int fade=m.layer==1?(int)MathRound(100-(100-m.fade)*0.75):m.fade;
      c=Blend(c,fade);
      string id="M"+IntegerToString(m.group)+"_"+IntegerToString(m.begin)+"_"+IntegerToString(m.end);
      if(m.line) DrawLine(id,m.begin,m.first,m.end,m.second,c,(ENUM_LINE_STYLE)m.style);
      int font=m.layer==1?(int)InpInternalSize:m.layer==2?(int)InpEqualSize:(int)InpSwingSize;
      DrawText(id+"T",(datetime)(((long)m.begin+(long)m.end)/2),(m.first+m.second)/2,
               m.text,c,font,m.above);
   }
   if(InpInternalOB) RenderBlocks(Engine.internalBlocks,InpInternalOBCount,true,end);
   if(InpSwingOB) RenderBlocks(Engine.swingBlocks,InpSwingOBCount,false,end);
   for(int k=0;k<ArraySize(Engine.gaps);k++)
   {
      SMCGap g=Engine.gaps[k];
      color c=g.bias==1?BullColor:BearColor;
      double mid=(g.top+g.bottom)/2;
      string id="FVG"+IntegerToString(g.begin)+"_"+IntegerToString(g.bias);
      DrawBox(id+"A",g.begin,g.end,g.top,mid,c,InpSoftClouds?82:70);
      DrawBox(id+"B",g.begin,g.end,mid,g.bottom,c,InpSoftClouds?82:70);
   }
   SMCExtremes t=Engine.displayedTrailing;
   if(InpStrongWeak)
   {
      if(SMCValid(t.top))
      {
         DrawLine("StrongH",t.topTime,t.top,end,t.top,BearColor,STYLE_SOLID);
         DrawText("StrongHT",end,t.top,t.trend==-1?"Strong High":"Weak High",BearColor,9,false);
      }
      if(SMCValid(t.bottom))
      {
         DrawLine("StrongL",t.bottomTime,t.bottom,end,t.bottom,BullColor,STYLE_SOLID);
         DrawText("StrongLT",end,t.bottom,t.trend==1?"Strong Low":"Weak Low",BullColor,9,true);
      }
   }
   if(InpZones && SMCValid(t.top) && SMCValid(t.bottom))
   {
      int opacity=InpSoftClouds?90:78;
      datetime mid=(datetime)(((long)t.pivotTime+(long)lastOpen)/2);
      DrawBox("Premium",t.pivotTime,lastOpen,t.top,0.95*t.top+0.05*t.bottom,BearColor,opacity);
      DrawBox("Equilibrium",t.pivotTime,lastOpen,0.525*t.top+0.475*t.bottom,
              0.525*t.bottom+0.475*t.top,NeutralColor,opacity);
      DrawBox("Discount",t.pivotTime,lastOpen,0.95*t.bottom+0.05*t.top,t.bottom,BullColor,opacity);
      DrawText("PremiumT",mid,t.top,"Premium",BearColor,10,true);
      DrawText("EquilibriumT",lastOpen,(t.top+t.bottom)/2,"Equilibrium",NeutralColor,10,false);
      DrawText("DiscountT",mid,t.bottom,"Discount",BullColor,10,false);
   }
   if(InpDaily) RenderMTF(PERIOD_D1,"D",InpDailyStyle,lastOpen,end);
   if(InpWeekly) RenderMTF(PERIOD_W1,"W",InpWeeklyStyle,lastOpen,end);
   if(InpMonthly) RenderMTF(PERIOD_MN1,"M",InpMonthlyStyle,lastOpen,end);
   EndDrawingFrame();
}

int OnInit()
{
   if(InpSwingLength<10 || InpATRLength<10 || InpEqualLength<1 ||
      InpEqualThreshold<0 || InpEqualThreshold>0.5 || InpInternalOBCount<1 || InpInternalOBCount>20 ||
      InpSwingOBCount<1 || InpSwingOBCount>20 || InpFVGExtend<0 || InpMaxMarks<1 || InpMaxMarks>500 ||
      InpButtonRight<0 || InpButtonRight>10000 || InpButtonTop<0 || InpButtonTop>10000 ||
      InpHistoryBars<MathMax(InpATRLength,InpSwingLength)*2)
   { Print("SMC Pro: invalid inputs or insufficient history window."); return INIT_PARAMETERS_INCORRECT; }
   if(InpFVG && InpFVGTimeframe!=PERIOD_CURRENT && PeriodSeconds(InpFVGTimeframe)<PeriodSeconds(_Period))
   { Print("SMC Pro: FVG timeframe must be current or higher."); return INIT_PARAMETERS_INCORRECT; }
   SetIndexBuffer(0,OpenBuffer,INDICATOR_DATA); SetIndexBuffer(1,HighBuffer,INDICATOR_DATA);
   SetIndexBuffer(2,LowBuffer,INDICATOR_DATA); SetIndexBuffer(3,CloseBuffer,INDICATOR_DATA);
   SetIndexBuffer(4,ColorBuffer,INDICATOR_COLOR_INDEX); SetIndexBuffer(5,EventBuffer,INDICATOR_DATA);
   SetIndexBuffer(6,InternalBuffer,INDICATOR_DATA); SetIndexBuffer(7,SwingBuffer,INDICATOR_DATA);
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,2);
   IndicatorSetInteger(INDICATOR_DIGITS,_Digits);
   Prefix="SMCP_"+IntegerToString(GetTickCount64())+"_"+
          IntegerToString(GetMicrosecondCount())+"_";
   IndicatorSetString(INDICATOR_SHORTNAME,"SMC Pro Neon MT5 v1.12 [Closed] "+InpInstanceTag+" ["+Prefix+"]");
   RestoreViewState();
   SMCDefaults(Config);
   Config.present=InpMode==Present; Config.candles=InpColorCandles;
   Config.internal=InpInternal; Config.swing=InpSwing; Config.confluence=InpConfluence;
   Config.internalBull=(int)InpInternalBull; Config.internalBear=(int)InpInternalBear;
   Config.swingBull=(int)InpSwingBull; Config.swingBear=(int)InpSwingBear;
   Config.swingLength=InpSwingLength; Config.swingPoints=InpSwingPointLabels;
   Config.strongWeak=InpStrongWeak; Config.internalOB=InpInternalOB; Config.swingOB=InpSwingOB;
   Config.internalOBCount=InpInternalOBCount; Config.swingOBCount=InpSwingOBCount;
   Config.meanRange=InpOBFilter==Cumulative_Mean_Range; Config.closeMitigation=InpOBMitigation==Close_Price;
   Config.equal=InpEqual; Config.equalLength=InpEqualLength; Config.equalThreshold=InpEqualThreshold;
   Config.fvg=InpFVG; Config.autoFVG=InpAutoFVG; Config.fvgExtend=InpFVGExtend;
   Config.zones=InpZones; Config.gradient=InpGradient; Config.atrLength=InpATRLength;
   Config.historyLimit=InpMaxMarks;
   Engine.Reset(Config); ResolveTheme();
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,BullColor);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,BearColor);
   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(Prefix!="")
   {
      bool retain=reason==REASON_CHARTCHANGE || reason==REASON_RECOMPILE || reason==REASON_PARAMETERS;
      if(retain) SaveViewState();
      for(int i=ObjectsTotal(0)-1;i>=0;i--)
      {
         string name=ObjectName(0,i);
         if(StringFind(name,Prefix)==0 && (!retain || name!=Prefix+"ViewState")) ObjectDelete(0,name);
      }
   }
   ChartRedraw(0);
}

void OnTimer()
{
   if(!ViewCleaned) { CVCleanOwnedObjects(0,Prefix); ViewCleaned=true; }
   if(InpShowToggle && ObjectGetInteger(0,Prefix+"Toggle",OBJPROP_STATE)) ToggleVisibility();
   VisibilityButton();
   if(!PendingMTF || LastTotal<2) return;
   // A newly requested higher timeframe can finish loading without a new tick.
   MqlRates rates[];
   int count=CopyRates(_Symbol,_Period,0,LastTotal,rates);
   if(count!=LastTotal) return;
   datetime t[]; double o[],h[],l[],c[]; long tv[],v[]; int s[];
   ArrayResize(t,count); ArrayResize(o,count); ArrayResize(h,count); ArrayResize(l,count);
   ArrayResize(c,count); ArrayResize(tv,count); ArrayResize(v,count); ArrayResize(s,count);
   for(int k=0;k<count;k++)
   {
      t[k]=rates[k].time; o[k]=rates[k].open; h[k]=rates[k].high;
      l[k]=rates[k].low; c[k]=rates[k].close;
      tv[k]=rates[k].tick_volume; v[k]=rates[k].real_volume; s[k]=rates[k].spread;
   }
   OnCalculate(count,count,t,o,h,l,c,tv,v,s);
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_OBJECT_CLICK && sparam==Prefix+"Toggle")
   {
      if(ObjectGetInteger(0,sparam,OBJPROP_STATE)) ToggleVisibility();
      return;
   }
   if(id==CHARTEVENT_CHART_CHANGE)
   {
      VisibilityButton();
      color newBackground=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
      if(newBackground!=Background && ArraySize(Engine.bars)>0) Render(LastOpen);
   }
}

string EventDescription(const uint mask)
{
   string names[16]={"Internal bullish BOS","Internal bearish BOS","Internal bullish CHoCH",
      "Internal bearish CHoCH","Swing bullish BOS","Swing bearish BOS","Swing bullish CHoCH",
      "Swing bearish CHoCH","Bullish internal OB mitigated","Bearish internal OB mitigated",
      "Bullish swing OB mitigated","Bearish swing OB mitigated","EQH","EQL","Bullish FVG","Bearish FVG"};
   string result="";
   for(int k=0;k<16;k++) if((mask&((uint)1<<k))!=0)
      result+=(result==""?"":", ")+names[k];
   return result;
}

int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],
                const double &high[],const double &low[],const double &close[],const long &tickVolume[],
                const long &volume[],const int &spread[])
{
   if(total<2) return 0;
   ArraySetAsSeries(time,false); ArraySetAsSeries(open,false); ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false); ArraySetAsSeries(close,false);
   bool initial=previous==0;
   bool fresh=time[total-1]!=LastOpen;
   bool liveChanged=high[total-1]!=LastLiveHigh || low[total-1]!=LastLiveLow;
   LastLiveHigh=high[total-1]; LastLiveLow=low[total-1];
   ulong now=GetTickCount64();
   if(!initial && !fresh && total==LastTotal && (!PendingMTF || now-LastMTFAttempt<1000))
   {
      // Same-timeframe source levels follow the still-forming period, as in Pine.
      if(liveChanged && ((_Period==PERIOD_D1 && InpDaily) || (_Period==PERIOD_W1 && InpWeekly) ||
         (_Period==PERIOD_MN1 && InpMonthly))) Render(time[total-1]);
      return total;
   }
   LastMTFAttempt=now;
   int first=MathMax(0,total-1-InpHistoryBars);
   if(initial)
      for(int k=0;k<first;k++)
      {
         OpenBuffer[k]=EMPTY_VALUE; HighBuffer[k]=EMPTY_VALUE;
         LowBuffer[k]=EMPTY_VALUE; CloseBuffer[k]=EMPTY_VALUE;
         ColorBuffer[k]=0; EventBuffer[k]=EMPTY_VALUE;
         InternalBuffer[k]=EMPTY_VALUE; SwingBuffer[k]=EMPTY_VALUE;
      }
   // Clear only bars leaving the selected window, and the unconfirmed bar.
   int oldFirst=MathMax(0,LastTotal-1-InpHistoryBars);
   if(!initial)
      for(int k=oldFirst;k<first;k++)
      {
         OpenBuffer[k]=EMPTY_VALUE; HighBuffer[k]=EMPTY_VALUE;
         LowBuffer[k]=EMPTY_VALUE; CloseBuffer[k]=EMPTY_VALUE;
         ColorBuffer[k]=0; EventBuffer[k]=EMPTY_VALUE;
         InternalBuffer[k]=EMPTY_VALUE; SwingBuffer[k]=EMPTY_VALUE;
      }
   OpenBuffer[total-1]=EMPTY_VALUE; HighBuffer[total-1]=EMPTY_VALUE;
   LowBuffer[total-1]=EMPTY_VALUE; CloseBuffer[total-1]=EMPTY_VALUE;
   ColorBuffer[total-1]=0; EventBuffer[total-1]=EMPTY_VALUE;
   InternalBuffer[total-1]=EMPTY_VALUE; SwingBuffer[total-1]=EMPTY_VALUE;
   Engine.Reset(Config); PendingMTF=false;
   ENUM_TIMEFRAMES fvgTF=InpFVGTimeframe==PERIOD_CURRENT?_Period:InpFVGTimeframe;
   bool external=InpFVG && fvgTF!=_Period;
   MqlRates htf[]; int hcount=0,hcursor=-1,processed=-1;
   if(external)
   {
      // Include two preceding HTF candles for three-candle gap detection.
      int shift=iBarShift(_Symbol,fvgTF,time[first],false);
      if(shift<0) PendingMTF=true;
      else hcount=CopyRates(_Symbol,fvgTF,0,shift+3,htf);
      if(hcount<=0) PendingMTF=true;
      while(hcursor+1<hcount && htf[hcursor+1].time<time[first]) hcursor++;
      processed=hcursor-1;
   }
   SMCOutput last; ZeroMemory(last);
   for(int k=first;k<total-1;k++)
   {
      MqlRates b; ZeroMemory(b);
      b.time=time[k]; b.open=open[k]; b.high=high[k]; b.low=low[k]; b.close=close[k];
      SMCOutput out=Engine.Append(b,external);
      if(external && hcount>0)
      {
         // A later HTF open proves completion; never read its live OHLC as a signal.
         datetime cutoff=time[k]+PeriodSeconds(_Period);
         while(hcursor+1<hcount && htf[hcursor+1].time<=cutoff) hcursor++;
         int complete=hcursor-1;
         for(int j=MathMax(1,processed+1);j<=complete;j++)
         {
            MqlRates older; ZeroMemory(older); if(j>=2) older=htf[j-2];
            Engine.DetectGap(older,htf[j-1],htf[j],k-first,PeriodSeconds(_Period),out);
         }
         processed=complete;
      }
      if(InpColorCandles)
      {
         OpenBuffer[k]=Visible?open[k]:EMPTY_VALUE; HighBuffer[k]=Visible?high[k]:EMPTY_VALUE;
         LowBuffer[k]=Visible?low[k]:EMPTY_VALUE; CloseBuffer[k]=Visible?close[k]:EMPTY_VALUE;
         ColorBuffer[k]=out.candleBias==1?0:1;
      }
      else
      {
         OpenBuffer[k]=EMPTY_VALUE; HighBuffer[k]=EMPTY_VALUE;
         LowBuffer[k]=EMPTY_VALUE; CloseBuffer[k]=EMPTY_VALUE; ColorBuffer[k]=0;
      }
      EventBuffer[k]=(double)out.events; InternalBuffer[k]=out.internalBias; SwingBuffer[k]=out.swingBias;
      last=out;
   }
   LastOpen=time[total-1]; LastTotal=total;
   Render(LastOpen);
   if(InpPopupAlerts && !initial && fresh && !PendingMTF && last.events!=0 && time[total-2]>LastAlert)
      Alert(_Symbol," ",EnumToString(_Period)," ",TimeToString(time[total-2])," | ",EventDescription(last.events));
   LastAlert=time[total-2];
   return total;
}
