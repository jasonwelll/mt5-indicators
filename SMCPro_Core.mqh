// Derived from LuxAlgo SMC and Jlubin782's SMC Pro [Neon], CC BY-NC-SA 4.0.
// See README.zh-CN.md and LICENSE.md. This is an independent MQL5 port.
#ifndef SMC_PRO_CORE_MQH
#define SMC_PRO_CORE_MQH

struct SMCConfig
{
   bool present,candles,internal,swing,confluence,swingPoints,strongWeak;
   int internalBull,internalBear,swingBull,swingBear,swingLength;
   bool internalOB,swingOB,meanRange,closeMitigation,equal,fvg,autoFVG,zones,gradient;
   int internalOBCount,swingOBCount,equalLength,fvgExtend,historyLimit,atrLength;
   double equalThreshold;
};

void SMCDefaults(SMCConfig &c)
{
   ZeroMemory(c);
   c.internal=true; c.swing=true; c.strongWeak=true; c.internalOB=true;
   c.equal=true; c.autoFVG=true; c.gradient=true;
   c.swingLength=50; c.internalOBCount=5; c.swingOBCount=5;
   c.equalLength=3; c.equalThreshold=0.1; c.fvgExtend=1;
   c.historyLimit=500; c.atrLength=200;
}

bool SMCValid(const double v) { return v!=EMPTY_VALUE && MathIsValidNumber(v); }

struct SMCPivot
{
   double level,last;
   int index;
   datetime time;
   bool crossed;
};
void SMCClearPivot(SMCPivot &p)
{
   ZeroMemory(p); p.level=EMPTY_VALUE; p.last=EMPTY_VALUE;
}

struct SMCMark
{
   int group,layer,bias,style,fade;
   datetime begin,end;
   double first,second;
   bool above,line;
   string text;
};

struct SMCBlock
{
   datetime time;
   double high,low;
   int bias;
};

struct SMCGap
{
   datetime begin,end;
   double top,bottom;
   int bias;
};

struct SMCExtremes
{
   double top,bottom;
   datetime topTime,bottomTime,pivotTime;
   int pivotIndex,trend;
};

// Bits follow the order of alert fields in the selected Pine source.
enum SMCEvent
{
   SMC_INT_BULL_BOS=0,SMC_INT_BEAR_BOS,SMC_INT_BULL_CHOCH,SMC_INT_BEAR_CHOCH,
   SMC_SW_BULL_BOS,SMC_SW_BEAR_BOS,SMC_SW_BULL_CHOCH,SMC_SW_BEAR_CHOCH,
   SMC_INT_BULL_OB_MIT,SMC_INT_BEAR_OB_MIT,SMC_SW_BULL_OB_MIT,SMC_SW_BEAR_OB_MIT,
   SMC_EQH,SMC_EQL,SMC_BULL_FVG,SMC_BEAR_FVG
};

struct SMCOutput
{
   uint events;
   int candleBias,internalBias,swingBias;
};

class SMCProEngine
{
public:
   SMCConfig config;
   MqlRates bars[];
   double parsedHigh[],parsedLow[];
   SMCPivot swingHigh,swingLow,internalHigh,internalLow,equalHigh,equalLow;
   int swingLeg,internalLeg,equalLeg,swingBias,internalBias;
   double atr,atrSeed,rangeSum,fvgDeltaSum;
   SMCExtremes trailing,displayedTrailing;
   SMCMark marks[];
   SMCBlock internalBlocks[],swingBlocks[];
   SMCGap gaps[];

