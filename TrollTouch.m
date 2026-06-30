#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach_time.h>

static NSString *kCommandPath;
static NSString *kLogPath;
static NSString * const kNotifyName = @"com.trolltouch.run";

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
static UILabel *_statusLabel;
static UIWindow *_statusWindow;

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
                if ([c isKindOfClass:[UIWindowScene class]] && c.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)c; break;
                }
            }
            if (!scene) {
                for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
                    if ([c isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)c; break; }
                }
            }
        }
        if (!scene) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                TTShowStatusLabel();
            });
            return;
        }

        _statusWindow = [[UIWindow alloc] initWithWindowScene:scene];
        _statusWindow.frame = CGRectMake(8, 50, 160, 22);
        _statusWindow.windowLevel = UIWindowLevelAlert + 100;
        _statusWindow.backgroundColor = [UIColor clearColor];
        _statusWindow.userInteractionEnabled = NO;

        _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 22)];
        _statusLabel.font = [UIFont boldSystemFontOfSize:11];
        _statusLabel.textColor = UIColor.whiteColor;
        _statusLabel.textAlignment = NSTextAlignmentCenter;
        _statusLabel.layer.cornerRadius = 6;
        _statusLabel.clipsToBounds = YES;
        _statusLabel.text = @"TT: 已加载 ✓";
        _statusLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:0.8];
        [_statusWindow addSubview:_statusLabel];
        _statusWindow.hidden = NO;

        TTLog(@"独立状态窗口已创建");
    });
}
    @try {
        [_logHandle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [_logHandle synchronizeFile];
    } @catch (NSException *e) {}
    NSLog(@"[TT] %@", msg);
}

static UIWindow *TTActiveWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *c in UIApplication.sharedApplication.connectedScenes) {
            if (![c isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)c;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (!w.isHidden && w.alpha > 0.01 && w != _statusWindow) return w;
            }
        }
    }
    UIWindow *kw = UIApplication.sharedApplication.keyWindow;
    return (kw != _statusWindow) ? kw : nil;
}

static UIView *TTFindSkipButtonInView(UIView *root) {
    if (!root) return nil;
    if ([root isKindOfClass:[UIButton class]]) {
        UIButton *btn = (UIButton *)root;
        NSString *t = btn.currentTitle ?: btn.titleLabel.text ?: @"";
        for (NSString *kw in _skipKeywords) {
            if (t.length > 0 && [t rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return btn;
            }
        }
    }
    if ([root isKindOfClass:[UILabel class]]) {
        UILabel *lb = (UILabel *)root;
        NSString *t = lb.text ?: @"";
        for (NSString *kw in _skipKeywords) {
            if (t.length > 0 && [t rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound) {
                UIView *parent = lb.superview;
                while (parent) {
                    if ([parent isKindOfClass:[UIControl class]]) return parent;
                    parent = parent.superview;
                }
            }
        }
    }
    for (UIView *sub in root.subviews) {
        if (sub == _statusLabel) continue;
        UIView *found = TTFindSkipButtonInView(sub);
        if (found) return found;
    }
    return nil;
}

static void TTClickView(UIView *v) {
    if ([v isKindOfClass:[UIControl class]]) {
        [(UIControl *)v sendActionsForControlEvents:UIControlEventTouchUpInside];
        TTLog(@"sendActions ok: %@", v);
        return;
    }
    if ([v respondsToSelector:@selector(accessibilityActivate)]) {
        [v accessibilityActivate];
        TTLog(@"AX ok: %@", v);
        return;
    }
    TTLog(@"cannot click: %@", v);
}

static void TTUpdateStatusLabel(NSString *text, UIColor *color) {
    if (!_statusLabel) return;
    _statusLabel.text = text;
    _statusLabel.backgroundColor = color;
}

static void TTAutoScanTick(void) {
    if (![_currentMode isEqualToString:@"auto"]) return;
    UIWindow *win = TTActiveWindow();
    if (!win) {
        TTUpdateStatusLabel(@"TT: 等待窗口…", [UIColor colorWithRed:0.8 green:0.6 blue:0.0 alpha:0.8]);
        return;
    }
    UIView *btn = TTFindSkipButtonInView(win);
    if (btn) {
        TTClickView(btn);
        TTLog(@"点击: %@ title=%@", NSStringFromClass(btn.class),
              [btn isKindOfClass:[UIButton class]] ? [(UIButton *)btn currentTitle] : @"");
        TTUpdateStatusLabel(@"TT: 已点击 ✓", [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:0.8]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if ([_currentMode isEqualToString:@"auto"]) {
                TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
            }
        });
    } else {
        TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
    }
}

static void TTStopScan(void) {
    [_scanTimer invalidate];
    _scanTimer = nil;
    _currentMode = @"idle";
    TTUpdateStatusLabel(@"TT: 已停止", [UIColor colorWithWhite:0.3 alpha:0.8]);
    TTLog(@"已停止");
}

static void TTStartAutoScan(void) {
    TTStopScan();
    _currentMode = @"auto";
    _scanTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) {
        TTAutoScanTick();
    }];
    [[NSRunLoop mainRunLoop] addTimer:_scanTimer forMode:NSRunLoopCommonModes];
    TTLog(@"自动扫描已启动 (1秒间隔)");
    TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
}

