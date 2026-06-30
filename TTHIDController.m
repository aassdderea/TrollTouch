#import "TTHIDController.h"
#import <dlfcn.h>
#import <mach/mach_time.h>

typedef struct __IOHIDEvent *IOHIDEventRef;
typedef struct __IOHIDEventSystemClient *IOHIDEventSystemClientRef;

static IOHIDEventRef (*pCreateDigitizer)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t,
    CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, Boolean, Boolean, uint32_t) = NULL;

static IOHIDEventSystemClientRef (*pSystemClientCreate)(CFAllocatorRef) = NULL;
static void (*pSystemClientSchedule)(IOHIDEventSystemClientRef, dispatch_queue_t) = NULL;
static int  (*pSystemClientDispatch)(IOHIDEventSystemClientRef, IOHIDEventRef) = NULL;

#define kFinger      2
#define kRange       (1<<0)
#define kTouch       (1<<1)
#define kAttr        (1<<3)

@interface TTHIDController ()
@property (nonatomic, assign) IOHIDEventSystemClientRef client;
@property (nonatomic, assign) BOOL repeating;
@property (nonatomic, copy) void(^logBlock)(NSString *);
@end

@implementation TTHIDController

+ (instancetype)shared {
    static TTHIDController *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [TTHIDController new]; });
    return s;
}

- (void)setLogHandler:(void(^)(NSString *))block { self.logBlock = block; }
- (void)log:(NSString *)m { if (self.logBlock) self.logBlock(m); }

- (BOOL)setup {
    static dispatch_once_t once;
    __block BOOL ok = NO;
    dispatch_once(&once, ^{
        void *io = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (io) {
            pCreateDigitizer     = dlsym(io, "IOHIDEventCreateDigitizerEvent");
            pSystemClientCreate   = dlsym(io, "IOHIDEventSystemClientCreate");
            pSystemClientSchedule = dlsym(io, "IOHIDEventSystemClientScheduleWithDispatchQueue");
            pSystemClientDispatch = dlsym(io, "IOHIDEventSystemClientDispatchEvent");
        }
        if (pSystemClientCreate && pSystemClientSchedule && pSystemClientDispatch && pCreateDigitizer) {
            IOHIDEventSystemClientRef c = pSystemClientCreate(kCFAllocatorDefault);
            if (c) {
                pSystemClientSchedule(c, dispatch_get_main_queue());
                self.client = c;
                ok = YES;
            }
        }
    });
    return ok;
}

- (IOHIDEventRef)_event:(CGPoint)p phase:(BOOL)touchDown {
    return pCreateDigitizer(
        kCFAllocatorDefault, mach_absolute_time(),
        kFinger, 0, 1,
        touchDown ? (kRange | kTouch | kAttr) : (kRange | kTouch | kAttr),
        0, p.x, p.y, 0.0, touchDown ? 0.1 : 0.0, 0.0, true, touchDown, 0);
}

- (int)_dispatch:(IOHIDEventRef)ev label:(NSString *)label {
    if (!self.client) return -999;
    int ret = pSystemClientDispatch(self.client, ev);
    [self log:[NSString stringWithFormat:@"HID %@ ret=%d", label, ret]];
    return ret;
}

- (void)tapAt:(CGPoint)pt {
    if (!self.client) { [self log:@"HID client nil"]; return; }
    IOHIDEventRef d = [self _event:pt phase:YES];
    [self _dispatch:d label:[NSString stringWithFormat:@"down(%.0f,%.0f)", pt.x, pt.y]];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        IOHIDEventRef u = [self _event:pt phase:NO];
        [self _dispatch:u label:[NSString stringWithFormat:@"up(%.0f,%.0f)", pt.x, pt.y]];
        CFRelease(u);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        CFRelease(d);
    });
}

- (void)startRepeating:(CGPoint)pt interval:(NSTimeInterval)sec {
    [self stopRepeating];
    if (!self.client) { [self log:@"HID client nil, cannot repeat"]; return; }
    self.repeating = YES;
    [self _repeatTick:pt interval:sec];
}

- (void)_repeatTick:(CGPoint)pt interval:(NSTimeInterval)sec {
    if (!self.repeating) return;
    [self tapAt:pt];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(sec * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _repeatTick:pt interval:sec];
    });
}

- (void)stopRepeating {
    self.repeating = NO;
    [self log:@"stopped"];
}

- (BOOL)isRepeating { return self.repeating; }

- (void)swipeFrom:(CGPoint)from to:(CGPoint)to steps:(NSInteger)steps duration:(NSTimeInterval)dur {
    if (!self.client || steps < 1) return;
    NSTimeInterval iv = dur / (NSTimeInterval)steps;
    [self _swipeStep:from to:to step:0 total:steps interval:iv];
}

- (void)_swipeStep:(CGPoint)from to:(CGPoint)to step:(NSInteger)i total:(NSInteger)n interval:(NSTimeInterval)iv {
    if (i > n) return;
    CGFloat r = (CGFloat)i / n;
    CGPoint p = CGPointMake(from.x + (to.x - from.x) * r, from.y + (to.y - from.y) * r);
    if (i == 0) {
        IOHIDEventRef d = [self _event:p phase:YES];
        [self _dispatch:d label:[NSString stringWithFormat:@"sw-down(%.0f,%.0f)", p.x, p.y]];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ CFRelease(d); });
    } else if (i == n) {
        IOHIDEventRef u = [self _event:p phase:NO];
        [self _dispatch:u label:[NSString stringWithFormat:@"sw-up(%.0f,%.0f)", p.x, p.y]];
        CFRelease(u);
        return;
    } else {
        IOHIDEventRef m = [self _event:p phase:YES];
        [self _dispatch:m label:[NSString stringWithFormat:@"sw-mv(%.0f,%.0f)", p.x, p.y]];
        CFRelease(m);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(iv * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self _swipeStep:from to:to step:i + 1 total:n interval:iv];
    });
}

@end