   void Reset(SMCConfig &c)
   {
      config=c;
      ArrayFree(bars); ArrayFree(parsedHigh); ArrayFree(parsedLow);
      ArrayFree(marks); ArrayFree(internalBlocks); ArrayFree(swingBlocks); ArrayFree(gaps);
      SMCClearPivot(swingHigh); SMCClearPivot(swingLow);
      SMCClearPivot(internalHigh); SMCClearPivot(internalLow);
      SMCClearPivot(equalHigh); SMCClearPivot(equalLow);
      swingLeg=0; internalLeg=0; equalLeg=0; swingBias=0; internalBias=0;
      atr=EMPTY_VALUE; atrSeed=0; rangeSum=0; fvgDeltaSum=0;
      ZeroMemory(trailing); trailing.top=EMPTY_VALUE; trailing.bottom=EMPTY_VALUE;
      displayedTrailing=trailing;
   }

   void AddMark(SMCMark &m)
   {
      if(config.present)
         for(int k=ArraySize(marks)-1;k>=0;k--)
            if(marks[k].group==m.group) ArrayRemove(marks,k,1);
      int n=ArraySize(marks);
      if(n>=config.historyLimit) { ArrayRemove(marks,0,1); n--; }
      ArrayResize(marks,n+1,512); marks[n]=m;
   }

   void DetectPivot(const int length,int &leg,SMCPivot &high,SMCPivot &low,
                    const int layer,SMCOutput &out)
   {
      int i=ArraySize(bars)-1;
      if(i<length) return;
      double highest=-DBL_MAX,lowest=DBL_MAX;
      for(int k=i-length+1;k<=i;k++)
      {
         highest=MathMax(highest,bars[k].high);
         lowest=MathMin(lowest,bars[k].low);
      }
      int next=leg,ci=i-length;
      if(bars[ci].high>highest) next=0;
      else if(bars[ci].low<lowest) next=1;
      if(next==leg) return;
      leg=next;
      if(next==1) SetPivot(low,true,ci,layer,out);
      else SetPivot(high,false,ci,layer,out);
   }

   void SetPivot(SMCPivot &p,const bool isLow,const int ci,const int layer,SMCOutput &out)
   {
      double price=isLow?bars[ci].low:bars[ci].high;
      if(layer==2 && SMCValid(p.level) && SMCValid(atr) &&
         MathAbs(p.level-price)<config.equalThreshold*atr)
      {
         SMCMark m; ZeroMemory(m);
         m.group=isLow?21:20; m.layer=2; m.bias=isLow?1:-1;
         m.style=STYLE_DOT; m.begin=p.time; m.end=bars[ci].time;
         m.first=p.level; m.second=price; m.above=!isLow; m.line=true;
         m.text=isLow?"EQL":"EQH"; AddMark(m);
         out.events|=(uint)1<<(isLow?SMC_EQL:SMC_EQH);
      }
      p.last=p.level; p.level=price; p.index=ci; p.time=bars[ci].time; p.crossed=false;
      if(layer!=0) return;
      if(isLow) { trailing.bottom=price; trailing.bottomTime=p.time; }
      else { trailing.top=price; trailing.topTime=p.time; }
      trailing.pivotTime=p.time; trailing.pivotIndex=ci;
      if(!config.swingPoints) return;
      SMCMark m; ZeroMemory(m);
      m.group=isLow?31:30; m.layer=3; m.bias=isLow?1:-1;
      m.begin=p.time; m.end=p.time; m.first=price; m.second=price; m.above=!isLow;
      m.text=isLow?(SMCValid(p.last)&&price<p.last?"LL":"HL"):
                   (SMCValid(p.last)&&price>p.last?"HH":"LH");
      AddMark(m);
   }

   void StoreBlock(SMCPivot &p,SMCBlock &blocks[],const int bias)
   {
      int i=ArraySize(bars)-1;
      if(p.index>=i) return;
      int selected=p.index;
      for(int k=p.index+1;k<i;k++)
         if(bias==1?parsedLow[k]<parsedLow[selected]:parsedHigh[k]>parsedHigh[selected])
            selected=k;
      int n=MathMin(ArraySize(blocks),99);
      ArrayResize(blocks,n+1,100);
      for(int k=n;k>0;k--) blocks[k]=blocks[k-1];
      blocks[0].time=bars[selected].time;
      blocks[0].high=parsedHigh[selected]; blocks[0].low=parsedLow[selected]; blocks[0].bias=bias;
   }

