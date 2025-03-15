//
//  DYYY
//
//  Copyright (c) 2024 huami. All rights reserved.
//  Channel: @huamidev
//  Created on: 2024/10/04
//
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CityManager.h"
#import "AwemeHeaders.h"
#import "DYYYSettingViewController.h"
#import <Photos/Photos.h>


#define DYYY @"抖音DYYY"

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

// 媒体类型枚举
typedef NS_ENUM(NSUInteger, MediaType) {
    MediaTypeVideo,
    MediaTypeImage,
    MediaTypeAudio,
    MediaTypeLivePhoto
};


//去除开屏广告
%hook BDASplashControllerView

+ (id)alloc {
    return nil; // 直接返回空指针，阻止内存分配
}


%end




//拦截顶栏位置提示线
%hook AWEFeedMultiTabSelectedContainerView

- (void)setHidden:(BOOL)hidden {
    %orig(YES); // 强制始终设为 YES
}

%end


// 屏蔽关注页XX个直播
%hook AWEConcernSkylightCapsuleView

- (void)setHidden:(BOOL)hidden {
    %orig(YES); // 强制始终设为 YES
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0);
}

%end


%hook AWEAwemePlayVideoViewController

- (void)setIsAutoPlay:(BOOL)arg0 {
    float defaultSpeed = [[NSUserDefaults standardUserDefaults] floatForKey:@"DYYYDefaultSpeed"];
    
    if (defaultSpeed > 0 && defaultSpeed != 1) {
        [self setVideoControllerPlaybackRate:defaultSpeed];
    }
    
    %orig(arg0);
}

%end


%hook AWENormalModeTabBarGeneralPlusButton
+ (id)button {
    BOOL isHiddenJia = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenJia"];
    if (isHiddenJia) {
        return nil;
    }
    return %orig;
}
%end

%hook AWEFeedContainerContentView
- (void)setAlpha:(CGFloat)alpha {
    NSString *transparentValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYtopbartransparent"];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnablePure"]) {
        %orig(0.0);
        
        static dispatch_source_t timer = nil;
        static int attempts = 0;
        
        if (timer) {
            dispatch_source_cancel(timer);
            timer = nil;
        }
        
        void (^tryFindAndSetPureMode)(void) = ^{
            Class FeedTableVC = NSClassFromString(@"AWEFeedTableViewController");
            UIViewController *feedVC = nil;
            
            UIWindow *keyWindow = [UIApplication sharedApplication].windows.firstObject;
            if (keyWindow && keyWindow.rootViewController) {
                feedVC = [self findViewController:keyWindow.rootViewController ofClass:FeedTableVC];
                if (feedVC) {
                    [feedVC setValue:@YES forKey:@"pureMode"];
                    if (timer) {
                        dispatch_source_cancel(timer);
                        timer = nil;
                    }
                    attempts = 0;
                    return;
                }
            }
            
            attempts++;
            if (attempts >= 10) {
                if (timer) {
                    dispatch_source_cancel(timer);
                    timer = nil;
                }
                attempts = 0;
            }
        };
        
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 0.5 * NSEC_PER_SEC, 0);
        dispatch_source_set_event_handler(timer, tryFindAndSetPureMode);
        dispatch_resume(timer);
        
        tryFindAndSetPureMode();
        return;
    }
    
    if (transparentValue && transparentValue.length > 0) {
        CGFloat alphaValue = [transparentValue floatValue];
        if (alphaValue >= 0.0 && alphaValue <= 1.0) {
            %orig(alphaValue);
        } else {
            %orig(1.0);
        }
    } else {
        %orig(1.0);
    }
}

%new
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass {
    if (!vc) return nil;
    if ([vc isKindOfClass:targetClass]) return vc;
    
    for (UIViewController *childVC in vc.childViewControllers) {
        UIViewController *found = [self findViewController:childVC ofClass:targetClass];
        if (found) return found;
    }
    
    return [self findViewController:vc.presentedViewController ofClass:targetClass];
}
%end

%hook AWEDanmakuContentLabel
- (void)setTextColor:(UIColor *)textColor {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDanmuColor"]) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
        
        if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
            textColor = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0
                                        green:(arc4random_uniform(256)) / 255.0
                                         blue:(arc4random_uniform(256)) / 255.0
                                        alpha:CGColorGetAlpha(textColor.CGColor)];
            self.layer.shadowOffset = CGSizeZero;
            self.layer.shadowOpacity = 0.0;
        } else if ([danmuColor hasPrefix:@"#"]) {
            textColor = [self colorFromHexString:danmuColor baseColor:textColor];
            self.layer.shadowOffset = CGSizeZero;
            self.layer.shadowOpacity = 0.0;
        } else {
            textColor = [self colorFromHexString:@"#FFFFFF" baseColor:textColor];
        }
    }

    %orig(textColor);
}

%new
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    if ([hexString length] != 6) {
        return [baseColor colorWithAlphaComponent:1];
    }
    unsigned int red, green, blue;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:CGColorGetAlpha(baseColor.CGColor)];
}
%end

