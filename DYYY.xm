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








#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVFoundation/AVFoundation.h>

// 假设这些类在其他头文件中定义，需要根据实际情况引入

// 定义媒体类型枚举
typedef NS_ENUM(NSInteger, MediaType) {
    MediaTypeImage,
    MediaTypeVideo,
    MediaTypeAudio,
    MediaTypeLivePhoto
};

// 显示提示信息的函数
static void showToast(NSString *text, BOOL isError) {
    if (@available(iOS 10.0, *)) {
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:isError ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium];
        [generator impactOccurred];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [%c(DUXToast) showText:text withCenterPoint:CGPointMake(CGRectGetMidX([UIScreen mainScreen].bounds), 100)];
    });
}

// 下载媒体的函数
static void saveMedia(NSURL *mediaURL, MediaType mediaType) {
    if (!mediaURL) {
        // 修正 showToast 调用，添加第二个参数
        showToast(@"媒体URL为空～", YES);
        return;
    }
    if (mediaType == MediaTypeAudio) {
        // 修正 showToast 调用，添加第二个参数
        showToast(@"音频暂不支持保存到相册", YES);
        return;
    }
    
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                if (mediaType == MediaTypeVideo) {
                    [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:mediaURL];
                } else if (mediaType == MediaTypeImage) {
                    UIImage *image = [UIImage imageWithContentsOfFile:mediaURL.path];
                    if (image) {
                        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
                    } else {
                        NSLog(@"[DYYY] 无法从URL加载图片: %@", mediaURL);
                    }
                }
            } completionHandler:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success) {
                        // 修正 showToast 调用，添加第二个参数
                        showToast([NSString stringWithFormat:@"%@已保存到相册", mediaType == MediaTypeVideo ? @"视频" : @"图片"], NO);
                    } else {
                        // 修正 showToast 调用，添加第二个参数
                        showToast([NSString stringWithFormat:@"保存失败: %@", error.localizedDescription], YES);
                    }
                    [[NSFileManager defaultManager] removeItemAtURL:mediaURL error:nil];
                });
            }];
        } else {
            // 修正 showToast 调用，添加第二个参数
            showToast(@"无权限保存到相册，请在设置中开启权限", YES);
        }
    }];
}

// 定义 topView 函数
UIViewController* topView() {
    UIViewController *rootViewController = UIApplication.sharedApplication.keyWindow.rootViewController;
    UIViewController *topVC = rootViewController;
    while (topVC.presentedViewController) {
        topVC = topVC.presentedViewController;
    }
    return topVC;
}

// 下载媒体文件，支持多种格式
static void downloadMedia(NSURL *url, MediaType mediaType, void (^completion)(NSURL *fileURL, NSError *error)) {
    if (!url) {
        // 修正 showToast 调用，添加第二个参数
        showToast(@"下载URL为空～", YES);
        completion(nil, [NSError errorWithDomain:@"DownloadError" code:0 userInfo:@{NSLocalizedDescriptionKey: @"URL为空"}]);
        return;
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIViewController *topVC = topView();
        __block UIAlertController *loadingAlert = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            loadingAlert = [UIAlertController alertControllerWithTitle:@"下载中..." message:nil preferredStyle:UIAlertControllerStyleAlert];
            if (topVC) [topVC presentViewController:loadingAlert animated:YES completion:nil];
        });

        NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
        NSURLSessionDownloadTask *downloadTask = [session downloadTaskWithURL:url completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [loadingAlert dismissViewControllerAnimated:YES completion:nil];
                if (!error && location) {
                    NSString *fileName = url.lastPathComponent;
                    NSString *extension = nil;

                    // 从响应头检测文件类型
                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                        NSString *contentType = httpResponse.allHeaderFields[@"Content-Type"];
                        if (contentType) {
                            if ([contentType containsString:@"video/mp4"]) extension = @"mp4";
                            else if ([contentType containsString:@"video/quicktime"]) extension = @"mov";
                            else if ([contentType containsString:@"video/x-msvideo"]) extension = @"avi";
                            else if ([contentType containsString:@"video/x-matroska"]) extension = @"mkv";
                            else if ([contentType containsString:@"video/webm"]) extension = @"webm";
                            else if ([contentType containsString:@"video/3gpp"]) extension = @"3gp";
                            else if ([contentType containsString:@"video/mpeg"]) extension = @"mpg";
                            else if ([contentType containsString:@"video/x-flv"]) extension = @"flv";
                            else if ([contentType containsString:@"image"]) extension = @"jpg";
                            else if ([contentType containsString:@"audio"]) extension = @"mp3";
                            else NSLog(@"[DYYY] 未知类型: %@", contentType);
                        }
                    }

                    // 如果未检测到格式，使用默认值
                    if (!extension) {
                        switch (mediaType) {
                            case MediaTypeVideo: extension = @"mp4"; break;
                            case MediaTypeImage: extension = @"jpg"; break;
                            case MediaTypeAudio: extension = @"mp3"; break;
                        }
                        NSLog(@"[DYYY] 未检测到文件类型，使用默认扩展名: %@", extension);
                    }

                    // 处理文件扩展名
                    if (!fileName.pathExtension.length) {
                        fileName = [fileName stringByAppendingPathExtension:extension];
                    } else if (![fileName.pathExtension isEqualToString:extension]) {
                        fileName = [[fileName stringByDeletingPathExtension] stringByAppendingPathExtension:extension];
                    }

                    // 使用 Documents 目录
                    NSURL *documentsDir = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
                    NSURL *destinationURL = [documentsDir URLByAppendingPathComponent:fileName];
                    NSError *moveError = nil;
                    [[NSFileManager defaultManager] moveItemAtURL:location toURL:destinationURL error:&moveError];
                    if (!moveError) {
                        completion(destinationURL, nil);
                    } else {
                        // 修正 showToast 调用，添加第二个参数
                        showToast([NSString stringWithFormat:@"移动文件失败: %@", moveError.localizedDescription], YES);
                        completion(nil, moveError);
                    }
                } else {
                    // 修正 showToast 调用，添加第二个参数
                    showToast([NSString stringWithFormat:@"下载失败: %@", error.localizedDescription], YES);
                    completion(nil, error);
                }
            });
        }];
        [downloadTask resume];
    });
}

