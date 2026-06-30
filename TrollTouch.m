#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

// ---- 类型与常量 ----
typedef struct __IOHIDEvent *IOHIDEventRef;
static IOHIDEventRef (*IOHIDEventCreateDigitizerEvent)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Boolean, Boolean, uint32_t) = NULL;

#define kFinger 2
#define kRange  (1<<0)
#define kTouch  (1<<1)
#define kAttr   (1<<3)

static NSString *kCommandPath, *kLogPath;
static const NSString *kNotifyName = @"com.trolltouch.run";

static NSFileHandle *_logHandle;
static NSTimer *_scanTimer;
static NSArray *_skipKeywords;
static NSString *_currentMode;
static UILabel *_statusLabel;
static UIWindow *_statusWindow;
static UIWindow *_panelWindow;
static UITextField *_pxField, *_pyField;

// ---- 前向声明 ----
static void TTLog(NSString *fmt, ...) __attribute__((format(NSString, 1, 2)));
static void TTUpdateStatusLabel(NSString *, UIColor *);
static UIWindow *TTActiveWindow(void);
static void TTTapHIDAtPoint(CGPoint pt);
static void TTDoTapFromPanel(void);
static void TTStartAutoScan(void);
static void TTStopScan(void);

// ---- TTLog ----
static void TTLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *m = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], m];
    if (!_logHandle) {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *dir = [kLogPath stringByDeletingLastPathComponent];
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [fm createFileAtPath:kLogPath contents:nil attributes:nil];
        _logHandle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        [_logHandle seekToEndOfFile];
    }
    @try { [_logHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [_logHandle synchronizeFile]; }
    @catch (NSException *e) {}
    NSLog(@"[TT] %@", m);
}

// ---- 状态标签 ----
static void TTUpdateStatusLabel(NSString *text, UIColor *color) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_statusLabel) return;
        _statusLabel.text = text;
        _statusLabel.backgroundColor = color;
    });
}

static void TTShowStatusLabel(void) {
    if (_statusLabel) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
                if ([c isKindOfClass:[UIWindowScene class]] && c.activationState == UISceneActivationStateForegroundActive)
                { scene = (UIWindowScene *)c; break; }
            }
            if (!scene)
                for (UIScene *c in UIApplication.sharedApplication.connectedScenes)
                    if ([c isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)c; break; }
        }
        if (!scene) { dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ TTShowStatusLabel(); }); return; }
        _statusWindow = [[UIWindow alloc] initWithWindowScene:scene];
        _statusWindow.frame = CGRectMake(8, 50, 160, 22);
        _statusWindow.windowLevel = UIWindowLevelAlert + 100;
        _statusWindow.backgroundColor = [UIColor clearColor];
        _statusWindow.userInteractionEnabled = NO;
        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 22)];
        _statusLabel.font = [UIFont boldSystemFontOfSize:11];
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.layer.cornerRadius = 6; _statusLabel.clipsToBounds = YES;
        _statusLabel.text = @"TT: 已加载 ✓";
        _statusLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:0.8];
        [_statusWindow addSubview:_statusLabel];
        _statusWindow.hidden = NO;
        TTLog(@"状态窗口创建完成");
    });
}

// ---- 窗口查找 ----
static UIWindow *TTActiveWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if (![c isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)c;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows)
                if (!w.isHidden && w.alpha > 0.01 && w != _statusWindow) return w;
        }
    }
    UIWindow *kw = UIApplication.sharedApplication.keyWindow;
    return (kw != _statusWindow) ? kw : nil;
}

// ---- 视图查找 ----
static UIView *TTFindSkipButtonInView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)root;
        NSString *t = btn.currentTitle ?: btn.titleLabel.text ?: @"";
        for (NSString *kw in _skipKeywords)
            if (t.length > 0 && [t rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) return btn;
    }
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *lb = (UILabel *)root;
        NSString *t = lb.text ?: @"";
        for (NSString *kw in _skipKeywords)
            if (t.length > 0 && [t rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
                UIView *p = lb.superview;
                while (p) { if ([p isKindOfClass:[UIControl class]]) return p; p = p.superview; }
            }
    }
    for (UIView *sub in root.subviews) {
        UIView *f = TTFindSkipButtonInView(sub);
        if (f) return f;
    }
    return nil;
}

