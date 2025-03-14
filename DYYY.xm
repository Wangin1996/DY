#import <UIKit/UIKit.h>
#import <objc/runtime.h>


//去开屏广告
%hook BDASplashControllerView

+ (id)alloc {
    return nil; // 直接返回空指针，阻止内存分配
}


%end

//拦截顶栏位置提示线
%hook AWEFeedMultiTabSelectedContainerView

- (void)setHidden:(BOOL)hidden {
    %orig(YES); 
}

%end

// 屏蔽关注页XX个直播
%hook AWEConcernSkylightCapsuleView

- (void)setHidden:(BOOL)hidden {
    %orig(YES); 
}

- (void)setAlpha:(CGFloat)alpha {
    %orig(0);
}

%end

//屏蔽广告以及直播
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
    return;
}

+ (id)liveStreamURLJSONTransformer {
    return nil;
}

+ (id)relatedLiveJSONTransformer {
    return nil;
}

+ (id)rawModelFromLiveRoomModel:(id)arg1 {
    return nil;
}

+ (id)aweLiveRoom_subModelPropertyKey {
    return nil;
}

%end
