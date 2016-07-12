//
//  CacheManager.h
//  LJRViewCliped
//
//  Created by lujianrong on 16/7/5.
//  Copyright © 2016年 LJR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#define kShareManager [CacheManager shareManager]
@interface CacheManager : NSObject
+ (instancetype)shareManager;
/**
 *	允许存入内存的最大值，单位为byte，默认为60M
 */
@property (nonatomic, assign) NSUInteger totalCostMemoryLimit;
/**
 *	是否存入Cache，默认为YES
 */
@property (nonatomic, assign) BOOL shouldCache;
@property (readonly, nonatomic, strong) NSCache *shareCache;
/**
 *  异步存储图片
 *
 *  @param image 图片
 *  @param key     通常是指URL(唯一), 内部 MD5
 */
+ (void)storeClipedImage:(UIImage *)image toDiskWithKey:(NSString *)key;
/**
 *	根据存储时指定的key先从缓存读取，若没有则读取本地文件。异步操作!
 *
 *	@param key				key
 *	@param completion	若有图片，则返回图片，否则返回nil
 */
+ (void)clipedImageFromDiskWithKey:(NSString *)key completion:(void (^)(UIImage *image))completion;
/**
 *	清除缓存，异步操作
 */
+ (void)clearClipedImagesCache;
/**
 *	获取本地已存储的所有已剪裁的缓存大小，单位为bytes
 *
 *	@return 缓存大小
 */
+ (unsigned long long)imagesCacheSize;
@end
