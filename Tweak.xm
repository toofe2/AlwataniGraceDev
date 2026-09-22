#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static UIWindow *AGDActiveWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;

    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;

        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive &&
            windowScene.activationState != UISceneActivationStateForegroundInactive) {
            continue;
        }

        for (UIWindow *window in windowScene.windows) {
            if (window.isKeyWindow) return window;
        }

        for (UIWindow *window in windowScene.windows) {
            if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal) {
                return window;
            }
        }
    }

    return nil;
}

static UIViewController *AGDTopViewController(void) {
    UIWindow *window = AGDActiveWindow();
    UIViewController *controller = window.rootViewController;
    if (!controller) return nil;

    while (YES) {
        if (controller.presentedViewController) {
            controller = controller.presentedViewController;
            continue;
        }

        if ([controller isKindOfClass:UINavigationController.class]) {
            UIViewController *visible = ((UINavigationController *)controller).visibleViewController;
            if (visible) {
                controller = visible;
                continue;
            }
        }

        if ([controller isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (selected) {
                controller = selected;
                continue;
            }
        }

        break;
    }

    return controller;
}

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) {
            NSLog(@"[AlwataniGraceDev] no active view controller");
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV"
                                                                       message:@"Developer test panel. This build does not bypass server validation."
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"Custom days";
            field.keyboardType = UIKeyboardTypeNumberPad;
            field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.spellCheckingType = UITextSpellCheckingTypeNo;
        }];

        [alert addAction:[UIAlertAction actionWithTitle:@"Close"
                                                  style:UIAlertActionStyleCancel
                                                handler:nil]];

        [root presentViewController:alert animated:YES completion:nil];
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AlwataniGraceDev] loaded");
        AGDShowPanel();
    });
}
