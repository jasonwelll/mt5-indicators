#ifndef TPO_SESSION_CORE_MQH
#define TPO_SESSION_CORE_MQH
#include "IB_RTH_Core.mqh"
#include "VP_Nodes_Core.mqh"

enum TPSession { RTH_Only=0, ETH_Only=1, Separate_RTH_ETH=2, Full_Day=3, Custom_Session=4 };
enum TPVolume { TP_Tick_Volume=0, TP_Real_Trade_Volume=1 };
enum TPExtension { Session_End=0, Latest_Profile=1, All_Profiles=2 };
enum TPUpdateMode { Developing_Subperiod=0, Closed_Subperiods_Only=1 };
enum TPPanelPosition { Panel_Bottom_Left=0, Panel_Top_Left=1, Panel_Bottom_Right=2 };
enum TPSingleLineMode { SP_Zone_Edges=0, SP_Each_Price_Row=1 };
struct TPSingleZone { int lower,upper,state; };
struct TPPanelBox { int x,y,width,height,columns; };
int TPProfileLeft(const int anchor,const int minimum,const int right,const int columns,const int cell,const int pitch,const bool fit)
{
   if(!fit || columns<1) return MathMax(minimum,anchor);
   return MathMax(minimum,MathMin(anchor,right-(columns-1)*pitch-cell));
}
TPPanelBox TPPanelLayout(const int chartWidth,const int chartHeight,const TPPanelPosition position,
   const bool visible,const int marginX,const int marginY)
{
   TPPanelBox box;
   int available=MathMax(1,chartWidth-60-2*marginX);
   box.columns=!visible?1:available>=412?4:available>=222?2:1;
   box.width=!visible?MathMin(82,available):box.columns==4?412:box.columns==2?222:MathMin(108,available);
   int rows=visible?(4+box.columns-1)/box.columns:1;
   box.height=rows*29-6;
   box.x=position==Panel_Bottom_Right?MathMax(0,chartWidth-60-marginX-box.width):marginX;
   box.y=position==Panel_Top_Left?marginY:MathMax(0,chartHeight-marginY-box.height);
   return box;
}
bool TPExtend(const TPExtension mode,const int index,const int count)
{ return index>=0 && index<count && (mode==All_Profiles || (mode==Latest_Profile && index==count-1)); }
struct TPWindow { IBWindow time; int kind; };
struct TPStats
{
   bool valid;
   int poc,lower,upper;
   double total,inside;
};

string TPLetter(const int slot)
{
   string alphabet="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
   return StringSubstr(alphabet,slot%52,1)+(slot>=52?IntegerToString(slot/52+1):"");
}
string TPKindName(const int kind)
{ return kind==0?"RTH":kind==1?"ETH":kind==2?"24H":"Custom"; }

TPStats TPAnalyze(const double &bins[],const double percent)
{
   TPStats s; ZeroMemory(s); int n=ArraySize(bins);
   if(n<1 || percent<=0 || percent>100) return s;
   double peak=0,mid=(n-1)/2.0;
   for(int i=0;i<n;i++)
   {
      s.total+=bins[i];
      if(bins[i]>peak || (bins[i]==peak && MathAbs(i-mid)<MathAbs(s.poc-mid)))
      { peak=bins[i]; s.poc=i; }
   }
   if(peak<=0 || s.total<=0) return s;
   s.valid=true; s.lower=s.poc; s.upper=s.poc; s.inside=bins[s.poc];
   while(s.inside<s.total*percent/100 && (s.lower>0 || s.upper<n-1))
   {
      double down=s.lower>0?bins[s.lower-1]:-1,up=s.upper<n-1?bins[s.upper+1]:-1;
      if(up==down && up>=0)
      { s.lower--; s.upper++; s.inside+=up+down; }
      else if(up>down && s.upper<n-1) { s.upper++; s.inside+=up; }
      else if(s.lower>0) { s.lower--; s.inside+=down; }
      else break;
   }
   return s;
}

bool TPBuildWindow(const datetime date,const int kind,const IBClock clock,const IBServerClock server,const int offset,
   const int rthStart,const int rthEnd,const int ethStart,const int ethEnd,const int dayStart,
   const int customStart,const int customEnd,TPWindow &w)
{
   int start=kind==0?rthStart:kind==1?ethStart:kind==2?dayStart:customStart;
   int end=kind==0?rthEnd:kind==1?ethEnd:kind==2?dayStart:customEnd;
   datetime anchor=date;
   // Associate an overnight ETH profile with the date on which it ends.
   if(kind==1 && ethEnd<=ethStart) anchor-=86400;
   if(!IBMakeWindow(anchor,clock,server,offset,start,1,end,w.time)) return false;
   w.time.date=date; w.kind=kind; return true;
}

