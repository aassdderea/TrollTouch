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

@interface TTFloatWindow () <UITextFieldDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, assign) CGPoint targetPoint;
@property (nonatomic, strong) UITextField *xField;
@property (nonatomic, strong) UITextField *yField;
@property (nonatomic, strong) UILabel *logLabel;
@property (nonatomic, strong) NSMutableString *logBuf;
@end

@implementation TTFloatWindow

+ (instancetype)sharedInstance {
    static TTFloatWindow *i;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ i = [TTFloatWindow new]; });
    return i;
}

- (void)show {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.window) { self.window.hidden = NO; return; }
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

- (void)log:(NSString *)m {
    [self.logBuf appendFormat:@"%@\n", m];
    NSArray *lines = [self.logBuf componentsSeparatedByString:@"\n"];
    NSUInteger max = 12, start = lines.count > max ? lines.count - max : 0;
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

    CGFloat w = 190.0, h = 310.0, pad = 10.0;
    CGFloat nowY = 10.0;
    CGRect rc;
    UIFont *f = [UIFont systemFontOfSize:13];

    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.frame = CGRectMake(10, 90, w, h);
    window.windowLevel = UIWindowLevelAlert + 1;
    window.backgroundColor = [UIColor colorWithWhite:0.05 alpha:0.88];
    window.layer.cornerRadius = 14.0;
    window.clipsToBounds = YES;
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];

    // 标题
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(pad, nowY, w - pad * 2, 18)];
    title.text = @"TrollTouch";
    title.textColor = [UIColor colorWithRed:0.25 green:0.72 blue:1.0 alpha:1.0];
    title.font = [UIFont boldSystemFontOfSize:15];
    [root.view addSubview:title];
    nowY += 22;

    // x 输入
    UILabel *xl = [[UILabel alloc] initWithFrame:CGRectMake(pad, nowY + 4, 16, 26)];
    xl.text = @"x"; xl.textColor = UIColor.whiteColor; xl.font = f;
    [root.view addSubview:xl];
    UITextField *xf = [[UITextField alloc] initWithFrame:CGRectMake(pad + 16, nowY, 65, 32)];
    xf.text = @"100"; xf.borderStyle = UITextBorderStyleRoundedRect;
    xf.keyboardType = UIKeyboardTypeNumberPad;
    xf.textColor = UIColor.whiteColor;
    xf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    xf.font = f; xf.delegate = self;
    [root.view addSubview:xf];
    _xField = xf;

    // y 输入
    UILabel *yl = [[UILabel alloc] initWithFrame:CGRectMake(pad + 88, nowY + 4, 16, 26)];
    yl.text = @"y"; yl.textColor = UIColor.whiteColor; yl.font = f;
    [root.view addSubview:yl];
    UITextField *yf = [[UITextField alloc] initWithFrame:CGRectMake(pad + 104, nowY, 65, 32)];
    yf.text = @"300"; yf.borderStyle = UITextBorderStyleRoundedRect;
    yf.keyboardType = UIKeyboardTypeNumberPad;
    yf.textColor = UIColor.whiteColor;
    yf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    yf.font = f; yf.delegate = self;
    [root.view addSubview:yf];
    _yField = yf;
    nowY += 38;

    // Set 按钮
    UIButton *setBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    setBtn.frame = CGRectMake(pad, nowY, w - pad * 2, 29);
    [setBtn setTitle:@"Set Coords" forState:UIControlStateNormal];
    setBtn.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.15];
    [setBtn setTitleColor:[UIColor colorWithWhite:0.9 alpha:1.0] forState:UIControlStateNormal];
    setBtn.layer.cornerRadius = 7;
    setBtn.titleLabel.font = [UIFont systemFontOfSize:13];
    [setBtn addTarget:self action:@selector(setCoords) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:setBtn];
    nowY += 34;

    // Tap 按钮
    UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    rc = CGRectMake(pad, nowY, w - pad * 2, 36);
    tapBtn.frame = rc;
    [tapBtn setTitle:@"> Tap <" forState:UIControlStateNormal];
    tapBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.52 blue:0.92 alpha:1.0];
    [tapBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    tapBtn.layer.cornerRadius = 8;
    tapBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [tapBtn addTarget:self action:@selector(doTapTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:tapBtn];
    nowY += 42;

    // Swipe
    UIButton *swBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    swBtn.frame = CGRectMake(pad, nowY, w - pad * 2, 28);
    [swBtn setTitle:@"Swipe" forState:UIControlStateNormal];
    swBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    [swBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    swBtn.layer.cornerRadius = 7;
    swBtn.titleLabel.font = f;
    [swBtn addTarget:self action:@selector(doSwipeTest) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:swBtn];
    nowY += 32;

    // Copy Logs
    UIButton *cpBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cpBtn.frame = CGRectMake(pad, nowY, w - pad * 2, 28);
    [cpBtn setTitle:@"Copy Logs" forState:UIControlStateNormal];
    cpBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    [cpBtn setTitleColor:[UIColor colorWithRed:0.25 green:0.72 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    cpBtn.layer.cornerRadius = 7;
    cpBtn.titleLabel.font = f;
    [cpBtn addTarget:self action:@selector(copyLogs) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:cpBtn];
    nowY += 34;

    // Log label
    self.logLabel = [[UILabel alloc] initWithFrame:CGRectMake(pad + 2, nowY, w - pad * 2 - 4, h - nowY - 6)];
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

- (void)setCoords {
    CGFloat x = _xField.text.floatValue;
    CGFloat y = _yField.text.floatValue;
    self.targetPoint = CGPointMake(x, y);
    [self endEditing];
    [self log:[NSString stringWithFormat:@"Set (%.0f, %.0f)", x, y]];
}

- (void)endEditing {
    [_xField resignFirstResponder];
    [_yField resignFirstResponder];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self endEditing]; return YES; }

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
    if (!host) { [self log:@"host window not found"]; return; }

    UIView *target = [host hitTest:point withEvent:nil];
    if (!target) target = host;
    CGSize sz = host.bounds.size;
    CGFloat sc = host.screen.scale;

    // ---- 红圈 ----
    [self showTapDotAtPoint:point onWindow:host];
    [self log:[NSString stringWithFormat:@"hot=%@ pt(%.0f,%.0f) px(%.0f,%.0f) sc=%.0f sz=%.0fx%.0f",
        NSStringFromClass(target.class), point.x, point.y, point.x * sc, point.y * sc, sc, sz.width, sz.height]];

    // 1 accessibilityActivate
    if ([target accessibilityActivate]) { [self log:@"AX ok"]; return; }
    // 2 UIControl
    if ([target isKindOfClass:[UIControl class]]) {
        [(UIControl *)target sendActionsForControlEvents:UIControlEventTouchUpInside];
        [self log:@"UIControl ok"]; return;
    }
    // 3 HID
    [self tapHIDAtPoint:point host:host target:target];
}

#pragma mark - HID

- (void)tapHIDAtPoint:(CGPoint)point host:(UIWindow *)host target:(UIView *)target {
    (void)host; (void)target;
    UIApplication *app = UIApplication.sharedApplication;
    NSArray *selNames = @[@"_enqueueHIDEvent:", @"_handleHIDEvent:", @"_enqueueHIDEvent:toQueue:"];
    SEL found = NULL;
    for (NSString *nm in selNames) {
        SEL s = NSSelectorFromString(nm);
        if ([app respondsToSelector:s]) { found = s; [self log:[NSString stringWithFormat:@"HID=%@", nm]]; break; }
    }
    if (!found) { [self log:@"HID selector not found"]; return; }

    TTLoadIOKit();
    if (!IOHIDEventCreateDigitizerEvent) { [self log:@"IOKitCreate nil"]; return; }

    typedef void (*Efn)(id, SEL, IOHIDEventRef);
    Efn enq = (Efn)[app methodForSelector:found];

    IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault, mach_absolute_time(),
        kDigitizerFinger, 0, 1,
        kDigitizerEventRange | kDigitizerEventTouch | kDigitizerEventAttr,
        0, point.x, point.y, 0.0, 0.1, 0.0, true, true, 0);
    if (IOHIDEventSetFloatValue) {
        IOHIDEventSetFloatValue(down, 720896, (float)point.x);
        IOHIDEventSetFloatValue(down, 720897, (float)point.y);
    }
    enq(app, found, down);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            kDigitizerFinger, 0, 1,
            kDigitizerEventRange | kDigitizerEventTouch | kDigitizerEventAttr,
            0, point.x, point.y, 0.0, 0.0, 0.0, true, false, 0);
        if (IOHIDEventSetFloatValue) {
            IOHIDEventSetFloatValue(up, 720896, (float)point.x);
            IOHIDEventSetFloatValue(up, 720897, (float)point.y);
        }
        enq(app, found, up);
        CFRelease(up);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(150 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        CFRelease(down);
    });

    [self log:@"HID sent ✔ (no effect? add entitlement com.apple.private.hid.client.event-dispatch)"];
}

