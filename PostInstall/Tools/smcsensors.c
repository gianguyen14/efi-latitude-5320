// SMC sensor check: CPU temperatures (sp78) and package power (sp96 = raw/64 W).
// Build: clang -O1 smcsensors.c -o smcsensors -framework IOKit
#include <IOKit/IOKitLib.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
typedef struct { char major, minor, build, reserved[1]; uint16_t release; } V;
typedef struct { uint16_t version, length; uint32_t cpuPLimit, gpuPLimit, memPLimit; } P;
typedef struct { uint32_t dataSize, dataType; char dataAttributes; } K;
typedef struct { uint32_t key; V vers; P pLimitData; K keyInfo; char result, status, data8; uint32_t data32; unsigned char bytes[32]; } D;
static io_connect_t c;
static uint32_t k4(const char*s){return (s[0]<<24)|(s[1]<<16)|(s[2]<<8)|s[3];}
static int call(D*in,D*out){size_t o=sizeof(D);return IOConnectCallStructMethod(c,2,in,sizeof(D),out,&o);}
static double rd(const char*key,char*type){D in={0},out={0};in.key=k4(key);in.data8=9;if(call(&in,&out)||out.result)return -1;
 uint32_t sz=out.keyInfo.dataSize,t=out.keyInfo.dataType;in.keyInfo.dataSize=sz;in.data8=5;memset(&out,0,sizeof out);if(call(&in,&out)||out.result)return -1;
 type[0]=t>>24;type[1]=t>>16;type[2]=t>>8;type[3]=t;type[4]=0;
 if(!strcmp(type,"flt "))return *(float*)out.bytes;
 if(!strcmp(type,"sp78"))return ((int16_t)((out.bytes[0]<<8)|out.bytes[1]))/256.0;
 if(!strcmp(type,"ui8 "))return out.bytes[0];
 if(!strcmp(type,"ui16"))return (out.bytes[0]<<8)|out.bytes[1];
 if(!strcmp(type,"sp96"))return ((int16_t)((out.bytes[0]<<8)|out.bytes[1]))/64.0;
 return -2;}
int main(int ac,char**av){io_service_t s=IOServiceGetMatchingService(kIOMainPortDefault,IOServiceMatching("AppleSMC"));
 if(!s||IOServiceOpen(s,mach_task_self(),0,&c)){puts("no smc");return 1;}
 const char*keys[]={"TC0P","TC0D","TC0E","TC0F","TCXC","TC1C","TC2C","PC0C","PCPC","PCPG","PCTR","PC0R"};
 for(int i=0;i<12;i++){char t[5]="";double v=rd(keys[i],t);if(v>-1)printf("%s(%s)=%.1f ",keys[i],t,v);}puts("");}
