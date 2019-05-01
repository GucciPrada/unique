//
//  Copyright (c) 2015 Tobias Becker <tobias_becker@me.com>, Andreas Kurtz <mail@andreas-kurtz.de>, Hugo Gascon <hgascon@cs.uni-goettingen.de>. All rights reserved.
//

#import "DeviceConfigurationHelper.h"
#import "Reachability.h"
#import "SSJailbreakCheck.h"
#import "SSNetworkInfo.h"
#import "SSDiskInfo.h"
#import "SSHardwareInfo.h"
#import "SSAccessoryInfo.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <StoreKit/StoreKit.h>
#import <sys/stat.h>
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>
#include <net/if_dl.h>

@implementation DeviceConfigurationHelper

#pragma mark - Unprotected Information

- (void)performAction
{
  [[Fingerprint sharedFingerprint] addInformationFromDictionary:[self configuration]];
  [[Fingerprint sharedFingerprint] addInformationFromDictionary:[self reachability]];
}

/*
 Collects information about device configuration
 */
- (NSDictionary *)configuration
{
  NSString *carrierName=@"";
  NSString *carrierVOIP=@"";
  if([CTTelephonyNetworkInfo instancesRespondToSelector:@selector(serviceSubscriberCellularProviders)]){
    CTTelephonyNetworkInfo *tel=[[CTTelephonyNetworkInfo alloc] init];
    if (@available(iOS 12.0, *)) {
      NSDictionary<NSString *, CTCarrier *> * carriers = [tel serviceSubscriberCellularProviders];
      NSDictionary<NSString*, NSString*> *services = [tel serviceCurrentRadioAccessTechnology];
      [carriers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, CTCarrier * _Nonnull obj, BOOL * _Nonnull stop) {
        //NSLog(@"%@:%@",key,obj);
        [carrierName stringByAppendingFormat:@"^%@-%@",[obj carrierName],services[key]];
        [carrierVOIP stringByAppendingFormat:@"^%d",[obj allowsVOIP]];
      }];
    } else {
      // Fallback on earlier versions
    }
  }else if([CTTelephonyNetworkInfo instancesRespondToSelector:@selector(subscriberCellularProvider)]){
    #pragma GCC diagnostic ignored "-Wdeprecated-declarations"
    CTCarrier *carrier=[[[CTTelephonyNetworkInfo alloc] init] subscriberCellularProvider];
    #pragma GCC diagnostic warning "-Wdeprecated-declarations"
    carrierName=[carrier carrierName];
    carrierVOIP=[NSString stringWithFormat:@"%d",[carrier allowsVOIP]];
  }
  
  NSString *localeCountry = [[NSLocale currentLocale] objectForKey:NSLocaleCountryCode];
  NSString *localeLanguage = [[NSLocale preferredLanguages] objectAtIndex:0];
  //NSNumber *diff = [[[[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode] lowercaseString] isEqualToString:language.lowercaseString] ? [NSNumber numberWithBool:NO] : [NSNumber numberWithBool:YES];
  NSArray *keyboards = [[NSUserDefaults standardUserDefaults] valueForKey:@"AppleKeyboards"];
  NSNumber *canMakePayments = [SKPaymentQueue canMakePayments] ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO];
  NSNumber *isJailbroken = [NSNumber numberWithBool:isJB()];
  NSNumber *ssJailbroken = [NSNumber numberWithInt:[SSJailbreakCheck jailbroken]];
  NSString *diskUsage=[NSString stringWithFormat:@"%@^%@", [SSDiskInfo freeDiskSpace:NO], [SSDiskInfo usedDiskSpace:NO]];
  NSNumber *debuggee = [NSNumber numberWithBool:[SSHardwareInfo debuggerAttached]];
  NSString *accessories = [SSAccessoryInfo nameAttachedAccessories];
  //[SSHardwareInfo pluggedIn];
  // Enter data in dictionary
  NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
  [deviceInfo setValue:carrierName forKey:kDEVICE_CONF_CARRIERNAME];
  [deviceInfo setValue:carrierVOIP forKey:kDEVICE_CONF_CARRIERVOIP];
  [deviceInfo setValue:localeCountry forKey:kDEVICE_CONF_LOCALE_COUNTRY];
  [deviceInfo setValue:localeLanguage forKey:kDEVICE_CONF_LOCALE_LANGUAGE];
  //[deviceInfo setValue:diff forKey:kDEVICE_CONF_COUNTRY_LANG_DIFF];
  [deviceInfo setValue:keyboards forKey:kDEVICE_CONF_KEYBOARDS];
  [deviceInfo setValue:canMakePayments forKey:kDEVICE_CONF_CAN_MAKE_PAYMENTS];
  [deviceInfo setValue:isJailbroken forKey:kDEVICE_CONF_IS_JAILBROKEN];
  [deviceInfo setValue:ssJailbroken forKey:kDEVICE_CONF_SS_JAILBROKEN];
  [deviceInfo setValue:diskUsage forKey:kDEVICE_CONF_DISK_INFO];
  [deviceInfo setValue:debuggee forKey:kDEVICE_CONF_IS_DEBUGGING];
  [deviceInfo setValue:accessories forKey:kDEVICE_CONF_ACCESSORY];
  return deviceInfo;
}

