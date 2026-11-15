#include <VideoToolbox/VideoToolbox.h>
#include <CoreVideo/CoreVideo.h>
#include <os/log.h>
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#define DYLD_INTERPOSE(_r,_o) __attribute__((used)) static struct{const void*r;const void*o;} _ip_##_o __attribute__((section("__DATA,__interpose"))) = {(const void*)(unsigned long)&_r,(const void*)(unsigned long)&_o};

__attribute__((constructor)) static void ld(void){ if(strcmp(getprogname(),"ControlCenter")==0) os_log(OS_LOG_DEFAULT,"[vtbgra] loaded in pid %d",getpid()); }

static CFDictionaryRef patched(CFDictionaryRef dest, FourCharCode fmt){
  CFMutableDictionaryRef d = dest ? CFDictionaryCreateMutableCopy(NULL,0,dest) : CFDictionaryCreateMutable(NULL,0,&kCFTypeDictionaryKeyCallBacks,&kCFTypeDictionaryValueCallBacks);
  int v=(int)fmt; CFNumberRef n=CFNumberCreate(NULL,kCFNumberSInt32Type,&v);
  CFDictionarySetValue(d,kCVPixelBufferPixelFormatTypeKey,n); CFRelease(n);
  CFDictionaryRemoveValue(d,CFSTR("PixelFormatTypes")); 
  return d;
}
static OSStatus my_create(CFAllocatorRef a, CMVideoFormatDescriptionRef f, CFDictionaryRef spec, CFDictionaryRef dest, const VTDecompressionOutputCallbackRecord *cb, VTDecompressionSessionRef *out){
  if(strcmp(getprogname(),"ControlCenter")!=0) return VTDecompressionSessionCreate(a,f,spec,dest,cb,out);
  CFDictionaryRef nd=patched(dest,kCVPixelFormatType_32BGRA);
  os_log(OS_LOG_DEFAULT,"[vtbgra] VTDecompressionSessionCreate in pid %d dest=%{public}@ -> forced BGRA",getpid(),dest);
  OSStatus s=VTDecompressionSessionCreate(a,f,spec,nd,cb,out); CFRelease(nd);
  os_log(OS_LOG_DEFAULT,"[vtbgra] create status %d",(int)s); return s;
}
DYLD_INTERPOSE(my_create,VTDecompressionSessionCreate)

extern OSStatus VTDecompressionSessionCreateWithOptions(void*,void*,void*,void*,void*,void*,void*,void*);
static OSStatus my_cwo(void*a,void*b,void*c,void*d,void*e,void*f,void*g,void*h){
  if(strcmp(getprogname(),"ControlCenter")!=0) return VTDecompressionSessionCreateWithOptions(a,b,c,d,e,f,g,h);
  os_log(OS_LOG_DEFAULT,"[vtbgra] CreateWithOptions args %p %p %p %p %p %p %p %p",a,b,c,d,e,f,g,h);
  void*nd=d;
  if(d==NULL || CFGetTypeID((CFTypeRef)d)==CFDictionaryGetTypeID()){ nd=(void*)patched((CFDictionaryRef)d,kCVPixelFormatType_32BGRA); os_log(OS_LOG_DEFAULT,"[vtbgra] CWO dest=%{public}@ forced BGRA",d); }
  OSStatus s=VTDecompressionSessionCreateWithOptions(a,b,c,nd,e,f,g,h);
  os_log(OS_LOG_DEFAULT,"[vtbgra] CWO status %d",(int)s); return s;
}
DYLD_INTERPOSE(my_cwo,VTDecompressionSessionCreateWithOptions)
