// Independent chart controls. Hiding never clears indicator data buffers.
#ifndef CODEX_CHART_VISIBILITY_MQH
#define CODEX_CHART_VISIBILITY_MQH

int CVButtonRank(const string name)
{
   if(StringLen(name)<6 || StringSubstr(name,StringLen(name)-6)!="Toggle") return -1;
   if(StringFind(name,"SMCP_")==0) return 0;
   if(StringFind(name,"STKO_")==0) return 1;
   if(StringFind(name,"IBR_")==0) return 2;
   if(StringFind(name,"VWAPEX_")==0) return 3;
   if(StringFind(name,"VPN_")==0) return 4;
   return -1;
}
void CVInt(const string name,const ENUM_OBJECT_PROPERTY_INTEGER property,const long value)
{ if(ObjectGetInteger(0,name,property)!=value) ObjectSetInteger(0,name,property,value); }
void CVText(const string name,const ENUM_OBJECT_PROPERTY_STRING property,const string value)
{ if(ObjectGetString(0,name,property)!=value) ObjectSetString(0,name,property,value); }

void CVCleanButtons(const int rank)
{
   string live="",titles[]={"SMC Pro Neon MT5 ","Supertrend KO MT5 ","IB RTH v","VWAP Execution v","VP Nodes MT5 "};
   string families[]={"SMCP_","STKO_","IBR_","VWAPEX_","VPN_"};
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++)
   {
      string title=ChartIndicatorName(0,0,i);
      if(StringFind(title,titles[rank])==0)
      {
         if(StringFind(title,"["+families[rank])<0) return;
         live+=title+"\n";
      }
   }
   // During iCustom initialization there may not yet be a native chart instance.
   if(live=="") return;
   for(int i=ObjectsTotal(0,0,OBJ_BUTTON)-1;i>=0;i--)
   {
      string name=ObjectName(0,i,0,OBJ_BUTTON);
      if(CVButtonRank(name)!=rank) continue;
      string owner=StringSubstr(name,0,StringLen(name)-6);
      if(StringFind(live,"["+owner+"]")<0) ObjectDelete(0,name);
   }
}

void CVCleanOwnedObjects(const int rank,const string own)
{
   string titles[]={"SMC Pro Neon MT5 ","Supertrend KO MT5 ","IB RTH v","VWAP Execution v","VP Nodes MT5 "};
   string families[]={"SMCP_","STKO_","IBR_","VWAPEX_","VPN_"};
   string live="",family=families[rank]; int start=StringLen(family);
   for(int i=0;i<ChartIndicatorsTotal(0,0);i++)
   {
      string title=ChartIndicatorName(0,0,i);
      if(StringFind(title,titles[rank])!=0) continue;
      // Leave older active versions that do not publish ownership untouched.
      if(StringFind(title,"["+family)<0) return;
      live+=title+"\n";
   }
   if(live=="") return;
   for(int i=ObjectsTotal(0)-1;i>=0;i--)
   {
      string name=ObjectName(0,i); if(StringFind(name,family)!=0) continue;
      int a=StringFind(name,"_",start),b=a<0?-1:StringFind(name,"_",a+1);
      if(a<=start || b<=a+1) continue;
      bool digits=true;
      for(int j=start;j<b;j++)
      {
         if(j==a) continue;
         ushort c=StringGetCharacter(name,j); if(c<'0' || c>'9') { digits=false; break; }
      }
      if(!digits) continue;
      string owner=StringSubstr(name,0,b+1);
      if(owner==own || StringFind(live,"["+owner+"]")>=0) continue;
      ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);
      if(type==OBJ_TREND || type==OBJ_TEXT || type==OBJ_RECTANGLE || type==OBJ_LABEL ||
         type==OBJ_BUTTON || type==OBJ_ARROW_RIGHT_PRICE) ObjectDelete(0,name);
   }
}

