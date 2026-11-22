// N busy threads (dependent adds); prints per-thread GHz once per second: "t=<s> ghz=<avg>"
#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <mach/mach_time.h>
#include <unistd.h>
static volatile int stop; static volatile unsigned long cnt[16];
static double now(){static mach_timebase_info_data_t tb; if(!tb.denom)mach_timebase_info(&tb); return mach_absolute_time()*(double)tb.numer/tb.denom/1e9;}
static void *run(void *a){long id=(long)a; unsigned long x=0;
 while(!stop){for(int i=0;i<1000000;i++){__asm__ volatile("add $1,%0":"+r"(x));} cnt[id]+=1000000;} return 0;}
int main(int c,char**v){int T=atoi(v[1]);int secs=atoi(v[2]);pthread_t th[16];
 for(long i=0;i<T;i++)pthread_create(&th[i],0,run,(void*)i);
 unsigned long prev[16]={0}; double t0=now(),tp=t0;
 for(int s=1;s<=secs;s++){ usleep(1000000-((int)((now()-tp)*1e6)%1000000)>0?1000000-(int)((now()-tp)*1e6)%1000000:0);
   double t=now(); double sum=0; for(int i=0;i<T;i++){unsigned long cc=cnt[i]; sum+=(cc-prev[i]); prev[i]=cc;}
   printf("t=%d ghz=%.2f\n",s,sum/T/(t-tp)/1e9); fflush(stdout); tp=t;}
 stop=1; for(int i=0;i<T;i++)pthread_join(th[i],0); return 0;}
