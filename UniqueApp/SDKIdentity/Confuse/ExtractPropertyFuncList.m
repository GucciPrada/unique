//
//  ExtractPropertyFuncList.m
//  SDKIdentity
//
//  Created by 程龙 on 2019/4/30.
//  Copyright © 2019 Tobias Becker. All rights reserved.
//

#if DEBUG

#import <Foundation/Foundation.h>
#import "ExtractPropertyFuncList.h"
#import <objc/runtime.h>
#import "UICKeychainStore.h"
#import "FCUUID.h"
#import "UIKitHelper.h"
#import "SSJailbreakCheck.h"
#import "SSNetworkInfo.h"
#import "SSDiskInfo.h"
#import "SSHardwareInfo.h"
#import "SSAccessoryInfo.h"
#import "GTMBase64.h"
#import "TWitterHelper.h"
#import "DeviceConfigurationHelper.h"
#import "UserInformationHelper.h"
#import "MediaHelper.h"
#import "Helper.h"
#import "PlistsHelper.h"
#import "HZPrivacyPrivilegeManager.h"
#import "Fingerprint.h"
#import "FingerprintCalculator.h"

//https://stackoverflow.com/questions/2094702/get-all-methods-of-an-objective-c-class-or-instance
@implementation ExtractPropertyFuncList : NSObject

+ (void)printList{
  NSArray * classList=@[
                        [UICKeyChainStore class],
                        [FCUUID class],
                        [UIKitHelper class],
                        [SSJailbreakCheck class],
                        [SSNetworkInfo class],
                        [SSDiskInfo class],
                        [SSHardwareInfo class],
                        [SSAccessoryInfo class],
                        [GTMBase64 class],
                        [TwitterHelper class],
                        [DeviceConfigurationHelper class],
                        [UserInformationHelper class],
                        [MediaHelper class],
                        [PlistsHelper class],
                        [HZPrivacyPrivilegeManager class],
                        [Fingerprint class],
                        [FingerprintCalculator class],
                        ];
  NSMutableSet * nameList=[[NSMutableSet alloc] initWithCapacity:60];
  for(Class clz in classList){
    [ExtractPropertyFuncList printAClassWithClass:clz appendTo:nameList];
    [ExtractPropertyFuncList printAClassWithClass: objc_getMetaClass(object_getClassName(clz)) appendTo:nameList];
  }
  NSArray * removeWords=@[@"init", @".cxx_destruct", @"sharedInstance", @"setValue", @"completion",
  @"forKey",@"systemVersion", @"synchronize",@"hash",@"save",@"accessibility",@"contains",@"description",
  @"debugDescription",@"value",@"query",@"length",@"error",@"setObject",@"allKeys",@"stringForKey",@"setString",
  @"itemClass",@"service",@"accessGroup",@"server",@"protocolType",@"authenticationType",@"accessibility",@"authenticationPolicy",
  @"synchronizable",@"useAuthenticationUI",@"authenticationPrompt",@"allItems",@"setSynchronizable",@"setIsSent"];
  for(NSString *w in removeWords){
    [nameList removeObject: w];
  }
  
  NSLog(@"all names=%@", nameList);
}


+(void)printAClassWithClass:(Class )clz appendTo:(NSMutableSet*) nameList{
  //class name
  NSString *clzName=NSStringFromClass(clz);
  NSLog(@"%@",clzName);
  [nameList addObject:clzName];
  unsigned int count=0;
  // property
  objc_property_t *propArr = class_copyPropertyList(clz, &count);
  for(int i=0; i<count; i++){
    objc_property_t prop=propArr[i];
    NSString *propName=[NSString stringWithUTF8String:property_getName(prop)];
    NSLog(@"%@",propName);
    [nameList addObject:propName];
  }
  NSLog(@"\n");
  
  //instance variable
//  count=0;
//  Ivar * ivarArr=class_copyIvarList(clz, &count);
//  for(int i =0; i<count; i++){
//    NSString *ivarName=[NSString stringWithUTF8String:ivar_getName(ivarArr[i])];
//    NSLog(@"%@",ivarName);
//    [nameList addObject:ivarName];
//  }
  
  // instance method or class method
  count=0;
  Method *methodArr=class_copyMethodList(clz, &count);
  for(int i=0; i<count; i++){
    Method m=methodArr[i];
    SEL sel=method_getName(m);
    NSString *methodName=[NSString stringWithUTF8String:sel_getName(sel)];
    NSArray *cmp=[methodName componentsSeparatedByString:@":"];
    if([cmp count]>0){
      for(NSString * part in cmp){
        if([part hasPrefix:@"initWith"]){continue;}
        [nameList addObject:part];
        NSLog(@"%@", part);
      }
    }else{
      if([methodName hasPrefix:@"initWith"]){continue;}
      [nameList addObject:methodName];
      NSLog(@"%@", methodName);
    }
  }
  NSLog(@"\n");
}
@end


#endif
