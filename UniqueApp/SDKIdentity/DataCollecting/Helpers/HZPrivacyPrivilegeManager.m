//
//  HZPrivacyPrivilegeManager.m
//  Unique
//
//  Created by 程龙 on 2019/4/26.
//  Copyright © 2019 Tobias Becker. All rights reserved.
//

#import "HZPrivacyPrivilegeManager.h"
#import <CoreLocation/CoreLocation.h>//位置
#import <UserNotifications/UserNotifications.h>//通知
#import <AVFoundation/AVFoundation.h>// 摄像头
#import <Photos/Photos.h>//相册
#import <AssetsLibrary/AssetsLibrary.h>// 相册
#import <AVFoundation/AVFoundation.h>// 麦克风
#import <AddressBook/AddressBook.h>//通讯录
#import <Contacts/Contacts.h>//通讯录
#import <CoreBluetooth/CoreBluetooth.h>  //蓝牙
#import <CoreTelephony/CTCellularData.h> // 互联网
#import <HealthKit/HealthKit.h> // 健康
#import <LocalAuthentication/LocalAuthentication.h> //Touch ID
#import <PassKit/PassKit.h>  //Apple Pay
#import <Speech/Speech.h>  // 语音识别
#import <MediaPlayer/MediaPlayer.h>//媒体资料库
#import <Intents/Intents.h> // Siri

@implementation HZPrivacyPrivilegeManager
//是否开启定位
+ (void)openLocationServiceWithBlock:(ReturnBlock)returnBlock
{
  BOOL isOPen = NO;
  if ([CLLocationManager locationServicesEnabled] && [CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied) {
    isOPen = YES;
  }
  if (returnBlock) {
    returnBlock(isOPen);
  }
}

//是否允许消息推送
+ (void)openMessageNotificationServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
    if (returnBlock) {
      returnBlock(settings.authorizationStatus == UNAuthorizationStatusAuthorized);
    }
  }];
#elif __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
  returnBlock([[UIApplication sharedApplication] isRegisteredForRemoteNotifications]);
#else
  UIRemoteNotificationType type = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
  if (returnBlock) {
    returnBlock(type != UIRemoteNotificationTypeNone);
  }
#endif
}

//是否开启摄像头
+ (void)openCaptureDeviceServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
  AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
  if (authStatus == AVAuthorizationStatusNotDetermined) {
    //        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
    //            if (returnBlock) {
    //                returnBlock(granted);
    //            }
    //        }];
    returnBlock(NO);
  } else if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
    returnBlock(NO);
  } else {
    returnBlock(YES);
  }
#endif
  if (returnBlock) {
    returnBlock(NO);
  }
}
//是否开启相册
+ (BOOL)isPhotosServiceAuthorized
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
  PHAuthorizationStatus authStatus = [PHPhotoLibrary authorizationStatus];
//  if (authStatus == PHAuthorizationStatusRestricted || authStatus == PHAuthorizationStatusDenied) {
  if(authStatus != PHAuthorizationStatusAuthorized){
    return NO;
  }
#else
  ALAuthorizationStatus author = [ALAssetsLibrary authorizationStatus];
  //if (author == ALAuthorizationStatusRestricted || author == ALAuthorizationStatusDenied) {
  if (author != ALAuthorizationStatusAuthorized) {
    return NO;
  }
#endif
  return YES;
}
//是否开启麦克风
+ (void)openRecordServiceWithBlock:(ReturnBlock)returnBlock wannaRequestNow:(BOOL)requestNow
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
  AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
  if (permissionStatus == AVAudioSessionRecordPermissionUndetermined) {
    if(!requestNow){
      if (returnBlock) {
        returnBlock(NO);
      }
    }else{
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (returnBlock) {
                returnBlock(granted);
            }
        }];
    }
  } else if (permissionStatus == AVAudioSessionRecordPermissionDenied) {
    returnBlock(NO);
  } else {
    returnBlock(YES);
  }
#endif
}

