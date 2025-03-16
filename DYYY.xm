#import <CoreServices/CoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "AwemeHeaders.h"
#import "DYYYSettingViewController.h"
#import <objc/runtime.h>

@interface MyDownloader : NSObject
+ (void)downloadLivePhotoWithImageURL:(NSURL *)imageURL videoURL:(NSURL *)videoURL;
@end


#define DYYY @"抖音助手"

// MARK: - 类型定义
typedef NS_ENUM(NSUInteger, MediaType) {
    MediaTypeImage,
    MediaTypeVideo,
    MediaTypeAudio,
    MediaTypeLivePhoto
};

// MARK: - 前置声明
static void saveMedia(NSArray<NSURL *> *mediaURLs, MediaType mediaType);
static void downloadMedia(NSArray<NSURL *> *urls, MediaType mediaType);
static NSString* mimeTypeToExtension(NSString *mimeType, MediaType mediaType);
static UIViewController* topViewController();
static NSURL* _processLivePhotoVideo(NSURL *videoURL, NSString *identifier);
static NSURL* _injectHEICMetadata(NSURL *imageURL, NSString *identifier);
static void showToast(NSString *message, BOOL isError);



// 获取顶级视图控制器
static UIViewController *getActiveTopViewController() {
    UIWindowScene *activeScene = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            activeScene = scene;
            break;
        }
    }
    if (!activeScene) {
        for (id scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                activeScene = (UIWindowScene *)scene;
                break;
            }
        }
    }
    if (!activeScene) return nil;
    UIWindow *window = activeScene.windows.firstObject;
    UIViewController *topController = window.rootViewController;
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

// 获取最上层视图控制器
static UIViewController *topView(void) {
    UIWindow *window = nil;
    for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (scene.activationState == UISceneActivationStateForegroundActive) {
            window = scene.windows.firstObject;
            break;
        }
    }
    if (!window) {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                window = scene.windows.firstObject;
                break;
            }
        }
    }
    if (!window) return nil;
    UIViewController *rootVC = window.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        return ((UINavigationController *)rootVC).topViewController;
    }
    return rootVC;
}


// MARK: - Hook实现
%hook AWELongPressPanelTableViewController

