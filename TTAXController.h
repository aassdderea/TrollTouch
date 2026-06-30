#import <Foundation/Foundation.h>
@interface TTAXController : NSObject
+ (instancetype)shared;
- (BOOL)checkAccess;
- (void)tapAt:(CGPoint)point;
@property (nonatomic,copy) void(^logBlock)(NSString *);
@end