//是否开启通讯录
+ (void)openContactsServiceWithBolck:(ReturnBlock)returnBlock wannaRequestNow:(BOOL) requestNow
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
  
  dispatch_queue_t queue = dispatch_queue_create("Contacts", DISPATCH_QUEUE_SERIAL);
  
  dispatch_async(queue, ^{
    
    CNAuthorizationStatus cnAuthStatus = [CNContactStore authorizationStatusForEntityType:CNEntityTypeContacts];
    if (cnAuthStatus == CNAuthorizationStatusNotDetermined) {
      if(!requestNow){
        if(returnBlock){returnBlock(NO);}
      }else{//异步申请权限
        CNContactStore *store = [[CNContactStore alloc] init];
        [store requestAccessForEntityType:CNEntityTypeContacts completionHandler:^(BOOL granted, NSError *error) {
          if (returnBlock) {
            dispatch_async(dispatch_get_main_queue(), ^{
              returnBlock(granted);
            });
          }
        }];
      }
      
    } else if (cnAuthStatus == CNAuthorizationStatusRestricted || cnAuthStatus == CNAuthorizationStatusDenied) {
      if (returnBlock) {
        //dispatch_async(dispatch_get_main_queue(), ^{
        returnBlock(NO);
        //});
      }
    } else {
      if (returnBlock) {
        //dispatch_async(dispatch_get_main_queue(), ^{
        returnBlock(YES);
        //});
      }
    }
  });
#else
  //ABAddressBookRef addressBook = ABAddressBookCreateWithOptions(NULL, NULL);
  dispatch_queue_t queue = dispatch_queue_create("Contacts", DISPATCH_QUEUE_SERIAL);
  
  dispatch_async(queue, ^{
    
    ABAddressBookRef addressBook = ABAddressBookCreate();
    ABAuthorizationStatus authStatus = ABAddressBookGetAuthorizationStatus();
    if (authStatus != kABAuthorizationStatusAuthorized) {
      if(requestNow){
        ABAddressBookRequestAccessWithCompletion(addressBook, ^(bool granted, CFErrorRef error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
              NSLog(@"Error: %@", (__bridge NSError *)error);
              if (returnBlock) {
                returnBlock(NO);
              }
            } else {
              if (returnBlock) {
                returnBlock(YES);
              }
            }
          });
        });
      }else{
        if(returnBlock){returnBlock(NO);}
      }
    } else {
      if (returnBlock) {
        dispatch_async(dispatch_get_main_queue(), ^{
          returnBlock(YES);
          
        });
      }
    }
    
  });
  
#endif
}

//是否开启蓝牙
+ (void)openPeripheralServiceWithBolck:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
  CBPeripheralManagerAuthorizationStatus cbAuthStatus = [CBPeripheralManager authorizationStatus];
  if (cbAuthStatus == CBPeripheralManagerAuthorizationStatusNotDetermined) {
    if (returnBlock) {
      returnBlock(NO);
    }
  } else if (cbAuthStatus == CBPeripheralManagerAuthorizationStatusRestricted || cbAuthStatus == CBPeripheralManagerAuthorizationStatusDenied) {
    if (returnBlock) {
      returnBlock(NO);
    }
  } else {
    if (returnBlock) {
      returnBlock(YES);
    }
  }
#endif
}

//

/**
 是否开启日历备忘录

 @param returnBlock 查询结果的回调函数
 @param entityType EKEntityTypeEvent    代表日历
                    EKEntityTypeReminder 代表备忘
 */
+ (void)openEventServiceWithBolck:(ReturnBlock)returnBlock withType:(EKEntityType)entityType wannaRequestNow:(BOOL)requestNow
{
  EKAuthorizationStatus ekAuthStatus = [EKEventStore authorizationStatusForEntityType:entityType];
  if (ekAuthStatus == EKAuthorizationStatusNotDetermined) {
    if(requestNow){
      EKEventStore *store = [[EKEventStore alloc] init];
      [store requestAccessToEntityType:entityType completion:^(BOOL granted, NSError *error) {
        if (returnBlock) {
          returnBlock(granted);
        }
      }];
    }else{
      if(returnBlock){returnBlock(NO);}
    }
  } else if (ekAuthStatus == EKAuthorizationStatusRestricted || ekAuthStatus == EKAuthorizationStatusDenied) {
    if (returnBlock) {
      returnBlock(NO);
    }
  } else {
    if (returnBlock) {
      returnBlock(YES);
    }
  }
}
//是否开启互联网
+ (void)openEventServiceWithBolck:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
  CTCellularData *cellularData = [[CTCellularData alloc] init];
  cellularData.cellularDataRestrictionDidUpdateNotifier = ^(CTCellularDataRestrictedState state){
    if (state == kCTCellularDataRestrictedStateUnknown || state == kCTCellularDataNotRestricted) {
      if (returnBlock) {
        returnBlock(NO);
      }
    } else {
      if (returnBlock) {
        returnBlock(YES);
      }
    }
  };
  CTCellularDataRestrictedState state = cellularData.restrictedState;
  if (state == kCTCellularDataRestrictedStateUnknown || state == kCTCellularDataNotRestricted) {
    if (returnBlock) {
      returnBlock(NO);
    }
  } else {
    if (returnBlock) {
      returnBlock(YES);
    }
  }
