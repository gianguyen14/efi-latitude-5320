// CPU clock check: per-thread dependent-add rate ~= core GHz. Usage: cpuclock <threads> <seconds>
// Build: clang -O1 cpuclock.c -o cpuclock
#include <stdio.h>
#include <pthread.h>
#include <mach/mach_time.h>
#include <stdlib.h>
static double secs; static volatile unsigned long sink;
static double now(){static mach_timebase_info_data_t tb; if(!tb.denom)mach_timebase_info(&tb); return mach_absolute_time()*(double)tb.numer/tb.denom/1e9;}
static void *run(void *a){unsigned long x=(unsigned long)a,n=0;double t0=now();
 while(now()-t0<secs){for(int i=0;i<10000000;i++){__asm__ volatile("add $1,%0":"+r"(x));}n+=10000000;}
 double g=n/(now()-t0)/1e9; sink+=x; double *r=malloc(8);*r=g;return r;}
int main(int c,char**v){int T=atoi(v[1]);secs=atof(v[2]);pthread_t th[16];double s=0;
 for(long i=0;i<T;i++)pthread_create(&th[i],0,run,(void*)i);
 for(int i=0;i<T;i++){double*r;pthread_join(th[i],(void**)&r);s+=*r;}
 printf("threads=%d avg per-thread %.2f GHz\n",T,s/T);}