/*
 Gets the current reachability
 */
- (NSDictionary *)reachability
{
  Reachability *reachability = [Reachability reachabilityForInternetConnection];
  NetworkStatus netStatus = [reachability currentReachabilityStatus];
  NSString *statusString;
  NSMutableDictionary *reachabilityInfo = [NSMutableDictionary dictionary];
  
  switch (netStatus) {
    case NotReachable:
      statusString = @"none";
      break;
    case ReachableViaWWAN: {
      statusString = @"wwan";
      break;
    }
    case ReachableViaWiFi: {
      statusString = @"wifi";
      [reachabilityInfo setValue:[self fetchWifiSSID] forKey:kDEVICE_CONF_REACHABILITY_SSID];
      break;
    }
  }
  [reachabilityInfo setValue:statusString forKey:kDEVICE_CONF_REACHABILITY_TYPE];
  NSDictionary *addresses = [DeviceConfigurationHelper getIPAddresses];
  [reachabilityInfo setValue:addresses forKey:kDEVICE_CONF_REACHABILITY_LOCAL_IP];
  [self performSelectorInBackground:@selector(fetchPublicIPAddress) withObject:nil];
  
  return reachabilityInfo;
}

BOOL isJB()
{
  
#if !TARGET_IPHONE_SIMULATOR
  
  if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]) {
    return YES;
  }
  
  // SandBox Integrity Check
  int pid = fork();
  if (!pid) {
    exit(0);
  }
  if (pid >= 0) {
    return YES;
  }
  
#endif
  return NO;
}

#pragma mark - Auxiliary methods


/**
 获取当前连接的wifi的热点信息
 Warnning:在ios 12上要添加Access Wifi Information
 @return SSID^BSSID^SSIDDATA
 */
- (NSString *)fetchWifiSSID
{
  NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
  id info = nil; NSString * interfaceName=nil;
  for (NSString *ifnam in ifs) {
    info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
    if (info && [info count]) {
      interfaceName=ifnam;
      break;
    }
  }
  NSDictionary *infoDict = (NSDictionary *)info;
  //    NSLog(@"wifi:%@",infoDict);
  //    NSLog(@"wifi BSSID:%@",[infoDict valueForKey:@"BSSID"]);
  //    NSLog(@"wifi SSIDDATA:%@",[infoDict valueForKey:@"SSIDDATA"]);
  NSString *wifiRouterAddr=[SSNetworkInfo wiFiRouterAddress];
  NSString * ret=[NSString stringWithFormat:@"%@^%@^%@^%@^%@",
                  interfaceName,[infoDict valueForKey:@"SSID"],
                  [infoDict valueForKey:@"BSSID"],
                  [infoDict valueForKey:@"SSIDDATA"],
                  wifiRouterAddr];
  return ret;
}


/**
 获取外网ip.
 去https://ipapi.co官网查看请求和响应说明.
 举例: curl http://ipapi.co/json
  {
    "ip": "59.41.119.193",
    "city": "Guangzhou",
    "region": "Guangdong",
    "region_code": "GD",
    "country": "CN",
    "country_name": "China",
    "continent_code": "AS",
    "in_eu": false,
    "postal": null,
    "latitude": 23.1167,
    "longitude": 113.25,
    "timezone": "Asia/Shanghai",
    "utc_offset": "+0800",
    "country_calling_code": "+86",
    "currency": "CNY",
    "languages": "zh-CN,yue,wuu,dta,ug,za",
    "asn": "AS4134",
    "org": "No.31,Jin-rong Street"
  }
 */
- (void)fetchPublicIPAddress
{
  NSData *ipData;
  //Reachability *hostReachability = [Reachability reachabilityWithHostName:@"ipapi.co"];
  //if ([hostReachability currentReachabilityStatus] != NotReachable) {
    ipData = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"https://ipapi.co/json"]];
    if (!ipData) {return;}
    NSDictionary *ipApiDict = [NSJSONSerialization JSONObjectWithData:ipData options:NSJSONReadingMutableContainers error:nil];
    if(!ipApiDict){return;}
    NSMutableDictionary *publicIPInfo = [NSMutableDictionary dictionary];
    [publicIPInfo setValue:ipApiDict forKey:@"publicIP"];
    //NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:[ipApiDict valueForKey:@"query"], kDEVICE_CONF_REACHABILITY_PUBLIC_IP, [ipApiDict valueForKey:@"isp"], kDEVICE_CONF_REACHABILITY_ISP, nil];
    [[Fingerprint sharedFingerprint] addInformationFromDictionary:publicIPInfo];
  //}
}



