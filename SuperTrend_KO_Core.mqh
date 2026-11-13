// This Source Code Form is subject to the Mozilla Public License, v. 2.0.
// https://mozilla.org/MPL/2.0/
// Original Supertrend: KivancOzbilgic, with credit to everget.
// Independent MQL5 adaptation: Codex, 2026.
#ifndef SUPERTREND_KO_CORE_MQH
#define SUPERTREND_KO_CORE_MQH

enum STATRMethod { ATR_RMA=0,ATR_SMA=1 };
enum STPrice { Source_HL2=0,Source_Close,Source_Open,Source_High,Source_Low,Source_HLC3,Source_OHLC4,Source_HLCC4 };
struct STPoint
{
   datetime time;
   double atr,lower,upper,line,mid;
   int direction,signal;
   bool valid;
};
double STSource(const MqlRates &b,const STPrice source)
{
   switch(source)
   {
      case Source_Close: return b.close;
      case Source_Open: return b.open;
      case Source_High: return b.high;
      case Source_Low: return b.low;
      case Source_HLC3: return (b.high+b.low+b.close)/3;
      case Source_OHLC4: return (b.open+b.high+b.low+b.close)/4;
      case Source_HLCC4: return (b.high+b.low+2*b.close)/4;
   }
   return (b.high+b.low)/2;
}
class STKernel
{
public:
   int period,count,samples,direction;
   double multiplier,previousClose,previousATR,previousLower,previousUpper,sum,window[];
   STATRMethod method;
   STPrice source;
   void Reset(const int length,const double factor,const STATRMethod atrMethod,const STPrice price)
   {
      period=length; multiplier=factor; method=atrMethod; source=price;
      count=0; samples=0; direction=1; previousClose=0; sum=0;
      previousATR=EMPTY_VALUE; previousLower=EMPTY_VALUE; previousUpper=EMPTY_VALUE;
      ArrayResize(window,MathMax(1,length)); ArrayInitialize(window,0);
   }
   STPoint Step(const MqlRates &bar,const bool commit=true)
   {
      STPoint p; ZeroMemory(p); p.time=bar.time; p.mid=(bar.open+bar.high+bar.low+bar.close)/4;
      p.atr=EMPTY_VALUE; p.lower=EMPTY_VALUE; p.upper=EMPTY_VALUE; p.line=EMPTY_VALUE; p.direction=direction;
      double tr=bar.high-bar.low;
      if(count>0) tr=MathMax(tr,MathMax(MathAbs(bar.high-previousClose),MathAbs(bar.low-previousClose)));
      // Pine atr() handles the first missing previous close; bare tr in sma(tr) does not.
      bool hasTR=method==ATR_RMA || count>0;
      double nextSum=sum;
      if(hasTR)
      {
         nextSum=sum+tr-(samples>=period?window[samples%period]:0);
         if(samples+1>=period)
            p.atr=method==ATR_SMA || samples+1==period?nextSum/period:
                  previousATR*(1.0-1.0/period)+tr/period;
      }
      if(p.atr!=EMPTY_VALUE && MathIsValidNumber(p.atr))
      {
         double price=STSource(bar,source),basicLow=price-multiplier*p.atr,basicHigh=price+multiplier*p.atr;
         double low1=previousLower==EMPTY_VALUE?basicLow:previousLower;
         double high1=previousUpper==EMPTY_VALUE?basicHigh:previousUpper;
         p.lower=count>0 && previousClose>low1?MathMax(basicLow,low1):basicLow;
         p.upper=count>0 && previousClose<high1?MathMin(basicHigh,high1):basicHigh;
         p.direction=direction==-1 && bar.close>high1?1:direction==1 && bar.close<low1?-1:direction;
         p.signal=p.direction==direction?0:p.direction;
         p.line=p.direction==1?p.lower:p.upper; p.valid=true;
      }
      if(commit)
      {
         if(hasTR) { window[samples%period]=tr; samples++; sum=nextSum; }
         previousATR=p.atr; previousLower=p.lower; previousUpper=p.upper;
         previousClose=bar.close; direction=p.direction; count++;
      }
      return p;
   }
};

// Only completed source bars can be selected. next bar's opening time is availability.
int STClosedIndex(const MqlRates &rates[],const datetime cutoff,int hint=-1)
{
   int count=ArraySize(rates); hint=MathMax(-1,MathMin(hint,count-2));
   while(hint+2<count && rates[hint+2].time<=cutoff) hint++;
   return hint;
}
#endif