%hook AWEDanmakuItemTextInfo
- (void)setDanmakuTextColor:(id)arg1 {
//    NSLog(@"Original Color: %@", arg1);
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYEnableDanmuColor"]) {
        NSString *danmuColor = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYdanmuColor"];
        
        if ([danmuColor.lowercaseString isEqualToString:@"random"] || [danmuColor.lowercaseString isEqualToString:@"#random"]) {
            arg1 = [UIColor colorWithRed:(arc4random_uniform(256)) / 255.0
                                   green:(arc4random_uniform(256)) / 255.0
                                    blue:(arc4random_uniform(256)) / 255.0
                                   alpha:1.0];
//            NSLog(@"Random Color: %@", arg1);
        } else if ([danmuColor hasPrefix:@"#"]) {
            arg1 = [self colorFromHexStringForTextInfo:danmuColor];
//            NSLog(@"Custom Hex Color: %@", arg1);
        } else {
            arg1 = [self colorFromHexStringForTextInfo:@"#FFFFFF"];
//            NSLog(@"Default White Color: %@", arg1);
        }
    }

    %orig(arg1);
}

%new
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    if ([hexString length] != 6) {
        return [UIColor whiteColor];
    }
    unsigned int red, green, blue;
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(0, 2)]] scanHexInt:&red];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(2, 2)]] scanHexInt:&green];
    [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(4, 2)]] scanHexInt:&blue];
    return [UIColor colorWithRed:(red / 255.0) green:(green / 255.0) blue:(blue / 255.0) alpha:1.0];
}
%end

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig(frame);
    if (window) {
        UILongPressGestureRecognizer *doubleFingerLongPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleFingerLongPressGesture:)];
        doubleFingerLongPressGesture.numberOfTouchesRequired = 2;
        [window addGestureRecognizer:doubleFingerLongPressGesture];
    }
    return window;
}

%new
- (void)handleDoubleFingerLongPressGesture:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *rootViewController = self.rootViewController;
        if (rootViewController) {
            UIViewController *settingVC = [[NSClassFromString(@"DYYYSettingViewController") alloc] init];
            
            if (settingVC) {
                if (@available(iOS 15.0, *) && UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) {
                    settingVC.modalPresentationStyle = UIModalPresentationPageSheet;
                } else {
                    settingVC.modalPresentationStyle = UIModalPresentationFullScreen;
                    
                    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
                    [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
                    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
                    
                    [settingVC.view addSubview:closeButton];
                    
                    [NSLayoutConstraint activateConstraints:@[
                        [closeButton.trailingAnchor constraintEqualToAnchor:settingVC.view.trailingAnchor constant:-10],
                        [closeButton.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:40],
                        [closeButton.widthAnchor constraintEqualToConstant:80],
                        [closeButton.heightAnchor constraintEqualToConstant:40]
                    ]];
                    
                    [closeButton addTarget:self action:@selector(closeSettings:) forControlEvents:UIControlEventTouchUpInside];
                }
                
                UIView *handleBar = [[UIView alloc] init];
                handleBar.backgroundColor = [UIColor whiteColor];
                handleBar.layer.cornerRadius = 2.5;
                handleBar.translatesAutoresizingMaskIntoConstraints = NO;
                [settingVC.view addSubview:handleBar];
                
                [NSLayoutConstraint activateConstraints:@[
                    [handleBar.centerXAnchor constraintEqualToAnchor:settingVC.view.centerXAnchor],
                    [handleBar.topAnchor constraintEqualToAnchor:settingVC.view.topAnchor constant:8],
                    [handleBar.widthAnchor constraintEqualToConstant:40],
                    [handleBar.heightAnchor constraintEqualToConstant:5]
                ]];
                
                [rootViewController presentViewController:settingVC animated:YES completion:nil];
            }
        }
    }
}

%new
- (void)closeSettings:(UIButton *)button {
    [button.superview.window.rootViewController dismissViewControllerAnimated:YES completion:nil];
}
%end


%hook AWEFeedLiveMarkView
- (void)setHidden:(BOOL)hidden {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"]) {
        hidden = YES;
    }

    %orig(hidden);
}
%end

%hook AWELongVideoControlModel
- (bool)allowDownload {
    return YES;
}
%end

%hook AWELongVideoControlModel
- (long long)preventDownloadType {
    return 0;
}
%end

%hook AWELandscapeFeedEntryView
- (void)setHidden:(BOOL)hidden {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenEntry"]) {
        hidden = YES;
    }
    
    %orig(hidden);
}
%end

%hook AWEAwemeModel

- (id)initWithDictionary:(id)arg1 error:(id *)arg2 {
    id orig = %orig;
    return self.isAds ? nil : orig; 
}

- (id)init {
    id orig = %orig;
    return self.isAds ? nil : orig;
}

- (void)live_callInitWithDictyCategoryMethod:(id)arg1 {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"]) {
        return;
    }
    %orig;
}

+ (id)liveStreamURLJSONTransformer {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"] ? nil : %orig;
}

+ (id)relatedLiveJSONTransformer {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"] ? nil : %orig;
}

+ (id)rawModelFromLiveRoomModel:(id)arg1 {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"] ? nil : %orig;
}

