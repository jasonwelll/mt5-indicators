#ifndef IB_RTH_CORE_MQH
#define IB_RTH_CORE_MQH

enum IBClock { New_York_Time=0, Broker_Server_Time=1, UTC_Time=2 };
enum IBServerClock { FTMO_US_DST=0, Fixed_UTC_Offset=1, European_DST=2 };

struct IBWindow
{
   datetime date;
   datetime start;
   datetime finish;
   datetime close;
};
struct IBRange
{
   bool valid;
   bool covered;
   bool complete;
   double high;
   double low;
   double middle;
   int bars;
};

datetime IBDay(const datetime value)
{ return (datetime)((long)value/86400*86400); }

datetime IBDate(const int year,const int month,const int day,const int hour=0)
{
   MqlDateTime t; ZeroMemory(t);
   t.year=year; t.mon=month; t.day=day; t.hour=hour;
   return StructToTime(t);
}

int IBSunday(const int year,const int month,const int occurrence)
{
   MqlDateTime first; TimeToStruct(IBDate(year,month,1),first);
   return 1+(7-first.day_of_week)%7+(occurrence-1)*7;
}

bool IBNewYorkDST(const datetime utc)
{
   MqlDateTime t; TimeToStruct(utc,t);
   return utc>=IBDate(t.year,3,IBSunday(t.year,3,2),7) &&
          utc<IBDate(t.year,11,IBSunday(t.year,11,1),6);
}

bool IBEuropeDST(const datetime utc)
{
   MqlDateTime t,lastMarch,lastOctober; TimeToStruct(utc,t);
   TimeToStruct(IBDate(t.year,3,31),lastMarch);
   TimeToStruct(IBDate(t.year,10,31),lastOctober);
   return utc>=IBDate(t.year,3,31-lastMarch.day_of_week,1) &&
          utc<IBDate(t.year,10,31-lastOctober.day_of_week,1);
}

int IBServerOffset(const datetime utc,const IBServerClock mode,const int standardMinutes)
{
   if(mode==FTMO_US_DST) return 120+(IBNewYorkDST(utc)?60:0);
   return standardMinutes+(mode==European_DST && IBEuropeDST(utc)?60:0);
}

datetime IBUTCToServer(const datetime utc,const IBServerClock mode,const int standardMinutes)
{ return utc+IBServerOffset(utc,mode,standardMinutes)*60; }

bool IBServerToUTC(const datetime server,const IBServerClock mode,const int standardMinutes,datetime &utc)
{
   int base=mode==FTMO_US_DST?120:standardMinutes;
   utc=server-base*60;
   if(IBUTCToServer(utc,mode,standardMinutes)==server) return true;
   utc=server-(base+60)*60;
   return IBUTCToServer(utc,mode,standardMinutes)==server;
}

datetime IBUTCToLocal(const datetime utc,const IBClock clock,const IBServerClock serverMode,const int offset)
{
   if(clock==New_York_Time) return utc+(IBNewYorkDST(utc)?-240:-300)*60;
   if(clock==Broker_Server_Time) return IBUTCToServer(utc,serverMode,offset);
   return utc;
}

bool IBLocalToUTC(const datetime local,const IBClock clock,const IBServerClock serverMode,const int offset,datetime &utc)
{
   if(clock==Broker_Server_Time) return IBServerToUTC(local,serverMode,offset,utc);
   if(clock==UTC_Time) { utc=local; return true; }
   // Resolve a repeated autumn hour to standard time; reject a missing spring hour.
   utc=local+300*60;
   if(IBUTCToLocal(utc,clock,serverMode,offset)==local) return true;
   utc=local+240*60;
   return IBUTCToLocal(utc,clock,serverMode,offset)==local;
}

bool IBMakeWindow(const datetime localDate,const IBClock clock,const IBServerClock serverMode,const int offset,
                  const int startMinute,const int duration,const int closeMinute,IBWindow &w)
{
   ZeroMemory(w); datetime date=IBDay(localDate),startUTC=0,closeUTC=0;
   if(startMinute<0 || startMinute>=1440 || closeMinute<0 || closeMinute>=1440 || duration<1 || duration>1440)
      return false;
   datetime startLocal=date+startMinute*60;
   datetime closeLocal=date+closeMinute*60+(closeMinute<=startMinute?86400:0);
   if(!IBLocalToUTC(startLocal,clock,serverMode,offset,startUTC) ||
      !IBLocalToUTC(closeLocal,clock,serverMode,offset,closeUTC) || startUTC+duration*60>closeUTC)
      return false;
   w.date=date;
   w.start=IBUTCToServer(startUTC,serverMode,offset);
   w.finish=IBUTCToServer(startUTC+duration*60,serverMode,offset);
   w.close=IBUTCToServer(closeUTC,serverMode,offset);
   // A server clock reversal inside the window is ambiguous in historical M1 timestamps.
   return w.finish>w.start && w.close>=w.finish &&
          IBServerOffset(startUTC,serverMode,offset)==IBServerOffset(closeUTC-1,serverMode,offset);
}

bool IBWeekday(const datetime localDate)
{
   MqlDateTime t; TimeToStruct(localDate,t);
   return t.day_of_week!=0 && t.day_of_week!=6;
}

IBRange IBMeasure(const MqlRates &rates[],const IBWindow &w,const datetime asOf)
{
   IBRange r; ZeroMemory(r);
   int count=ArraySize(rates);
   if(count==0 || asOf<w.start) return r;
   r.covered=rates[0].time<=w.start;
   r.complete=asOf>=w.finish;
   for(int i=0;i<count;i++)
   {
      if(rates[i].time<w.start) continue;
      if(rates[i].time>=w.finish || rates[i].time>asOf) break;
      if(!MathIsValidNumber(rates[i].high) || !MathIsValidNumber(rates[i].low) || rates[i].high<rates[i].low)
         continue;
      if(r.bars==0) { r.high=rates[i].high; r.low=rates[i].low; }
      else { r.high=MathMax(r.high,rates[i].high); r.low=MathMin(r.low,rates[i].low); }
      r.bars++;
   }
   r.valid=r.bars>0 && r.covered;
   if(r.valid) r.middle=(r.high+r.low)/2.0;
   return r;
}

#endif
