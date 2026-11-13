// MPL 2.0. Chart object ownership for the retained Volume Nodes renderer.
#ifndef VP_OBJECTS_MQH
#define VP_OBJECTS_MQH
bool VPDigits(const string text)
{
   if(StringLen(text)==0) return false;
   for(int i=0;i<StringLen(text);i++)
   { ushort c=StringGetCharacter(text,i); if(c<'0' || c>'9') return false; }
   return true;
}
string VPOwnerPrefix(const string name)
{
   if(StringFind(name,"VPN_")!=0) return "";
   int first=StringFind(name,"_",4),second=first<0?-1:StringFind(name,"_",first+1);
   if(first<=4 || second<=first+1) return "";
   for(int i=4;i<second;i++)
   {
      if(i==first) continue;
      ushort c=StringGetCharacter(name,i);
      if(c<'0' || c>'9') return "";
   }
   return StringSubstr(name,0,second+1);
}
bool VPRecognizedObject(const long chart,const string name,const string prefix)
{
   string role=StringSubstr(name,StringLen(prefix));
   ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(chart,name,OBJPROP_TYPE);
   if(role=="Status") return type==OBJ_LABEL;
   if(role=="Toggle") return type==OBJ_BUTTON;
   if(role=="POC" || role=="VAH" || role=="VAL") return type==OBJ_TREND;
   if(role=="POCLabel" || role=="VAHLabel" || role=="VALLabel") return type==OBJ_LABEL;
   if(StringFind(role,"Row")==0 && StringLen(role)>7)
      return type==OBJ_RECTANGLE_LABEL && VPDigits(StringSubstr(role,3,StringLen(role)-7)) &&
             (StringSubstr(role,StringLen(role)-4)=="Bull" || StringSubstr(role,StringLen(role)-4)=="Bear");
   if(StringFind(role,"HVN")==0 || StringFind(role,"LVN")==0)
   {
      string tail=StringSubstr(role,3);
      if(type==OBJ_RECTANGLE) return VPDigits(tail);
      if(type==OBJ_LABEL && StringLen(tail)>5 && StringSubstr(tail,StringLen(tail)-5)=="Label")
         return VPDigits(StringSubstr(tail,0,StringLen(tail)-5));
   }
   return false;
}
bool VPCleanOrphans(const long chart,const string own)
{
   string live[];
   for(int w=0;w<(int)ChartGetInteger(chart,CHART_WINDOWS_TOTAL);w++)
      for(int i=0;i<ChartIndicatorsTotal(chart,w);i++)
      {
         string name=ChartIndicatorName(chart,w,i);
         if(StringFind(name,"VP Nodes MT5 ")!=0) continue;
         int start=StringFind(name,"[VPN_");
         // Older active instances do not expose ownership; leave their objects intact.
         if(start<0) return false;
         int end=StringFind(name,"]",start);
         if(end>start)
         { int n=ArraySize(live); ArrayResize(live,n+1); live[n]=StringSubstr(name,start+1,end-start-1); }
      }
   bool changed=false;
   for(int i=ObjectsTotal(chart)-1;i>=0;i--)
   {
      string name=ObjectName(chart,i),prefix=VPOwnerPrefix(name);
      if(prefix=="" || prefix==own) continue;
      bool active=false;
      for(int j=0;j<ArraySize(live);j++) if(live[j]==prefix) { active=true; break; }
      // MT5 templates omit tooltip strings. Match the renderer's names AND object types.
      if(active || !VPRecognizedObject(chart,name,prefix)) continue;
      string tip=ObjectGetString(chart,name,OBJPROP_TOOLTIP);
      if(StringSubstr(name,StringLen(prefix))!="Toggle" && tip!="" && StringFind(tip,"Volume Nodes")!=0) continue;
      if(ObjectDelete(chart,name)) changed=true;
   }
   if(changed) ChartRedraw(chart);
   return true;
}
#endif
