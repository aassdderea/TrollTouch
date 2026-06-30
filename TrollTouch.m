#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

static NSString * const kCommandPath = @"/var/mobile/Library/Preferences/com.trolltouch.command.plist";
static NSString * const kLogPath     = @"/var/mobile/Library/Preferences/com.trolltouch.log.txt";
static NSString * const kNotifyName  = @"com.trolltouch.run";

typedef struct __IOHIDEvent *IOHIDEventRef;
static IOHIDEventRef (*IOHIDEventCreateDigitizerEvent)(
    CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Boolean, Boolean, uint32_t
) = NULL;

#define kFinger 2
#define kRange  (1<<0)
#define kTouch  (1<<1)
#define kAttr   (1<<3)

static NSFileHandle *_logHandle;
static NSTimer *_scanTimer;
static NSArray *_skipKeywords;
static NSString *_currentMode;

static void TTLoadIOKit(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (h) {
            IOHIDEventCreateDigitizerEvent = dlsym(h, "IOHIDEventCreateDigitizerEvent");
        }
    });
}

static void TTLog(NSString *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSDateFormatter *df = [NSDateFormatter new];
    df.dateFormat = @"HH:mm:ss";
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [df stringFromDate:[NSDate date]], msg];
    if (!_logHandle) {
        [[NSFileManager defaultManager] createFileAtPath:kLogPath contents:nil attributes:nil];
        _logHandle = [NSFileHandle fileHandleForWritingAtPath:kLogPath];
        [_logHandle seekToEndOfFile];
    }
    @try { [_logHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; }
    @catch (NSException *e) { NSLog(@"[TT] log err: %@", e); }
    NSLog(@"[TT] %@", msg);
}

static UIWindow *TTActiveWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if (![c isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)c;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (!w.isHidden && w.alpha > 0.01) return w;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow;
}

static UIView *TTFindSkipButtonInView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)root;
        NSString *t = btn.currentTitle ?: btn.titleLabel.text ?: @"";
        for (NSString *kw in _skipKeywords) {
            if (t.length > 0 && [t rangeOfString:kw].location != NSNotFound) {
                return btn;
            }
        }
    }
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *lb = (UILabel *)root;
        NSString *t = lb.text ?: @"";
        for (NSString *kw in _skipKeywords) {
            if (t.length > 0 && [t rangeOfString:kw].location != NSNotFound) {
                UIView *parent = lb.superview;
                while (parent) {
                    if ([parent isKindOfClass:[UIControl class]]) return parent;
                    parent = parent.superview;
                }
            }
        }
    }
    for (UIView *sub in root.subviews) {
        UIView *found = TTFindSkipButtonInView(sub);
        if (found) return found;
    }
    return nil;
}

static void TTClickView(UIView *v) {
    if ([v isKindOfClass:[UIControl class]]) {
        [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
        TTLog(@"点击按钮: %@", NSStringFromClass(v.class));
        return;
    }
    [v accessibilityActivate];
    TTLog(@"AX激活: %@", NSStringFromClass(v.class));
}

static void TTAutoScanTick(void) {
    if (![_currentMode isEqualToString:@"auto"]) return;
    UIWindow *win = TTActiveWindow();
    if (!win) return;
    UIView *btn = TTFindSkipButtonInView(win);
    if (btn) {
        TTClickView(btn);
        TTLog(@"自动跳过成功: %@", btn);
        [btn.superview setNeedsLayout]; // 确保UI更新
    }
}

static void TTStartAutoScan(void) {
    TTStopScan();
    _currentMode = @"auto";
    _scanTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        TTAutoScanTick();
    }];
    [[NSRunLoop mainRunLoop] addTimer:_scanTimer forMode:NSRunLoopCommonModes];
    TTLog(@"自动扫描已启动 (间隔1秒)");
}

static void TTStopScan(void) {
    [_scanTimer invalidate];
    _scanTimer = nil;
    _currentMode = @"idle";
}

#pragma mark - HID

static void TTTapHIDAtPoint(CGPoint pt) {
    TTLoadIOKit();
    if (!IOHIDEventCreateDigitizerEvent) {
        TTLog(@"HID: IOKit 加载失败");
        return;
    }
    SEL sel = NSSelectorFromString(@"_enqueueHIDEvent:");
    UIApplication *app = UIApplication.sharedApplication;
    if (![app respondsToSelector:sel]) {
        TTLog(@"HID: _enqueueHIDEvent: 不存在");
        return;
    }
    typedef void (*EFn)(id, SEL, IOHIDEventRef);
    EFn enq = (EFn)[app methodForSelector:sel];

    IOHIDEventRef down = IOHIDEventCreateDigitizerEvent(
        kCFAllocatorDefault, mach_absolute_time(),
        kFinger, 0, 1, kRange | kTouch | kAttr,
        0, pt.x, pt.y, 0.0, 0.1, 0.0, true, true, 0);
    enq(app, sel, down);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 50 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        IOHIDEventRef up = IOHIDEventCreateDigitizerEvent(
            kCFAllocatorDefault, mach_absolute_time(),
            kFinger, 0, 1, kRange | kTouch | kAttr,
            0, pt.x, pt.y, 0.0, 0.0, 0.0, true, false, 0);
        enq(app, sel, up);
        CFRelease(up);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 120 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        CFRelease(down);
    });
    TTLog(@"HID: 点击 (%.0f, %.0f)", pt.x, pt.y);
}

#pragma mark - command

static void TTHandleCommand(void) {
    NSDictionary *cmd = [NSDictionary dictionaryWithContentsOfFile:kCommandPath];
    if (![cmd isKindOfClass:[NSDictionary class]]) return;
    NSString *mode = cmd[@"mode"];
    if (![mode isKindOfClass:[NSString class]]) return;

    if ([mode isEqualToString:@"auto"]) {
        TTStartAutoScan();
    } else if ([mode isEqualToString:@"tap"]) {
        CGFloat x = [cmd[@"x"] isKindOfClass:[NSNumber class]] ? [cmd[@"x"] floatValue] : 0;
        CGFloat y = [cmd[@"y"] isKindOfClass:[NSNumber class]] ? [cmd[@"y"] floatValue] : 0;
        TTTapHIDAtPoint(CGPointMake(x, y));
    } else if ([mode isEqualToString:@"stop"]) {
        TTStopScan();
        TTLog(@"已停止");
    }
}

#pragma mark - init

__attribute__((constructor)) static void TrollTouchInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _skipKeywords = @[@"跳过", @"关闭", @"知道了", @"好的", @"同意",
                          @"skip", @"close", @"Skip", @"Close",
                          @"领取", @"签到", @"确定", @"允许", @"继续",
                          @"立刻体验", @"立即体验", @"马上体验"];
        TTLog(@"TrollTouch loaded, bundle=%@", NSBundle.mainBundle.bundleIdentifier ?: @"?");
        TTLog(@"keywords=%@", [_skipKeywords componentsJoinedByString:@", "]);

        int token = 0;
        notify_register_dispatch(kNotifyName.UTF8String, &token, dispatch_get_main_queue(), ^(int t) {
            (void)t;
            TTHandleCommand();
        });

        // ESign installed App → auto-start scanner 3 seconds after launch
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!_scanTimer && ![_currentMode isEqualToString:@"auto"]) {
                TTStartAutoScan();
                TTLog(@"3秒后自动启动扫描");
            }
        });
    });
}
