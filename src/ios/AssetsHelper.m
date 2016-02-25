/********* AssetsHelper.m Cordova Plugin Implementation *******/

#import <Cordova/CDV.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "MD5Handler.h"

@interface AssetsHelper : CDVPlugin

@property (nonatomic, strong) ALAssetsLibrary *assetsLibrary;
@property (nonatomic, strong) NSMutableArray *groups;
@property (nonatomic, strong) NSMutableArray *assets;
@property (nonatomic, strong) NSDateFormatter *dateFormatter;
@property int assetsCount;

- (void)getAllPhotos:(CDVInvokedUrlCommand*)command;
- (void)getThumbnails:(CDVInvokedUrlCommand*)command;
- (void)exportAsset:(CDVInvokedUrlCommand*)command;
- (void)savePhoto:(CDVInvokedUrlCommand*)command;

@end

@implementation AssetsHelper

- (void)getAllPhotos:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getAllPhotos");
    if (self.assetsLibrary == nil) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    if (self.groups == nil) {
        _groups = [[NSMutableArray alloc] init];
    } else {
        [self.groups removeAllObjects];
    }
    if (!self.assets) {
        _assets = [[NSMutableArray alloc] init];
    } else {
        [self.assets removeAllObjects];
    }
    self.assetsCount = 0;

    ALAssetsGroupEnumerationResultsBlock assetsEnumerationBlock = ^(ALAsset *result, NSUInteger index, BOOL *stop) {
        if (result) {
            
            [self.assets addObject:result];
            if ([self.assets count] == self.assetsCount)
            {
                NSLog(@"Got all %d photos",self.assetsCount);
                [self getAllPhotosComplete:command with:nil];
            }
        }
    };

    // setup our failure view controller in case enumerateGroupsWithTypes fails
    ALAssetsLibraryAccessFailureBlock failureBlock = ^(NSError *error) {

        NSString* errorMessage = nil;
        switch ([error code]) {
            case ALAssetsLibraryAccessUserDeniedError:
            case ALAssetsLibraryAccessGloballyDeniedError:
                errorMessage = @"The user has declined access to it.";
                break;
            default:
                errorMessage = @"Reason unknown.";
                break;
        }
        NSLog(@"Problem reading assets library %@",errorMessage);
        [self getAllPhotosComplete:command with:errorMessage];
    };

    ALAssetsLibraryGroupsEnumerationResultsBlock listGroupBlock = ^(ALAssetsGroup *group, BOOL *stop) {
        ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
        [group setAssetsFilter:onlyPhotosFilter];
        // NSLog(@"AssetsLib::getAllPhotos::listGroupBlock > %@ (%d)   type: %@    url: %@",[group valueForProperty:ALAssetsGroupPropertyName],[group numberOfAssets],[group valueForProperty:ALAssetsGroupPropertyType],[group valueForProperty:ALAssetsGroupPropertyURL]);
        if(!group)
        {
            NSLog(@"Got all %lu asset groups with total %d assets",(unsigned long)[self.groups count],self.assetsCount);
            for (ALAssetsGroup *group in self.groups)
            {   // Enumarate each asset group
                ALAssetsFilter *onlyPhotosFilter = [ALAssetsFilter allPhotos];
                [group setAssetsFilter:onlyPhotosFilter];
                [group enumerateAssetsUsingBlock:assetsEnumerationBlock];
            }
        }
        else if ([group numberOfAssets] > 0)
        {
            //NSLog(@"Got asset group \"%@\" with %ld photos",[group valueForProperty:ALAssetsGroupPropertyName],(long)[group numberOfAssets]);
            [self.groups addObject:group];
            self.assetsCount = self.assetsCount + [group numberOfAssets];
        }
        
    };
    
    [self.commandDelegate runInBackground:^{
        // enumerate only photos
        NSUInteger groupTypes = ALAssetsGroupAll; // ALAssetsGroupAlbum | ALAssetsGroupEvent | ALAssetsGroupFaces | ALAssetsGroupSavedPhotos | ALAssetsGroupPhotoStream;
        [self.assetsLibrary enumerateGroupsWithTypes:groupTypes usingBlock:listGroupBlock failureBlock:failureBlock];
    }];
  
}