static void TTClickView(UIView *v) {
    if ([v isKindOfClass:[UIControl class]]) {
        [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
        TTLog(@"sendActions: %@", v);
    } else {
        [v accessibilityActivate];
        TTLog(@"AX: %@", v);
    }
}

// ---- 自动扫描 ----
static void TTAutoScanTick(void) {
    if (![_currentMode isEqualToString:@"auto"]) return;
    UIWindow *win = TTActiveWindow();
    if (!win) { TTUpdateStatusLabel(@"TT: 等待窗口…", [UIColor colorWithRed:0.8 green:0.6 blue:0.0 alpha:0.8]); return; }
    UIView *btn = TTFindSkipButtonInView(win);
    if (btn) {
        TTClickView(btn);
        TTLog(@"自动点击: %@", NSStringFromClass(btn.class));
        TTUpdateStatusLabel(@"TT: 已点击 ✓", [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:0.8]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([_currentMode isEqualToString:@"auto"])
                TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
        });
    } else {
        TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
    }
}

static void TTStopScan(void) {
    [_scanTimer invalidate]; _scanTimer = nil; _currentMode = @"idle";
    TTUpdateStatusLabel(@"TT: 已停止", [UIColor colorWithWhite:0.3 alpha:0.8]);
    TTLog(@"已停止");
}

static void TTStartAutoScan(void) {
    TTStopScan(); _currentMode = @"auto";
    _scanTimer = [NSTimer scheduledTimerWithTimeInterval:0.8 repeats:YES block:^(NSTimer *t) { TTAutoScanTick(); }];
    [[NSRunLoop mainRunLoop] addTimer:_scanTimer forMode:NSRunLoopCommonModes];
    TTLog(@"自动扫描已启动");
    TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
}

// ---- HID ----
static void TTTapHIDAtPoint(CGPoint pt) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (h) IOHIDEventCreateDigitizerEvent = dlsym(h, "IOHIDEventCreateDigitizerEvent");
    });
    if (!IOHIDEventCreateDigitizerEvent) { TTLog(@"HID FAIL: IOKit nil"); TTUpdateStatusLabel(@"TT: IOKit缺失", [UIColor redColor]); return; }
    SEL sel = NSSelectorFromString(@"_enqueueHIDEvent:");
    UIApplication *app = UIApplication.sharedApplication;
    if (![app respondsToSelector:sel]) { TTLog(@"HID FAIL: selector nil"); TTUpdateStatusLabel(@"TT: 方法缺失", [UIColor redColor]); return; }
    typedef void (*EFn)(id, SEL, IOHIDEventRef);
    EFn enq = (EFn)[app methodForSelector:sel];
    @try {
        IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, mach_absolute_time(), kFinger, 0, 1, kRange|kTouch|kAttr, 0, pt.x, pt.y, 0.0, 0.1, 0.0, true, true, 0);
        enq(app, sel, down);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(kCFAllocatorDefault, mach_absolute_time(), kFinger, 0, 1, kRange|kTouch|kAttr, 0, pt.x, pt.y, 0.0, 0.0, 0.0, true, false, 0);
            enq(app, sel, up); CFRelease(up);
        });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ CFRelease(down); });
        TTLog(@"HID SENT (%.0f,%.0f)", pt.x, pt.y);
        TTUpdateStatusLabel([NSString stringWithFormat:@"HID (%.0f,%.0f)", pt.x, pt.y], [UIColor orangeColor]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1*NSEC_PER_SEC), dispatch_get_main_queue(), ^{ TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]); });
    } @catch (NSException *e) {
        TTLog(@"HID CRASH: %@", e);
        TTUpdateStatusLabel(@"TT: HID崩溃", [UIColor redColor]);
    }
}

// ---- 控制面板 ----
@interface TTPanelHelper : NSObject @end
@implementation TTPanelHelper
+ (void)doTap { TTDoTapFromPanel(); }
@end

static void TTDoTapFromPanel(void) {
    CGFloat x = [_pxField.text floatValue]; if (x <= 0) x = 200;
    CGFloat y = [_pyField.text floatValue]; if (y <= 0) y = 400;
    TTTapHIDAtPoint(CGPointMake(x, y));
    TTLog(@"面板触发 (%.0f,%.0f)", x, y);
}

