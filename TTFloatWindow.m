#import "TTFloatWindow.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;

static IOHIDEventRef (*IOHIDEventCreateDigitizerEvent)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Boolean, Boolean, uint32_t
) = NULL;

static void (*IOHIDEventSetFloatValue)(IOHIDEventRef, int32_t, float) = NULL;


#define kDigitizerFinger 2
#define kDigitizerEventRange  (1<<0)
#define kDigitizerEventTouch  (1<<1)
#define kDigitizerEventAttr   (1<<3)

static void TTLoadIOKit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (h) {
            IOHIDEventCreateDigitizerEvent = dlsym(h, "IOHIDEventCreateDigitizerEvent");
            IOHIDEventSetFloatValue = dlsym(h, "IOHIDEventSetFloatValue");
        }
    });
}



@interface TTFloatWindow ()
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, assign) CGPoint targetPoint;
@property (nonatomic, assign) NSInteger tapCount;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) NSMutableString *logBuf;
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
        self.logBuf = [NSMutableString new];
        [self buildWindow];
    });
}

- (UIWindowScene *)_foregroundScene {
    if (@available(iOS 13.0, *)) {
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if ([c isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *ws = (UIWindowScene *)c;
                if (ws.activationState == UISceneActivationStateForegroundActive) return ws;
            }
        }
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if ([c isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)c;
        }
    }
    return nil;
}