#pragma mark - HID

static void TTTapHIDAtPoint(CGPoint pt) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (h) IOHIDEventCreateDigitizerEvent = dlsym(h, "IOHIDEventCreateDigitizerEvent");
    });
    if (!IOHIDEventCreateDigitizerEvent) {
        TTLog(@"HID FAIL: IOKitCreateDigitizer nil");
        TTUpdateStatusLabel(@"TT: HID IOKit缺失", [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.8]);
        return;
    }
    SEL sel = NSSelectorFromString(@"_enqueueHIDEvent:");
    UIApplication *app = UIApplication.sharedApplication;
    if (![app respondsToSelector:sel]) {
        TTLog(@"HID FAIL: _enqueueHIDEvent: not found");
        TTUpdateStatusLabel(@"TT: HID方法缺失", [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.8]);
        return;
    }
    typedef void (*EFn)(id, SEL, IOHIDEventRef);
    EFn enq = (EFn)[app methodForSelector:sel];

    @try {
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

        TTLog(@"HID SENT: (%.0f,%.0f) ent=%@ sel=_enqueueHIDEvent:",
              pt.x, pt.y, [app respondsToSelector:sel] ? @"ok" : @"nil");
        TTUpdateStatusLabel(
            [NSString stringWithFormat:@"TT: HID (%.0f,%.0f)", pt.x, pt.y],
            [UIColor colorWithRed:0.9 green:0.5 blue:0.0 alpha:0.8]);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            TTUpdateStatusLabel(@"TT: 扫描中…", [UIColor colorWithRed:0.1 green:0.4 blue:0.8 alpha:0.8]);
        });
    } @catch (NSException *e) {
        TTLog(@"HID CRASH: %@", e);
        TTUpdateStatusLabel(@"TT: HID崩溃", [UIColor colorWithRed:0.85 green:0.2 blue:0.2 alpha:0.8]);
    }
}

#pragma mark - command

static void TTHandleCommand(void) {
    NSDictionary *cmd = [NSDictionary dictionaryWithContentsOfFile:kCommandPath];
    if (![cmd isKindOfClass:[NSDictionary class]]) return;
    NSString *mode = cmd[@"mode"];
    if ([mode isEqualToString:@"auto"]) { TTStartAutoScan(); }
    else if ([mode isEqualToString:@"tap"]) {
        CGFloat x = [cmd[@"x"] isKindOfClass:[NSNumber class]] ? [cmd[@"x"] floatValue] : 0;
        CGFloat y = [cmd[@"y"] isKindOfClass:[NSNumber class]] ? [cmd[@"y"] floatValue] : 0;
        TTTapHIDAtPoint(CGPointMake(x, y));
    } else if ([mode isEqualToString:@"stop"]) { TTStopScan(); }
}

#pragma mark - init

static void TTShowStatusLabel(void) {
    UIWindow *win = TTActiveWindow();
    if (!win) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            TTShowStatusLabel();
        });
        return;
    }
    if (_statusLabel) return;
    _statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, 50, 160, 22)];
    _statusLabel.font = [UIFont boldSystemFontOfSize:11];
    _statusLabel.textColor = UIColor.whiteColor;
    _statusLabel.textAlignment = NSTextAlignmentCenter;
    _statusLabel.layer.cornerRadius = 6;
    _statusLabel.clipsToBounds = YES;
    _statusLabel.userInteractionEnabled = NO;
    _statusLabel.text = @"TT: 已加载 ✓";
    _statusLabel.backgroundColor = [UIColor colorWithRed:0.0 green:0.6 blue:0.2 alpha:0.8];
    [win addSubview:_statusLabel];
    TTLog(@"状态标签已显示");
}

__attribute__((constructor)) static void TrollTouchInit(void) {
    NSString *docs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    if (!docs) docs = @"/var/mobile/Documents";
    kCommandPath = [docs stringByAppendingPathComponent:@"com.trolltouch.command.plist"];
    kLogPath     = [docs stringByAppendingPathComponent:@"com.trolltouch.log.txt"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _skipKeywords = @[@"跳过", @"关闭", @"知道了", @"好的", @"同意",
                          @"skip", @"close", @"Skip", @"Close",
                          @"领取", @"签到", @"确定", @"允许", @"继续",
                          @"立刻体验", @"立即体验", @"马上体验",
                          @"×", @"✕", @"X"];

        TTLog(@"TrollTouch v2.1 loaded");
        TTLog(@"bundle=%@", NSBundle.mainBundle.bundleIdentifier ?: @"?");
        TTLog(@"logPath=%@", kLogPath);

        TTShowStatusLabel();

        int token = 0;
        notify_register_dispatch(kNotifyName.UTF8String, &token, dispatch_get_main_queue(), ^(int t) {
            (void)t; TTHandleCommand();
        });

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!_scanTimer && ![_currentMode isEqualToString:@"auto"]) {
                TTStartAutoScan();
                TTLog(@"自动扫描已启动");
            }
        });
    });
}
