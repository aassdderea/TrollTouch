#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TTFloatWindow.h"

__attribute__((constructor)) static void TrollTouchInit(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[TTFloatWindow sharedInstance] show];
    });
}