   void DetectBreak(const bool internal,SMCPivot &high,SMCPivot &low,int &bias,
                    const double previousHigh,const double previousLow,SMCOutput &out)
   {
      int i=ArraySize(bars)-1;
      if(i==0) return;
      // Retain the source's unusual confluence expression for parity.
      double upper=bars[i].high-MathMax(bars[i].close,bars[i].open);
      double lower=MathMin(bars[i].close,bars[i].open-bars[i].low);
      if(!internal || (SMCValid(swingHigh.level) && high.level!=swingHigh.level &&
         (!config.confluence || upper>lower)))
         BreakOne(internal,high,bias,1,previousHigh,out);
      if(!internal || (SMCValid(swingLow.level) && low.level!=swingLow.level &&
         (!config.confluence || upper<lower)))
         BreakOne(internal,low,bias,-1,previousLow,out);
   }

   void BreakOne(const bool internal,SMCPivot &p,int &bias,const int direction,
                 const double previous,SMCOutput &out)
   {
      int i=ArraySize(bars)-1;
      if(!SMCValid(p.level) || !SMCValid(previous) || p.crossed) return;
      bool crosses=direction==1?bars[i].close>p.level && bars[i-1].close<=previous:
                                bars[i].close<p.level && bars[i-1].close>=previous;
      if(!crosses) return;
      bool choch=bias==-direction;
      p.crossed=true; bias=direction;
      int bit=(internal?0:4)+(choch?2:0)+(direction==1?0:1);
      out.events|=(uint)1<<bit;
      int filter=internal?(direction==1?config.internalBull:config.internalBear):
                          (direction==1?config.swingBull:config.swingBear);
      if((internal?config.internal:config.swing) && (filter==0 || filter==(choch?2:1)))
      {
         SMCMark m; ZeroMemory(m);
         m.group=(internal?0:2)+(direction==1?0:1); m.layer=internal?1:0; m.bias=direction;
         m.style=internal?STYLE_DASH:STYLE_SOLID; m.begin=p.time; m.end=bars[i].time;
         m.first=p.level; m.second=p.level; m.above=direction==1; m.line=true;
         m.text=choch?"CHoCH":"BOS";
         if(config.gradient && SMCValid(atr) && atr>0)
            m.fade=(int)MathRound(55*(1-MathMin(MathAbs(bars[i].close-p.level)/atr,3.0)/3.0));
         AddMark(m);
      }
      if(internal && config.internalOB) StoreBlock(p,internalBlocks,direction);
      if(!internal && config.swingOB) StoreBlock(p,swingBlocks,direction);
   }

   void Mitigate(SMCBlock &blocks[],const bool internal,SMCOutput &out)
   {
      int i=ArraySize(bars)-1;
      // Reverse traversal removes every invalidated block, including adjacent ones.
      for(int k=ArraySize(blocks)-1;k>=0;k--)
      {
         bool broken=blocks[k].bias==1?
            (config.closeMitigation?bars[i].close:bars[i].low)<blocks[k].low:
            (config.closeMitigation?bars[i].close:bars[i].high)>blocks[k].high;
         if(!broken) continue;
         out.events|=(uint)1<<((internal?8:10)+(blocks[k].bias==1?0:1));
         ArrayRemove(blocks,k,1);
      }
   }