+ (id)aweLiveRoom_subModelPropertyKey {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisSkipLive"] ? nil : %orig;
}

%end

%hook AWEPlayInteractionViewController
- (void)viewDidLayoutSubviews {
    %orig;
    
    if (![self.parentViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
        return;
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        CGRect frame = self.view.frame;
        frame.size.height = self.view.superview.frame.size.height - 83;
        self.view.frame = frame;
    }
    
    BOOL shouldHideSubview = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"] || 
                             [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"];
    
    if (shouldHideSubview) {
        for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:[UIView class]] && 
                subview.backgroundColor && 
                CGColorEqualToColor(subview.backgroundColor.CGColor, [UIColor blackColor].CGColor)) {
                subview.hidden = YES;
            }
        }
    }
}
%end


%hook AWEStoryContainerCollectionView
- (void)layoutSubviews {
    %orig;
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]]) {
            UIView *nextResponder = (UIView *)subview.nextResponder;
            if ([nextResponder isKindOfClass:%c(AWEPlayInteractionViewController)]) {
                UIViewController *awemeBaseViewController = [nextResponder valueForKey:@"awemeBaseViewController"];
                if (![awemeBaseViewController isKindOfClass:%c(AWEFeedCellViewController)]) {
                    return;
                }
            }
            
            CGRect frame = subview.frame;
            if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
                frame.size.height = subview.superview.frame.size.height - 83;
                subview.frame = frame;
            }
        }
    }
}
%end

%hook AWEFeedTableView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        CGRect frame = self.frame;
        frame.size.height = self.superview.frame.size.height;
        self.frame = frame;
    }
}
%end

%hook AWEPlayInteractionProgressContainerView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {
                [subview setBackgroundColor:[UIColor clearColor]];
            }
        }
    }
}
%end

%hook UIView

- (void)setFrame:(CGRect)frame {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        %orig;
        return;
    }
    
    UIViewController *vc = [self firstAvailableUIViewController];
    if ([vc isKindOfClass:%c(AWEAwemePlayVideoViewController)]) {
        if (frame.origin.x != 0 || frame.origin.y != 0) {
            return;
        }
    }
    %orig;
}

%end

%hook AWEBaseListViewController
- (void)viewDidLayoutSubviews {
    %orig;
    [self applyBlurEffectIfNeeded];
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    [self applyBlurEffectIfNeeded];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    [self applyBlurEffectIfNeeded];
}

%new
- (void)applyBlurEffectIfNeeded {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"] && 
        [self isKindOfClass:NSClassFromString(@"AWECommentPanelContainerSwiftImpl.CommentContainerInnerViewController")]) {
        
        self.view.backgroundColor = [UIColor clearColor];
        for (UIView *subview in self.view.subviews) {
            if (![subview isKindOfClass:[UIVisualEffectView class]]) {
                subview.backgroundColor = [UIColor clearColor];
            }
        }
        
        UIVisualEffectView *existingBlurView = nil;
        for (UIView *subview in self.view.subviews) {
            if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 999) {
                existingBlurView = (UIVisualEffectView *)subview;
                break;
            }
        }
        
        BOOL isDarkMode = YES;
        
        UILabel *commentLabel = [self findCommentLabel:self.view];
        if (commentLabel) {
            UIColor *textColor = commentLabel.textColor;
            CGFloat red, green, blue, alpha;
            [textColor getRed:&red green:&green blue:&blue alpha:&alpha];
            
            if (red > 0.7 && green > 0.7 && blue > 0.7) {
                isDarkMode = YES;
            } else if (red < 0.3 && green < 0.3 && blue < 0.3) {
                isDarkMode = NO;
            }
        }
        
        UIBlurEffectStyle blurStyle = isDarkMode ? UIBlurEffectStyleDark : UIBlurEffectStyleLight;
        
        if (!existingBlurView) {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
            UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurEffectView.frame = self.view.bounds;
            blurEffectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            blurEffectView.alpha = 0.98;
            blurEffectView.tag = 999;
            
            UIView *overlayView = [[UIView alloc] initWithFrame:self.view.bounds];
            CGFloat alpha = isDarkMode ? 0.3 : 0.1;
            overlayView.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:alpha];
            overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [blurEffectView.contentView addSubview:overlayView];
            
            [self.view insertSubview:blurEffectView atIndex:0];
        } else {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:blurStyle];
            [existingBlurView setEffect:blurEffect];
            
            for (UIView *subview in existingBlurView.contentView.subviews) {
                if (subview.tag != 999) {
                    CGFloat alpha = isDarkMode ? 0.3 : 0.1;
                    subview.backgroundColor = [UIColor colorWithWhite:(isDarkMode ? 0 : 1) alpha:alpha];
                }
            }
            
            [self.view insertSubview:existingBlurView atIndex:0];
        }
    }
}

%new
- (UILabel *)findCommentLabel:(UIView *)view {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (label.text && ([label.text hasSuffix:@"条评论"] || [label.text hasSuffix:@"暂无评论"])) {
            return label;
        }
    }
    
    for (UIView *subview in view.subviews) {
        UILabel *result = [self findCommentLabel:subview];
        if (result) {
            return result;
        }
    }
    
    return nil;
}
%end

