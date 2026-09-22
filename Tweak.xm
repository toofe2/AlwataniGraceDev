#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = UIApplication.sharedApplication.keyWindow;
        if (!window) {
            for (UIWindow *candidate in UIApplication.sharedApplication.windows) {
                if (!candidate.hidden && candidate.alpha > 0.0) { window = candidate; break; }
            }
        }
        UIViewController *root = window.rootViewController;
        while (root.presentedViewController) root = root.presentedViewController;
        if (!root) return;

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV"
                                                                       message:@"Developer test panel. This build does not bypass server validation."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"Custom days";
            field.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AlwataniGraceDev] loaded");
        AGDShowPanel();
    });
}
