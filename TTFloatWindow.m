#import "TTFloatWindow.h"
#import "TTTouchSimulator.h"

@interface TTFloatWindow ()
@property (nonatomic, strong) UIWindow *window;
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

        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
                if ([candidate isKindOfClass:[UIWindowScene class]] && candidate.activationState == UISceneActivationStateForegroundActive) {
                    scene = (UIWindowScene *)candidate;
                    break;
                }
            }
        }
        if (!scene) {
            return;
        }

        CGRect frame = CGRectMake(20, 160, 120, 120);
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        window.frame = frame;
        window.windowLevel = UIWindowLevelAlert + 1;
        window.backgroundColor = [UIColor colorWithWhite:0.08 alpha:0.90];
        window.layer.cornerRadius = 12.0;
        window.clipsToBounds = YES;

        UIViewController *controller = [UIViewController new];
        controller.view.backgroundColor = [UIColor clearColor];
        window.rootViewController = controller;

        UIButton *tapButton = [UIButton buttonWithType:UIButtonTypeSystem];
        tapButton.frame = CGRectMake(12, 12, 96, 42);
        [tapButton setTitle:@"Tap" forState:UIControlStateNormal];
        [tapButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        tapButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.85 alpha:1.0];
        tapButton.layer.cornerRadius = 8.0;
        [tapButton addTarget:self action:@selector(handleTapButton) forControlEvents:UIControlEventTouchUpInside];
        [controller.view addSubview:tapButton];

        UIButton *hideButton = [UIButton buttonWithType:UIButtonTypeSystem];
        hideButton.frame = CGRectMake(12, 68, 96, 34);
        [hideButton setTitle:@"Hide" forState:UIControlStateNormal];
        [hideButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        hideButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        hideButton.layer.cornerRadius = 8.0;
        [hideButton addTarget:self action:@selector(handleHideButton) forControlEvents:UIControlEventTouchUpInside];
        [controller.view addSubview:hideButton];

        self.window = window;
        [self.window makeKeyAndVisible];
    });
}

- (void)handleTapButton {
    CGPoint point = CGPointMake(100, 300);
    [[TTTouchSimulator sharedInstance] tapAtPoint:point duration:0.05];
}

- (void)handleHideButton {
    self.window.hidden = YES;
}

@end