%hook AFDFastSpeedView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {
                [subview setBackgroundColor:[UIColor clearColor]];
            }
        }
    }
}
%end

%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    UIViewController *vc = [self firstAvailableUIViewController];
    
    if ([vc isKindOfClass:%c(AWEPlayInteractionViewController)] && alpha > 0) {
        NSString *transparentValue = [[NSUserDefaults standardUserDefaults] stringForKey:@"DYYYGlobalTransparency"];
        if (transparentValue.length > 0) {
            CGFloat alphaValue = transparentValue.floatValue;
            if (alphaValue >= 0.0 && alphaValue <= 1.0) {
                %orig(alphaValue);
                return;
            }
        }
    }
    %orig;
}

%new
- (UIViewController *)firstAvailableUIViewController {
    UIResponder *responder = [self nextResponder];
    while (responder != nil) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
        responder = [responder nextResponder];
    }
    return nil;
}

%end

%hook AWENormalModeTabBarBadgeContainerView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenBottomDot"]) {
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                [subview setHidden:YES];
            }
        }
    }
}

%end

%hook AWELeftSideBarEntranceView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenSidebarDot"]) {
        for (UIView *subview in [self subviews]) {
            if ([subview isKindOfClass:NSClassFromString(@"DUXBadge")]) {
                subview.hidden = YES;
            }
        }
    }
}

%end

%hook AWEFeedVideoButton

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"点赞"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLikeButton"]) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"评论"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCommentButton"]) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"分享"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShareButton"]) {
            [self removeFromSuperview];
            return;
        }
    } else if ([accessibilityLabel isEqualToString:@"收藏"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideCollectButton"]) {
            [self removeFromSuperview];
            return;
        }
    }

}

%end

%hook AWEMusicCoverButton

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"音乐详情"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMusicButton"]) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEPlayInteractionListenFeedView
- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMusicButton"]) {
        [self removeFromSuperview];
        return;
    }
}
%end

%hook AWEPlayInteractionFollowPromptView

- (void)layoutSubviews {
    %orig;

    NSString *accessibilityLabel = self.accessibilityLabel;

    if ([accessibilityLabel isEqualToString:@"关注"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"]) {
            [self removeFromSuperview];
            return;
        }
    }
}

%end

%hook AWEAdAvatarView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideAvatarButton"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWENormalModeTabBar

- (void)layoutSubviews {
    %orig;

    BOOL hideShop = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideShopButton"];
    BOOL hideMsg = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMessageButton"];
    BOOL hideFri = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideFriendsButton"];
    
    NSMutableArray *visibleButtons = [NSMutableArray array];
    Class generalButtonClass = %c(AWENormalModeTabBarGeneralButton);
    Class plusButtonClass = %c(AWENormalModeTabBarGeneralPlusButton);
    
    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:generalButtonClass] && ![subview isKindOfClass:plusButtonClass]) continue;
        
        NSString *label = subview.accessibilityLabel;
        BOOL shouldHide = NO;
        
        if ([label isEqualToString:@"商城"]) {
            shouldHide = hideShop;
        } else if ([label containsString:@"消息"]) {
            shouldHide = hideMsg;
        } else if ([label containsString:@"朋友"]) {
            shouldHide = hideFri;
        }
        
        if (!shouldHide) {
            [visibleButtons addObject:subview];
        } else {
            [subview removeFromSuperview];
        }
    }

    [visibleButtons sortUsingComparator:^NSComparisonResult(UIView* a, UIView* b) {
        return [@(a.frame.origin.x) compare:@(b.frame.origin.x)];
    }];

    CGFloat totalWidth = self.bounds.size.width;
    CGFloat buttonWidth = totalWidth / visibleButtons.count;
    
    for (NSInteger i = 0; i < visibleButtons.count; i++) {
        UIView *button = visibleButtons[i];
        button.frame = CGRectMake(i * buttonWidth, button.frame.origin.y, buttonWidth, button.frame.size.height);
    }

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHiddenBottomBg"] || [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"]) {
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {
                BOOL hasImageView = NO;
                for (UIView *childView in subview.subviews) {
                    if ([childView isKindOfClass:[UIImageView class]]) {
                        hasImageView = YES;
                        break;
                    }
                }
                
                if (hasImageView) {
                    subview.hidden = YES;
                    break;
                }
            }
        }
    }
}

%end

%hook UITextInputTraits
- (void)setKeyboardAppearance:(UIKeyboardAppearance)appearance {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        %orig(UIKeyboardAppearanceDark);
    }else {
        %orig;
    }
}
%end

%hook AWECommentMiniEmoticonPanelView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook AWECommentPublishGuidanceView

- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UICollectionView class]]) {
                subview.backgroundColor = [UIColor colorWithRed:115/255.0 green:115/255.0 blue:115/255.0 alpha:1.0];
            }
        }
    }
}
%end

