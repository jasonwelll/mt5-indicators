#property copyright "Codex, 2026"
#property version "1.06"
#property indicator_chart_window
#property indicator_plots 0
#property indicator_buffers 0
#include <Canvas\Canvas.mqh>
#include "TPO_Session_Core.mqh"

input group "Session (times use InpSessionClock)"
input TPSession InpSessionMode=RTH_Only;
input IBClock InpSessionClock=New_York_Time;
input string InpRTHStart="09:30";
input string InpRTHEnd="16:00";
input string InpETHStart="16:00";
input string InpETHEnd="09:30";
input string InpFullDayStart="00:00";
input string InpCustomStart="09:30";
input string InpCustomEnd="16:00";
input bool InpWeekdaysOnly=true;
input group "Broker clock"
input IBServerClock InpServerClock=FTMO_US_DST;
input int InpStandardUTCMinutes=120;
input group "Profile calculation"
input int InpSubperiodMinutes=30;
input double InpPriceRowSize=2.0;
input int InpMaximumRows=500;
input double InpValueAreaPercent=70.0;
input TPVolume InpVolumeSource=TP_Tick_Volume;
input bool InpPOCUseVolume=true;
input bool InpValueAreaUseVolume=false;
input group "Display"
input bool InpExpanded=false;
input bool InpLetters=true;
input int InpProfiles=3;
input int InpLookbackDays=14;
input int InpFontSize=10;
input bool InpShowPOC=true;
input bool InpShowValueArea=true;
input bool InpShowLabels=true;
input bool InpShowControls=true;
input int InpControlX=8;
input int InpControlY=8;
input color InpValueAreaColor=C'38,130,190';
input color InpVolumePOCColor=C'215,45,135';
input color InpTPOPOCColor=C'218,125,30';
input bool InpVisible=true;
input group "Single Prints"
input bool InpShowSinglePrints=true;
input bool InpSinglePrintConfirmedOnly=true;
input bool InpSinglePrintIncludeTails=false;
input color InpSinglePrintColor=C'102,204,153';
input color InpSinglePrintDevelopingColor=C'225,155,35';
input group "Level extensions and update timing"
input TPExtension InpPOCExtension=Latest_Profile;
input TPExtension InpVAExtension=Latest_Profile;
input TPUpdateMode InpSubperiodUpdate=Developing_Subperiod;
input group "Panel visibility and position"
input TPPanelPosition InpPanelPosition=Panel_Bottom_Right;
input bool InpShowStatus=false;
input group "Single Print levels and session markers"
input bool InpShowSinglePrintLines=true;
input bool InpShowSinglePrintPrices=true;
input TPSingleLineMode InpSinglePrintLineMode=SP_Zone_Edges;
input TPExtension InpSinglePrintExtension=Latest_Profile;
input ENUM_LINE_STYLE InpSinglePrintLineStyle=STYLE_DOT;
input int InpSinglePrintLineWidth=1;
input bool InpShowSessionOpen=true;
input bool InpShowSessionClose=true;
input bool InpShowDevelopingClose=false;
input color InpSessionOpenColor=C'255,140,0';
input color InpSessionCloseColor=C'230,55,65';
input group "Developing profile layout"
input bool InpAutoFitDeveloping=true;

CCanvas Canvas;
TPProfile Profiles[10];
MqlRates Source[];
string Prefix,ShortName,LastError="",Retain[],SettingsHash="";
int InstanceSlot=-1;
bool Expanded,VolumePOC,VolumeVA,Visible,Busy=false,HasCanvas=false,Pending=true,ClippedColumns=false,Blocks=false;
int Times[7],ProfileCount=0;
datetime SourceMinute=0,AsOf=0;
color Foreground;