   void DetectGap(MqlRates &older,MqlRates &middle,MqlRates &current,
                  const int chartIndex,const int chartSeconds,SMCOutput &out)
   {
      if(middle.open==0 || chartIndex<=0) return;
      double delta=(middle.close-middle.open)/(middle.open*100.0);
      fvgDeltaSum+=MathAbs(delta);
      double threshold=config.autoFVG?fvgDeltaSum/chartIndex*2:0;
      bool bull=older.time!=0 && current.low>older.high && middle.close>older.high && delta>threshold;
      bool bear=older.time!=0 && current.high<older.low && middle.close<older.low && -delta>threshold;
      if(!bull && !bear) return;
      int n=MathMin(ArraySize(gaps),249);
      ArrayResize(gaps,n+1,256);
      for(int k=n;k>0;k--) gaps[k]=gaps[k-1];
      gaps[0].begin=middle.time;
      gaps[0].end=current.time+config.fvgExtend*chartSeconds;
      gaps[0].bias=bull?1:-1;
      gaps[0].top=bull?current.low:current.high;
      gaps[0].bottom=bull?older.high:older.low;
      out.events|=(uint)1<<(bull?SMC_BULL_FVG:SMC_BEAR_FVG);
   }

   SMCOutput Append(MqlRates &b,const bool externalFVG=false)
   {
      int i=ArraySize(bars);
      SMCOutput out; ZeroMemory(out); out.candleBias=internalBias;
      double psh=swingHigh.level,psl=swingLow.level,pih=internalHigh.level,pil=internalLow.level;
      double tr=b.high-b.low;
      if(i>0) tr=MathMax(tr,MathMax(MathAbs(b.high-bars[i-1].close),MathAbs(b.low-bars[i-1].close)));
      if(i<config.atrLength) atrSeed+=tr;
      if(i==config.atrLength-1) atr=atrSeed/config.atrLength;
      else if(i>=config.atrLength) atr=(atr*(config.atrLength-1)+tr)/config.atrLength;
      if(i>0) rangeSum+=tr;
      double measure=config.meanRange?(i>0?rangeSum/i:EMPTY_VALUE):atr;
      bool volatileBar=SMCValid(measure) && b.high-b.low>=2*measure;
      ArrayResize(bars,i+1,4096); bars[i]=b;
      ArrayResize(parsedHigh,i+1,4096); parsedHigh[i]=volatileBar?b.low:b.high;
      ArrayResize(parsedLow,i+1,4096); parsedLow[i]=volatileBar?b.high:b.low;
      if(config.strongWeak || config.zones)
      {
         if(SMCValid(trailing.top) && b.high>=trailing.top)
         { trailing.top=b.high; trailing.topTime=b.time; }
         if(SMCValid(trailing.bottom) && b.low<=trailing.bottom)
         { trailing.bottom=b.low; trailing.bottomTime=b.time; }
         displayedTrailing=trailing; displayedTrailing.trend=swingBias;
      }
      if(config.fvg)
         for(int k=ArraySize(gaps)-1;k>=0;k--)
            if(gaps[k].bias==1?b.low<gaps[k].bottom:b.high>gaps[k].top) ArrayRemove(gaps,k,1);
      DetectPivot(config.swingLength,swingLeg,swingHigh,swingLow,0,out);
      DetectPivot(5,internalLeg,internalHigh,internalLow,1,out);
      if(config.equal) DetectPivot(config.equalLength,equalLeg,equalHigh,equalLow,2,out);
      if(config.internal || config.internalOB || config.candles)
         DetectBreak(true,internalHigh,internalLow,internalBias,pih,pil,out);
      if(config.swing || config.swingOB || config.strongWeak)
         DetectBreak(false,swingHigh,swingLow,swingBias,psh,psl,out);
      if(config.internalOB) Mitigate(internalBlocks,true,out);
      if(config.swingOB) Mitigate(swingBlocks,false,out);
      if(config.fvg && !externalFVG && i>=1)
      {
         MqlRates older; ZeroMemory(older);
         if(i>=2) older=bars[i-2];
         DetectGap(older,bars[i-1],b,i,(int)(b.time-bars[i-1].time),out);
      }
      out.internalBias=internalBias; out.swingBias=swingBias;
      return out;
   }
};
#endif
