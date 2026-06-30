#import "TTTouchSimulator.h"
#import <objc/message.h>

@interface UITouch (TTPrivate)
- (void)setWindow:(UIWindow *)window;
- (void)setView:(UIView *)view;
- (void)setTapCount:(NSUInteger)tapCount;
- (void)setTimestamp:(NSTimeInterval)timestamp;
- (void)setLocationInWindow:(CGPoint)location resetPrevious:(BOOL)resetPrevious;
- (void)setPhase:(UITouchPhase)phase;
@end

@implementation TTTouchSimulator

+ (instancetype)sharedInstance {
    static TTTouchSimulator *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [TTTouchSimulator new];
    });
    return instance;
}

- (UIWindow *)activeWindow {
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

- (id)createTouchesEvent {
    Class eventClass = NSClassFromString(@"UITouchesEvent");
    return eventClass ? [eventClass new] : nil;
}

- (void)dispatchTouchWithPhase:(UITouchPhase)phase point:(CGPoint)point {
    UIWindow *window = [self activeWindow];
    if (!window) {
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

    id event = [self createTouchesEvent];
    if (!event) {
        return;
    }

    SEL addTouchSelector = NSSelectorFromString(@"_addTouch:forDelayedDelivery:");
    if ([event respondsToSelector:addTouchSelector]) {
        typedef void (*TTAddTouchFn)(id, SEL, id, BOOL);
        ((TTAddTouchFn)objc_msgSend)(event, addTouchSelector, touch, NO);
        [[UIApplication sharedApplication] sendEvent:event];
    }
}

- (BOOL)tapAtPoint:(CGPoint)point duration:(NSTimeInterval)duration {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dispatchTouchWithPhase:UITouchPhaseBegan point:point];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self dispatchTouchWithPhase:UITouchPhaseEnded point:point];
        });
    });
    return YES;
}

@end