%hook AWELongPressPanelTableViewController

- (NSArray *)dataArray {
    NSArray *originalArray = %orig;
    BOOL enableDownload = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYlongpressdownload"];
    if (!enableDownload) return originalArray;
    
    AWELongPressPanelViewGroupModel *newGroup = [[%c(AWELongPressPanelViewGroupModel) alloc] init];
    newGroup.groupType = 0;
    
    AWELongPressPanelBaseViewModel *tempModel = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
    AWEAwemeModel *aweme = tempModel.awemeModel;
    if (!aweme) {
        NSLog(@"aweme 模型为空");
        return originalArray;
    }
    
    NSMutableArray *customActions = [NSMutableArray array];
    
    if (aweme.awemeType == 68) { // 图集类型
        AWEImageAlbumImageModel *currentImage = aweme.albumImages.count == 1 ? aweme.albumImages.firstObject : aweme.albumImages[aweme.currentImageIndex - 1];
        
        if (currentImage) {
            if(currentImage.clipVideo){
                [customActions addObject:@{
                    @"title": @"下载当前实况照片",
                    @"type": @(MediaTypeLivePhoto),
                    @"icon": @"ic_star_outlined_12",
                    @"action": ^{
                        NSMutableArray *urls = [NSMutableArray array];
                        if (currentImage.urlList.count > 0) {
                            [urls addObject:[NSURL URLWithString:currentImage.urlList.firstObject]];
                        }
                        if (currentImage.clipVideo.h264URL.originURLList.count > 0) {
                            NSString *videoURL = currentImage.clipVideo.h264URL.originURLList.firstObject;
                            [urls addObject:[NSURL URLWithString:videoURL]];
                        }
                        else {
                            // 修正 showToast 调用，添加第二个参数
                            showToast(@"不是实况照片", YES);
                        }
                        // 修正 downloadMedia 调用，遍历 urls 数组
                        for (NSURL *url in urls) {
                            downloadMedia(url, MediaTypeLivePhoto, ^(NSURL *fileURL, NSError *error) {
                                // 处理下载完成的回调
                            });
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
                            // 修正 downloadMedia 调用，传递单个 URL
                            downloadMedia(url, MediaTypeImage, ^(NSURL *fileURL, NSError *error) {
                                // 处理下载完成的回调
                            });
                        }
                    }
                }];
            }
        }
        
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
                // 修正 downloadMedia 调用，遍历 urls 数组
                for (NSURL *url in urls) {
                    downloadMedia(url, MediaTypeImage, ^(NSURL *fileURL, NSError *error) {
                        // 处理下载完成的回调
                    });
                }
            }
        }];
    } 
    else { // 视频类型
        [customActions addObject:@{
            @"title": @"下载视频",
            @"type": @(MediaTypeVideo),
            @"icon": @"ic_star_outlined_12",
            @"action": ^{
                if (aweme.video.h264URL.originURLList.count > 0) {
                    NSURL *url = [NSURL URLWithString:aweme.video.h264URL.originURLList.firstObject];
                    // 修正 downloadMedia 调用，传递单个 URL
                    downloadMedia(url, MediaTypeVideo, ^(NSURL *fileURL, NSError *error) {
                        // 处理下载完成的回调
                    });
                }
            }
        }];
    }
    
    if (aweme.music.playURL.originURLList.count > 0) {
        [customActions addObject:@{
            @"title": @"下载音频",
            @"type": @(MediaTypeAudio),
            @"icon": @"ic_star_outlined_12",
            @"action": ^{
                NSURL *url = [NSURL URLWithString:aweme.music.playURL.originURLList.firstObject];
                // 修正 downloadMedia 调用，传递单个 URL
                downloadMedia(url, MediaTypeAudio, ^(NSURL *fileURL, NSError *error) {
                    // 处理下载完成的回调
                });
            }
        }];
    }
    
    NSMutableArray *viewModels = [NSMutableArray array];
    [customActions enumerateObjectsUsingBlock:^(NSDictionary *action, NSUInteger idx, BOOL *stop) {
        AWELongPressPanelBaseViewModel *vm = [[%c(AWELongPressPanelBaseViewModel) alloc] init];
        vm.describeString = action[@"title"];
        // 修正 DYYY 未定义问题，这里假设使用 1 作为替代值
        vm.enterMethod = 1;
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