bool ParseMinute(const string text,int &minute)
{
   if(StringLen(text)!=5 || StringSubstr(text,2,1)!=":") return false;
   for(int i=0;i<5;i++)
      if(i!=2 && (StringGetCharacter(text,i)<'0' || StringGetCharacter(text,i)>'9')) return false;
   int hour=(int)StringToInteger(StringSubstr(text,0,2)),min=(int)StringToInteger(StringSubstr(text,3,2));
   minute=hour*60+min; return hour<24 && min<60;
}
string Owner(const string title)
{
   int a=StringFind(title,"[TPX_"),b=a<0?-1:StringFind(title,"]",a);
   return a>=0 && b>a?StringSubstr(title,a+1,b-a-1):"";
}
int ChartSlot(const string title)
{
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++) if(ChartIndicatorName(0,0,i)==title) return i;
   return -1;
}
string InputHash()
{
   string values[]={(string)InpSessionMode,(string)InpSessionClock,InpRTHStart,InpRTHEnd,InpETHStart,InpETHEnd,
      InpFullDayStart,InpCustomStart,InpCustomEnd,(string)InpWeekdaysOnly,(string)InpServerClock,(string)InpStandardUTCMinutes,
      (string)InpSubperiodMinutes,DoubleToString(InpPriceRowSize,16),(string)InpMaximumRows,DoubleToString(InpValueAreaPercent,16),
      (string)InpVolumeSource,(string)InpPOCUseVolume,(string)InpValueAreaUseVolume,(string)InpExpanded,(string)InpLetters,
      (string)InpProfiles,(string)InpLookbackDays,(string)InpFontSize,(string)InpShowPOC,(string)InpShowValueArea,
      (string)InpShowLabels,(string)InpShowControls,(string)InpControlX,(string)InpControlY,(string)InpValueAreaColor,
      (string)InpVolumePOCColor,(string)InpTPOPOCColor,(string)InpVisible,(string)InpShowSinglePrints,
      (string)InpSinglePrintConfirmedOnly,(string)InpSinglePrintIncludeTails,(string)InpSinglePrintColor,
      (string)InpSinglePrintDevelopingColor,(string)InpPOCExtension,(string)InpVAExtension,(string)InpSubperiodUpdate,
      (string)InpPanelPosition,(string)InpShowStatus,(string)InpShowSinglePrintLines,(string)InpShowSinglePrintPrices,
      (string)InpSinglePrintLineMode,(string)InpSinglePrintExtension,(string)InpSinglePrintLineStyle,
      (string)InpSinglePrintLineWidth,(string)InpShowSessionOpen,(string)InpShowSessionClose,(string)InpShowDevelopingClose,
      (string)InpSessionOpenColor,(string)InpSessionCloseColor,(string)InpAutoFitDeveloping};
   uint hash=2166136261;
   for(int i=0;i<ArraySize(values);i++)
   {
      string value=IntegerToString(StringLen(values[i]))+":"+values[i]+";";
      for(int j=0;j<StringLen(value);j++) hash=(hash^(uint)StringGetCharacter(value,j))*16777619;
   }
   return IntegerToString(hash);
}
void SaveViewState()
{
   if(InstanceSlot<0 || SettingsHash=="" || Prefix=="") return;
   int slot=ChartSlot(ShortName); if(slot>=0) InstanceSlot=slot;
   string name=Prefix+"State";
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   int flags=(Expanded?1:0)|(VolumePOC?2:0)|(VolumeVA?4:0)|(Visible?8:0);
   ObjectSetString(0,name,OBJPROP_TEXT,"");
   ObjectSetString(0,name,OBJPROP_TOOLTIP,IntegerToString(ChartID())+"|"+IntegerToString(InstanceSlot)+"|"+
      SettingsHash+"|"+_Symbol+"|"+IntegerToString((int)_Period)+"|"+IntegerToString(flags));
   ObjectSetInteger(0,name,OBJPROP_TIMEFRAMES,OBJ_NO_PERIODS);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}