%hook UIView
- (void)layoutSubviews {
    %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:NSClassFromString(@"AWECommentInputViewSwiftImpl.CommentInputViewMiddleContainer")]) {
                for (UIView *innerSubview in subview.subviews) {
                    if ([innerSubview isKindOfClass:[UIView class]]) {
                        innerSubview.backgroundColor = [UIColor colorWithRed:31/255.0 green:33/255.0 blue:35/255.0 alpha:1.0];
                        break;
                    }
                }
            }
            if ([subview isKindOfClass:NSClassFromString(@"AWEIMEmoticonPanelBoxView")]) {
                subview.backgroundColor = [UIColor colorWithRed:33/255.0 green:33/255.0 blue:33/255.0 alpha:1.0];
            }
        }
    }
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableFullScreen"] || 
    [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableCommentBlur"]) {
        NSString *className = NSStringFromClass([self class]);
        if ([className isEqualToString:@"AWECommentInputViewSwiftImpl.CommentInputContainerView"]) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIView class]] && subview.backgroundColor) {
                    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                    [subview.backgroundColor getRed:&red green:&green blue:&blue alpha:&alpha];
                    
                    if ((red == 22/255.0 && green == 22/255.0 && blue == 22/255.0) || 
                        (red == 1.0 && green == 1.0 && blue == 1.0)) {
                        subview.backgroundColor = [UIColor clearColor];
                    }
                }
            }
        }
    }
}
%end

%hook UILabel

- (void)setText:(NSString *)text {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        if ([text hasPrefix:@"善语"] || [text hasPrefix:@"友爱评论"] || [text hasPrefix:@"回复"]) {
            self.textColor = [UIColor colorWithRed:125/255.0 green:125/255.0 blue:125/255.0 alpha:0.6];
        }
    }
    %orig;
}

%end

%hook UIButton

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    NSString *label = self.accessibilityLabel;
//    NSLog(@"Label -> %@",accessibilityLabel);
    if ([label isEqualToString:@"表情"] || [label isEqualToString:@"at"] || [label isEqualToString:@"图片"] || [label isEqualToString:@"键盘"]) {
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
            
            UIImage *whiteImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            
            self.tintColor = [UIColor whiteColor];
            
            %orig(whiteImage, state);
        }else {
            %orig(image, state);
        }
    } else {
        %orig(image, state);
    }
}

%end

%hook AWETextViewInternal

- (void)drawRect:(CGRect)rect {
    %orig(rect);
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        self.textColor = [UIColor whiteColor];
    }
}

- (double)lineSpacing {
    double r = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisDarkKeyBoard"]) {
        
        self.textColor = [UIColor whiteColor];
    }
    return r;
}

%end

%hook AWEPlayInteractionUserAvatarElement

- (void)onFollowViewClicked:(UITapGestureRecognizer *)gesture {
//    NSLog(@"拦截到关注按钮点击");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYfollowTips"]) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:@"关注确认"
                                                  message:@"是否确认关注？"
                                                  preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *cancelAction = [UIAlertAction
                                           actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                           handler:nil];
            
            UIAlertAction *confirmAction = [UIAlertAction
                                            actionWithTitle:@"确定"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                %orig(gesture);
            }];
            
            [alertController addAction:cancelAction];
            [alertController addAction:confirmAction];
            
            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alertController animated:YES completion:nil];
        });
    }else {
        %orig;
    }
}

%end

%hook AWEFeedVideoButton
- (id)touchUpInsideBlock {
    id r = %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYcollectTips"] && [self.accessibilityLabel isEqualToString:@"收藏"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController
                                                  alertControllerWithTitle:@"收藏确认"
                                                  message:@"是否[确认/取消]收藏？"
                                                  preferredStyle:UIAlertControllerStyleAlert];

            UIAlertAction *cancelAction = [UIAlertAction
                                           actionWithTitle:@"取消"
                                           style:UIAlertActionStyleCancel
                                           handler:nil];

            UIAlertAction *confirmAction = [UIAlertAction
                                            actionWithTitle:@"确定"
                                            style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
                if (r && [r isKindOfClass:NSClassFromString(@"NSBlock")]) {
                    ((void(^)(void))r)();
                }
            }];

            [alertController addAction:cancelAction];
            [alertController addAction:confirmAction];

            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alertController animated:YES completion:nil];
        });

        return nil; // 阻止原始 block 立即执行
    }

    return r;
}
%end

%hook AWEFeedProgressSlider

- (void)setAlpha:(CGFloat)alpha {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisShowSchedule"]) {
        alpha = 1.0;
        %orig(alpha);
    }else {
        %orig;
    }
}

%end

%hook AWENormalModeTabBarTextView

- (void)layoutSubviews {
    %orig;
    
    NSString *indexTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYIndexTitle"];
    NSString *friendsTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYFriendsTitle"];
    NSString *msgTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYMsgTitle"];
    NSString *selfTitle = [[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYSelfTitle"];
    
    for (UIView *subview in [self subviews]) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"首页"]) {
                if (indexTitle.length > 0) {
                    [label setText:indexTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"朋友"]) {
                if (friendsTitle.length > 0) {
                    [label setText:friendsTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"消息"]) {
                if (msgTitle.length > 0) {
                    [label setText:msgTitle];
                    [self setNeedsLayout];
                }
            }
            if ([label.text isEqualToString:@"我"]) {
                if (selfTitle.length > 0) {
                    [label setText:selfTitle];
                    [self setNeedsLayout];
                }
            }
        }
    }
}
%end

