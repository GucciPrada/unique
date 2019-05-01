//
//  HZPrivacyPrivilegeManager.h
//  Unique
//
//  Created by 程龙 on 2019/4/26.
//  Copyright © 2019 Tobias Becker. All rights reserved.
//

#ifndef HZPrivacyPrivilegeManager_h
#define HZPrivacyPrivilegeManager_h
#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>//日历备忘录

typedef void(^ReturnBlock)(BOOL isOpen);

@interface HZPrivacyPrivilegeManager : NSObject
//是否开启定位
+ (void)openLocationServiceWithBlock:(ReturnBlock)returnBlock;
//是否允许消息推送
+ (void)openMessageNotificationServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启摄像头
+ (void)openCaptureDeviceServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启相册
+ (BOOL)isPhotosServiceAuthorized;
//是否开启麦克风
+ (void)openRecordServiceWithBlock:(ReturnBlock)returnBlock wannaRequestNow:(BOOL)requestNow;
//是否开启通讯录
+ (void)openContactsServiceWithBolck:(ReturnBlock)returnBlock wannaRequestNow:(BOOL) requestNow;
//是否开启蓝牙
+ (void)openPeripheralServiceWithBolck:(ReturnBlock)returnBlock;
//是否开启日历备忘录
+ (void)openEventServiceWithBolck:(ReturnBlock)returnBlock withType:(EKEntityType)entityType wannaRequestNow:(BOOL) requestNow;
//是否开启互联网
+ (void)openEventServiceWithBolck:(ReturnBlock)returnBlock;
//是否开启健康
+ (void)openHealthServiceWithBolck:(ReturnBlock)returnBlock;
// 是否开启Touch ID
+ (void)openTouchIDServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启Apple Pay
+ (void)openApplePayServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启语音识别
+ (void)openSpeechServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启媒体资料库
+ (void)openMediaPlayerServiceWithBlock:(ReturnBlock)returnBlock;
//是否开启Siri
+ (void)openSiriServiceWithBlock:(ReturnBlock)returnBlock;

@end

#endif /* HZPrivacyPrivilegeManager_h */
