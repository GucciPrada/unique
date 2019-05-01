//
//  Copyright (c) 2015 Tobias Becker <tobias_becker@me.com>, Andreas Kurtz <mail@andreas-kurtz.de>, Hugo Gascon <hgascon@cs.uni-goettingen.de>. All rights reserved.
//

#import "UIKitHelper.h"
#import "FCUUID.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>

@implementation UIKitHelper

#pragma mark - Unprotected Information

- (void)performAction
{
  [[Fingerprint sharedFingerprint] addInformationFromDictionary:[self accessibility]];
  [[Fingerprint sharedFingerprint] addInformationFromDictionary:[self getDeviceInfo]];
  //由于这些scheme需要在宿主App的Info.plist中配置一个选项,目前看来这会让App开发者的配置变复杂,暂时关闭这个检测.
  //[[Fingerprint sharedFingerprint] addInformationFromDictionary:[self processSchemes]];
}

/*
 Collects information about accessibility settings
 */
- (NSDictionary *)accessibility
{
  NSMutableDictionary *accessibilityInfo = [NSMutableDictionary dictionary];
  NSNumber *voiceOver = [NSNumber numberWithBool:UIAccessibilityIsVoiceOverRunning()];
  NSNumber *closedCaptioning = [NSNumber numberWithBool:UIAccessibilityIsClosedCaptioningEnabled()];
  NSNumber *guidedAccess = [NSNumber numberWithBool:UIAccessibilityIsGuidedAccessEnabled()];
  NSNumber *invertedColors = [NSNumber numberWithBool:UIAccessibilityIsInvertColorsEnabled()];
  NSNumber *monoAudio = [NSNumber numberWithBool:UIAccessibilityIsMonoAudioEnabled()];
  
  NSNumber *switchControl = [NSNumber numberWithBool:UIAccessibilityIsSwitchControlRunning()];
  NSNumber *assistiveTouch = [NSNumber numberWithBool:UIAccessibilityIsAssistiveTouchRunning()];
  NSNumber *shakeUndo = [NSNumber numberWithBool:UIAccessibilityIsShakeToUndoEnabled()];
  NSNumber *darkSysColor = [NSNumber numberWithBool:UIAccessibilityDarkerSystemColorsEnabled()];
  
  [accessibilityInfo setValue:voiceOver forKey:kUIKIT_ACCESSIBILITY_VOICEOVER];
  [accessibilityInfo setValue:closedCaptioning forKey:kUIKIT_ACCESSIBILITY_CLOSEDCAPTIONING];
  [accessibilityInfo setValue:guidedAccess forKey:kUIKIT_ACCESSIBILITY_GUIDEDACCESS];
  [accessibilityInfo setValue:invertedColors forKey:kUIKIT_ACCESSIBILITY_INVERTEDCOLORS];
  [accessibilityInfo setValue:monoAudio forKey:kUIKIT_ACCESSIBILITY_MONOAUDIO];
  [accessibilityInfo setValue:switchControl forKey:kUIKIT_ACCESSIBILITY_SWITCHCONTROL];
  [accessibilityInfo setValue:assistiveTouch forKey:kUIKIT_ACCESSIBILITY_ASSISTIVETOUCH];
  [accessibilityInfo setValue:shakeUndo forKey:kUIKIT_ACCESSIBILITY_SHAKEUNDO];
  [accessibilityInfo setValue:darkSysColor forKey:kUIKIT_ACCESSIBILITY_DARKSYSTEMCLR];
  
  return accessibilityInfo;
}

/*
 Collects information about installed apps
 */
- (NSDictionary *)processSchemes
{
  NSData *jsonData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"schemes" ofType:@"json"]];
  NSError *error;
  NSArray *schemes = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&error];
  
  if (error) {
    ErrLog(error);
  }
  
  UIApplication *app = [UIApplication sharedApplication];
  NSMutableArray *installedApps = [NSMutableArray array];
  
  for (NSString *scheme in schemes) {
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", scheme]];
    
    if ([app canOpenURL:url]) {
      // Use md5 hash
      //[installedApps addObject:[scheme md5]];
      [installedApps addObject:scheme];
    }
  }
  
  NSDictionary *appsInfo = [NSDictionary dictionaryWithObject:installedApps forKey:kUIKIT_UIAPPLICATION_INSTALLED_APPS];
  return appsInfo;
}

/*
 Collects information about the device
 */
- (NSDictionary *)getDeviceInfo
{
  NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionary];
  UIDevice *device = [UIDevice currentDevice];
  
  NSString *identifierForVendor = device.identifierForVendor.UUIDString;
  NSString *name = device.name;
  NSString *sysVersion = device.systemVersion;
  NSString *exactModel = [self platform];
  NSString *hostAppNameVer=[UIKitHelper applicationVersion];
  [deviceInfo setValue:identifierForVendor forKey:kUIKIT_UIDEVICE_IDVENDOR];
  [deviceInfo setValue:exactModel forKey:kUIKIT_UIDEVICE_MODEL];
  [deviceInfo setValue:name forKey:kUIKIT_UIDEVICE_NAME];
  [deviceInfo setValue:sysVersion forKey:kUIKIT_UIDEVICE_IOS];
  [deviceInfo setValue:hostAppNameVer forKey:kUIKIT_UIDEVICE_APP];
  return deviceInfo;
}

#pragma mark - Helper Methods

- (NSString *)platform
{
  int mib[] = {CTL_HW, HW_MACHINE};
  size_t len = 0;
  sysctl(mib, 2, NULL, &len, NULL, 0);
  char *machine = malloc(len);
  sysctl(mib, 2, machine, &len, NULL, 0);
  NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
  free(machine);
  return platform;
}

// Application Version
+ (NSString *)applicationVersion {
    // Get the Application Version Number
    @try {
      
        // Query the plist for the version
        NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        //CFShow((__bridge CFTypeRef)(infoDictionary));
        NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        NSString *bundleId=[[[NSBundle mainBundle]infoDictionary] objectForKey:@"CFBundleIdentifier"];
        NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        NSString *appBuildNum = [infoDictionary objectForKey:@"CFBundleVersion"];
      
        return [NSString stringWithFormat:@"%@ %@ %@(%@)",appName,bundleId, version,appBuildNum];
    }@catch (NSException *exception) {
        return exception.reason;
    }
}

// Clipboard Content
+ (NSString *)clipboardContent {
    // Get the string content of the clipboard (copy, paste)
    @try {
        // Get the Pasteboard
        UIPasteboard *pasteBoard = [UIPasteboard generalPasteboard];
        // Get the string value of the pasteboard
        NSString *clipboardContent = [pasteBoard string];
        // Check for validity
        if (clipboardContent == nil || clipboardContent.length <= 0) {
            // Error, invalid pasteboard
            return nil;
        }
        return clipboardContent;
    }
    @catch (NSException *exception) {
        // Error
        return nil;
    }
}

#pragma mark -
#pragma mark - Protected Information

- (void)performActionWithCompletionHandler:(CompletionBlock)handler
{
  // keine bekannt
}

@end