%hook AWEFeedIPhoneAutoPlayManager

- (BOOL)isAutoPlayOpen {
    BOOL r = %orig;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableAutoPlay"]) {
        return YES;
    }
    return r;
}

%end

%hook AWEHPTopTabItemModel

- (void)setChannelID:(NSString *)channelID {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    if (([channelID isEqualToString:@"homepage_hot_container"] && [defaults boolForKey:@"DYYYHideHotContainer"]) ||
        ([channelID isEqualToString:@"homepage_follow"] && [defaults boolForKey:@"DYYYHideFollow"]) ||
        ([channelID isEqualToString:@"homepage_mediumvideo"] && [defaults boolForKey:@"DYYYHideMediumVideo"]) ||
        ([channelID isEqualToString:@"homepage_mall"] && [defaults boolForKey:@"DYYYHideMall"]) ||
        ([channelID isEqualToString:@"homepage_nearby"] && [defaults boolForKey:@"DYYYHideNearby"]) ||
        ([channelID isEqualToString:@"homepage_groupon"] && [defaults boolForKey:@"DYYYHideGroupon"]) ||
        ([channelID isEqualToString:@"homepage_tablive"] && [defaults boolForKey:@"DYYYHideTabLive"]) ||
        ([channelID isEqualToString:@"homepage_pad_hot"] && [defaults boolForKey:@"DYYYHidePadHot"]) ||
        ([channelID isEqualToString:@"homepage_hangout"] && [defaults boolForKey:@"DYYYHideHangout"])) {
        return;
    }
    %orig;
}

%end

%hook AWEPlayInteractionTimestampElement
- (id)timestampLabel {
    UILabel *label = %orig;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"]) {
        NSString *text = label.text;
        NSString *cityCode = self.model.cityCode;
        
        if (cityCode.length > 0) {
            NSString *cityName = [CityManager.sharedInstance getCityNameWithCode:cityCode] ?: @"";
            NSString *provinceName = [CityManager.sharedInstance getProvinceNameWithCode:cityCode] ?: @"";
            
            if (cityName.length > 0 && ![text containsString:cityName]) {
                if (!self.model.ipAttribution) {
                    BOOL isDirectCity = [provinceName isEqualToString:cityName] || 
                                       ([cityCode hasPrefix:@"11"] || [cityCode hasPrefix:@"12"] || 
                                        [cityCode hasPrefix:@"31"] || [cityCode hasPrefix:@"50"]);
                    
                    if (isDirectCity) {
                        label.text = [NSString stringWithFormat:@"%@  IP属地：%@", text, cityName];
                    } else {
                        label.text = [NSString stringWithFormat:@"%@  IP属地：%@ %@", text, provinceName, cityName];
                    }
                } else {
                    BOOL isDirectCity = [provinceName isEqualToString:cityName] || 
                                       ([cityCode hasPrefix:@"11"] || [cityCode hasPrefix:@"12"] || 
                                        [cityCode hasPrefix:@"31"] || [cityCode hasPrefix:@"50"]);
                    
                    BOOL containsProvince = [text containsString:provinceName];
                    
                    if (isDirectCity && containsProvince) {
                        label.text = text;
                    } else if (containsProvince) {
                        label.text = [NSString stringWithFormat:@"%@ %@", text, cityName];
                    } else {
                        label.text = text;
                    }
                }
            }
        }
    }
    return label;
}

+(BOOL)shouldActiveWithData:(id)arg1 context:(id)arg2{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisEnableArea"];
}

%end

%hook AWEFeedRootViewController

- (BOOL)prefersStatusBarHidden {
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYisHideStatusbar"]){
        return YES;
    } else {
        return %orig;
    }
}

%end


%hook AWEHPDiscoverFeedEntranceView
- (void)setAlpha:(CGFloat)alpha {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideDiscover"]) {
        alpha = 0;
        %orig(alpha);
   }else {
       %orig;
    }
}

%end

%hook AWEUserWorkCollectionViewComponentCell

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMyPage"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEFeedRefreshFooter

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMyPage"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWERLSegmentView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideMyPage"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEFeedTemplateAnchorView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideLocation"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEPlayInteractionSearchAnchorView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideInteractionSearch"]) {
        [self removeFromSuperview];
        return;
    }
}

%end

%hook AWEAwemeMusicInfoView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideQuqishuiting"]) {
        self.hidden = YES;
    }
}

%end

%hook AWETemplateHotspotView

- (void)layoutSubviews {
    %orig;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYHideHotspot"]) {
        [self removeFromSuperview];
        return;
    }
}

%end






#import <CoreServices/CoreServices.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>








