@class AWEVideoModel;
@class AWEMusicModel;
@class AWEImageAlbumImageModel;
@class AWEAwemeModel;
@class CityManager;

// AWELongPressPanelBaseViewModel
@interface AWELongPressPanelBaseViewModel : NSObject
@property (nonatomic, strong) AWEAwemeModel *awemeModel;
@property (nonatomic, strong) NSString *enterMethod;
@property (nonatomic, assign) NSUInteger actionType;
@property (nonatomic, strong) NSString *duxIconName;
@property (nonatomic, strong) NSString *describeString;
@property (nonatomic, assign) BOOL showIfNeed;
@property (nonatomic, copy) void (^action)(void);
@end

// AWELongPressPanelViewGroupModel
@interface AWELongPressPanelViewGroupModel : NSObject
@property (nonatomic, assign) NSUInteger groupType;
@property (nonatomic, strong) NSArray<AWELongPressPanelBaseViewModel *> *groupArr;
@end

// AWELongPressPanelTableViewController
@interface AWELongPressPanelTableViewController : UIViewController
- (NSArray *)dataArray;
- (void)updateSheetHeightWithHeight:(CGFloat)height withMinimumHeight:(CGFloat)minimumHeight;
- (CGFloat)getLongPressPanelMinimumHeight;
@end

// AWEURLModel
@interface AWEURLModel : NSObject
@property (nonatomic, copy) NSArray *originURLList;
@end

// AWEMusicModel
@interface AWEMusicModel : NSObject
@property (nonatomic, strong, readonly) AWEURLModel *playURL;
@end

// AWEVideoModel
@interface AWEVideoModel : NSObject
@property (nonatomic, strong, readonly) AWEURLModel *playURL;
@property (nonatomic, strong, readonly) AWEURLModel *h264URL;
@property (nonatomic, strong, readonly) AWEURLModel *coverURL;
@property (nonatomic, copy) NSArray *bitrateModels;
@end

// AWEImageAlbumImageModel
@interface AWEImageAlbumImageModel : NSObject
@property (nonatomic, copy) NSArray *urlList;
@property (nonatomic, copy) NSinteger type;
@end

//以上为新增

@interface AWESettingItemModel : NSObject
@property (nonatomic, strong, readwrite) NSString *identifier;
@property (nonatomic, strong, readwrite) NSString *title;
@property (nonatomic, assign, readwrite) NSInteger type;
@property (nonatomic, strong, readwrite) NSString *svgIconImageName;
@property (nonatomic, strong, readwrite) NSString *iconImageName;
@property (nonatomic, assign, readwrite) NSInteger cellType;
@property (nonatomic, assign, readwrite) BOOL isEnable;
@property (nonatomic, copy, readwrite) id cellTappedBlock;
@property (nonatomic, assign, readwrite) NSInteger colorStyle;
@property (nonatomic, strong, readwrite) NSString *detail;
@end

@interface AWESettingSectionModel : NSObject
@property (nonatomic, strong, readwrite) NSArray<AWESettingItemModel *> *itemArray;
@property (nonatomic, assign, readwrite) NSInteger type;
@property (nonatomic, strong, readwrite) NSString *sectionHeaderTitle;
@property (nonatomic, assign, readwrite) CGFloat sectionHeaderHeight;
@end

@interface AWESettingsViewModel : NSObject
@property (nonatomic, weak, readwrite) id controllerDelegate;
@end



@interface AWENormalModeTabBarGeneralButton : UIButton
@end

@interface AWENormalModeTabBarBadgeContainerView : UIView

@end

@interface AWEFeedContainerContentView : UIView
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end

@interface AWELeftSideBarEntranceView : UIView
@end

@interface AWEDanmakuContentLabel : UILabel
- (UIColor *)colorFromHexString:(NSString *)hexString baseColor:(UIColor *)baseColor;
@end

@interface AWELandscapeFeedEntryView : UIView
@end

@interface AWEPlayInteractionViewController : UIViewController
@property (nonatomic, strong) UIView *view;
@end

@interface UIView (Transparency)
- (UIViewController *)firstAvailableUIViewController;
@end

@interface AWEFeedVideoButton : UIButton
@end

@interface AWEMusicCoverButton : UIButton
@end

@interface AWEAwemePlayVideoViewController : UIViewController
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context;
- (void)setVideoControllerPlaybackRate:(double)arg0;

@end

@interface AWEDanmakuItemTextInfo : NSObject
- (void)setDanmakuTextColor:(id)arg1;
- (UIColor *)colorFromHexStringForTextInfo:(NSString *)hexString;
@end

@interface AWECommentMiniEmoticonPanelView : UIView

@end

@interface AWEBaseElementView : UIView

@end

@interface AWETextViewInternal : UITextView

@end

@interface AWECommentPublishGuidanceView : UIView

@end

@interface AWEPlayInteractionFollowPromptView : UIView

@end

@interface AWENormalModeTabBarTextView : UIView

@end

@interface AWEPlayInteractionProgressController : UIView
- (UIViewController *)findViewController:(UIViewController *)vc ofClass:(Class)targetClass;
@end

@interface AWEAdAvatarView : UIView

@end

@interface AWENormalModeTabBar : UIView

@end

@interface AWEPlayInteractionListenFeedView : UIView

@end

@interface AWEFeedLiveMarkView : UIView

@end

@interface AWEAwemeModel : NSObject
@property (nonatomic, copy) NSString *ipAttribution;
@property (nonatomic, copy) NSString *cityCode;
@property (nonatomic, assign) BOOL isAds;
@property (nonatomic, strong) AWEAwemeModel *currentAweme;
@property (nonatomic, strong, readonly) AWEVideoModel *video;
@property (nonatomic, strong) AWEMusicModel *music;
@property (nonatomic, strong) NSArray<AWEImageAlbumImageModel *> *albumImages;
@property (nonatomic, assign) NSInteger awemeType;
@property (nonatomic, assign) NSInteger currentImageIndex;
- (void)live_callInitWithDictyCategoryMethod:(id)arg1;
+ (id)liveStreamURLJSONTransformer;
+ (id)relatedLiveJSONTransformer;
+ (id)rawModelFromLiveRoomModel:(id)arg1;
+ (id)aweLiveRoom_subModelPropertyKey;
@end

@interface AWEPlayInteractionTimestampElement : UIView
@property (nonatomic, strong) AWEAwemeModel *model;
@end

@interface AWEFeedTableViewController : UIViewController
@end

@interface AWEFeedTableView : UIView
@end

@interface AWEPlayInteractionProgressContainerView : UIView
@end

@interface AFDFastSpeedView : UIView
@end

@interface AWEUserWorkCollectionViewComponentCell : UICollectionViewCell
@end

@interface AWEFeedRefreshFooter : UIView
@end

@interface AWERLSegmentView : UIView
@end

@interface AWEBaseListViewController : UIViewController
- (void)applyBlurEffectIfNeeded;
- (UILabel *)findCommentLabel:(UIView *)view;
@end

@interface AWEFeedTemplateAnchorView : UIView
@end

@interface AWEPlayInteractionSearchAnchorView : UIView
@end

@interface AWETemplateHotspotView : UIView
@end

@interface AWEAwemeMusicInfoView : UIView
@end

@interface AWEStoryContainerCollectionView : UIView
@end

@interface AWELiveNewPreStreamViewController : UIViewController
@end

@interface CommentInputContainerView : UIView
@end
