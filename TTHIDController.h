#import <UIKit/UIKit.h>

@interface TTHIDController : NSObject
+ (instancetype)shared;
- (BOOL)setup;
- (void)setLogHandler:(void(^)(NSString *msg))block;
- (void)tapAt:(CGPoint)point;
- (void)startRepeating:(CGPoint)point interval:(NSTimeInterval)sec;
- (void)stopRepeating;
- (void)swipeFrom:(CGPoint)from to:(CGPoint)to steps:(NSInteger)steps duration:(NSTimeInterval)dur;
@property (nonatomic, readonly) BOOL isRepeating;
@end