- (NSArray *)dataArray {
    NSArray *originalArray = %orig;
    
    AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    newGroup.groupType = 0;
    
    AWELongPressPanelBaseViewModel *tempModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
    AWEAwemeModel *aweme = tempModel.awemeModel;
    
    NSMutableArray *customActions = [NSMutableArray array];
    
    // 处理媒体类型
    if (aweme.awemeType == 68) { // 图集类型
        AWEImageAlbumImageModel *currentImage = aweme.albumImages.count == 1 ? aweme.albumImages.firstObject : aweme.albumImages[aweme.currentImageIndex - 1];
        
        // 当前图片处理
        if (currentImage) {
            if(currentImage.clipVideo){
                [customActions addObject:@{
                    @"title": @"下载当前实况照片",
                    @"type": @(MediaTypeLivePhoto),
                    @"icon": @"ic_star_outlined_12",
                    @"action": ^{
                        if (currentImage.urlList.count > 0 || currentImage.clipVideo.h264URL.originURLList.count > 0) {
                            NSURL *imageurl = [NSURL URLWithString:currentImage.urlList.firstObject];
                            NSURL *videourl = [NSURL URLWithString:currentImage.clipVideo.h264URL.originURLList.firstObject];
                            [MyDownloader downloadLivePhotoWithImageURL:imageURL videoURL:videoURL];
                        }
                        else {
                            showToast(@"不是实况照片", YES);
                        }
                    }
                }];
            }
            else{
                [customActions addObject:@{
                    @"title": @"下载当前图片",
                    @"type": @(MediaTypeImage),
                    @"icon": @"ic_star_outlined_12",
                    @"action": ^{
                        if (currentImage.urlList.count > 0) {
                            NSURL *url = [NSURL URLWithString:currentImage.urlList.firstObject];
                            downloadMedia(@[url], MediaTypeImage);
                        }
                    }
                }];
            }
        // 下载全部图片
        [customActions addObject:@{
            @"title": @"下载全部图片",
            @"type": @(MediaTypeImage),
            @"icon": @"ic_star_outlined_12",
            @"action": ^{
                NSMutableArray *urls = [NSMutableArray array];
                for (AWEImageAlbumImageModel *image in aweme.albumImages) {
                    if (image.urlList.count > 0) {
                        [urls addObject:[NSURL URLWithString:image.urlList.firstObject]];
                    }
                }
                downloadMedia(urls, MediaTypeImage);
            }
        }];
        }
    } 
    else { // 视频类型
        [customActions addObject:@{
            @"title": @"下载视频",
            @"type": @(MediaTypeVideo),
            @"icon": @"ic_star_outlined_12",
            @"action": ^{
                if (aweme.video.h264URL.originURLList.count > 0) {
                    NSURL *url = [NSURL URLWithString:aweme.video.h264URL.originURLList.firstObject];
                    downloadMedia(@[url], MediaTypeVideo);
                }
            }
        }];
    }
    
    // 音频下载
    if (aweme.music.playURL.originURLList.count > 0) {
        [customActions addObject:@{
            @"title": @"下载音频",
            @"type": @(MediaTypeAudio),
            @"icon": @"ic_star_outlined_12",
            @"action": ^{
                NSURL *url = [NSURL URLWithString:aweme.music.playURL.originURLList.firstObject];
                downloadMedia(@[url], MediaTypeAudio);
            }
        }];
    }
    
    // 构建视图模型
    NSMutableArray *viewModels = [NSMutableArray array];
    [customActions enumerateObjectsUsingBlock:^(NSDictionary *action, NSUInteger idx, BOOL *stop) {
        AWELongPressPanelBaseViewModel *vm = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        vm.describeString = action[@"title"];
        vm.enterMethod = DYYY;
        vm.actionType = 100 + idx;
        vm.showIfNeed = YES;
        vm.duxIconName = action[@"icon"];
        vm.action = action[@"action"];
        [viewModels addObject:vm];
    }];
    
    newGroup.groupArr = viewModels;
    return [@[newGroup] arrayByAddingObjectsFromArray:originalArray ?: @[]];
}
%end

static void downloadLivePhoto(NSURL *imageURL, NSURL *videoURL) {
    // 创建全局队列组
    dispatch_group_t group = dispatch_group_create();
    __block NSURL *processedImageURL = nil;
    __block NSURL *processedVideoURL = nil;
    NSString *assetID = [[NSUUID UUID] UUIDString];
    
    // 显示加载提示
    UIAlertController *loadingAlert = createLoadingAlert(@"开始下载实况照片");
    presentOnTopViewController(loadingAlert);
    
    // 并行下载任务
    dispatch_group_enter(group);
    downloadMediaResource(imageURL, MediaTypeImage, ^(NSURL *location) {
        processedImageURL = injectLivePhotoMetadata(location, assetID, YES);
        dispatch_group_leave(group);
    });
    
    dispatch_group_enter(group);
    downloadMediaResource(videoURL, MediaTypeVideo, ^(NSURL *location) {
        processedVideoURL = injectLivePhotoMetadata(location, assetID, NO);
        dispatch_group_leave(group);
    });
    
    // 最终合并处理
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        [loadingAlert dismissViewControllerAnimated:YES completion:^{
            if (processedImageURL && processedVideoURL) {
                saveLivePhotoToAlbum(processedImageURL, processedVideoURL);
            } else {
                showToastWithError(@"素材下载失败");
            }
        }];
    });
}