#endif
}

//是否开启健康
+ (void)openHealthServiceWithBolck:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
  if (![HKHealthStore isHealthDataAvailable]) {
    if (returnBlock) {
      returnBlock(NO);
    }
  } else {
    HKHealthStore *healthStore = [[HKHealthStore alloc] init];
    HKObjectType *hkObjectType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
    HKAuthorizationStatus hkAuthStatus = [healthStore authorizationStatusForType:hkObjectType];
    if (hkAuthStatus == HKAuthorizationStatusNotDetermined) {
      // 1. 你创建了一个NSSet对象，里面存有本篇教程中你将需要用到的从Health Stroe中读取的所有的类型：个人特征（血液类型、性别、出生日期）、数据采样信息（身体质量、身高）以及锻炼与健身的信息。
      NSSet <HKObjectType *> * healthKitTypesToRead = [[NSSet alloc] initWithArray:@[[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth],[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBloodType],[HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex],[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass],[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight],[HKObjectType workoutType]]];
      // 2. 你创建了另一个NSSet对象，里面有你需要向Store写入的信息的所有类型（锻炼与健身的信息、BMI、能量消耗、运动距离）
      NSSet <HKSampleType *> * healthKitTypesToWrite = [[NSSet alloc] initWithArray:@[[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMassIndex],[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned],[HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning],[HKObjectType workoutType]]];
      [healthStore requestAuthorizationToShareTypes:healthKitTypesToWrite readTypes:healthKitTypesToRead completion:^(BOOL success, NSError *error) {
        if (returnBlock) {
          returnBlock(success);
        }
      }];
    } else if (hkAuthStatus == HKAuthorizationStatusSharingDenied) {
      if (returnBlock) {
        returnBlock(NO);
      }
    } else {
      if (returnBlock) {
        returnBlock(YES);
      }
    }
  }
#endif
}

//是否开启Touch ID
+ (void)openTouchIDServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0
  LAContext *laContext = [[LAContext alloc] init];
  laContext.localizedFallbackTitle = @"输入密码";
  NSError *error;
  if ([laContext canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&error]) {
    NSLog(@"恭喜,Touch ID可以使用!");
    [laContext evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:@"需要验证您的指纹来确认您的身份信息" reply:^(BOOL success, NSError *error) {
      if (success) {
        // 识别成功
        if (returnBlock) {
          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            returnBlock(YES);
          }];
        }
      } else if (error) {
        if (returnBlock) {
          [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            returnBlock(NO);
          }];
        }
        if (error.code == LAErrorAuthenticationFailed) {
          // 验证失败
        }
        if (error.code == LAErrorUserCancel) {
          // 用户取消
        }
        if (error.code == LAErrorUserFallback) {
          // 用户选择输入密码
        }
        if (error.code == LAErrorSystemCancel) {
          // 系统取消
        }
        if (error.code == LAErrorPasscodeNotSet) {
          // 密码没有设置
        }
      }
    }];
  } else {
    NSLog(@"设备不支持Touch ID功能,原因:%@",error);
    if (returnBlock) {
      returnBlock(NO);
    }
  }
#endif
}


//是否开启Apple Pay
+ (void)openApplePayServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0
  NSArray<PKPaymentNetwork> *supportedNetworks = @[PKPaymentNetworkAmex, PKPaymentNetworkMasterCard, PKPaymentNetworkVisa, PKPaymentNetworkDiscover];
  if ([PKPaymentAuthorizationViewController canMakePayments] && [PKPaymentAuthorizationViewController canMakePaymentsUsingNetworks:supportedNetworks]) {
    if (returnBlock) {
      returnBlock(YES);
    }
  } else {
    if (returnBlock) {
      returnBlock(NO);
    }
  }
#endif
}

