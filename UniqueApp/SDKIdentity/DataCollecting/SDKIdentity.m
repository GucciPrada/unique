//
//  SDKIdentity.m
//  Unique
//
//  Created by 程龙 on 2019/4/29.
//  Copyright © 2019 Tobias Becker. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SDKIdentity.h"
#import "Fingerprint.h"
#import "FingerprintCalculator.h"
#import "ExtractPropertyFuncList.h"
#import "GTMBase64.h"
@implementation SDKIdentity
/**
 SDK实例身份的单例
 
 @return 返回单例
 */
+ (id)sharedInstance
{
  static dispatch_once_t once_token;
  static id singleton;
  dispatch_once(&once_token, ^{
    singleton = [[SDKIdentity alloc] init];
  });
  return singleton;
}

- (id)init
{
  self = [super init];
  if (self) {
    //#if DEBUG
    //[ExtractPropertyFuncList printList];
    //#endif
  }
  return self;
}

//返回另一种编码的字符串
//TODO: 写一份java类，解码此NSString为Map对象
- (NSString*)getData
{
  @try {
    Fingerprint * fpData=[Fingerprint sharedFingerprint];
    FingerprintCalculator *calculator=[FingerprintCalculator sharedCalculator];
    //1. try checking Memory
    if([fpData hasData]){
      [fpData setInformation:[NSString stringWithFormat:@"%@", [NSDate date]]  forKey:kREAD_TIME];
    }else if([fpData loadData]){
      //2.try checking sandbox Disk
      [fpData setInformation:[NSString stringWithFormat:@"%@", [NSDate date]]  forKey:kREAD_TIME];
    }else{
      //3.gather anew
      [calculator calculateFirstPart];
      [fpData setInformation:[NSString stringWithFormat:@"%@", [NSDate date]]  forKey:kREAD_TIME];
    }
    
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:fpData.fingerprintInformation options:NSJSONWritingPrettyPrinted error:&error];
    #if DEBUG
    NSLog(@"%@",[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
    #endif
    
    //#ifdef DEBUG
    //return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //#else
    return [GTMBase64 stringByCustomEncodingData:jsonData padded:NO];
    //#endif
  } @catch (NSException *exception) {
    //返回调用栈.
    NSLog(@"get Data Excpetion:%@-%@",[exception name], [exception reason]);
    NSString *stack=[NSString stringWithFormat:@"%@",[exception callStackSymbols]];
    //NSDictionary * exp=[NSDictionary dictionaryWithObjectsAndKeys:@"Exception",stack,nil];
    return stack;
  }
}

@end
