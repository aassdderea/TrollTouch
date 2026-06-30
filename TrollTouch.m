#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TTFloatWindow.h"

__attribute__((constructor)) static void TrollTouchInit(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[TTFloatWindow sharedInstance] show];
    });
}
