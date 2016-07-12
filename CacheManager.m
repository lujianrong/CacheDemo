//
//  CacheManager.m
//  LJRViewCliped
//
//  Created by lujianrong on 16/7/5.
//  Copyright © 2016年 LJR. All rights reserved.
//

#import "CacheManager.h"
#import <CommonCrypto/CommonDigest.h>


#define kDefaultCenter [NSNotificationCenter defaultCenter]
#define kCachePath [self cachePath]

static inline NSUInteger GetCacheImageSize(UIImage *image) {
    return image.size.height * image.size.width * image.scale * image.scale;
}

@interface CacheManager()
@property (nonatomic, strong) NSCache *cache;
@property (nonatomic, strong) dispatch_queue_t serialQueue;
@property (nonatomic, strong) NSFileManager *fileManager;
@end


@implementation CacheManager
- (instancetype)init {
    if (self = [super init]) {
        _totalCostMemoryLimit = 60 * 1024 * 1024;
        _cache = [[NSCache alloc] init];
        _cache.totalCostLimit = _totalCostMemoryLimit;//设置默认60M
        _shouldCache = YES;
        _serialQueue = dispatch_queue_create("LJR", DISPATCH_QUEUE_SERIAL);//FIFO
        dispatch_async(_serialQueue, ^{
            _fileManager = [[NSFileManager alloc] init];
        });
        [kDefaultCenter addObserver:self selector:@selector(didReceiveMemoryWarningNotifi) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}
- (void)dealloc {
    [kDefaultCenter removeObserver:self];
}
- (void)didReceiveMemoryWarningNotifi {
    [_cache removeAllObjects];
}
- (void)setTotalCostMemoryLimit:(NSUInteger)totalCostMemoryLimit {
    self.cache.totalCostLimit = totalCostMemoryLimit;
}
- (NSCache *)shareCache {
    return self.cache;
}
+ (NSString *)MD5:(NSString *)key {
    if (key == nil || key.length) return nil;
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
    CC_MD5([key UTF8String], (int)[key lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
    NSMutableString *mString = @"".mutableCopy;
    
    for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [mString appendFormat:@"%02x",(int)digest[i]];
    }
    return [mString copy];
}
+ (NSString *)cachePath {
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/cacheImages"];
}
+ (void)storeClipedImage:(UIImage *)image toDiskWithKey:(NSString *)key {
    if (image == nil || key == nil || key.length == 0) return;
    
    NSString *subpath = [self MD5:key];
    if (kShareManager.shouldCache) {//存进缓存
        NSUInteger cost = GetCacheImageSize(image);
        [kShareManager.cache setObject:image forKey:subpath cost:cost];
    }
    
    dispatch_async(kShareManager.serialQueue, ^{
        if (![kShareManager.fileManager fileExistsAtPath:kCachePath isDirectory:nil]) {
            NSError *error;
            BOOL result = [kShareManager.fileManager createDirectoryAtPath:kCachePath withIntermediateDirectories:YES attributes:nil error:&error]; //创建目录
            if (result && error == nil) {
                NSLog(@"\n create directory fail");
            } else {
                NSLog(@"\n create directory success");
            }
        }
    });
    
    @autoreleasepool {
        NSString *path = [kCachePath stringByAppendingPathComponent:subpath];
        NSData *data = UIImageJPEGRepresentation(image, 1.0);//存储图片
        BOOL result = [kShareManager.fileManager createFileAtPath:path contents:data attributes:nil];
        if (result) {
//#define LJRViewCliped 要定义这个宏才会打印
#ifdef LJRViewCliped
            NSLog(@"\n save image to disk success - path : %@", path);
#endif
        } else {
#ifdef LJRViewCliped
            NSLog(@"\n save image to disk fail - path : %@", path);
#endif
        }
    }
    
}

+ (void)clipedImageFromDiskWithKey:(NSString *)key completion:(void (^)(UIImage *))completion {
    if (key && key.length) {
        dispatch_async(kShareManager.serialQueue, ^{
            NSString *subpath = [self MD5:key];
            UIImage *image = nil;
            if (kShareManager.shouldCache) {//先到缓存里取
                image = [kShareManager.cache objectForKey:subpath];
                if (image) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion)  completion(image);
                    });
                    return;
                }
            }
            //没有到 disk 中取
            NSString *path = [kCachePath stringByAppendingPathComponent:subpath];
            image = [UIImage imageWithContentsOfFile:path];
            if (image != nil && kShareManager.shouldCache) {//存入缓存
                NSUInteger cost = GetCacheImageSize(image);
                [kShareManager.cache setObject:image forKey:path cost:cost];
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion)  completion(image);
            });
        });
    } else {
        completion(nil);
    }
}
+ (void)clearClipedImagesCache {
    dispatch_async(kShareManager.serialQueue, ^{
        if ([kShareManager.fileManager fileExistsAtPath:kCachePath isDirectory:nil]) {
            NSError *error = nil;
            [kShareManager.fileManager removeItemAtPath:kCachePath error:&error];
            if (error) {
                NSLog(@"\nclear caches error: %@", error);
            } else {
                NSLog(@"\n clear caches success");
            }
        }
    });
}
+ (unsigned long long)imagesCacheSize {
    BOOL result = NO;
    unsigned long long total = 0;
    if ([kShareManager.fileManager fileExistsAtPath:kCachePath isDirectory:&result]) {
        if (result) {
            NSError *error = nil;
            NSArray *array = [kShareManager.fileManager contentsOfDirectoryAtPath:kCachePath error:&error];
            if (error == nil) {
                for (NSString *path in array) {
                    NSString *subpath = [path stringByAppendingPathComponent:path];
                    NSDictionary *dict = [kShareManager.fileManager attributesOfItemAtPath:subpath error:&error];
                    if (!error) {
                        total+= [dict[NSFileSize] unsignedIntegerValue];
                    }
                }
            }
        }
    }
    return total;
}

static id _instance;
+ (instancetype)shareManager {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}

- (id)copyWithZone:(NSZone *)zone{
    return _instance;
}

+ (id)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}

@end