// MARK: - 核心处理函数
static NSURL* injectLivePhotoMetadata(NSURL *fileURL, NSString *identifier, BOOL isImage) {
    if (isImage) {
        // HEIC 元数据注入
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)fileURL, NULL);
        NSMutableDictionary *metadata = [(__bridge NSDictionary*)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL) mutableCopy];
        
        // 注入关键标识符
        metadata[(__bridge id)kCGImagePropertyMakerAppleDictionary] = @{ @"17" : identifier };
        metadata[@"ContentIdentifier"] = identifier;
        
        // 写入临时文件
        NSURL *outputURL = tempFileURLWithExtension(@"heic");
        CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)outputURL, kUTTypeHEIC, 1, NULL);
        CGImageDestinationAddImageFromSource(dest, source, 0, (__bridge CFDictionaryRef)metadata);
        CGImageDestinationFinalize(dest);
        
        CFRelease(source);
        CFRelease(dest);
        return outputURL;
    } else {
        // MOV 元数据注入
        AVAsset *asset = [AVAsset assetWithURL:fileURL];
        AVAssetExportSession *exporter = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetHEVCHighestQuality];
        
        // 配置元数据项
        AVMutableMetadataItem *contentIDItem = [[AVMutableMetadataItem alloc] init];
        contentIDItem.key = kKeyContentIdentifier;
        contentIDItem.keySpace = kKeySpaceQuickTimeMetadata;
        contentIDItem.value = identifier;
        
        AVMutableMetadataItem *stillTimeItem = [[AVMutableMetadataItem alloc] init];
        stillTimeItem.key = kKeyStillImageTime;
        stillTimeItem.keySpace = kKeySpaceQuickTimeMetadata;
        stillTimeItem.value = @(CMTimeGetSeconds(asset.duration)/2); // 取中间帧
        
        exporter.metadata = @[contentIDItem, stillTimeItem];
        exporter.outputURL = tempFileURLWithExtension(@"mov");
        exporter.outputFileType = AVFileTypeQuickTimeMovie;
        
        // 同步导出
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        __block BOOL success = NO;
        [exporter exportAsynchronouslyWithCompletionHandler:^{
            success = exporter.status == AVAssetExportSessionStatusCompleted;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        
        return success ? exporter.outputURL : nil;
    }
}

// MARK: - 相册保存
static void saveLivePhotoToAlbum(NSURL *imageURL, NSURL *videoURL) {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            showToastWithError(@"需要相册权限");
            return;
        }
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            
            // 添加配对资源
            [request addResourceWithType:PHAssetResourceTypePairedImage
                                fileURL:imageURL
                               options:[PHAssetResourceCreationOptions new]];
            
            [request addResourceWithType:PHAssetResourceTypePairedVideo
                                fileURL:videoURL
                               options:[PHAssetResourceCreationOptions new]];
            
        } completionHandler:^(BOOL success, NSError *error) {
            // 清理临时文件
            [[NSFileManager defaultManager] removeItemAtURL:imageURL error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:videoURL error:nil];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    showToastWithSuccess(@"实况照片保存成功");
                } else {
                    showToastWithError([NSString stringWithFormat:@"保存失败: %@", error.localizedDescription]);
                }
            });
        }];
    }];
}

// MARK: - 工具方法
static NSURL* tempFileURLWithExtension(NSString *ext) {
    return [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [NSUUID UUID].UUIDString, ext]]];
}

static void downloadMediaResource(NSURL *url, MediaType type, void(^completion)(NSURL*)) {
    NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if (location) {
            NSURL *dest = tempFileURLWithExtension(type == MediaTypeVideo ? @"mp4" : @"heic");
            [[NSFileManager defaultManager] moveItemAtURL:location toURL:dest error:nil];
            completion(dest);
        } else {
            completion(nil);
        }
    }];
    [task resume];
}


// MARK: - 辅助方法
static UIViewController* topViewController() {
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

// MARK: - Toast 实现
@interface DUXToast : UIView
+ (void)showText:(id)arg1 withCenterPoint:(CGPoint)arg2;
+ (void)showText:(id)arg1;
@end

CGPoint topCenter = CGPointMake(
    CGRectGetMidX([UIScreen mainScreen].bounds),
    CGRectGetMinY([UIScreen mainScreen].bounds) + 90
);

void showToast(NSString *text, BOOL isError) {
    // 触觉反馈
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackStyle style = isError ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium;
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [%c(DUXToast) showText:text withCenterPoint:topCenter];
    });
}

%ctor {
    %init(AWELongPressPanelTableViewController = objc_getClass("AWELongPressPanelTableViewController"));
}




