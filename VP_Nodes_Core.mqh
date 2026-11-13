// This Source Code Form is subject to the Mozilla Public License, v. 2.0.
// https://mozilla.org/MPL/2.0/
// Port of Visible Range Volume Nodes by Crypto_Imperija (TradingView, 2026).
// MQL5 adaptation: Codex, 2026. See reference/ and README.zh-CN.md.
#ifndef VP_NODES_CORE_MQH
#define VP_NODES_CORE_MQH

int VPClamp(const int n,const int lo,const int hi) { return MathMax(lo,MathMin(hi,n)); }

bool VPWindow(const int firstVisible,const int visibleBars,const int total,const int cap,
              int &newest,int &oldest,bool &truncated)
{
   newest=0; oldest=-1; truncated=false;
   if(firstVisible<0 || visibleBars<=0 || total<=0 || cap<=0) return false;
   newest=MathMax(0,firstVisible-visibleBars+1);
   oldest=MathMin(firstVisible,MathMin(total-1,cap-1));
   truncated=firstVisible>oldest;
   return newest<=oldest;
}

double VPMin(const double &a[],const int lo,const int hi)
{
   if(lo>hi) return 0;
   double v=a[lo]; for(int i=lo+1;i<=hi;i++) v=MathMin(v,a[i]); return v;
}
double VPMax(const double &a[],const int lo,const int hi)
{
   if(lo>hi) return 0;
   double v=a[lo]; for(int i=lo+1;i<=hi;i++) v=MathMax(v,a[i]); return v;
}
bool VPFar(const int row,const int &a[],const int distance)
{
   for(int i=0;i<ArraySize(a);i++) if(MathAbs(row-a[i])<=distance) return false;
   return true;
}
bool VPExtreme(const double &a[],const int row,const bool maximum)
{
   for(int step=1;step<=2;step++)
   {
      if(row-step>=0 && (maximum?a[row-step]>a[row]:a[row-step]<a[row])) return false;
      if(row+step<ArraySize(a) && (maximum?a[row+step]>a[row]:a[row+step]<a[row])) return false;
   }
   return true;
}
void VPPush(int &a[],const int n) { int k=ArraySize(a); ArrayResize(a,k+1); a[k]=n; }
void VPCandidate(int &a[],double &scores[],const int n,const double score)
{
   int k=ArraySize(a); ArrayResize(a,k+1); ArrayResize(scores,k+1); a[k]=n; scores[k]=score;
}
void VPSort(int &a[],double &scores[])
{
   for(int i=0;i<ArraySize(a)-1;i++)
   {
      int best=i;
      for(int j=i+1;j<ArraySize(a);j++) if(scores[j]>scores[best]) best=j;
      if(best!=i)
      {
         int row=a[i]; double score=scores[i];
         a[i]=a[best]; scores[i]=scores[best]; a[best]=row; scores[best]=score;
      }
   }
}

class VPProfile
{
public:
   double bins[],bull[],bear[],smooth[];
   int hvn[],lvn[];
   double low,high,step,total,maxRaw,maxSmooth,mean,poc,vah,val,vaVolume;
   int pocRow,vaLow,vaHigh,barCount,positiveBars,realBars;
   bool valid;

   void Reset()
   {
      ArrayFree(bins); ArrayFree(bull); ArrayFree(bear); ArrayFree(smooth);
      ArrayFree(hvn); ArrayFree(lvn);
      low=0; high=0; step=0; total=0; maxRaw=0; maxSmooth=0; mean=0;
      poc=0; vah=0; val=0; vaVolume=0;
      pocRow=0; vaLow=0; vaHigh=0; barCount=0; positiveBars=0; realBars=0; valid=false;
   }

