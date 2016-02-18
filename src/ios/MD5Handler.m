//
//  MD5Handler.m
//  OatosIphoneClient2.0
//
//  Created by qycloud on 14-2-18.
//  Copyright (c) 2014年 qycloud. All rights reserved.
//

#import "MD5Handler.h"

@implementation MD5Handler


- (void)initCtx
{
    CC_MD5_Init(&md5Ctx);
}

- (void)updataCtx:(NSData *)bytes
{
    CC_MD5_Update(&md5Ctx, [bytes bytes], [bytes length]);
}

- (NSMutableString *)getMd5
{
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5Ctx);
    
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (NSInteger i=0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x", digest[i]];
    }
    return ret;
}

@end
