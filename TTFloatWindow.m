#import "TTFloatWindow.h"
#import <dlfcn.h>

typedef struct __IOHIDEvent *IOHIDEventRef;

static IOHIDEventRef (*IOHIDEventCreateDigitizerEvent)(
    CFAllocatorRef allocator,
    uint64_t timestamp,
    uint32_t type,
    uint32_t index,
    uint32_t identity,
    uint32_t eventMask,
    uint32_t buttonMask,
    CGFloat x,
    CGFloat y,
    CGFloat z,
    CGFloat tipPressure,
    CGFloat barrelPressure,
    Boolean range,
    Boolean touch,
    uint32_t options
) = NULL;

static void (*IOHIDEventSetFloatValue)(IOHIDEventRef event, int32_t field, float value) = NULL;

#define kDigitizerFinger      2
#define kDigitizerEventRange  (1 << 0)
#define kDigitizerEventTouch  (1 << 1)
#define kDigitizerEventAttribute (1 << 3)

static void TTLoadIOKit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *ioKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (ioKit) {
            IOHIDEventCreateDigitizerEvent = dlsym(ioKit, "IOHIDEventCreateDigitizerEvent");
            IOHIDEventSetFloatValue = dlsym(ioKit, "IOHIDEventSetFloatValue");
        }
    });
}

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
    CGFloat h = 170.0;
    CGFloat x = 16.0;
    CGFloat y = 120.0;

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

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 110, w - 24, 52)];
    self.statusLabel.text = @"等待操作...";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:10];
    self.statusLabel.numberOfLines = 3;
    [root.view addSubview:self.statusLabel];

    UIButton *testBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    testBtn.frame = CGRectMake(12, 38, w - 24, 32);
    [testBtn setTitle:@"Tap" forState:UIControlStateNormal];
    [testBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.90 alpha:1.0];
    testBtn.layer.cornerRadius = 8.0;
    testBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [testBtn addTarget:self action:@selector(doTapTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:testBtn];

    UIButton *swipeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    swipeBtn.frame = CGRectMake(12, 74, w - 24, 28);
    [swipeBtn setTitle:@"Swipe" forState:UIControlStateNormal];
    [swipeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    swipeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    swipeBtn.layer.cornerRadius = 8.0;
    swipeBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [swipeBtn addTarget:self action:@selector(doSwipeTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:swipeBtn];

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
        self.statusLabel.text = @"❌ window_not_found";
        return NO;
    }

    UIView *target = [host hitTest:point withEvent:nil];
    if (!target) {
        target = host;
    }

    NSString *cls = NSStringFromClass(target.class);

    BOOL activated = [target accessibilityActivate];
    if (activated) {
        self.statusLabel.text = [NSString stringWithFormat:@"✅ AX activate\n(%@)", cls];
        self.tapCount++;
        return YES;
    }

    if ([target isKindOfClass:[UIControl class]]) {
        [(UIControl *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
        self.statusLabel.text = [NSString stringWithFormat:@"✅ UIControl\n(%@)", cls];
        self.tapCount++;
        return YES;
    }

    BOOL hidOk = [self tapHIDAtPoint:point];
    if (hidOk) {
        self.statusLabel.text = [NSString stringWithFormat:@"✅ HID event\n(%.0f,%.0f)", point.x, point.y];
        self.tapCount++;
        return YES;
    }

    self.statusLabel.text = [NSString stringWithFormat:@"⚠️ all failed\n(%@)", cls];
    return NO;
}

#pragma mark - HID

- (BOOL)tapHIDAtPoint:(CGPoint)point {
    TTLoadIOKit();
    if (!IOHIDEventCreateDigitizerEvent) {
        return NO;
    }

    SEL sel = NSSelectorFromString(@"_enqueueHIDEvent:");
    UIApplication *app = [UIApplication sharedApplication];
    if (![app respondsToSelector:sel]) {
        return NO;
    }
    typedef void (*EnqueueFn)(id, SEL, IOHIDEventRef);
    EnqueueFn enqueue = (EnqueueFn)[app methodForSelector:sel];

    IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault,
        mach_absolute_time(),
        kDigitizerFinger,
        0,       // index
        1,       // identity
        kDigitizerEventRange | kDigitizerEventTouch,
        0,       // buttonMask
        point.x, point.y, 0.0,
        0.0,     // tipPressure
        0.0,     // barrelPressure
        true,    // range
        true,    // touch
        0        // options
    );

    if (IOHIDEventSetFloatValue) {
        IOHIDEventSetFloatValue(down, 0x50000, (float)point.x); // kIOHIDEventFieldDigitizerX
        IOHIDEventSetFloatValue(down, 0x50001, (float)point.y); // kIOHIDEventFieldDigitizerY
    }

    enqueue(app, sel, down);

    IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault,
        mach_absolute_time(),
        kDigitizerFinger,
        0, 1,
        kDigitizerEventRange | kDigitizerEventTouch,
        0,
        point.x, point.y, 0.0,
        0.0, 0.0,
        true,   // range
        false,  // touch = 0
        0
    );

    enqueue(app, sel, up);

    CFRelease(down);
    CFRelease(up);

    return YES;
}

#pragma mark - actions

- (void)doTapTest {
    [self tapAtPoint:self.targetPoint];
}

- (void)doSwipeTest {
    self.statusLabel.text = @"Swipe...";
    dispatch_async(dispatch_get_main_queue(), ^{
        for (NSInteger i = 0; i <= 10; i++) {
            CGFloat ty = 600.0 - (i / 10.0) * 300.0;
            [self tapHIDAtPoint:CGPointMake(200, ty)];
            usleep(16000);
        }
        self.statusLabel.text = @"✅ Swipe done";
    });
}

@end