static void TTShowControlPanel(void) {
    if (_panelWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *c in UIApplication.sharedApplication.connectedScenes)
                if ([c isKindOfClass:[UIWindowScene class]] && c.activationState == UISceneActivationStateForegroundActive)
                { scene = (UIWindowScene *)c; break; }
            if (!scene)
                for (UIScene *c in UIApplication.sharedApplication.connectedScenes)
                    if ([c isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)c; break; }
        }
        if (!scene) return;
        CGFloat sw = UIScreen.mainScreen.bounds.size.width, pw = sw - 32.0, h = 60.0;
        CGFloat y = UIScreen.mainScreen.bounds.size.height - h - 40.0;
        _panelWindow = [[UIWindow alloc] initWithWindowScene:scene];
        _panelWindow.frame = CGRectMake(16, y, pw, h);
        _panelWindow.windowLevel = UIWindowLevelAlert + 99;
        _panelWindow.backgroundColor = [UIColor colorWithWhite:0.06 alpha:0.90];
        _panelWindow.layer.cornerRadius = 12.0; _panelWindow.clipsToBounds = YES;
        UIViewController *vc = [UIViewController new];
        vc.view.backgroundColor = [UIColor clearColor];
        // X label + field
        UILabel *xl = [[UILabel alloc] initWithFrame:CGRectMake(10, 8, 16, 20)];
        xl.text = @"X"; xl.textColor = UIColor.whiteColor; xl.font = [UIFont systemFontOfSize:13];
        [vc.view addSubview:xl];
        UITextField *xf = [[UITextField alloc] initWithFrame:CGRectMake(26, 8, 70, 32)];
        xf.text = @"200"; xf.borderStyle = UITextBorderStyleRoundedRect; xf.keyboardType = UIKeyboardTypeNumberPad;
        xf.textColor = UIColor.whiteColor; xf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        xf.font = [UIFont systemFontOfSize:14]; [vc.view addSubview:xf]; _pxField = xf;
        // Y label + field
        UILabel *yl = [[UILabel alloc] initWithFrame:CGRectMake(104, 8, 16, 20)];
        yl.text = @"Y"; yl.textColor = UIColor.whiteColor; yl.font = [UIFont systemFontOfSize:13];
        [vc.view addSubview:yl];
        UITextField *yf = [[UITextField alloc] initWithFrame:CGRectMake(120, 8, 70, 32)];
        yf.text = @"400"; yf.borderStyle = UITextBorderStyleRoundedRect; yf.keyboardType = UIKeyboardTypeNumberPad;
        yf.textColor = UIColor.whiteColor; yf.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
        yf.font = [UIFont systemFontOfSize:14]; [vc.view addSubview:yf]; _pyField = yf;
        // TAP button
        UIButton *tapBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        tapBtn.frame = CGRectMake(200, 8, pw - 210, 32);
        [tapBtn setTitle:@"TAP" forState:UIControlStateNormal];
        [tapBtn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        tapBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.55 blue:0.92 alpha:1.0];
        tapBtn.layer.cornerRadius = 8; tapBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [tapBtn addTarget:[TTPanelHelper class] action:@selector(doTap) forControlEvents:UIControlEventTouchUpInside];
        [vc.view addSubview:tapBtn];
        _panelWindow.rootViewController = vc;
        _panelWindow.hidden = NO;
        TTLog(@"控制面板已创建");
    });
}

// ---- 命令 ----
static void TTHandleCommand(void) {
    NSDictionary *cmd = [NSDictionary dictionaryWithContentsOfFile:kCommandPath];
    if (![cmd isKindOfClass:[NSDictionary class]]) return;
    NSString *mode = cmd[@"mode"];
    if ([mode isEqualToString:@"auto"]) { TTStartAutoScan(); [@{} writeToFile:kCommandPath atomically:YES]; }
    else if ([mode isEqualToString:@"tap"]) {
        CGFloat x = [cmd[@"x"] isKindOfClass:[NSNumber class]] ? [cmd[@"x"] floatValue] : 0;
        CGFloat y = [cmd[@"y"] isKindOfClass:[NSNumber class]] ? [cmd[@"y"] floatValue] : 0;
        [@{} writeToFile:kCommandPath atomically:YES];
        TTTapHIDAtPoint(CGPointMake(x, y));
    } else if ([mode isEqualToString:@"stop"]) { TTStopScan(); [@{} writeToFile:kCommandPath atomically:YES]; }
}

// ---- 入口 ----
__attribute__((constructor)) static void TrollTouchInit(void) {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docs) docs = @"/var/mobile/Documents";
    kCommandPath = [docs stringByAppendingPathComponent:@"com.trolltouch.command.plist"];
    kLogPath     = [docs stringByAppendingPathComponent:@"com.trolltouch.log.txt"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        _skipKeywords = @[@"跳过", @"关闭", @"知道了", @"好的", @"同意",
                          @"skip", @"close", @"Skip", @"Close",
                          @"领取", @"签到", @"确定", @"允许", @"继续",
                          @"立刻体验", @"立即体验", @"马上体验", @"×", @"✕", @"X"];
        TTLog(@"TrollTouch v2.3 loaded bundle=%@", NSBundle.mainBundle.bundleIdentifier ?: @"?");
        TTLog(@"cmd=%@", kCommandPath);
        TTShowStatusLabel();
        TTShowControlPanel();
        [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *t) { TTHandleCommand(); }];
        int token = 0;
        notify_register_dispatch([kNotifyName cStringUsingEncoding:NSUTF8StringEncoding], &token, dispatch_get_main_queue(), ^(int t) { (void)t; TTHandleCommand(); });
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500*NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            if (!_scanTimer && ![_currentMode isEqualToString:@"auto"]) TTStartAutoScan();
        });
    });
}