// MARK: - 前置声明
static void saveMedia(NSArray<NSURL *> *mediaURLs, MediaType mediaType);
static void downloadMedia(NSArray<NSURL *> *urls, MediaType mediaType);
static NSString* mimeTypeToExtension(NSString *mimeType, MediaType mediaType);
static UIViewController* topViewController();
static NSURL* _processLivePhotoVideo(NSURL *videoURL, NSString *identifier);
static void showToast(NSString *message, BOOL isError);




// MARK: - Hook实现
%hook AWELongPressPanelTableViewController

- (NSArray *)dataArray {
    NSArray *originalArray = %orig;
    BOOL enableDownload = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYlongpressdownload"];
    if (!enableDownload) return originalArray;
    
    AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    newGroup.groupType = 0;
    
    AWELongPressPanelBaseViewModel *tempModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
    AWEAwemeModel *aweme = tempModel.awemeModel;
    
    NSMutableArray *customActions = [NSMutableArray array];
    
    // 处理媒体类型
    if (aweme.awemeType == 68) { // 图集类型
        AWEImageAlbumImageModel *currentImage = nil;
        if (aweme.albumImages.count > aweme.currentImageIndex) {
            currentImage = aweme.albumImages[aweme.currentImageIndex];
        }
        
        // 当前图片处理
        if (currentImage) {
            if (aweme.albumImages.firstObject.clipVideo) { // 实况照片
                [customActions addObject:@{
                    @"title": @"下载实况照片",
                    @"type": @(MediaTypeLivePhoto),
                    @"customIcons": @"ic_star_outlined_12",
                    @"action": ^{
                        NSMutableArray *urls = [NSMutableArray array];
                        if (aweme.albumImages.firstObject.urlList.count > 0) {
                            [urls addObject:[NSURL URLWithString:aweme.albumImages.firstObject.urlList.firstObject]];
                        }
                        if (aweme.albumImages.firstObject.clipVideo.h264URL.originURLList.count > 0) {
                            NSString *videoURL = aweme.albumImages.firstObject.clipVideo.h264URL.originURLList.firstObject;
                            [urls addObject:[NSURL URLWithString:videoURL]];
                        }
                        if (urls.count == 2) {
                            downloadMedia(urls, MediaTypeLivePhoto);
                        }
                    }
                }];
            } else { // 普通图片
                [customActions addObject:@{
                    @"title": @"下载当前图片",
                    @"type": @(MediaTypeImage),
                    @"customIcons": @"ic_star_outlined_12",
                    @"action": ^{
                        if (currentImage.urlList.count > 0) {
                            NSURL *url = [NSURL URLWithString:currentImage.urlList.firstObject];
                            downloadMedia(@[url], MediaTypeImage);
                        }
                    }
                }];
            }
        }
        
        // 下载全部图片（排除实况视频部分）
        [customActions addObject:@{
            @"title": @"下载全部图片",
            @"type": @(MediaTypeImage),
            @"customIcons": @"ic_star_outlined_12",
            @"action": ^{
                NSMutableArray *urls = [NSMutableArray array];
                for (AWEImageAlbumImageModel *image in aweme.albumImages) {
                    if (image.type != 3 && image.urlList.count > 0) {
                        [urls addObject:[NSURL URLWithString:image.urlList.firstObject]];
                    }
                }
                if (urls.count > 0) {
                    downloadMedia(urls, MediaTypeImage);
                }
            }
        }];
    } 
    else { // 视频类型
        [customActions addObject:@{
            @"title": @"下载视频",
            @"type": @(MediaTypeVideo),
            @"customIcons": @"ic_star_outlined_12",
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
            @"customIcons": @"ic_star_outlined_12",
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
        vm.actionType = 100 + [customActions indexOfObject:action];
        vm.showIfNeed = YES;
        vm.duxIconName = action[@"icon"];
        vm.action = action[@"action"];
        [viewModels addObject:vm];
    }];
    
    newGroup.groupArr = viewModels;
    return [@[newGroup] arrayByAddingObjectsFromArray:originalArray ?: @[]];
}

%end

// MARK: - 下载核心逻辑
static void downloadMedia(NSArray<NSURL *> *urls, MediaType mediaType) {
    dispatch_group_t group = dispatch_group_create();
    NSMutableArray<NSURL *> *tempFiles = [NSMutableArray array];
    __block BOOL hasError = NO;
    __block NSString *livePhotoID = [[NSUUID UUID] UUIDString];
    
    for (NSURL *url in urls) {
        dispatch_group_enter(group);
        
        NSURLSessionDownloadTask *task = [[NSURLSession sharedSession] downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if (!error && location) {
                NSString *extension = mimeTypeToExtension(response.MIMEType, mediaType);
                NSURL *processedURL = location;
                
                // 处理LivePhoto视频元数据
                if (mediaType == MediaTypeLivePhoto && [extension isEqualToString:@"mov"]) {
                    NSURL *newVideoURL = _processLivePhotoVideo(location, livePhotoID);
                    if (newVideoURL) {
                        processedURL = newVideoURL;
                        extension = @"mov";
                    } else {
                        hasError = YES;
                    }
                }
                
                NSURL *tempDir = [NSURL fileURLWithPath:NSTemporaryDirectory()];
                NSURL *destURL = [tempDir URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], extension]];
                
                NSError *fileError;
                if ([[NSFileManager defaultManager] moveItemAtURL:processedURL toURL:destURL error:&fileError]) {
                    @synchronized(tempFiles) {
                        [tempFiles addObject:destURL];
                    }
                } else {
                    NSLog(@"文件移动失败: %@", fileError);
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

// MARK: - 文件类型处理
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

// MARK: - LivePhoto视频元数据处理
static NSURL* _processLivePhotoVideo(NSURL *videoURL, NSString *identifier) {
    AVAsset *asset = [AVAsset assetWithURL:videoURL];
    
    AVMutableMetadataItem *contentID = [[AVMutableMetadataItem alloc] init];
    contentID.identifier = AVMetadataIdentifierQuickTimeMetadataContentIdentifier;
    contentID.value = identifier;
    contentID.dataType = (__bridge NSString *)kCMMetadataBaseDataType_UTF8;
    
    AVMutableMetadataItem *stillTime = [[AVMutableMetadataItem alloc] init];
    stillTime.identifier = AVMetadataIdentifierQuickTimeMetadataDisplayName;
    stillTime.value = @(0);
    stillTime.dataType = (__bridge NSString *)kCMMetadataBaseDataType_SInt8;
    
    AVAssetExportSession *exportSession = [AVAssetExportSession exportSessionWithAsset:asset presetName:AVAssetExportPresetPassthrough];
    NSURL *outputURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov", [[NSUUID UUID] UUIDString]]]];
    
    exportSession.outputURL = outputURL;
    exportSession.outputFileType = AVFileTypeQuickTimeMovie;
    exportSession.metadata = @[contentID, stillTime];
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSError *exportError = nil;
    
    [exportSession exportAsynchronouslyWithCompletionHandler:^{
        if (exportSession.status != AVAssetExportSessionStatusCompleted) {
            exportError = exportSession.error;
	    showToast([NSString stringWithFormat:@"视频元数据注入失败: %@", exportError], YES);
        }
        dispatch_semaphore_signal(sema);
    }];
    
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    return exportError ? nil : outputURL;
}

// MARK: - 相册保存
static void saveMedia(NSArray<NSURL *> *files, MediaType mediaType) {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status != PHAuthorizationStatusAuthorized) {
            dispatch_async(dispatch_get_main_queue(), ^{
                showToast(@"需要相册访问权限", YES);
            });
            return;
        }
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            if (mediaType == MediaTypeLivePhoto && files.count >= 2) {
                PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
                
                PHAssetResourceCreationOptions *photoOptions = [PHAssetResourceCreationOptions new];
                photoOptions.shouldMoveFile = YES;
                
                PHAssetResourceCreationOptions *videoOptions = [PHAssetResourceCreationOptions new];
                videoOptions.shouldMoveFile = YES;
                
                [request addResourceWithType:PHAssetResourceTypePhoto
                                    fileURL:files[0]
                                   options:photoOptions];
                [request addResourceWithType:PHAssetResourceTypePairedVideo
                                    fileURL:files[1]
                                   options:videoOptions];
            } else {
                for (NSURL *url in files) {
                    if (mediaType == MediaTypeVideo) {
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                    } else {
                        [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:url];
                    }
                }
            }
        } completionHandler:^(BOOL success, NSError *error) {
            [files enumerateObjectsUsingBlock:^(NSURL *url, NSUInteger idx, BOOL *stop) {
                [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
            }];
            
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSString *typeStr = @"内容";
                    switch (mediaType) {
                        case MediaTypeLivePhoto: typeStr = @"实况照片"; break;
                        case MediaTypeVideo: typeStr = @"视频"; break;
                        case MediaTypeImage: typeStr = @"图片"; break;
                        default: break;
                    }
                    showToast([NSString stringWithFormat:@"%@保存成功", typeStr], NO);
                } else {
                    showToast([NSString stringWithFormat:@"保存失败: %@", error.localizedDescription], YES);
                }
            });
        }];
    }];
}

// MARK: - 辅助方法
static UIViewController* topViewController() {
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    while (rootVC.presentedViewController) {
        rootVC = rootVC.presentedViewController;
    }
    return rootVC;
}

@interface DUXToast : UIView
+ (void)showText:(id)arg1 withCenterPoint:(CGPoint)arg2;
+ (void)showText:(id)arg1;
@end


CGPoint topCenter = CGPointMake(
    CGRectGetMidX([UIScreen mainScreen].bounds),
    CGRectGetMinY([UIScreen mainScreen].bounds) + 90
);


void showToast(NSString *text, BOOL isError) {
    // 触觉反馈（支持iOS 10+）
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackStyle style = isError ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium;
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:style];
        [generator prepare];
        [generator impactOccurred];
    }
    
    // 显示Toast（主线程安全）
    dispatch_async(dispatch_get_main_queue(), ^{
        [%c(DUXToast) showText:text withCenterPoint:topCenter];
    });
}

%ctor {
    %init(AWELongPressPanelTableViewController = objc_getClass("AWELongPressPanelTableViewController"));
}