   bool Build(const MqlRates &bars[],const int rows,const double valuePct,const double tick,
              const bool realVolume,const bool showHVN=true,const bool showLVN=true)
   {
      Reset();
      barCount=ArraySize(bars);
      if(barCount<1 || rows<1 || valuePct<1 || valuePct>100 || tick<=0) return false;
      low=bars[0].low; high=bars[0].high;
      for(int i=0;i<barCount;i++)
      {
         low=MathMin(low,bars[i].low); high=MathMax(high,bars[i].high);
         if(bars[i].real_volume>0) realBars++;
      }
      if(high<=low) { high+=tick; low-=tick; }
      step=(high-low)/rows;
      ArrayResize(bins,rows); ArrayResize(bull,rows); ArrayResize(bear,rows);
      ArrayInitialize(bins,0); ArrayInitialize(bull,0); ArrayInitialize(bear,0);
      // Pine traverses newest to oldest; preserve its summation order.
      for(int i=barCount-1;i>=0;i--)
      {
         double volume=(double)(realVolume?bars[i].real_volume:bars[i].tick_volume);
         if(volume<=0) continue;
         positiveBars++;
         double share=bars[i].close>bars[i].open?1.0:bars[i].close<bars[i].open?0.0:0.5;
         double span=bars[i].high-bars[i].low;
         int first=VPClamp((int)MathFloor((bars[i].low-low)/step),0,rows-1);
         int last=VPClamp((int)MathFloor((bars[i].high-low)/step),0,rows-1);
         if(span<=0)
         {
            int row=VPClamp((int)MathFloor((bars[i].close-low)/step),0,rows-1);
            bins[row]+=volume; bull[row]+=volume*share; bear[row]+=volume*(1-share);
         }
         else for(int row=first;row<=last;row++)
         {
            double overlap=MathMax(0.0,MathMin(bars[i].high,low+(row+1)*step)-MathMax(bars[i].low,low+row*step));
            double added=volume*overlap/span;
            bins[row]+=added; bull[row]+=added*share; bear[row]+=added*(1-share);
         }
      }
      return Analyze(valuePct,showHVN,showLVN);
   }

