#import "TTFloatWindow.h"

@interface TTFloatWindow ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, assign) CGPoint targetPoint;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation TTFloatWindow

+ (instancetype)sharedInstance {
    static TTFloatWindow *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [TTFloatWindow new];
    });
    return instance;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window) {
            self.window.hidden = NO;
            return;
        }
        [self buildWindow];
    });
}

- (UIWindowScene *)_foregroundScene {
    if (@available(iOS 13.0, *)) {
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if ([candidate isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)candidate;
                if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                    return windowScene;
                }
            }
        }
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if ([candidate isKindOfClass:[UIWindowScene class]]) {
                return (UIWindowScene *)candidate;
            }
        }
    }
    return nil;
}

- (void)buildWindow {
    UIWindowScene *scene = [self _foregroundScene];
    if (!scene) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self buildWindow];
        });
        return;
    }

    self.targetPoint = CGPointMake(100, 300);

    CGFloat w = 140.0;
    CGFloat h = 140.0;
    CGFloat x = 16.0;
    CGFloat y = 140.0;

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.frame = CGRectMake(x, y, w, h);
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.92];
    window.layer.cornerRadius = 14.0;
    window.clipsToBounds = YES;

    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 14, w - 24, 20)];
    title.text = @"TrollTouch";
    title.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:14];
    [root.view addSubview:title];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 92, w - 24, 38)];
    self.statusLabel.text = @"等待操作...";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:11];
    self.statusLabel.numberOfLines = 2;
    [root.view addSubview:self.statusLabel];

    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    testBtn.frame = CGRectMake(12, 38, w - 24, 40);
    [testBtn setTitle:@"Test Tap" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.90 alpha:1.0];
    testBtn.layer.cornerRadius = 8.0;
    testBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [testBtn addTarget:self action:@selector(doTapTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:testBtn];

    window.rootViewController = root;
    self.window = window;
    [self.window makeKeyAndVisible];
}

#pragma mark - Hit

- (UIWindow *)_hostWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if (![candidate isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)candidate;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (w == self.window) continue;
                if (!w.isHidden && w.alpha > 0.01) return w;
            }
        }
    }
    UIWindow *kw = UIApplication.sharedApplication.keyWindow;
    return (kw != self.window) ? kw : nil;
}

- (BOOL)tapAtPoint:(CGPoint)point {
    UIWindow *host = [self _hostWindow];
    if (!host) {
        self.statusLabel.text = @"❌ Host window not found";
        return NO;
    }

    UIView *target = [host hitTest:point withEvent:nil];
    if (!target) {
        target = host;
    }

    self.statusLabel.text = [NSString stringWithFormat:@"目标: %@\n坐标: (%.0f,%.0f)", NSStringFromClass(target.class), point.x, point.y];

    BOOL activated = [target accessibilityActivate];
    if (activated) {
        self.statusLabel.text = [NSString stringWithFormat:@"✅ 已激活\n(%@)", NSStringFromClass(target.class)];
        self.tapCount++;
        return YES;
    }

    if ([target isKindOfClass:[UIControl class]]) {
        [(UIControl *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
        self.statusLabel.text = [NSString stringWithFormat:@"✅ UIControl 触发\n(%@)", NSStringFromClass(target.class)];
        self.tapCount++;
        return YES;
    }

    Class axResponder = NSClassFromString(@"AXSimpleRuntimeManager");
    if (axResponder) {
        self.statusLabel.text = [NSString stringWithFormat:@"⚠️ return=%d\n(%@)", activated, NSStringFromClass(target.class)];
        return activated;
    }

    self.statusLabel.text = [NSString stringWithFormat:@"⚠️ 无法激活\n(类型: %@)", NSStringFromClass(target.class)];
    return NO;
}

- (void)doTapTest {
    [self tapAtPoint:self.targetPoint];
}

@end
