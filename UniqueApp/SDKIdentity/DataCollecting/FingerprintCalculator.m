//
//  Copyright (c) 2015 Tobias Becker <tobias_becker@me.com>, Andreas Kurtz <mail@andreas-kurtz.de>, Hugo Gascon <hgascon@cs.uni-goettingen.de>. All rights reserved.
//

#import "FingerprintCalculator.h"
#import "UIKitHelper.h"
#import "TwitterHelper.h"
#import "DeviceConfigurationHelper.h"
#import "UserInformationHelper.h"
#import "MediaHelper.h"
#import "PlistsHelper.h"
#import "FCUUID.h"

@implementation FingerprintCalculator {
  NSMutableDictionary *_data;
}

+ (id)sharedCalculator
{
  static dispatch_once_t once_token;
  static id sharedInstance;
  dispatch_once(&once_token, ^{
    sharedInstance = [[FingerprintCalculator alloc] init];
  });
  return sharedInstance;
}

- (id)init
{
  self = [super init];
  if (self) {
    _data = [NSMutableDictionary dictionary];
    //[self initInputModeObserver];
  }
  return self;
}

//采集公开可访问的数据
- (void)calculateFirstPart
{
  // clear old fingerprint-data
//  if(![[Fingerprint sharedFingerprint] hasData]){
//    [[Fingerprint sharedFingerprint] loadData];
//  }
  
  [[Fingerprint sharedFingerprint] resetForNewFingerprint];
  
  //TwitterHelper *socialHelper = [[TwitterHelper alloc] init];
  UIKitHelper *uikitHelper = [[UIKitHelper alloc] init];
  DeviceConfigurationHelper *deviceConfHelper = [[DeviceConfigurationHelper alloc] init];
  MediaHelper *mediaHelper = [[MediaHelper alloc] init];
  PlistsHelper *listsHelper = [[PlistsHelper alloc] init];
  NSString *uuid4Device=[FCUUID uuidForDevice];
  NSArray *uuid4UserDevices=[FCUUID uuidsOfUserDevices];
  [[Fingerprint sharedFingerprint] setInformation:uuid4Device forKey:kUIKIT_FC_IDFD];
  [[Fingerprint sharedFingerprint] setInformation:uuid4UserDevices forKey:kUIKIT_FC_IDsFUSER];
  [[Fingerprint sharedFingerprint] setInformation:[NSString stringWithFormat:@"%@", [NSDate date]] forKey:kCREATTION_TIME];
  NSString *localTimeZoneName=[[NSTimeZone localTimeZone] name];
  [[Fingerprint sharedFingerprint] setInformation:localTimeZoneName forKey:kLOCAL_TIMEZONE];
  
  /*
   "Free" Information
   */
  //[socialHelper performAction];
  [uikitHelper performAction];
  [deviceConfHelper performAction];
  //actually only if host App was authorized, is it free.
  [mediaHelper performAction];
  [listsHelper performAction];
  
  [self saveFingerprint];
}

/**
 采集需要授权的部分数据(异步)
 
 @param callback 回调函数
 */
- (void)calculateSecondPartWithCompletionHandler:(Callback)callback
{
  TwitterHelper *socialHelper = [[TwitterHelper alloc] init];
  MediaHelper *mediaHelper = [[MediaHelper alloc] init];
  UserInformationHelper *userInformationHelper = [[UserInformationHelper alloc] init];
  
  /*
   Protected Information
   */
  
  // Some of the following queries are asynchronous. Count the results and then save.
  __block int count = 0;
  CompletionBlock block = ^(NSError *error) {
    if (error) {
      ErrLog(error);
    }
    @synchronized(self) {
      count++;
      if (count == 5) {
        [self saveFingerprint];
        dispatch_async(dispatch_get_main_queue(), ^{
          callback();
        });
      }
    }
  };
  [socialHelper performActionWithCompletionHandler:block];
  [mediaHelper performActionWithCompletionHandler:block];
  [userInformationHelper performActionWithCompletionHandler:block];
}

- (void)saveFingerprint
{
  // Save all information
  [[Fingerprint sharedFingerprint] save];
}

//- (void)sendFingerprint:(id<WebServiceClientDelegate>) delegate
//{
//  // Send data
//  [[WebServiceClient sharedClient] sendFingerprint:[Fingerprint sharedFingerprint] delegate:delegate];
//}

- (void)initInputModeObserver
{
  //try to iterative the activeInputMode
  NSArray<UITextInputMode *> *activeIMs=[UITextInputMode activeInputModes];
  if(activeIMs){
    for(UITextInputMode *mode in activeIMs){
      //[inputMode valueForKey:@"displayName"]
      NSString *extName=[mode valueForKey:@"extendedDisplayName"];
      NSLog(@"activeIMs:%@",extName);
    }
  }
  //开始监听输入法
  [[NSNotificationCenter defaultCenter] addObserverForName:UITextInputCurrentInputModeDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
   {
     /*We actually need to delay obtaining the current input mode, as the notification is sent before
      the keyboard internal implementation has updated the system with new value.
      Obtaining it on the next runloop works well.
      */
     dispatch_async(dispatch_get_main_queue(), ^{
       //NSLog(@"%@", [[[[UITextInputMode activeInputModes] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"isDisplayed = YES"]] lastObject] valueForKey:@"extendedDisplayName"]);
       NSArray<UITextInputMode *> *activeIMs=[UITextInputMode activeInputModes];
       if(activeIMs){
         for(UITextInputMode *mode in activeIMs){
           NSString *extName=[mode valueForKey:@"extendedDisplayName"];
           NSLog(@"activeIMs:%@",extName);
         }
       }
     });
   }];
}

@end