// MARK: - MIME 类型转文件扩展名
static NSString* mimeTypeToExtension(NSString *mimeType, MediaType mediaType) {
    if (@available(iOS 14.0, *)) {
        UTType *type = [UTType typeWithMIMEType:mimeType];
        return type.preferredFilenameExtension ?: @"tmp";
    } else {
        CFStringRef uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)mimeType, NULL);
        CFStringRef extension = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassFilenameExtension);
        CFRelease(uti);
        
        if (!extension) {
            switch (mediaType) {
                case MediaTypeVideo: return @"mp4";
                case MediaTypeImage: return @"heic";
                case MediaTypeAudio: return @"mp3";
                case MediaTypeLivePhoto: return @"mov";
                default: return @"tmp";
            }
        }
        return (__bridge_transfer NSString *)extension;
    }
}

// MARK: - 下载核心逻辑
static void downloadMedia(NSArray<NSURL *> *urls, MediaType mediaType) {
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSURL *> *tempFiles = [NSMutableArray array];
    __block BOOL hasError = NO;
    NSString *assetIdentifier = [[NSUUID UUID] UUIDString]; // 统一标识符
    
    for (NSURL *url in urls) {
        dispatch_group_enter(group);
        
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (!error && location) {
                NSString *extension = mimeTypeToExtension(response.MIMEType, mediaType);
                NSURL *processedURL = location;
                
                // Live Photo 元数据处理
                if (mediaType == MediaTypeLivePhoto) {
                    if ([extension isEqualToString:@"jpg"] || [extension isEqualToString:@"jpeg"]) {
                        NSURL *heicURL = _injectHEICMetadata(location, assetIdentifier);
                        if (heicURL) {
                            processedURL = heicURL;
                            extension = @"heic";
                        } else {
                            hasError = YES;
                        }
                    } else if ([extension isEqualToString:@"mov"]) {
                        NSURL *newVideoURL = _processLivePhotoVideo(location, assetIdentifier);
                        if (newVideoURL) {
                            processedURL = newVideoURL;
                        } else {
                            hasError = YES;
                        }
                    }
                }
                
                // 移动至临时目录
                NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
                NSURL *destURL = [tempDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], extension]];
                
                NSError *fileError;
                if ([[NSFileManager defaultManager] moveItemAtURL:processedURL toURL:destURL error:&fileError]) {
                    @synchronized(tempFiles) {
                        [tempFiles addObject:destURL];
                    }
                } else {
		    showToast(@"文件移动失败", YES);
                    //NSLog(@"文件移动失败: %@", fileError);
                    hasError = YES;
                }
            } else {
                hasError = YES;
            }
            dispatch_group_leave(group);
        }];
        [task resume];
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        if (hasError || tempFiles.count == 0) {
            showToast(@"下载失败", YES);
            return;
        }
        
        if (mediaType == MediaTypeAudio) {
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:tempFiles applicationActivities:nil];
            [activityVC setCompletionWithItemsHandler:^(UIActivityType activityType, BOOL completed, NSArray *returnedItems, NSError *error) {
                [tempFiles enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, BOOL *stop) {
                    [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
                }];
            }];
            [topViewController() presentViewController:activityVC animated:YES completion:nil];
        } else {
            saveMedia(tempFiles, mediaType);
        }
    });
}

// MARK: - HEIC 元数据注入（修正版）
static NSURL* _injectHEICMetadata(NSURL *imageURL, NSString *identifier) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)imageURL, NULL);
    if (!source) return nil;
    
    // 提前声明变量
    NSURL *heicURL = nil;
    CGImageDestinationRef destination = NULL;
    
    @try {
        // 创建目标路径
        heicURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic", [[NSUUID UUID] UUIDString]]]];
        
        // 创建目标写入器
        CFStringRef heicUTI = CFSTR("public.heic");
        destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)heicURL, heicUTI, 1, NULL);
        if (!destination) {
            NSLog(@"Failed to create image destination");
            return nil;
        }
        
        // 元数据构造
        NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
        NSDictionary *makerAppleDict = @{
            @"ContentIdentifier" : identifier,
            @"AssetIdentifier" : identifier
        };
        metadata[(__bridge NSString*)kCGImagePropertyMakerAppleDictionary] = makerAppleDict;
        
        // 保留原始元数据
        NSDictionary *sourceMetadata = (__bridge NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL);
        if (sourceMetadata) {
            [metadata addEntriesFromDictionary:sourceMetadata];
        }
        
        // 写入文件
        CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)metadata);
        if (!CGImageDestinationFinalize(destination)) {
            NSLog(@"Failed to finalize image destination");
            return nil;
        }
    }
    @finally {
        // 释放资源
        if (source) CFRelease(source);
        if (destination) CFRelease(destination);
    }
    
    return heicURL;
}