#define IOS_CELLULAR    @"pdp_ip0"
//en2,en3..是有线,暂不考虑有线
#define IOS_WIFI        @"en0"
//vpn的接口名各种各样的，难以预料
//#define IOS_VPN       @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"
#define ADDR_LINK       @"link"


/**
 获取本地ipv4或ipv6地址.优先获取wifi的，其次是cellular
 
 @param preferIPv4 是否优先获取每个接口的ipv4地址?
 @return 返回的是单个地址
 */
+ (NSString *)getIPAddress:(BOOL)preferIPv4
{
  //搜索顺序, wifi总是在cellular前面
  NSArray *searchArray = preferIPv4 ?
  /*
   @[ //IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6,
   IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6,
   IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ]
   :
   @[ //IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4,
   IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4,
   IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;*/
  
  @[
    @"en0/ipv4", @"en0/ipv6",
    @"pdp_ip0/ipv4", @"pdp_ip0/ipv6",
    @"pdp_ip1/ipv4", @"pdp_ip1/ipv6",
    @"pdp_ip2/ipv4",@"pdp_ip2/ipv6",
    @"pdp_ip3/ipv4",@"pdp_ip3/ipv6"]
  :
  @[
    @"en0/ipv6", @"en0/ipv4",
    @"pdp_ip0/ipv6", @"pdp_ip0/ipv4",
    @"pdp_ip1/ipv6", @"pdp_ip1/ipv4",
    @"pdp_ip2/ipv6",  @"pdp_ip2/ipv4",
    @"pdp_ip3/ipv6",@"pdp_ip3/ipv4"] ;
  
  NSDictionary *addresses = [self getIPAddresses];
  NSLog(@"addresses: %@", addresses);
  
  __block NSString *address;
  [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
   {
     address = addresses[key];
     if(address) *stop = YES;
   } ];
  return address ? address : @"0.0.0.0";
}

//所有接口的地址或flag
+ (NSDictionary *)getIPAddresses
{
  NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
  @try {
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
      // Loop through linked list of interfaces
      struct ifaddrs *interface;
      for(interface=interfaces; interface; interface=interface->ifa_next) {
        if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
          NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
          NSString *type = [NSString stringWithFormat:@"%d",interface->ifa_flags];
          NSString *key = [NSString stringWithFormat:@"%@/DOWN",name];
          addresses[key] = type;
          continue;
        }
        const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
        char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
        if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
          NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
          NSString *type;
          if(addr->sin_family == AF_INET) {
            if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
              type = IP_ADDR_IPv4;
            }
          } else {
            const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
            if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
              type = IP_ADDR_IPv6;
            }
          }
          if(type) {
            NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
            addresses[key] = [NSString stringWithUTF8String:addrBuf];
          }
        }else if(addr && addr->sin_family==AF_LINK){
          struct sockaddr_dl* sdl = (struct sockaddr_dl*)addr;
          NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
          NSString *key=[NSString stringWithFormat:@"%@/%@",name,ADDR_LINK];
          NSString *nameAddrSelector=nil;
          if(sdl->sdl_nlen + sdl->sdl_alen + sdl->sdl_slen == 0){
            nameAddrSelector = [NSString stringWithFormat: @"#%d", sdl->sdl_index];
          }else{
            nameAddrSelector = [NSString stringWithCString:link_ntoa(sdl) encoding:NSUTF8StringEncoding];
          }
          addresses[key]=nameAddrSelector;
        }else{
          //地址为空或者其他地址类型,但该接口没有DOWN可能是UP且inactive
          NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
          NSString *type = [NSString stringWithFormat:@"%d",interface->ifa_flags];
          NSString *key = [NSString stringWithFormat:@"%@/%d",name, (int)(addr?addr->sin_family:-1)];
          addresses[key] = type;
        }
      }//end for
      // Free memory
      freeifaddrs(interfaces);
    }
  } @catch(NSException *exp){
    NSLog(@"cannot get addresses.Exception:%@,%@",[exp name], [exp reason]);
    return nil;
  }
  return [addresses count] ? addresses : nil;
}

#pragma mark -
#pragma mark - Protected Information

- (void)performActionWithCompletionHandler:(CompletionBlock)handler
{
  // keine bekannt
}

@end
