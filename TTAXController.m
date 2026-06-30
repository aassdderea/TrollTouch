#import "TTAXController.h"
#import <dlfcn.h>

typedef const void *AXUIElementRef;
typedef int AXError;

static AXUIElementRef (*AXUIElementCreateSystemWide)(void) = NULL;
static AXUIElementRef (*AXUIElementCopyElementAtPosition)(AXUIElementRef, float, float) = NULL;
static AXError (*AXUIElementPerformAction)(AXUIElementRef, CFStringRef) = NULL;
static CFTypeRef (*AXUIElementCopyAttributeValue)(AXUIElementRef, CFStringRef, void **) = NULL;

static int (*_AXSAccessibilityPreference)(void) = NULL;
static void (*_AXSSetAccessibilityPreference)(int) = NULL;

@interface TTAXController ()
@property (nonatomic,assign) BOOL axOK;
@end

@implementation TTAXController

+ (instancetype)shared {
    static TTAXController *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [TTAXController new]; });
    return s;
}

- (void)log:(NSString *)m { if (self.logBlock) self.logBlock(m); }

- (BOOL)setupAX {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *ax = dlopen("/System/Library/PrivateFrameworks/AXRuntime.framework/AXRuntime", RTLD_NOW);
        if (ax) {
            AXUIElementCreateSystemWide = dlsym(ax, "AXUIElementCreateSystemWide");
            AXUIElementCopyElementAtPosition = dlsym(ax, "AXUIElementCopyElementAtPosition");
            AXUIElementPerformAction = dlsym(ax, "AXUIElementPerformAction");
            AXUIElementCopyAttributeValue = dlsym(ax, "AXUIElementCopyAttributeValue");
        }
        void *au = dlopen("/System/Library/PrivateFrameworks/AccessibilityUtilities.framework/AccessibilityUtilities", RTLD_NOW);
        if (au) {
            _AXSAccessibilityPreference = dlsym(au, "_AXSAccessibilityPreference");
            _AXSSetAccessibilityPreference = dlsym(au, "_AXSSetAccessibilityPreference");
        }
        self.axOK = (AXUIElementCreateSystemWide != NULL &&
                     AXUIElementCopyElementAtPosition != NULL &&
                     AXUIElementPerformAction != NULL);
    });
    return self.axOK;
}

- (BOOL)checkAccess {
    if (![self setupAX]) { [self log:@"AX Runtime not loaded"]; return NO; }
    if (_AXSAccessibilityPreference) {
        int val = _AXSAccessibilityPreference();
        [self log:[NSString stringWithFormat:@"AX pref value=%d", val]];
        if (val == 0) {
            [self log:@"辅助功能未授权，请去 设置→辅助功能 开启"];
            return NO;
        }
    }
    if (!self.axOK) { [self log:@"AX functions missing"]; return NO; }
    [self log:@"AX ready"];
    return YES;
}

- (void)tapAt:(CGPoint)point {
    if (!self.axOK && ![self setupAX]) {
        [self log:@"AX unavailable"];
        return;
    }
    AXUIElementRef sys = AXUIElementCreateSystemWide();
    if (!sys) { [self log:@"CreateSystemWide failed"]; return; }

    AXUIElementRef el = AXUIElementCopyElementAtPosition(sys, (float)point.x, (float)point.y);
    if (el) {
        CFStringRef act = CFSTR("AXPress");
        AXError ret = AXUIElementPerformAction(el, act);
        [self log:[NSString stringWithFormat:@"AX press at (%.0f,%.0f) ret=%d", point.x, point.y, ret]];
        CFRelease(el);
    } else {
        [self log:[NSString stringWithFormat:@"AX no element at (%.0f,%.0f)", point.x, point.y]];
    }
    CFRelease(sys);
}

@end
