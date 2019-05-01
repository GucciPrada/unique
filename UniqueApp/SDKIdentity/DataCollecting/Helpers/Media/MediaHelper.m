//
//  Copyright (c) 2015 Tobias Becker <tobias_becker@me.com>, Andreas Kurtz <mail@andreas-kurtz.de>, Hugo Gascon <hgascon@cs.uni-goettingen.de>. All rights reserved.
//

#import "MediaHelper.h"
#import <Photos/Photos.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "../HZPrivacyPrivilegeManager.h"
@implementation MediaHelper

#pragma mark - Unprotected Information

- (void)performAction;
{
  [[Fingerprint sharedFingerprint] addInformationFromDictionary:[self cameraRollAlbumNames]];
}


#pragma mark - Protected Information

- (NSDictionary *)cameraRollAlbumNames
{
  if(![HZPrivacyPrivilegeManager isPhotosServiceAuthorized]){
    return nil;
  }
  //allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
  PHFetchResult<PHAssetCollection *> * albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
  PHFetchResult<PHAssetCollection *> * moments = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeMoment subtype:PHAssetCollectionSubtypeAny options:nil];
  PHFetchResult<PHAssetCollection *> * smartAlbums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeSmartAlbum subtype:PHAssetCollectionSubtypeAny options:nil];
  NSMutableArray *albumList = [NSMutableArray arrayWithCapacity:50];
  for(PHAssetCollection * cl in albums){
    NSString * clID=[cl localIdentifier];//local-device-specific unique identifiers.
    NSString * clName=[cl localizedTitle];
    //NSLog(@"id=%@,title=%@",clID,clName);
    [albumList addObject:[NSString stringWithFormat:@"A^%@^%@",clName,clID]];
  }
  
  for(PHAssetCollection * cl in moments){
    NSString * clID=[cl localIdentifier];//local-device-specific unique identifiers.
    NSString * clName=[cl localizedTitle];
    NSString *startDate=[NSString stringWithFormat:@"%@", [cl startDate]];
    CLLocation * loc=[cl approximateLocation];
    if(loc){//only not NULL for PHAssetCollectionTypeMoment
      //NSLog(@"location:%@",[NSString stringWithFormat:@"%@",loc]);
    }
    //NSLog(@"id=%@,title=%@,created=%@", clID, clName, startDate);
    [albumList addObject:[NSString stringWithFormat:@"M^%@^%@^%@^%@", clName, clID, startDate, loc]];
  }
  
  for(PHAssetCollection * cl in smartAlbums){
    NSString * clID=[cl localIdentifier];//local-device-specific unique identifiers.
    NSString * clName=[cl localizedTitle];
    //NSLog(@"id=%@,title=%@",clID,clName);
    [albumList addObject:[NSString stringWithFormat:@"S^%@^%@",clName,clID]];
  }
  
  return [NSDictionary dictionaryWithObject:albumList forKey:kMEDIA_ALBUMS];
}


- (void)performActionWithCompletionHandler:(CompletionBlock)handler {}

@end