void RestoreViewState()
{
   if(InstanceSlot<0 || SettingsHash=="") return;
   string candidate=""; int flags=0,matches=0; bool exact=false; long generation=-1;
   for(int i=0;i<ObjectsTotal(0);i++)
   {
      string name=ObjectName(0,i); int length=StringLen(name);
      if(StringFind(name,"TPX_")!=0 || length<6 || StringSubstr(name,length-5)!="State" ||
         ObjectGetInteger(0,name,OBJPROP_TYPE)!=OBJ_LABEL) continue;
      string fields[];
      if(StringSplit(ObjectGetString(0,name,OBJPROP_TOOLTIP),'|',fields)!=6 || fields[0]!=IntegerToString(ChartID()) ||
         fields[2]!=SettingsHash || (fields[3]==_Symbol && (int)StringToInteger(fields[4])==(int)_Period)) continue;
      int bits=(int)StringToInteger(fields[5]); if(bits<0 || bits>15) continue;
      // Ordinal matching isolates identical instances; a unique settings match also survives a removed neighbour.
      bool atSlot=(int)StringToInteger(fields[1])==InstanceSlot;
      long stamp=StringToInteger(StringSubstr(name,4));
      if(atSlot && (!exact || stamp>generation))
      { exact=true; candidate=name; flags=bits; generation=stamp; }
      else if(!exact) { matches++; candidate=name; flags=bits; }
   }
   if(!exact && matches!=1) return;
   Expanded=(flags&1)!=0; VolumePOC=(flags&2)!=0; VolumeVA=(flags&4)!=0; Visible=(flags&8)!=0;
   ObjectDelete(0,candidate);
}
void CleanOrphans()
{
   string active[];
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++)
   {
      string title=ChartIndicatorName(0,0,i);
      if(StringFind(title,"TPO Session v")!=0) continue;
      string owner=Owner(title); if(owner=="") return;
      int n=ArraySize(active); ArrayResize(active,n+1); active[n]=owner;
   }
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i); if(StringFind(name,"TPX_")!=0 || StringFind(name,Prefix)==0) continue;
      int a=StringFind(name,"_",4),b=a<0?-1:StringFind(name,"_",a+1);
      if(a<0 || b<0) continue;
      string owner=StringSubstr(name,0,b+1); bool live=false;
      for(int k=0;k<ArraySize(active);k++) if(owner==active[k]) live=true;
      string role=StringSubstr(name,b+1);
      ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      bool known=(role=="Canvas" && type==OBJ_BITMAP_LABEL) || (role=="Status" && type==OBJ_LABEL) ||
         ((role=="Show" || role=="View" || role=="POC" || role=="VA") && type==OBJ_BUTTON) ||
         (StringFind(role,"L_")==0 && (type==OBJ_TREND || type==OBJ_TEXT));
      if(!live && known) ObjectDelete(0,name);
      if(!live && role=="State" && type==OBJ_LABEL)
      {
         string fields[];
         int count=StringSplit(ObjectGetString(0,name,OBJPROP_TOOLTIP),'|',fields);
         if(count!=6 || fields[0]!=IntegerToString(ChartID()) ||
            (fields[3]==_Symbol && (int)StringToInteger(fields[4])==(int)_Period)) ObjectDelete(0,name);
      }
   }
}
void Keep(const string name)
{ int n=ArraySize(Retain); ArrayResize(Retain,n+1); Retain[n]=name; }
void Common(const string name)
{
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,false); ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
}
TPPanelBox Panel()
{
   int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   return TPPanelLayout(width,height,InpPanelPosition,Visible,InpControlX,InpControlY);
}
void Status(const string text)
{
   string name=Prefix+"Status";
   if(!InpShowStatus) { ObjectDelete(0,name); return; }
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   TPPanelBox box=Panel();
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,box.x);
   int top=box.y;
   if(InpShowControls) top+=InpPanelPosition==Panel_Top_Left?box.height+5:-17;
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,MathMax(0,top));
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,name,OBJPROP_COLOR,Foreground);
   int limit=(int)MathMax(10,box.width/7);
   ObjectSetString(0,name,OBJPROP_TEXT,StringLen(text)>limit?StringSubstr(text,0,limit-3)+"...":text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,text); ObjectSetString(0,name,OBJPROP_FONT,"Arial"); Common(name);
}
void Button(const string role,const string text,const int x,const int y,const int width)
{
   string name=Prefix+role;
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width); ObjectSetInteger(0,name,OBJPROP_YSIZE,23);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C'235,239,242');
   ObjectSetInteger(0,name,OBJPROP_COLOR,C'25,35,40'); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,C'120,130,140');
   ObjectSetInteger(0,name,OBJPROP_ZORDER,50); ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,text); Common(name);
}
void Controls()
{
   SaveViewState();
   if(!InpShowControls) return;
   TPPanelBox box=Panel();
   string roles[]={"Show","View","POC","VA"};
   string labels[]={Visible?"Hide TPO":"Show TPO",Expanded?"View: Split":"View: Merged",
      VolumePOC?"POC: Volume":"POC: TPO",VolumeVA?"VA: Volume":"VA: TPO"};
   int offsets[]={0,88,198,312},widths[]={82,104,108,100};
   for(int i=0;i<(Visible?4:1);i++)
   {
      int x=box.x+(box.columns==4?offsets[i]:(i%box.columns)*114);
      int y=box.y+(i/box.columns)*29;
      int width=!Visible?box.width:box.columns==4?widths[i]:box.columns==2?108:box.width;
      Button(roles[i],labels[i],x,y,width);
   }
   if(Visible && Expanded && ClippedColumns)
      ObjectSetString(0,Prefix+"View",OBJPROP_TOOLTIP,"Split columns clipped: zoom in / use M5 or fewer profiles");
}
void HideDrawings()
{
   Canvas.Destroy(); HasCanvas=false;
   ObjectsDeleteAll(0,Prefix+"L_");
   string roles[]={"Status","View","POC","VA"};
   for(int i=0;i<ArraySize(roles);i++) ObjectDelete(0,Prefix+roles[i]);
}
string VolumeName() { return InpVolumeSource==TP_Tick_Volume?"Tick":"Real"; }
string LevelName(TPProfile &p,const string role)
{ return Prefix+"L_"+IntegerToString((long)p.window.time.start)+"_"+IntegerToString(p.window.kind)+"_"+role; }
void Level(TPProfile &p,const string role,const double price,const color colour,const ENUM_LINE_STYLE style,const string title,const bool extend,
   const bool labelEnabled=true,const ENUM_ANCHOR_POINT anchor=ANCHOR_RIGHT_LOWER)
{
   string name=LevelName(p,role); Keep(name);
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,p.window.time.start,price,p.window.time.close,price);
   ObjectMove(0,name,0,p.window.time.start,price); ObjectMove(0,name,1,p.window.time.close,price);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,extend); ObjectSetInteger(0,name,OBJPROP_RAY_LEFT,false);
   ObjectSetInteger(0,name,OBJPROP_COLOR,colour); ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,role=="POC"?2:StringFind(role,"SP_")==0?InpSinglePrintLineWidth:1);
   ObjectSetInteger(0,name,OBJPROP_BACK,false); Common(name);
   string tip=TPKindName(p.window.kind)+" | "+TimeToString(p.window.time.start,TIME_DATE|TIME_MINUTES)+" - "+
      TimeToString(p.window.time.close,TIME_DATE|TIME_MINUTES)+" server | M1 bars "+IntegerToString(p.bars)+
      " | TPO POC "+DoubleToString(p.POC(false),_Digits)+" | VP POC "+
      (p.volume.valid?DoubleToString(p.POC(true),_Digits):"unavailable")+" | "+title+" "+DoubleToString(price,_Digits);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   if(!InpShowLabels || !labelEnabled) return;
   string label=name+"_T"; Keep(label);
   datetime at=p.window.time.close;
   long first=ChartGetInteger(0,CHART_FIRST_VISIBLE_BAR),visible=ChartGetInteger(0,CHART_VISIBLE_BARS);
   int shift=(int)(first-visible+3);
   datetime right=iTime(_Symbol,_Period,MathMax(0,shift))+MathMax(0,-shift)*PeriodSeconds(_Period);
   if(right>p.window.time.start && (extend || right<at)) at=right;
   if(ObjectFind(0,label)<0) ObjectCreate(0,label,OBJ_TEXT,0,at,price);
   ObjectMove(0,label,0,at,price); ObjectSetInteger(0,label,OBJPROP_ANCHOR,anchor);
   ObjectSetInteger(0,label,OBJPROP_COLOR,colour); ObjectSetInteger(0,label,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,label,OBJPROP_FONT,"Arial");
   ObjectSetString(0,label,OBJPROP_TEXT,title+" "+DoubleToString(price,_Digits)+" "+TPKindName(p.window.kind));
   ObjectSetString(0,label,OBJPROP_TOOLTIP,tip); Common(label);
}
bool HasBars(const TPWindow &w)
{
   for(int i=ArraySize(Source)-1;i>=0;i--)
   { if(Source[i].time<w.time.start) break; if(Source[i].time<w.time.close) return true; }
   return false;
}
bool Calculate()
{
   MqlRates last[]; if(CopyRates(_Symbol,PERIOD_M1,0,1,last)!=1) { LastError="Waiting for M1 history"; return false; }
   datetime utc=0;
   if(!IBServerToUTC(last[0].time,InpServerClock,InpStandardUTCMinutes,utc))
   { LastError="Broker clock conversion failed"; return false; }
   datetime date=IBDay(IBUTCToLocal(utc,InpSessionClock,InpServerClock,InpStandardUTCMinutes));
   AsOf=TimeCurrent(); if(AsOf<last[0].time || AsOf>last[0].time+59) AsOf=last[0].time+59;
   if(Pending || SourceMinute!=last[0].time || ArraySize(Source)==0)
   {
      MqlRates fresh[]; datetime from=last[0].time-(InpLookbackDays+3)*86400;
      int n=CopyRates(_Symbol,PERIOD_M1,from,last[0].time,fresh);
      if(n<1) { LastError="Downloading M1 history"; Pending=true; return false; }
      ArrayResize(Source,n); ArrayCopy(Source,fresh); SourceMinute=last[0].time;
      Pending=!((bool)SeriesInfoInteger(_Symbol,PERIOD_M1,SERIES_SYNCHRONIZED));
   }
   else Source[ArraySize(Source)-1]=last[0];
   TPWindow candidates[];
   for(int day=InpLookbackDays;day>=-1;day--)
   {
      int begin=InpSessionMode==RTH_Only || InpSessionMode==Separate_RTH_ETH?0:
         InpSessionMode==ETH_Only?1:InpSessionMode==Full_Day?2:3;
      int end=InpSessionMode==Separate_RTH_ETH?1:begin;
      for(int kind=begin;kind<=end;kind++)
      {
         TPWindow w;
         if(!TPBuildWindow(date-day*86400,kind,InpSessionClock,InpServerClock,InpStandardUTCMinutes,
            Times[0],Times[1],Times[2],Times[3],Times[4],Times[5],Times[6],w)) continue;
         if(w.time.start>AsOf || Source[0].time>w.time.start ||
            (InpWeekdaysOnly && !TPWindowWeekday(w,InpSessionClock,InpServerClock,InpStandardUTCMinutes)) || !HasBars(w)) continue;
         int n=ArraySize(candidates); ArrayResize(candidates,n+1); candidates[n]=w;
      }
   }
   int n=ArraySize(candidates);
   for(int i=0;i<n-1;i++) for(int j=i+1;j<n;j++)
      if(candidates[j].time.start<candidates[i].time.start)
      { TPWindow temp=candidates[i]; candidates[i]=candidates[j]; candidates[j]=temp; }
   ProfileCount=0; LastError="";
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE); if(tick<=0) tick=_Point;
   for(int i=MathMax(0,n-InpProfiles);i<n;i++)
   {
      if(Profiles[ProfileCount].Build(Source,candidates[i],AsOf,InpSubperiodMinutes,InpPriceRowSize,tick,
         InpValueAreaPercent,InpVolumeSource,InpMaximumRows,InpSubperiodUpdate==Closed_Subperiods_Only)) ProfileCount++;
      else if(Profiles[ProfileCount].error!="") LastError=Profiles[ProfileCount].error;
   }
   if(ProfileCount==0 && LastError=="") LastError="No covered session in available M1 history";
   return true;
}
void DrawProfile(TPProfile &p,const int index,const int width,const int height)
{
   int x=0,y=0,xEnd=0,dummy=0;
   if(!ChartTimePriceToXY(0,0,p.window.time.start,p.low,x,y) ||
      !ChartTimePriceToXY(0,0,p.complete?p.window.time.close:p.closeTime,p.low,xEnd,dummy)) return;
   if(xEnd<0 || x>width) return;
   int next=width-75;
   if(index+1<ProfileCount)
   {
      int nx=0,ny=0;
      if(ChartTimePriceToXY(0,0,Profiles[index+1].window.time.start,p.low,nx,ny))
      {
         if(index+1==ProfileCount-1 && Expanded && InpAutoFitDeveloping && !Profiles[index+1].complete && nx<=width)
         {
            int nc=MathMax(10,Canvas.TextWidth(TPLetter(Profiles[index+1].slots-1))+3);
            nx=TPProfileLeft(nx,4,width-75,Profiles[index+1].closeSlot+1,nc,nc+3,true);
         }
         next=MathMin(next,nx-6);
      }
   }
   int cell=MathMax(10,Canvas.TextWidth(TPLetter(p.slots-1))+3),fontHeight=Canvas.TextHeight("A");
   int pitch=cell+(Expanded?3:0);
   bool fit=index==ProfileCount-1 && Expanded && !p.complete && InpAutoFitDeveloping;
   x=TPProfileLeft(x,4,next,p.closeSlot+1,cell,pitch,fit);
   if(next<=x) { ClippedColumns=true; return; }
   int y0=0,y1=0;
   ChartTimePriceToXY(0,0,p.window.time.start,p.Price(0),dummy,y0);
   ChartTimePriceToXY(0,0,p.window.time.start,p.Price(0)+p.step,dummy,y1);
   int rowPixels=MathAbs(y1-y0);
   bool letters=InpLetters && rowPixels>=fontHeight;
   if(InpLetters && !letters) Blocks=true;
   TPStats va=VolumeVA?p.volume:p.tpo,chosen=VolumePOC?p.volume:p.tpo;
   for(int row=0;row<p.rows;row++)
   {
      int yy=0; ChartTimePriceToXY(0,0,p.window.time.start,p.Price(row),dummy,yy);
      if(yy<fontHeight+2 || yy>=height-20) continue;
      color colour=va.valid && row>=va.lower && row<=va.upper?InpValueAreaColor:Foreground;
      if(chosen.valid && row==chosen.poc) colour=VolumePOC?InpVolumePOCColor:InpTPOPOCColor;
      int single=InpShowSinglePrints?p.SinglePrintState(row,InpSinglePrintIncludeTails):0;
      if(single==2) colour=InpSinglePrintColor;
      else if(single==1 && !InpSinglePrintConfirmedOnly) colour=InpSinglePrintDevelopingColor;
      int packed=0;
      for(int slot=0;slot<p.slots;slot++) if(p.Hit(row,slot))
      {
         int column=Expanded?slot:packed; packed++;
         int xx=x+column*pitch; if(xx+cell>next) { ClippedColumns=true; continue; }
         color shade=InpShowSessionOpen && p.OpeningCell(row,slot)?InpSessionOpenColor:colour;
         if(letters) Canvas.TextOut(xx,yy-fontHeight/2,TPLetter(slot),ColorToARGB(shade,245));
         else Canvas.FillRectangle(xx,yy-MathMax(1,rowPixels/2-1),xx+cell-2,yy+MathMax(0,rowPixels/2-1),ColorToARGB(shade,210));
      }
   }
   if(InpShowSessionClose && p.CloseVisible(InpShowDevelopingClose))
   {
      int yy=0,column=p.DisplayColumn(p.closeRow,p.closeSlot,Expanded),size=4;
      int xx=MathMin(x+column*pitch+cell+2,next-size*2-1);
      if(column>=0 && xx>=x &&
         ChartTimePriceToXY(0,0,p.closeTime,p.closePrice,dummy,yy) && yy-size>=2 && yy+size<height-20)
      {
         uint shade=ColorToARGB(InpSessionCloseColor);
         if(p.complete) Canvas.FillTriangle(xx,yy,xx+size*2,yy-size,xx+size*2,yy+size,shade);
         else Canvas.Triangle(xx,yy,xx+size*2,yy-size,xx+size*2,yy+size,shade);
      }
   }
   int titleY=0; ChartTimePriceToXY(0,0,p.window.time.start,p.high,dummy,titleY);
   titleY-=fontHeight+5;
   string title=TPKindName(p.window.kind)+" "+TimeToString(p.window.time.date,TIME_DATE)+(p.complete?"":" *");
   int reserved=InpPanelPosition==Panel_Top_Left && (InpShowControls || InpShowStatus)?InpControlY+70:30;
   if(titleY>=reserved && titleY<height-35 && Canvas.TextWidth(title)<next-x)
      Canvas.TextOut(x,titleY,title,ColorToARGB(Foreground));
}
void DrawLevels(TPProfile &p,const int index)
{
   TPStats va=VolumeVA?p.volume:p.tpo,chosen=VolumePOC?p.volume:p.tpo;
   if(InpShowPOC && chosen.valid)
      Level(p,"POC",p.Price(chosen.poc),VolumePOC?InpVolumePOCColor:InpTPOPOCColor,STYLE_SOLID,
         (VolumePOC?"VP POC ("+VolumeName()+")":"TPO POC"),TPExtend(InpPOCExtension,index,ProfileCount));
   if(InpShowValueArea && va.valid)
   {
      string basis=VolumeVA?"VP ("+VolumeName()+")":"TPO";
      Level(p,"VAH",p.low+(va.upper+1)*p.step,InpValueAreaColor,STYLE_DASH,basis+" VAH",TPExtend(InpVAExtension,index,ProfileCount));
      Level(p,"VAL",p.low+va.lower*p.step,InpValueAreaColor,STYLE_DASH,basis+" VAL",TPExtend(InpVAExtension,index,ProfileCount));
   }
}
void DrawSinglePrintLines(TPProfile &p,const int index)
{
   if(!InpShowSinglePrints || !InpShowSinglePrintLines) return;
   TPSingleZone zones[]; int count=p.SinglePrintZones(zones,InpSinglePrintConfirmedOnly,InpSinglePrintIncludeTails);
   bool extend=TPExtend(InpSinglePrintExtension,index,ProfileCount);
   for(int i=0;i<count;i++)
   {
      TPSingleZone zone=zones[i];
      color shade=zone.state==2?InpSinglePrintColor:InpSinglePrintDevelopingColor;
      string mark=zone.state==2?"":" *";
      if(InpSinglePrintLineMode==SP_Each_Price_Row || zone.lower==zone.upper)
      {
         for(int row=zone.lower;row<=zone.upper;row++)
            Level(p,"SP_"+IntegerToString(row)+"_C",p.Price(row),shade,InpSinglePrintLineStyle,"SP"+mark,
               extend,InpShowSinglePrintPrices);
      }
      else
      {
         string stem="SP_"+IntegerToString(zone.lower);
         Level(p,stem+"_H",p.low+(zone.upper+1)*p.step,shade,InpSinglePrintLineStyle,"SPH"+mark,
            extend,InpShowSinglePrintPrices);
         Level(p,stem+"_L",p.low+zone.lower*p.step,shade,InpSinglePrintLineStyle,"SPL"+mark,
            extend,InpShowSinglePrintPrices,ANCHOR_RIGHT_UPPER);
      }
   }
}
void Render()
{
   if(!Visible) { HideDrawings(); Controls(); ChartRedraw(); return; }
   Foreground=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND);
   int width=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS),height=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(width<80 || height<80) return;
   if(!HasCanvas)
   {
      HasCanvas=Canvas.CreateBitmapLabel(0,0,Prefix+"Canvas",0,0,width,height,COLOR_FORMAT_ARGB_NORMALIZE);
      if(!HasCanvas) { Status("Canvas creation failed"); return; }
      Common(Prefix+"Canvas"); ObjectSetInteger(0,Prefix+"Canvas",OBJPROP_BACK,false);
      ObjectSetInteger(0,Prefix+"Canvas",OBJPROP_ZORDER,0);
   }
   if((Canvas.Width()!=width || Canvas.Height()!=height) && !Canvas.Resize(width,height))
   { Status("Canvas resize failed"); return; }
   Canvas.Erase(0); Canvas.FontSet("Consolas",-InpFontSize*10); ArrayFree(Retain); ClippedColumns=false; Blocks=false;
   for(int i=0;i<ProfileCount;i++)
   { DrawProfile(Profiles[i],i,width,height); DrawLevels(Profiles[i],i); DrawSinglePrintLines(Profiles[i],i); }
   Canvas.Update(false);
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i); if(StringFind(name,Prefix+"L_")!=0) continue;
      bool keep=false; for(int j=0;j<ArraySize(Retain);j++) if(Retain[j]==name) { keep=true; break; }
      if(!keep) ObjectDelete(0,name);
   }
   Controls();
   string state="TPO | "+EnumToString(InpSessionMode)+" | "+IntegerToString(InpSubperiodMinutes)+"m | row "+
      DoubleToString(InpPriceRowSize,_Digits)+" | "+VolumeName()+" volume | "+IntegerToString(ProfileCount)+" profiles";
   if(ProfileCount>0 && (VolumePOC || VolumeVA))
   { TPProfile *p=GetPointer(Profiles[ProfileCount-1]); if(!p.volume.valid) state+=" | Volume unavailable"; else if(p.partialVolume) state+=" | Partial volume"; }
   if(LastError!="") state+=" | "+LastError;
   if(ClippedColumns) state+=" | Columns clipped: zoom in / use M5";
   if(Blocks) state+=" | Blocks: increase row size / vertical zoom";
   if(InpSubperiodUpdate==Closed_Subperiods_Only) state+=" | Closed subperiods only";
   if(InpShowSinglePrints) state+=" | SP: "+(InpSinglePrintConfirmedOnly?"confirmed":"confirmed + developing");
   Status(state); ChartRedraw();
}
bool ReadButtons()
{
   bool changed=false;
   string roles[]={"View","POC","VA","Show"};
   for(int i=0;i<ArraySize(roles);i++) if(ObjectFind(0,Prefix+roles[i])>=0 && ObjectGetInteger(0,Prefix+roles[i],OBJPROP_STATE))
   {
      ObjectSetInteger(0,Prefix+roles[i],OBJPROP_STATE,false); changed=true;
      if(i==0) Expanded=!Expanded; else if(i==1) VolumePOC=!VolumePOC;
      else if(i==2) VolumeVA=!VolumeVA; else Visible=!Visible;
   }
   return changed;
}
void Refresh()
{
   if(Busy) return; Busy=true;
   // Template objects can arrive after OnInit, so clean their obsolete copies on refresh too.
   CleanOrphans(); ReadButtons(); if(Visible) Calculate(); Render(); Busy=false;
}
int OnInit()
{
   // Rebuild all price data; only explicit view-state checkpoints survive a chart change.
   Canvas.Destroy(); HasCanvas=false; Busy=false; Pending=true; ProfileCount=0;
   SourceMinute=0; AsOf=0; LastError=""; ArrayFree(Source); ArrayFree(Retain);
   for(int i=0;i<10;i++) Profiles[i].Reset();
   string text[]={InpRTHStart,InpRTHEnd,InpETHStart,InpETHEnd,InpFullDayStart,InpCustomStart,InpCustomEnd};
   for(int i=0;i<7;i++) if(!ParseMinute(text[i],Times[i])) { Print("Use HH:MM, 00:00-23:59"); return INIT_PARAMETERS_INCORRECT; }
   if(InpProfiles<1 || InpProfiles>10 || InpLookbackDays<1 || InpLookbackDays>60 ||
      InpSubperiodMinutes<5 || InpSubperiodMinutes>240 || InpPriceRowSize<=0 || InpMaximumRows<2 || InpMaximumRows>2000 ||
      InpValueAreaPercent<1 || InpValueAreaPercent>100 || InpFontSize<6 || InpFontSize>24 ||
      InpStandardUTCMinutes< -720 || InpStandardUTCMinutes>840 || InpControlX<0 || InpControlY<0 ||
      InpSinglePrintLineWidth<1 || InpSinglePrintLineWidth>5) return INIT_PARAMETERS_INCORRECT;
   InstanceSlot=ChartSlot(MQLInfoString(MQL_PROGRAM_NAME)); SettingsHash=InputHash();
   Expanded=InpExpanded; VolumePOC=InpPOCUseVolume; VolumeVA=InpValueAreaUseVolume; Visible=InpVisible;
   RestoreViewState();
   Prefix="TPX_"+IntegerToString((long)GetTickCount64())+"_"+IntegerToString((long)GetMicrosecondCount())+"_";
   // MT5 truncates long short names; keep drawing ownership before parameter text.
   ShortName="TPO Session v1.06 ["+Prefix+"] "+IntegerToString((int)InpSessionMode)+"/"+
      IntegerToString(InpSubperiodMinutes)+"/"+DoubleToString(InpPriceRowSize,2)+(InpPOCUseVolume?" V":" T");
   IndicatorSetString(INDICATOR_SHORTNAME,ShortName);
   Foreground=(color)ChartGetInteger(0,CHART_COLOR_FOREGROUND); CleanOrphans(); Controls();
   if(Visible) Status("Loading M1 session profiles");
   return EventSetTimer(1)?INIT_SUCCEEDED:INIT_FAILED;
}
int OnCalculate(const int total,const int previous,const datetime &time[],const double &open[],const double &high[],
   const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{ if(previous==0) Refresh(); return total; }
void OnTimer() { Refresh(); }
void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id==CHARTEVENT_CHART_CHANGE || (id==CHARTEVENT_OBJECT_CLICK && StringFind(sparam,Prefix)==0))
   { if(ReadButtons()) Refresh(); else Render(); }
}
void OnDeinit(const int reason)
{
   EventKillTimer(); Canvas.Destroy();
   if(Prefix!="")
   {
      if(reason==REASON_CHARTCHANGE)
      {
         for(int i=ObjectsTotal(0)-1;i>=0;i--)
         { string name=ObjectName(0,i); if(StringFind(name,Prefix)==0 && name!=Prefix+"State") ObjectDelete(0,name); }
      }
      else ObjectsDeleteAll(0,Prefix);
   }
   ChartRedraw();
}
