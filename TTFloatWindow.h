#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface TTFloatWindow : NSObject
+ (instancetype)sharedInstance;
- (void)show;
@end
