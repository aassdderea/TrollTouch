#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <notify.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static NSString * const kCommandPath = @"/var/mobile/Library/Preferences/com.trolltouch.command.plist";
static NSString * const kNotifyName = @"com.trolltouch.run";

@interface TrollTouchCommand : NSObject
@property (nonatomic, assign) CGFloat x;
@property (nonatomic, assign) CGFloat y;
@property (nonatomic, assign) NSTimeInterval duration;
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
    if (![x isKindOfClass:[NSNumber class]] || ![y isKindOfClass:[NSNumber class]]) {
        return command;
    }

    command.x = x.doubleValue;
    command.y = y.doubleValue;
    command.duration = [duration isKindOfClass:[NSNumber class]] ? duration.doubleValue : 0.05;
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

@interface UIEvent (Private)
- (void)_setHIDEvent:(void *)event;
@end

static id CreateTouchEventObject(void) {
    Class eventClass = NSClassFromString(@"UITouchesEvent");
    return [eventClass new];
}

static void DispatchTouch(UITouchPhase phase, CGPoint point) {
    UIWindow *window = UIApplication.sharedApplication.keyWindow;
    if (!window) {
        for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
            if (!candidate.isHidden) {
                window = candidate;
                break;
            }
        }
    }
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

    id event = CreateTouchEventObject();
    if (!event) {
        return;
    }

    NSMutableSet *touches = [NSMutableSet setWithObject:touch];
    SEL selector = NSSelectorFromString(@"_addTouch:forDelayedDelivery:");
    if ([event respondsToSelector:selector]) {
        typedef void (*AddTouchMsgSend)(id, SEL, id, BOOL);
        ((AddTouchMsgSend)objc_msgSend)(event, selector, touch, NO);
    }

    [[UIApplication sharedApplication] sendEvent:event];
    (void)touches;
}

static void RunTap(CGPoint point, NSTimeInterval duration) {
    dispatch_async(dispatch_get_main_queue(), ^{
        DispatchTouch(UITouchPhaseBegan, point);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            DispatchTouch(UITouchPhaseEnded, point);
        });
    });
}

static void HandleCommand(void) {
    TrollTouchCommand *command = [TrollTouchCommand loadFromDisk];
    if (!command.valid) {
        return;
    }
    RunTap(CGPointMake(command.x, command.y), command.duration);
}

__attribute__((constructor)) static void TrollTouchInit(void) {
    int token = 0;
    notify_register_dispatch(kNotifyName.UTF8String, &token, dispatch_get_main_queue(), ^(int unusedToken) {
        HandleCommand();
    });
}
