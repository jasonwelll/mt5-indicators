// Independent bar-based VWAP calculation. No trading or external data access.
#ifndef VWAP_EXECUTION_CORE_MQH
#define VWAP_EXECUTION_CORE_MQH

enum VWAnchor { Trading_Day=0,Trading_Week=1,Manual_Start=2 };
enum VWVolume { Tick_Activity=0,Real_Trade_Volume=1 };

datetime VWAnchorTime(const datetime time,const VWAnchor mode,const int resetMinutes,const datetime manual)
{
   if(mode==Manual_Start) return time>=manual?manual:0;
   datetime shifted=time-resetMinutes*60;
   MqlDateTime d; TimeToStruct(shifted,d);
   int weekday=d.day_of_week;
   d.hour=0; d.min=0; d.sec=0;
   datetime start=StructToTime(d)+resetMinutes*60;
   if(mode==Trading_Week) start-=((weekday+6)%7)*86400;
   return start;
}

double VWPrice(const MqlRates &bar,const ENUM_APPLIED_PRICE source)
{
   switch(source)
   {
      case PRICE_OPEN: return bar.open;
      case PRICE_HIGH: return bar.high;
      case PRICE_LOW: return bar.low;
      case PRICE_MEDIAN: return (bar.high+bar.low)/2;
      case PRICE_TYPICAL: return (bar.high+bar.low+bar.close)/3;
      case PRICE_WEIGHTED: return (bar.high+bar.low+2*bar.close)/4;
      default: return bar.close;
   }
}

struct VWPoint
{
   double mean,deviation,weight;
   datetime anchor;
   int quality; // 0=no weight, 1=complete, 2=zero-weight bars, 3=truncated history
   bool valid;
};

class VWKernel
{
private:
   VWAnchor mode;
   VWVolume volume;
   ENUM_APPLIED_PRICE source;
   int resetMinutes;
   datetime manual,currentAnchor,previousTime;
   double weight,mean,m2;
   bool complete;
   int missing;
public:
   void Reset(const VWAnchor a,const VWVolume v,const ENUM_APPLIED_PRICE s,const int minutes,const datetime start)
   {
      mode=a; volume=v; source=s; resetMinutes=minutes; manual=start;
      currentAnchor=0; previousTime=0; weight=0; mean=0; m2=0; complete=false; missing=0;
   }

   VWPoint Step(const MqlRates &bar,const bool commit=true)
   {
      VWPoint p; ZeroMemory(p);
      datetime key=VWAnchorTime(bar.time,mode,resetMinutes,manual);
      if(key==0)
      {
         if(commit) previousTime=bar.time;
         return p;
      }
      double w=weight,mu=mean,varianceSum=m2;
      int gaps=missing;
      bool covered=complete;
      if(key!=currentAnchor)
      {
         w=0; mu=0; varianceSum=0; gaps=0;
         // A preceding source bar or an exact boundary proves the anchor was loaded.
         covered=bar.time==key || (previousTime>0 && previousTime<key);
      }
      double amount=(double)(volume==Tick_Activity?bar.tick_volume:bar.real_volume);
      double price=VWPrice(bar,source);
      if(amount>0 && MathIsValidNumber(price))
      {
         double next=w+amount,delta=price-mu;
         mu+=amount/next*delta;
         varianceSum+=amount*delta*(price-mu);
         w=next;
      }
      else gaps++;
      p.anchor=key; p.weight=w;
      p.quality=!covered?3:w<=0?0:gaps>0?2:1;
      p.valid=covered && w>0;
      if(p.valid) { p.mean=mu; p.deviation=MathSqrt(MathMax(0,varianceSum/w)); }
      if(commit)
      {
         currentAnchor=key; previousTime=bar.time; weight=w; mean=mu;
         m2=varianceSum; complete=covered; missing=gaps;
      }
      return p;
   }
};

#endif
