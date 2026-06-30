#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static UIWindow *TTGetWindow(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (ws.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *w in ws.windows) {
                if (!w.isHidden && w.alpha > 0.01) return w;
            }
        }
    }
    return UIApplication.sharedApplication.keyWindow;
}

BOOL TTTapAtPoint(CGPoint point) {
    UIWindow *window = TTGetWindow();
    if (!window) return NO;

    UIView *target = [window hitTest:point withEvent:nil];
    if (!target) target = window;

    BOOL activated = [target accessibilityActivate];
    NSLog(@"[TrollTouch] tap (%f,%f) -> view=%@ activated=%d", point.x, point.y, NSStringFromClass(target.class), activated);
    return activated;
}

__attribute__((constructor)) static void TrollTouchMinimalInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        BOOL result = TTTapAtPoint(CGPointMake(100, 300));
        NSLog(@"[TrollTouch] 3s auto-test result=%d", result);
    });
}