void CVButton(const string name,const string title,const string tag,const bool visible,
              const bool enabled,const int right,const int top)
{
   if(!enabled) { ObjectDelete(0,name); return; }
   bool created=ObjectFind(0,name)<0;
   if(created)
   {
      CVCleanButtons(CVButtonRank(name));
      if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0)) return;
   }
   int slot=0,rank=CVButtonRank(name),buttons=ObjectsTotal(0,0,OBJ_BUTTON);
   // A stable order prevents indicators from repeatedly pushing one another down.
   for(int i=0;i<buttons;i++)
   {
      string other=ObjectName(0,i,0,OBJ_BUTTON);
      int otherRank=CVButtonRank(other);
      if(otherRank>=0 && (otherRank<rank || (otherRank==rank && StringCompare(other,name)<0))) slot++;
   }
   int width=118,height=24,gap=5;
   int chartWidth=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   int chartHeight=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   int priceChars=(int)MathMax(StringLen(DoubleToString(ChartGetDouble(0,CHART_PRICE_MAX,0),_Digits)),
      StringLen(DoubleToString(ChartGetDouble(0,CHART_PRICE_MIN,0),_Digits)));
   int reserve=(int)MathMax(64,priceChars*8+16);
   int baseTop=(int)MathMin(top,MathMax(0,chartHeight-height));
   int rows=(int)MathMax(1,(chartHeight-baseTop)/(height+gap));
   int x=(int)MathMax(4,chartWidth-reserve-right-width-(slot/rows)*(width+gap));
   int y=baseTop+(slot%rows)*(height+gap);
   uint bg=(uint)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   bool dark=(int)(bg&255)+(int)((bg>>8)&255)+(int)((bg>>16)&255)<384;
   CVInt(name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   CVInt(name,OBJPROP_XDISTANCE,x); CVInt(name,OBJPROP_YDISTANCE,y);
   CVInt(name,OBJPROP_XSIZE,width); CVInt(name,OBJPROP_YSIZE,height);
   CVInt(name,OBJPROP_FONTSIZE,9); CVText(name,OBJPROP_FONT,"Arial");
   CVInt(name,OBJPROP_COLOR,dark?C'230,234,238':C'30,36,42');
   CVInt(name,OBJPROP_BGCOLOR,dark?C'38,44,50':C'239,242,245');
   CVInt(name,OBJPROP_BORDER_COLOR,dark?C'95,105,115':C'150,160,170');
   CVInt(name,OBJPROP_SELECTABLE,false); CVInt(name,OBJPROP_SELECTED,false);
   CVInt(name,OBJPROP_HIDDEN,true); CVInt(name,OBJPROP_BACK,false);
   CVInt(name,OBJPROP_ZORDER,100); CVInt(name,OBJPROP_TIMEFRAMES,OBJ_ALL_PERIODS);
   if(created) ObjectSetInteger(0,name,OBJPROP_STATE,false);
   CVText(name,OBJPROP_TEXT,title+(visible?": Hide":": Show"));
   CVText(name,OBJPROP_TOOLTIP,tag+": "+(visible?"Hide drawings; calculations and alerts continue":"Show drawings"));
}

class CVView
{
private:
   string prefix,title,tag,key;
   bool enabled,start;
   bool cleaned;
   int right,top;
public:
   bool visible;
   CVView()
   {
      prefix=""; title=""; tag=""; key=""; enabled=false; start=true;
      right=16; top=28; cleaned=false; visible=true;
   }
   void Init(const string owner,const string caption,const string instance,const bool showButton,
             const bool startVisible,const int rightPixels,const int topPixels)
   {
      prefix=owner; title=caption; tag=instance; enabled=showButton;
      start=startVisible; right=rightPixels; top=topPixels; visible=start; cleaned=false;
      uint hash=2166136261; string identity=title+"|"+tag;
      for(int i=0;i<StringLen(identity);i++) hash=(hash^(uint)StringGetCharacter(identity,i))*16777619;
      key="CVIEW_"+IntegerToString(ChartID())+"_"+IntegerToString(hash);
      double saved=0;
      if(GlobalVariableGet(key,saved) && (int)saved/2==(int)start) visible=((int)saved%2)==1;
   }
   string ButtonName() { return prefix+"Toggle"; }
   void Draw()
   {
      int rank=CVButtonRank(ButtonName());
      if(!cleaned && (rank==1 || rank==3)) { CVCleanOwnedObjects(rank,prefix); cleaned=true; }
      CVButton(ButtonName(),title,tag,visible,enabled,right,top);
   }
   bool Click(const int event,const string name)
   {
      if(!enabled || (event!=CHARTEVENT_OBJECT_CLICK && event!=-1) ||
         (event==CHARTEVENT_OBJECT_CLICK && name!=ButtonName()) ||
         !ObjectGetInteger(0,ButtonName(),OBJPROP_STATE)) return false;
      ObjectSetInteger(0,ButtonName(),OBJPROP_STATE,false);
      visible=!visible; Draw(); return true;
   }
   void Object(const string name)
   { CVInt(name,OBJPROP_TIMEFRAMES,visible?OBJ_ALL_PERIODS:OBJ_NO_PERIODS); }
   void Finish(const int reason)
   {
      if(prefix=="") return;
      if(key!="")
      {
         if(reason==REASON_CHARTCHANGE || reason==REASON_RECOMPILE || reason==REASON_PARAMETERS || reason==REASON_CLOSE)
            GlobalVariableSet(key,(int)start*2+(int)visible);
         else GlobalVariableDel(key);
      }
      ObjectDelete(0,ButtonName());
   }
};
#endif