//是否开启语音识别
+ (void)openSpeechServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  SFSpeechRecognizerAuthorizationStatus speechAuthStatus = [SFSpeechRecognizer authorizationStatus];
  if (speechAuthStatus == SFSpeechRecognizerAuthorizationStatusNotDetermined) {
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
      if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(YES);
          }
        });
      } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(YES);
          }
        });
      }
    }];
  } else if (speechAuthStatus == SFSpeechRecognizerAuthorizationStatusAuthorized) {
    if (returnBlock) {
      returnBlock(YES);
    }
  } else{
    if (returnBlock) {
      returnBlock(NO);
    }
  }
#endif
}


//是否开启媒体资料库
+ (void)openMediaPlayerServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_3
  MPMediaLibraryAuthorizationStatus authStatus = [MPMediaLibrary authorizationStatus];
  if (authStatus == MPMediaLibraryAuthorizationStatusNotDetermined) {
    [MPMediaLibrary requestAuthorization:^(MPMediaLibraryAuthorizationStatus status) {
      if (status == MPMediaLibraryAuthorizationStatusAuthorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(YES);
          }
        });
      }else{
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(NO);
          }
        });
      }
    }];
  }else if (authStatus == MPMediaLibraryAuthorizationStatusAuthorized){
    if (returnBlock) {
      returnBlock(YES);
    }
  }else{
    if (returnBlock) {
      returnBlock(NO);
    }
  }
#endif
}


//是否开启Siri
+ (void)openSiriServiceWithBlock:(ReturnBlock)returnBlock
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_0
  INSiriAuthorizationStatus siriAutoStatus = [INPreferences siriAuthorizationStatus];
  if (siriAutoStatus == INSiriAuthorizationStatusNotDetermined) {
    [INPreferences requestSiriAuthorization:^(INSiriAuthorizationStatus status) {
      if (status == INSiriAuthorizationStatusAuthorized) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(YES);
          }
        });
      } else {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (returnBlock) {
            returnBlock(YES);
          }
        });
      }
    }];
  } else if (siriAutoStatus == INSiriAuthorizationStatusAuthorized) {
    if (returnBlock) {
      returnBlock(YES);
    }
  } else{
    if (returnBlock) {
      returnBlock(NO);
    }
  }
#endif
}

/*
 <!-- 相册 -->
 <key>NSPhotoLibraryUsageDescription</key>
 <string>App需要您的同意,才能访问相册</string>
 <!-- 相机 -->
 <key>NSCameraUsageDescription</key>
 <string>App需要您的同意,才能访问相机</string>
 <!-- 麦克风 -->
 <key>NSMicrophoneUsageDescription</key>
 <string>App需要您的同意,才能访问麦克风</string>
 <!-- 位置 -->
 <key>NSLocationUsageDescription</key>
 <string>App需要您的同意,才能访问位置</string>
 <!-- 在使用期间访问位置 -->
 <key>NSLocationWhenInUseUsageDescription</key>
 <string>App需要您的同意,才能在使用期间访问位置</string>
 <!-- 始终访问位置 -->
 <key>NSLocationAlwaysUsageDescription</key>
 <string>App需要您的同意,才能始终访问位置</string>
 <!-- 日历 -->
 <key>NSCalendarsUsageDescription</key>
 <string>App需要您的同意,才能访问日历</string>
 <!-- 提醒事项 -->
 <key>NSRemindersUsageDescription</key>
 <string>App需要您的同意,才能访问提醒事项</string>
 <!-- 运动与健身 -->
 <key>NSMotionUsageDescription</key>
 <string>App需要您的同意,才能访问运动与健身</string>
 <!-- 健康更新 -->
 <key>NSHealthUpdateUsageDescription</key>
 <string>App需要您的同意,才能访问健康更新 </string>
 <!-- 健康分享 -->
 <key>NSHealthShareUsageDescription</key>
 <string>App需要您的同意,才能访问健康分享</string>
 <!-- 蓝牙 -->
 <key>NSBluetoothPeripheralUsageDescription</key>
 <string>App需要您的同意,才能访问蓝牙</string>
 <!-- 媒体资料库 -->
 <key>NSAppleMusicUsageDescription</key>
 <string>App需要您的同意,才能访问媒体资料库</string>
 <!-- 语音识别 -->
 <key>NSSpeechRecognitionUsageDescription</key>
 <string>App需要您的同意,才能使用语音识别</string>
 */
@end
