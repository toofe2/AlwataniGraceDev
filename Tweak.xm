#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

static NSInteger const kAGDBadgeTag = 0x4D4B44; // "MKD"

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

static void AGDInstallMKBadge(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = AGDActiveWindow();
        if (!window) return;

        UIView *existing = [window viewWithTag:kAGDBadgeTag];
        if (existing) {
            [window bringSubviewToFront:existing];
            return;
        }

        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 46.0, 30.0)];
        badge.tag = kAGDBadgeTag;
        badge.text = @"MK";
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [UIFont boldSystemFontOfSize:16.0];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor colorWithRed:0.78 green:0.04 blue:0.08 alpha:0.95];
        badge.layer.cornerRadius = 9.0;
        badge.layer.masksToBounds = YES;
        badge.layer.borderWidth = 1.0;
        badge.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.28].CGColor;
        badge.userInteractionEnabled = NO;
        badge.accessibilityLabel = @"MK Developer Injection Active";

        UIEdgeInsets insets = window.safeAreaInsets;
        CGFloat top = MAX(insets.top + 8.0, 12.0);
        CGFloat left = 12.0;
        badge.frame = CGRectMake(left, top, 46.0, 30.0);

        [window addSubview:badge];
        [window bringSubviewToFront:badge];
        NSLog(@"[AlwataniGraceDev] MK badge installed");
    });
}

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) {
            NSLog(@"[AlwataniGraceDev] no active view controller");
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV"
                                                                       message:@"MK injection active. Developer test panel. This build does not bypass server validation."
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"[AlwataniGraceDev] loaded");
        AGDInstallMKBadge();
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        AGDShowPanel();
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:NSOperationQueue.mainQueue
                                                  usingBlock:^(__unused NSNotification *note) {
        AGDInstallMKBadge();
    }];
}