#pragma mark - dot

- (void)showTapDotAtPoint:(CGPoint)p onWindow:(UIWindow *)host {
    if (!host) return;
    CGFloat s = 56.0;
    UIView *dot = [[UIView alloc] initWithFrame:CGRectMake(p.x - s/2, p.y - s/2, s, s)];
    dot.backgroundColor = [UIColor colorWithRed:1.0 green:0.12 blue:0.12 alpha:0.30];
    dot.layer.borderColor = [UIColor.whiteColor colorWithAlphaComponent:0.9].CGColor;
    dot.layer.borderWidth = 3.5;
    dot.layer.cornerRadius = s / 2;
    dot.layer.shadowColor = [UIColor.redColor CGColor];
    dot.layer.shadowOffset = CGSizeZero;
    dot.layer.shadowRadius = 6;
    dot.layer.shadowOpacity = 0.7;
    dot.userInteractionEnabled = NO;
    [host addSubview:dot];
    [host bringSubviewToFront:dot];
    [UIView animateWithDuration:0.7 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        dot.transform = CGAffineTransformMakeScale(1.5, 1.5);
        dot.alpha = 0.0;
    } completion:^(BOOL f) { [dot removeFromSuperview]; }];
}

#pragma mark - log

- (void)copyLogs {
    [UIPasteboard generalPasteboard].string = self.logBuf ?: @"";
    [self log:@"copied to pasteboard"];
}

#pragma mark - actions

- (void)doTapTest {
    [self endEditing];
    [self tapDiagnoseAtPoint:self.targetPoint];
}

- (void)doSwipeTest {
    [self endEditing];
    [self runSwipeFrom:CGPointMake(200, 600) to:CGPointMake(200, 200) steps:6 interval:0.03];
}

- (void)runSwipeFrom:(CGPoint)f to:(CGPoint)t steps:(NSInteger)n interval:(NSTimeInterval)iv {
    [self dispatchSwipeStep:f to:t step:0 total:n interval:iv];
}

- (void)dispatchSwipeStep:(CGPoint)f to:(CGPoint)t step:(NSInteger)i total:(NSInteger)n interval:(NSTimeInterval)iv {
    if (i > n) { [self log:@"Swipe done"]; return; }
    CGFloat r = (CGFloat)i / n;
    CGPoint p = CGPointMake(f.x + (t.x - f.x) * r, f.y + (t.y - f.y) * r);
    [self tapDiagnoseAtPoint:p];
    __weak typeof(self) ws = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(iv * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [ws dispatchSwipeStep:f to:t step:i + 1 total:n interval:iv];
    });
}

@end