- (void)log:(NSString *)msg {
    [self.logBuf appendFormat:@"%@\n", msg];
    NSArray *lines = [self.logBuf componentsSeparatedByString:@"\n"];
    NSUInteger max = 10;
    NSUInteger start = lines.count > max ? lines.count - max : 0;
    self.logLabel.text = [[lines subarrayWithRange:NSMakeRange(start, MIN(lines.count - start, max))] componentsJoinedByString:@"\n"];
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

    CGFloat w = 175.0;
    CGFloat h = 260.0;  // taller for log + copy button
    CGFloat x = 12.0;
    CGFloat y = 100.0;

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.frame = CGRectMake(x, y, w, h);
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.90];
    window.layer.cornerRadius = 14.0;
    window.clipsToBounds = YES;

    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(12, 12, w - 24, 20)];
    title.text = @"TrollTouch";
    title.textColor = [UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:15];
    [root.view addSubview:title];

    UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    tapBtn.frame = CGRectMake(12, 38, w - 24, 34);
    [tapBtn setTitle:@"Tap" forState:UIControlStateNormal];
    tapBtn.backgroundColor = [UIColor colorWithRed:0.18 green:0.50 blue:0.90 alpha:1.0];
    [tapBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    tapBtn.layer.cornerRadius = 8.0;
    tapBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [tapBtn addTarget:self action:@selector(doTapTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:tapBtn];

    UIButton *swipeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    swipeBtn.frame = CGRectMake(12, 76, w - 24, 30);
    [swipeBtn setTitle:@"Swipe" forState:UIControlStateNormal];
    swipeBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [swipeBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    swipeBtn.layer.cornerRadius = 8.0;
    swipeBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [swipeBtn addTarget:self action:@selector(doSwipeTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:swipeBtn];

    UIButton *copyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    copyBtn.frame = CGRectMake(12, 110, w - 24, 30);
    [copyBtn setTitle:@"Copy Logs" forState:UIControlStateNormal];
    copyBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    [copyBtn setTitleColor:[UIColor colorWithRed:0.3 green:0.7 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    copyBtn.layer.cornerRadius = 8.0;
    copyBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [copyBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:copyBtn];

    self.logLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 148, w - 24, h - 156)];
    self.logLabel.text = @"等待操作…";
    self.logLabel.textColor = [UIColor colorWithWhite:0.72 alpha:1.0];
    self.logLabel.font = [UIFont systemFontOfSize:9];
    self.logLabel.numberOfLines = 0;
    [root.view addSubview:self.logLabel];

    window.rootViewController = root;
    self.window = window;
    [self.window makeKeyAndVisible];

    [self log:@"TrollTouch loaded"];
    [self log:[NSString stringWithFormat:@"bundle=%@", NSBundle.mainBundle.bundleIdentifier ?: @"?"]];
}

#pragma mark - host window

- (UIWindow *)_hostWindow {
    if (@available(iOS 13.0, *)) {
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if (![c isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)c;
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

#pragma mark - tap

- (void)tapDiagnoseAtPoint:(CGPoint)point {
    UIWindow *host = [self _hostWindow];
    if (!host) { [self log:@"❌ host window not found"]; return; }

    UIView *target = [host hitTest:point withEvent:nil];
    if (!target) target = host;

    CGSize screenSize = host.bounds.size;
    CGFloat scale = host.screen.scale;

    [self showTapDotAtPoint:point onWindow:host];
    [self log:[NSString stringWithFormat:@"hit=%@ scale=%.0f screen=%.0fx%.0f",
        NSStringFromClass(target.class), scale, screenSize.width, screenSize.height]];
    [self log:[NSString stringWithFormat:@"pt=(%.0f,%.0f) px=(%.0f,%.0f)",
        point.x, point.y, point.x * scale, point.y * scale]];

    // 1) accessibilityActivate
    if ([target accessibilityActivate]) {
        [self log:[NSString stringWithFormat:@"✅ AX ok (%@)", NSStringFromClass(target.class)]];
        self.tapCount++; return;
    }

    // 2) UIControl
    if ([target isKindOfClass:[UIControl class]]) {
        [(UIControl *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self log:[NSString stringWithFormat:@"✅ UIControl (%@)", NSStringFromClass(target.class)]];
        self.tapCount++; return;
    }

    // 3) HID  检查好几个可能的Selector
    UIApplication *app = UIApplication.sharedApplication;
    NSArray *selNames = @[@"_enqueueHIDEvent:", @"_handleHIDEvent:", @"_enqueueHIDEvent:toQueue:"];
    SEL foundSel = NULL;
    for (NSString *name in selNames) {
        SEL s = NSSelectorFromString(name);
        if ([app respondsToSelector:s]) { foundSel = s; [self log:[NSString stringWithFormat:@"HID sel=%@", name]]; break; }
    }
    if (!foundSel) { [self log:@"❌ no HID selector"]; return; }

    TTLoadIOKit();
    [self log:[NSString stringWithFormat:@"IOKitCreateFn=%s", IOHIDEventCreateDigitizerEvent ? "ok" : "nil"]];

    if (!IOHIDEventCreateDigitizerEvent) { [self log:@"❌ IOKit fn nil"]; return; }

    typedef void (*EFn)(id, SEL, IOHIDEventRef);
    EFn enq = (EFn)[app methodForSelector:foundSel];

    IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault, mach_absolute_time(),
        kDigitizerFinger, 0, 1,
        kDigitizerEventRange | kDigitizerEventTouch | kDigitizerEventAttr,
        0,
        point.x, point.y, 0.0, 0.1, 0.0, true, true, 0
    );
    if (IOHIDEventSetFloatValue) {
        IOHIDEventSetFloatValue(down, 720896, (float)point.x);
        IOHIDEventSetFloatValue(down, 720897, (float)point.y);
    }
    enq(app, foundSel, down);
    [self log:@"HID down enqueued"];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(80 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            kDigitizerFinger, 0, 1,
            kDigitizerEventRange | kDigitizerEventTouch | kDigitizerEventAttr,
            0,
            point.x, point.y, 0.0, 0.0, 0.0, true, false, 0
        );
        if (IOHIDEventSetFloatValue) {
            IOHIDEventSetFloatValue(up, 720896, (float)point.x);
            IOHIDEventSetFloatValue(up, 720897, (float)point.y);
        }
        enq(app, foundSel, up);
        CFRelease(up);
        [weakSelf log:@"HID up enqueued"];
    });

    // hold down ref until up fires
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        CFRelease(down);
    });

    [self log:@"HID path deployed"];
    self.tapCount++;
}

#pragma mark - dot

- (void)showTapDotAtPoint:(CGPoint)point onWindow:(UIWindow *)host {
    if (!host) return;
    CGFloat size = 32.0;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(point.x - size / 2.0, point.y - size / 2.0, size, size)];
    dot.backgroundColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.15 alpha:0.25];
    dot.layer.borderColor = [UIColor colorWithRed:1.0 green:0.15 blue:0.15 alpha:0.85].CGColor;
    dot.layer.borderWidth = 2.5;
    dot.layer.cornerRadius = size / 2.0;
    dot.userInteractionEnabled = NO;
    [host addSubview:dot];
    [UIView animateWithDuration:0.45 animations:^{
        dot.transform = CGAffineTransformMakeScale(1.8, 1.8);
        dot.alpha = 0.0;
    } completion:^(BOOL f) { [dot removeFromSuperview]; }];
}

#pragma mark - log copy

- (void)copyLogs {
    [UIPasteboard generalPasteboard].string = self.logBuf ?: @"no logs";
    [self log:@"📋 copied to pasteboard"];
}

#pragma mark - actions

- (void)doTapTest {
    [self tapDiagnoseAtPoint:self.targetPoint];
}

- (void)doSwipeTest {
    [self runSwipeFrom:CGPointMake(200, 600) to:CGPointMake(200, 300) steps:8 interval:0.022];
}

- (void)runSwipeFrom:(CGPoint)from to:(CGPoint)to steps:(NSInteger)steps interval:(NSTimeInterval)interval {
    [self dispatchSwipeStepFrom:from to:to step:0 total:steps interval:interval];
}

- (void)dispatchSwipeStepFrom:(CGPoint)from to:(CGPoint)to step:(NSInteger)step total:(NSInteger)total interval:(NSTimeInterval)interval {
    if (step > total) { [self log:@"✅ Swipe done"]; return; }
    CGFloat r = (CGFloat)step / total;
    CGPoint p = CGPointMake(from.x + (to.x - from.x) * r, from.y + (to.y - from.y) * r);
    [self tapDiagnoseAtPoint:p];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(interval * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf dispatchSwipeStepFrom:from to:to step:step + 1 total:total interval:interval];
    });
}

@end
