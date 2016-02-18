//
//  MD5Handler.h
//  OatosIphoneClient2.0
//
//  Created by qycloud on 14-2-18.
//  Copyright (c) 2014年 qycloud. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

@interface MD5Handler : NSObject
{
    CC_MD5_CTX md5Ctx;
}

- (void)initCtx;
- (void)updataCtx:(NSData *)bytes;
- (NSMutableString *)getMd5;
@end