// MARK: - LivePhoto 视频处理（修正版）
static NSURL* _processLivePhotoVideo(NSURL *videoURL, NSString *identifier) {
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    if (!asset) return nil;
    
    // 创建元数据
    AVMutableMetadataItem *contentID = [[AVMutableMetadataItem alloc] init];
    contentID.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    contentID.key = @"com.apple.quicktime.content.identifier";
    contentID.value = identifier;
    contentID.dataType = (__bridge NSString*)kCMMetadataBaseDataType_UTF8;
    
    AVMutableMetadataItem *stillTime = [[AVMutableMetadataItem alloc] init];
    stillTime.keySpace = AVMetadataKeySpaceQuickTimeMetadata;
    stillTime.key = @"com.apple.quicktime.still-image-time";
    stillTime.value = @(0);
    stillTime.dataType = (__bridge NSString*)kCMMetadataBaseDataType_SInt32; // 必须为32位
    
    // 导出配置
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"livephoto_%@.mov", [[NSUUID UUID] UUIDString]]]];
    
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    exportSession.metadata = @[contentID, stillTime];
    
    // 强制视频轨道处理
    NSArray *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    if (videoTracks.count > 0) {
        AVAssetTrack *videoTrack = videoTracks[0];
        exportSession.timeRange = CMTimeRangeMake(kCMTimeZero, videoTrack.timeRange.duration);
    }
    
    // 同步导出
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        success = (exportSession.status == AVAssetExportSessionStatusCompleted);
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return success ? outputURL : nil;
}

// MARK: - 相册保存（优化版）
// 完全保持原有函数签名不变
static void saveMedia(NSArray<NSURL *> *files, MediaType mediaType) {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            showToast(@"需要相册访问权限", YES);
            return;
        }
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            // 新增 Live Photo 处理分支
            if (mediaType == MediaTypeLivePhoto && files.count >= 2) {
                // 提取图片和视频文件
                NSURL *imageURL = files[0];
                NSURL *videoURL = files[1];
                
                // 创建请求
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                
                // 添加图片资源 (强制指定 HEIC 类型)
                PHAssetResourceCreationOptions *photoOptions = [PHAssetResourceCreationOptions new];
                photoOptions.uniformTypeIdentifier = @"public.heic";
                [request addResourceWithType:PHAssetResourceTypePhoto fileURL:imageURL options:photoOptions];
                
                // 添加视频资源 (强制指定 MOV 类型)
                PHAssetResourceCreationOptions *videoOptions = [PHAssetResourceCreationOptions new];
                videoOptions.uniformTypeIdentifier = @"com.apple.quicktime-movie";
                [request addResourceWithType:PHAssetResourceTypePairedVideo fileURL:videoURL options:videoOptions];
                
            } else {
                // 原有其他媒体类型的处理逻辑保持不变
                for (NSURL *url in files) {
                    if (mediaType == MediaTypeVideo) {
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                    } else {
                        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
                    }
                }
            }
        } completionHandler:^(BOOL success, NSError *error) {
            // 清理临时文件
            [files enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, BOOL *stop) {
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    showToast(@"保存成功", NO);
                } else {
                    showToast([NSString stringWithFormat:@"保存失败: %@ (Code %@)", 
                             error.localizedDescription, 
                             error.localizedFailureReason ], YES);
                }
            });
        }];
    }];
}
