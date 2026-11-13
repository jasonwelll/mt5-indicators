#ifndef IB_RTH_OBJECTS_MQH
#define IB_RTH_OBJECTS_MQH
bool IBDigits(const string value)
{
   if(StringLen(value)==0) return false;
   for(int i=0;i<StringLen(value);i++)
   { ushort c=StringGetCharacter(value,i); if(c<'0' || c>'9') return false; }
   return true;
}
string IBOwner(const string name)
{
   if(StringFind(name,"IBR_")!=0) return "";
   int a=StringFind(name,"_",4),b=a<0?-1:StringFind(name,"_",a+1);
   if(a<0 || b<0 || !IBDigits(StringSubstr(name,4,a-4)) || !IBDigits(StringSubstr(name,a+1,b-a-1))) return "";
   return StringSubstr(name,0,b+1);
}
bool IBRecognized(const long chart,const string name,const string owner)
{
   string role=StringSubstr(name,StringLen(owner));
   ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(chart,name,OBJPROP_TYPE);
   if(role=="Status") return type==OBJ_LABEL;
   if(role=="Toggle") return type==OBJ_BUTTON;
   int split=StringFind(role,"_");
   if(split<1 || !IBDigits(StringSubstr(role,0,split))) return false;
   role=StringSubstr(role,split+1);
   if(role=="IBH" || role=="IBL" || role=="IBM") return type==OBJ_TREND;
   return (role=="IBH_T" || role=="IBL_T" || role=="IBM_T") && type==OBJ_TEXT;
}
void IBCleanOrphans(const long chart,const string own)
{
   string active[];
   for(int i=0;i<ChartIndicatorsTotal(chart,0);i++)
   {
      string title=ChartIndicatorName(chart,0,i);
      if(StringFind(title,"IB RTH v")!=0) continue;
      int a=StringFind(title,"[IBR_"),b=a<0?-1:StringFind(title,"]",a);
      if(a<0 || b<0) return;
      int n=ArraySize(active); ArrayResize(active,n+1); active[n]=StringSubstr(title,a+1,b-a-1);
   }
   for(int i=ObjectsTotal(chart)-1;i>=0;i--)
   {
      string name=ObjectName(chart,i),owner=IBOwner(name);
      if(owner=="" || owner==own || !IBRecognized(chart,name,owner)) continue;
      bool live=false;
      for(int j=0;j<ArraySize(active);j++) if(active[j]==owner) { live=true; break; }
      if(!live) ObjectDelete(chart,name);
   }
}
#endif