bool TPWindowWeekday(const TPWindow &w,const IBClock clock,const IBServerClock server,const int offset)
{
   if(w.kind!=1) return IBWeekday(w.time.date);
   datetime startUTC=0,endUTC=0;
   if(!IBServerToUTC(w.time.start,server,offset,startUTC) || !IBServerToUTC(w.time.close-1,server,offset,endUTC)) return false;
   return IBWeekday(IBDay(IBUTCToLocal(startUTC,clock,server,offset))) ||
      IBWeekday(IBDay(IBUTCToLocal(endUTC,clock,server,offset)));
}

class TPProfile
{
public:
   TPWindow window;
   double low,step,high;
   int rows,slots,bars,positiveVolumeBars;
   int periodSeconds,firstMultiple,lastMultiple;
   int openRow,openSlot,closeRow,closeSlot;
   double openPrice,closePrice;
   datetime openTime,closeTime;
   datetime observedAt;
   bool valid,complete,partialVolume;
   string error;
   uchar visits[];
   uchar occupiedSlots[];
   double counts[],volumes[];
   TPStats tpo,volume;

   void Reset()
   {
      low=0; step=0; high=0; rows=0; slots=0; bars=0; positiveVolumeBars=0;
      periodSeconds=0; observedAt=0; firstMultiple=-1; lastMultiple=-1;
      openRow=-1; openSlot=-1; closeRow=-1; closeSlot=-1;
      openPrice=0; closePrice=0; openTime=0; closeTime=0;
      valid=false; complete=false; partialVolume=false; error="";
      ZeroMemory(tpo); ZeroMemory(volume);
      ArrayFree(visits); ArrayFree(occupiedSlots); ArrayFree(counts); ArrayFree(volumes);
   }
   bool Hit(const int row,const int slot)
   { return row>=0 && row<rows && slot>=0 && slot<slots && visits[row*slots+slot]!=0; }
   int PackedColumn(const int row,const int slot)
   {
      if(!Hit(row,slot)) return -1;
      int n=0; for(int i=0;i<slot;i++) if(Hit(row,i)) n++; return n;
   }
   int DisplayColumn(const int row,const int slot,const bool expanded)
   { return !Hit(row,slot)?-1:expanded?slot:PackedColumn(row,slot); }
   double Price(const int row) { return low+(row+0.5)*step; }
   bool OpeningCell(const int row,const int slot)
   { return valid && row==openRow && slot==openSlot; }
   bool CloseVisible(const bool developing=false)
   { return valid && (complete || developing); }
   double POC(const bool useVolume)
   { return useVolume?(volume.valid?Price(volume.poc):EMPTY_VALUE):(tpo.valid?Price(tpo.poc):EMPTY_VALUE); }
   // 0 = not a single, 1 = developing, 2 = following subperiod has closed.
   int SinglePrintState(const int row,const bool includeTails=false)
   {
      if(!valid || row<0 || row>=rows || counts[row]!=1 || periodSeconds<1) return 0;
      if(!includeTails && (firstMultiple<0 || row<=firstMultiple || row>=lastMultiple)) return 0;
      int owner=-1;
      for(int i=0;i<slots;i++) if(Hit(row,i)) { owner=i; break; }
      if(owner<0) return 0;
      if(owner+1>=slots || occupiedSlots[owner+1]==0) return 1;
      datetime followingClose=(datetime)MathMin((long)window.time.close,(long)window.time.start+(owner+2)*periodSeconds);
      return observedAt>=followingClose?2:1;
   }
   int SinglePrintZones(TPSingleZone &zones[],const bool confirmedOnly=true,const bool includeTails=false)
   {
      ArrayFree(zones);
      for(int row=0;row<rows;row++)
      {
         int state=SinglePrintState(row,includeTails);
         if(state==0 || (confirmedOnly && state!=2)) continue;
         int count=ArraySize(zones);
         if(count>0 && zones[count-1].upper==row-1 && zones[count-1].state==state) zones[count-1].upper=row;
         else
         {
            ArrayResize(zones,count+1); zones[count].lower=row; zones[count].upper=row; zones[count].state=state;
         }
      }
      return ArraySize(zones);
   }
   bool Build(const MqlRates &source[],const TPWindow &w,const datetime asOf,const int periodMinutes,
      const double rowSize,const double tick,const double valuePercent,const TPVolume volumeSource,const int maxRows,
      const bool closedSubperiodsOnly=false)
   {
      Reset(); window=w; complete=asOf>=w.time.close;
      int total=ArraySize(source);
      if(total<1 || source[0].time>w.time.start) { error="Incomplete M1 history"; return false; }
      if(asOf<w.time.start || periodMinutes<1 || rowSize<=0 || tick<=0 || maxRows<1) return false;
      periodSeconds=periodMinutes*60; observedAt=asOf;
      datetime cutoff=asOf;
      if(closedSubperiodsOnly && !complete)
         cutoff=w.time.start+((asOf-w.time.start)/periodSeconds)*periodSeconds-1;
      if(cutoff<w.time.start) { error="Waiting for first closed TPO subperiod"; return false; }
      MqlRates selected[];
      int first=-1,last=-1;
      for(int i=0;i<total;i++)
      {
         if(source[i].time<w.time.start) continue;
         if(source[i].time>=w.time.close || source[i].time>cutoff) break;
         if(first<0) first=i; last=i;
      }
      if(first<0) return false;
      bars=last-first+1;
      openPrice=source[first].open; closePrice=source[last].close;
      openTime=source[first].time; closeTime=source[last].time;
      if(!MathIsValidNumber(openPrice) || !MathIsValidNumber(closePrice) ||
         openPrice<source[first].low || openPrice>source[first].high ||
         closePrice<source[last].low || closePrice>source[last].high)
      { error="Invalid M1 open/close"; return false; }
      ArrayResize(selected,bars+1);
      for(int i=0;i<bars;i++) selected[i]=source[first+i];
      double minPrice=selected[0].low,maxPrice=selected[0].high;
      for(int i=0;i<bars;i++)
      {
         if(!MathIsValidNumber(selected[i].low) || !MathIsValidNumber(selected[i].high) || selected[i].low>selected[i].high)
         { error="Invalid M1 price"; return false; }
         minPrice=MathMin(minPrice,selected[i].low); maxPrice=MathMax(maxPrice,selected[i].high);
         if((volumeSource==TP_Tick_Volume?selected[i].tick_volume:selected[i].real_volume)>0) positiveVolumeBars++;
      }
      step=MathMax(tick,MathCeil(rowSize/tick-1e-9)*tick);
      low=MathFloor(minPrice/step+1e-9)*step;
      rows=(int)MathFloor((maxPrice-low)/step+1e-9)+1;
      slots=(int)MathCeil((double)(w.time.close-w.time.start)/(periodMinutes*60));
      if(rows>maxRows || slots>288) { error="Increase price row size / subperiod length"; return false; }
      if(rows<1 || slots<1) return false;
      high=low+rows*step;
      openRow=VPClamp((int)MathFloor((openPrice-low)/step+1e-9),0,rows-1);
      closeRow=VPClamp((int)MathFloor((closePrice-low)/step+1e-9),0,rows-1);
      openSlot=(int)((openTime-w.time.start)/periodSeconds);
      closeSlot=(int)((closeTime-w.time.start)/periodSeconds);
      ArrayResize(visits,rows*slots); ArrayInitialize(visits,0);
      ArrayResize(occupiedSlots,slots); ArrayInitialize(occupiedSlots,0);
      ArrayResize(counts,rows); ArrayInitialize(counts,0);
      for(int i=0;i<bars;i++)
      {
         int slot=(int)((selected[i].time-w.time.start)/(periodMinutes*60));
         occupiedSlots[slot]=1;
         int bottom=VPClamp((int)MathFloor((selected[i].low-low)/step+1e-9),0,rows-1);
         int top=VPClamp((int)MathFloor((selected[i].high-low)/step+1e-9),0,rows-1);
         for(int row=bottom;row<=top;row++)
            if(!Hit(row,slot)) { visits[row*slots+slot]=1; counts[row]++; }
      }
      for(int row=0;row<rows;row++) if(counts[row]>1)
      { if(firstMultiple<0) firstMultiple=row; lastMultiple=row; }
      tpo=TPAnalyze(counts,valuePercent);
      // Reuse the existing bar-volume allocator on this profile's fixed price grid.
      // A zero-volume sentinel sets the grid bounds without adding any activity.
      ZeroMemory(selected[bars]); selected[bars].low=low; selected[bars].high=high;
      selected[bars].open=low; selected[bars].close=low; selected[bars].time=w.time.start;
      VPProfile allocator;
      if(allocator.Build(selected,rows,valuePercent,tick,volumeSource==TP_Real_Trade_Volume,false,false))
      {
         ArrayCopy(volumes,allocator.bins); volume=TPAnalyze(volumes,valuePercent);
      }
      else { ArrayResize(volumes,rows); ArrayInitialize(volumes,0); }
      partialVolume=positiveVolumeBars>0 && positiveVolumeBars<bars;
      valid=tpo.valid; return valid;
   }
};
#endif
