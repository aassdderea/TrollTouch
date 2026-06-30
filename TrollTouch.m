#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSString * const kCommandPath = @"/var/mobile/Library/Preferences/com.trolltouch.command.plist";
static NSString * const kNotifyName = @"com.trolltouch.run";
static NSString * const kPingNotifyName = @"com.trolltouch.ping";
static NSString * const kResultPath = @"/var/mobile/Library/Preferences/com.trolltouch.result.plist";

@interface TrollTouchCommand : NSObject
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, assign) BOOL valid;
+ (instancetype)loadFromDisk;
@end

@implementation TrollTouchCommand
+ (instancetype)loadFromDisk {
    TrollTouchCommand *command = [TrollTouchCommand new];
    NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:kCommandPath];
    if (![payload isKindOfClass:[NSDictionary class]]) {
        return command;
    }

    NSNumber *x = payload[@"x"];
    NSNumber *y = payload[@"y"];
    NSNumber *duration = payload[@"duration"];
    NSString *type = [payload[@"type"] isKindOfClass:[NSString class]] ? payload[@"type"] : @"tap";
    if (![x isKindOfClass:[NSNumber class]] || ![y isKindOfClass:[NSNumber class]]) {
        return command;
    }

    command.x = x.doubleValue;
    command.y = y.doubleValue;
    command.duration = [duration isKindOfClass:[NSNumber class]] ? duration.doubleValue : 0.05;
    command.type = type;
    command.valid = YES;
    return command;
}
@end

@interface UITouch (Private)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)tapCount;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)resetPrevious;
- (void)setPhase:(UITouchPhase)phase;
@end

static UIWindow *TTActiveWindow(void) {
    UIApplication *application = UIApplication.sharedApplication;
    if (!application) {
        return nil;
    }

    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in application.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }
            UIWindowScene *windowScene = (UIWindowScene *)scene;
            if (windowScene.activationState != UISceneActivationStateForegroundActive) {
                continue;
            }
            for (UIWindow *window in windowScene.windows) {
                if (!window.isHidden && window.alpha > 0.01) {
                    return window;
                }
            }
        }
    }

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (application.keyWindow && !application.keyWindow.isHidden) {
        return application.keyWindow;
    }
#pragma clang diagnostic pop

    for (UIWindow *window in application.windows) {
        if (!window.isHidden && window.alpha > 0.01) {
            return window;
        }
    }
    return nil;
}

static id TTCreateTouchesEvent(void) {
    Class eventClass = NSClassFromString(@"UITouchesEvent");
    return eventClass ? [eventClass new] : nil;
}

static void TTWriteResult(NSDictionary *result) {
    [result writeToFile:kResultPath atomically:YES];
}

static void TTDispatchTouch(UITouchPhase phase, CGPoint point) {
    UIWindow *window = TTActiveWindow();
    if (!window) {
        TTWriteResult(@{@"ok": @NO, @"reason": @"window_not_found"});
        return;
    }

    UIView *view = [window hitTest:point withEvent:nil];
    if (!view) {
        view = window;
    }

    UITouch *touch = [UITouch new];
    [touch setWindow:window];
    [touch setView:view];
    [touch setTapCount:1];
    [touch setLocationInWindow:point resetPrevious:YES];
    [touch setPhase:phase];
    [touch setTimestamp:NSProcessInfo.processInfo.systemUptime];

    id event = TTCreateTouchesEvent();
    if (!event) {
        TTWriteResult(@{@"ok": @NO, @"reason": @"event_create_failed"});
        return;
    }

    SEL addTouchSelector = NSSelectorFromString(@"_addTouch:forDelayedDelivery:");
    if ([event respondsToSelector:addTouchSelector]) {
        typedef void (*TTAddTouchFn)(id, SEL, id, BOOL);
        ((TTAddTouchFn)objc_msgSend)(event, addTouchSelector, touch, NO);
    } else {
        TTWriteResult(@{@"ok": @NO, @"reason": @"event_add_touch_missing"});
        return;
    }

    [[UIApplication sharedApplication] sendEvent:event];
    TTWriteResult(@{
        @"ok": @YES,
        @"phase": phase == UITouchPhaseBegan ? @"began" : @"ended",
        @"x": @(point.x),
        @"y": @(point.y),
        @"bundle": NSBundle.mainBundle.bundleIdentifier ?: @"unknown"
    });
}

static void TTRunTap(CGPoint point, NSTimeInterval duration) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TTDispatchTouch(UITouchPhaseBegan, point);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            TTDispatchTouch(UITouchPhaseEnded, point);
        });
    });
}

static void TTHandlePing(void) {
    UIApplication *application = UIApplication.sharedApplication;
    NSString *bundle = NSBundle.mainBundle.bundleIdentifier ?: @"unknown";
    UIWindow *window = TTActiveWindow();
    CGSize size = window.bounds.size;

    TTWriteResult(@{
        @"ok": @YES,
        @"type": @"ping",
        @"bundle": bundle,
        @"state": @(application.applicationState),
        @"windowFound": @(window != nil),
        @"width": @(size.width),
        @"height": @(size.height)
    });
}

static void TTHandleCommand(void) {
    TrollTouchCommand *command = [TrollTouchCommand loadFromDisk];
    if (!command.valid) {
        TTWriteResult(@{@"ok": @NO, @"reason": @"invalid_command"});
        return;
    }

    if ([command.type isEqualToString:@"tap"]) {
        TTRunTap(CGPointMake(command.x, command.y), command.duration);
        return;
    }

    TTWriteResult(@{@"ok": @NO, @"reason": @"unsupported_type"});
}

__attribute__((constructor)) static void TrollTouchInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        TTWriteResult(@{
            @"ok": @YES,
            @"type": @"loaded",
            @"bundle": NSBundle.mainBundle.bundleIdentifier ?: @"unknown"
        });
    });

    int runToken = 0;
    notify_register_dispatch(kNotifyName.UTF8String, &runToken, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        TTHandleCommand();
    });

    int pingToken = 0;
    notify_register_dispatch(kPingNotifyName.UTF8String, &pingToken, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        TTHandlePing();
    });
}