   bool Analyze(const double valuePct,const bool showHVN=true,const bool showLVN=true)
   {
      int rows=ArraySize(bins);
      if(rows<1 || step<=0 || valuePct<1 || valuePct>100) return false;
      total=0; maxRaw=0; maxSmooth=0; mean=0; pocRow=0; valid=false;
      ArrayFree(hvn); ArrayFree(lvn); ArrayResize(smooth,rows);
      for(int row=0;row<rows;row++)
      {
         total+=bins[row];
         if(bins[row]>maxRaw) { maxRaw=bins[row]; pocRow=row; }
         double sum=bins[row]*3,weight=3;
         for(int d=1;d<=2;d++)
         {
            if(row-d>=0) { sum+=bins[row-d]*(3-d); weight+=3-d; }
            if(row+d<rows) { sum+=bins[row+d]*(3-d); weight+=3-d; }
         }
         smooth[row]=sum/weight; mean+=smooth[row]; maxSmooth=MathMax(maxSmooth,smooth[row]);
      }
      if(total<=0 || maxRaw<=0 || maxSmooth<=0) return false;
      mean/=rows;
      vaLow=pocRow; vaHigh=pocRow; vaVolume=bins[pocRow];
      double target=total*valuePct/100;
      while(vaVolume<target && (vaLow>0 || vaHigh<rows-1))
      {
         double down=vaLow>0?bins[vaLow-1]:-1;
         double up=vaHigh<rows-1?bins[vaHigh+1]:-1;
         if(up>=down && vaHigh<rows-1) { vaHigh++; vaVolume+=MathMax(0.0,up); }
         else if(vaLow>0) { vaLow--; vaVolume+=MathMax(0.0,down); }
         else break;
      }
      poc=low+(pocRow+0.5)*step; val=low+vaLow*step; vah=low+(vaHigh+1)*step;
      int hr[],lr[]; double hs[],ls[];
      int merge=VPClamp((int)MathRound(rows*0.065),12,18);
      int apart=VPClamp((int)MathRound(rows*0.040),7,11);
      int buffer=VPClamp((int)MathRound(rows*0.025),4,7);
      double hMin=MathMax(mean*1.18,maxSmooth*0.20),hProm=MathMax(mean*0.08,maxSmooth*0.018);
      double lMax=MathMin(mean*1.02,maxSmooth*0.54),lShoulder=MathMax(mean*0.88,maxSmooth*0.14);
      double lDepth=MathMax(mean*0.10,maxSmooth*0.020);
      for(int row=2;row<rows-2;row++)
      {
         int start=MathMax(0,row-20),end=MathMin(rows-1,row+20);
         double s=smooth[row],raw=bins[row];
         if(showHVN && VPExtreme(smooth,row,true))
         {
            double prominence=s-MathMax(VPMin(smooth,start,row-1),VPMin(smooth,row+1,end));
            if(MathAbs(row-pocRow)>buffer+3 && (s>=hMin || raw>=maxRaw*0.28) &&
               (prominence>=hProm || raw>=maxRaw*0.34))
               VPCandidate(hr,hs,row,raw*2.60+s*1.50+prominence*0.70);
         }
         if(showLVN && VPExtreme(smooth,row,false))
         {
            double left=VPMax(smooth,start,row-1),right=VPMax(smooth,row+1,end);
            double weaker=MathMin(left,right),stronger=MathMax(left,right),depth=weaker-s;
            double relative=stronger>0?depth/stronger:0;
            if(MathAbs(row-pocRow)>buffer && (weaker>=lShoulder || relative>=0.14) &&
               (s<=lMax || s<=weaker*0.72) && (depth>=lDepth || relative>=0.18))
               VPCandidate(lr,ls,row,depth*3+relative*mean*4+MathMax(0.0,mean-s)*1.20-s*0.03);
         }
      }
      VPSort(hr,hs);
      for(int i=0;i<ArraySize(hr) && ArraySize(hvn)<3;i++) if(VPFar(hr[i],hvn,merge)) VPPush(hvn,hr[i]);
      if(showLVN)
      {
         int anchors[]; VPPush(anchors,pocRow);
         for(int i=0;i<ArraySize(hvn);i++) if(VPFar(hvn[i],anchors,apart)) VPPush(anchors,hvn[i]);
         for(int i=0;i<MathMin(ArraySize(hr),8);i++) if(VPFar(hr[i],anchors,apart)) VPPush(anchors,hr[i]);
         ArraySort(anchors);
         for(int i=0;i<ArraySize(anchors)-1;i++)
         {
            int start=anchors[i]+apart,end=anchors[i+1]-apart;
            if(end<start || end-start<3) continue;
            int best=start;
            for(int row=start;row<=end;row++) if(smooth[row]<smooth[best]) best=row;
            double weak=MathMin(smooth[anchors[i]],smooth[anchors[i+1]]);
            double strong=MathMax(smooth[anchors[i]],smooth[anchors[i+1]]);
            double depth=weak-smooth[best],relative=strong>0?depth/strong:0;
            if(MathAbs(best-pocRow)>buffer && (smooth[best]<=mean*1.06 || smooth[best]<=weak*0.76) &&
               (depth>=MathMax(mean*0.08,maxSmooth*0.018) || relative>=0.10))
               VPCandidate(lr,ls,best,depth*3.50+relative*mean*5+MathMax(0.0,mean-smooth[best])*1.35-smooth[best]*0.04);
         }
      }
      VPSort(lr,ls);
      for(int i=0;i<ArraySize(lr) && ArraySize(lvn)<4;i++)
         if(VPFar(lr[i],lvn,merge) && VPFar(lr[i],hvn,apart)) VPPush(lvn,lr[i]);
      valid=true; return true;
   }

   void Bounds(const int center,const bool highNode,int &lower,int &upper)
   {
      lower=center; upper=center;
      double threshold=0;
      if(highNode) threshold=MathMax(mean*1.03,smooth[center]*0.64);
      else
      {
         double weaker=MathMin(VPMax(smooth,MathMax(0,center-20),center-1),
                               VPMax(smooth,center+1,MathMin(ArraySize(bins)-1,center+20)));
         threshold=smooth[center]+MathMax(mean*0.16,(weaker-smooth[center])*0.52);
      }
      for(int d=1;d<=3;d++)
      {
         int row=center-d;
         if(row>=0 && (highNode?(MathAbs(row-pocRow)>4 && smooth[row]>=threshold):smooth[row]<=threshold)) lower=row;
         else break;
      }
      for(int d=1;d<=3;d++)
      {
         int row=center+d;
         if(row<ArraySize(bins) && (highNode?(MathAbs(row-pocRow)>4 && smooth[row]>=threshold):smooth[row]<=threshold)) upper=row;
         else break;
      }
   }
};
#endif
