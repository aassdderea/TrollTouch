#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TTTouchSimulator : NSObject
+ (instancetype)sharedInstance;
- (BOOL)tapAtPoint:(CGPoint)point duration:(NSTimeInterval)duration;
@end