- (void)getAllPhotosComplete:(CDVInvokedUrlCommand*)command with:(NSString*)error
{
    CDVPluginResult* pluginResult = nil;

    if (error != nil && [error length] > 0)
    {   // Call error
        NSLog(@"Error occured for command.callbackId:%@, error:%@", command.callbackId, error);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:error];
    }
    else
    {   // Call was successful
        NSMutableDictionary* photos = [NSMutableDictionary dictionaryWithDictionary:@{}];
        if (self.dateFormatter == nil) {
                    _dateFormatter = [[NSDateFormatter alloc] init];
                    _dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ssZ";
                }
        for (int i=0; i<[self.assets count]; i++)
        {
            ALAsset* asset = self.assets[i];
            NSString* url = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
            NSString* date = [self.dateFormatter stringFromDate:[asset valueForProperty:ALAssetPropertyDate]];
            ALAssetRepresentation* representation = [asset defaultRepresentation];
            NSDictionary* photo = @{
                                    @"url": url,
                                    @"date": date,
                                    @"filename":[representation filename]
                                   };
            
            //NSMutableDictionary* photometa = [self getImageMeta:asset];
            //[photometa addEntriesFromDictionary:photo];

            [photos setObject:photo forKey:photo[@"url"]];
            date = nil;
            photo = nil;
        }
        NSArray* photoMsg = [photos allValues];
        NSLog(@"Sending to phonegap application message with %lu photos",(unsigned long)[photoMsg count]);
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:photoMsg];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getThumbnails:(CDVInvokedUrlCommand*)command
{
    NSLog(@"getThumbnails");

    ALAssetsLibraryProcessBlock processThumbnailsBlock = ^(ALAsset *asset) {
        NSString* url = [[asset valueForProperty:ALAssetPropertyAssetURL] absoluteString];
        CGImageRef thumbnailImageRef = [asset thumbnail];
        UIImage* thumbnail = [UIImage imageWithCGImage:thumbnailImageRef];
        NSString* base64encoded = [UIImagePNGRepresentation(thumbnail) base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
        NSDictionary* photo = @{
                                @"url": url,
                                @"base64encoded": base64encoded
                               };
        return photo;
    };

    [self.commandDelegate runInBackground:^{
        [self getPhotos:command processBlock:processThumbnailsBlock];
    }];
}

- (NSMutableDictionary* ) getImageMeta:(ALAsset*)asset
{
    ALAssetRepresentation* representation = [asset defaultRepresentation];
    struct CGSize size = [representation dimensions];
    NSDictionary* metadata = [representation metadata];

    NSMutableDictionary* dict = [[NSMutableDictionary alloc] init];
    [dict setValue:[representation filename] forKey:@"filename"];
    [dict setValue:@(size.width) forKey:@"width"];
    [dict setValue:@(size.height) forKey:@"height"];

    //@"{GPS}"
    NSDictionary* gps = [metadata objectForKey:@"{GPS}"];
    if (gps != nil){
        NSNumber* Latitude     = [gps objectForKey:@"Latitude"];
        NSNumber* Longitude    = [gps objectForKey:@"Longitude"];
        NSString* LatitudeRef  = [gps objectForKey:@"LatitudeRef"];
        NSString* LongitudeRef = [gps objectForKey:@"LongitudeRef"];
        [dict setValue:Latitude forKey:@"gps_Latitude"];
        [dict setValue:Longitude forKey:@"gps_Longitude"];
        [dict setValue:LatitudeRef forKey:@"gps_LatitudeRef"];
        [dict setValue:LongitudeRef forKey:@"gps_LongitudeRef"];
    }
    //@"{Exif}"
    NSDictionary* exif = [metadata objectForKey:@"{Exif}"];
    if (exif != nil){
        NSString* DateTimeOriginal  = [exif objectForKey:@"DateTimeOriginal"];
        NSString* DateTimeDigitized = [exif objectForKey:@"DateTimeDigitized"];
        [dict setValue:DateTimeOriginal forKey:@"exif_DateTimeOriginal"];
        [dict setValue:DateTimeDigitized forKey:@"exif_DateTimeDigitized"];
    }
    //@"{IPTC}"
    NSDictionary* iptc = [metadata objectForKey:@"{IPTC}"];
    if (iptc != nil){
        NSArray* Keywords = [iptc objectForKey:@"Keywords"];
        [dict setValue:Keywords forKey:@"iptc_Keywords"];
    }
    //[AssetsLib logDict:dict];
    return dict;
}

+ (void) logDict:(NSDictionary*)dict
{
    for (id key in dict)
    {
        NSLog(@"key: %@, value: %@ ", key, [dict objectForKey:key]);
    }
}

typedef NSDictionary* (^ALAssetsLibraryProcessBlock)(ALAsset *asset);

- (void)getPhotos:(CDVInvokedUrlCommand*)command processBlock:(ALAssetsLibraryProcessBlock)process
{
    NSArray* urlList = [command.arguments objectAtIndex:0];
    if (urlList != nil && [urlList count] > 0)
    {
        if (self.assetsLibrary == nil) {
            _assetsLibrary = [[ALAssetsLibrary alloc] init];
        }

        NSMutableDictionary* photos = [NSMutableDictionary dictionaryWithDictionary:@{}];

        for (int i=0; i<[urlList count]; i++)
        {
            NSString* urlString = [urlList objectAtIndex:i];
            NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
            //NSLog(@"Asset url: %@", url);
            [self.assetsLibrary assetForURL:url
                                resultBlock: ^(ALAsset *asset){
                                    NSDictionary* photo = process(asset);
                                    NSLog(@"Done %d: %@", i, photo[@"url"]);
                                    [photos setObject:photo forKey:photo[@"url"]];
                                    if ([urlList count] == [photos count])
                                    {
                                        NSArray* photoMsg = [photos allValues];
                                        NSLog(@"Sending to phonegap application message with %lu photos",(unsigned long)[photoMsg count]);
                                        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:photoMsg];
                                        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                                    }
                                }
                               failureBlock: ^(NSError *error)
             {
                 NSLog(@"Failed to process asset(s)");
                 [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
             }
             ];
        }
    }
    else
    {
        NSLog(@"Missing parameter urlList");
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
    }
}

- (void)savePhoto:(CDVInvokedUrlCommand*)command
{
    if (self.assetsLibrary == nil) {
        _assetsLibrary = [[ALAssetsLibrary alloc] init];
    }
    NSString *filePath= [command.arguments objectAtIndex:0];
    NSLog(@"saveFileTOPhotoAlbum  filepath: %@",filePath);
    if (filePath == nil || [filePath isEqual:[NSNull null]] || filePath.length <= 0)
    {
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];

        NSLog(@"saveFileTOPhotoAlbum  filepath error ");
        return;
    }

    UIImage *imgData = [UIImage imageWithContentsOfFile:filePath];
    NSLog(@"saveFileTOPhotoAlbum  imgData: %@",imgData);
    if(!imgData){
        [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
        return;
    }

    [self.assetsLibrary writeImageToSavedPhotosAlbum:[imgData CGImage] orientation:(ALAssetOrientation)[imgData imageOrientation] completionBlock:^(NSURL *assetURL, NSError *error) {
        NSLog(@"writeImageToSavedPhotosAlbum err %@",error);
        if (error) {
            [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
        }
        else{
            NSString *url = [assetURL absoluteString];
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[url]];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
    imgData = nil;
}


- (void)exportAsset:(CDVInvokedUrlCommand*)command
{
    NSDictionary* assetInfo = [command.arguments objectAtIndex:0];
    NSString *localpath= [self getUploadTempFilePath:[assetInfo objectForKey:@"filename"]];
    ALAssetsLibraryProcessBlock processThumbnailsBlock = ^(ALAsset *asset) {
        return [self mediaInfoWithALAssert:asset filePath:localpath];
    };

    NSURL *url = [NSURL URLWithString:[[assetInfo objectForKey:@"url"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [self.assetsLibrary assetForURL:url
                        resultBlock: ^(ALAsset *asset){
                            NSDictionary* assetInfo = processThumbnailsBlock(asset);
                            NSLog(@"Asset assetInfo: %@", assetInfo);
                            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:@[assetInfo]];
                            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
                        }
                       failureBlock: ^(NSError *error)
     {
         NSLog(@"Failed to process asset(s)");
         [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR] callbackId:command.callbackId];
     }
     ];
}

- (NSString *)getUploadTempFilePath:(NSString *)fname
{
    fname = [fname lastPathComponent];

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [NSString stringWithFormat:@"%@/%@",[paths objectAtIndex:0],@"backupAlbum"];
    NSString *imageFilePath = [documentsDirectory stringByAppendingPathComponent:fname];
    BOOL isCreated = NO;
    NSError *error;
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if ([fileMgr fileExistsAtPath:documentsDirectory]) {
        isCreated = YES;
    } else {
        isCreated = [fileMgr createDirectoryAtPath:documentsDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        if (!isCreated) {
            return nil;
        }
    }
    return imageFilePath;
}


- (NSDictionary *)mediaInfoWithALAssert:(ALAsset *)result filePath:(NSString *)datapath
{

    ALAssetRepresentation *assetRep = [result defaultRepresentation];

    long long size = [assetRep size];
    //大于64M 分块大小8M 否则分块大小<=4M
    long long buffLength = 1024*1024*4;

    NSUInteger secCount = 1;
    NSUInteger temp = (size % buffLength == 0) ? 0 : 1;
    secCount = size / buffLength + temp;

    MD5Handler *pMd5 = [[MD5Handler alloc] init];
    [pMd5 initCtx];
    //本地缓存历史文件是否删除，如要保存需要考虑完整性
    [self deleteFile:datapath];
    //文本分段写入本地临时目录,上传时获取分块使用

    for (int i = 0; i < secCount; i++)
    {

        uint8_t *buff = malloc(buffLength);
        NSError *err = nil;
        unsigned long long offset = i*buffLength;
        NSUInteger gotByteCount = [assetRep getBytes:buff fromOffset:offset length:buffLength error:&err];

        NSData *tmpData = [[NSData alloc] initWithBytesNoCopy:buff length:gotByteCount freeWhenDone:NO];

        if (![[NSFileManager defaultManager] fileExistsAtPath:datapath])
        {
            [[NSFileManager defaultManager] createFileAtPath:datapath contents:nil attributes:nil];
        }
        NSFileHandle *outFile = [NSFileHandle fileHandleForUpdatingAtPath:datapath];
        if (outFile != nil) {
            //找到并定位
            [outFile seekToEndOfFile];
            [outFile writeData:tmpData];
            //关闭读写文件
            [outFile closeFile];

        }
        [pMd5 updataCtx:tmpData];
        tmpData = nil;
        free(buff);
    }
    __autoreleasing  NSDictionary *tmpDic = [[NSDictionary alloc] initWithObjectsAndKeys:[pMd5 getMd5],@"md5",
                                             [NSString stringWithFormat:@"%lld",size],@"size",
                                             datapath,@"localpath",nil];
    pMd5 = nil;
    return tmpDic;
}


- (NSData *)readDataForPath:(NSString *)sourcePath start:(unsigned long long )startByte
{
    //取需要大小的data数据 减少内存
    NSData *blockData = nil;
    long long buffLength = 1024*1024*4;
    if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath]) {
        NSFileHandle *outFile = [NSFileHandle fileHandleForReadingAtPath:sourcePath];
        if (outFile != nil) {
            //找到并定位
            [outFile seekToFileOffset:startByte];
            blockData = [outFile readDataOfLength:buffLength];
            //关闭读写文件
            [outFile closeFile];
        }
    }

    return blockData;
}


- (BOOL)deleteFile:(NSString *)filePath
{
    if (filePath == nil || [filePath isEqual:[NSNull null]] || filePath.length <= 0)
        return NO;

    // 创建文件管理器
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    if ([fileMgr fileExistsAtPath:filePath])
    {
        NSError *err;
        return [fileMgr removeItemAtPath:filePath error:&err];
    }

    return NO;
}





@end
