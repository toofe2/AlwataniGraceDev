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

static void AGDShowMessage(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) return;

        UIAlertController *result = [UIAlertController alertControllerWithTitle:title
                                                                          message:message
                                                                   preferredStyle:UIAlertControllerStyleAlert];
        [result addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:result animated:YES completion:nil];
    });
}

static void AGDHandleSend(UITextField *field) {
    NSString *raw = [field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (raw.length == 0) {
        AGDShowMessage(@"Grace Days — DEV", @"Enter a positive whole number first.");
        return;
    }

    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    if ([raw rangeOfCharacterFromSet:nonDigits].location != NSNotFound) {
        AGDShowMessage(@"Grace Days — DEV", @"Only whole positive numbers are accepted.");
        return;
    }

    unsigned long long value = strtoull(raw.UTF8String, NULL, 10);
    if (value == 0) {
        AGDShowMessage(@"Grace Days — DEV", @"Value must be greater than zero.");
        return;
    }

    // Stage 1 send action: validates and records the requested value. Network wiring is added separately
    // once the exact authorized /grace-days request path is intercepted reliably.
    NSLog(@"[AlwataniGraceDev] Send tapped. Requested graceDaysCount=%llu", value);
    NSString *msg = [NSString stringWithFormat:@"Send button is active.\nRequested graceDaysCount: %llu\n\nNetwork dispatch is not wired yet, so no server request was sent in this build.", value];
    AGDShowMessage(@"MK Send", msg);
}

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) {
            NSLog(@"[AlwataniGraceDev] no active view controller");
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV"
                                                                       message:@"MK injection active. Enter a custom positive number of days."
                                                                preferredStyle:UIAlertControllerStyleAlert];

        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"Custom days";
            field.keyboardType = UIKeyboardTypeNumberPad;
            field.autocorrectionType = UITextAutocorrectionTypeNo;
            field.spellCheckingType = UITextSpellCheckingTypeNo;
        }];

        __weak UIAlertController *weakAlert = alert;
        [alert addAction:[UIAlertAction actionWithTitle:@"Send"
                                                  style:UIAlertActionStyleDefault
                                                handler:^(__unused UIAlertAction *action) {
            UIAlertController *strongAlert = weakAlert;
            UITextField *field = strongAlert.textFields.firstObject;
            AGDHandleSend(field);
        }]];

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
