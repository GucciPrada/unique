//
//  SDKIdentity.h
//  Unique
//
//  Created by 程龙 on 2019/4/29.
//  Copyright © 2019 Tobias Becker. All rights reserved.
//

#ifndef SDKIdentity_h
#define SDKIdentity_h


@interface SDKIdentity : NSObject


+ (id)sharedInstance;
- (NSString*)getData;

@end

#endif /* SDKIdentity_h */
