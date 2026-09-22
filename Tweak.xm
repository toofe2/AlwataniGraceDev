#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

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
            if (visible) { controller = visible; continue; }
        }
        if ([controller isKindOfClass:UITabBarController.class]) {
            UIViewController *selected = ((UITabBarController *)controller).selectedViewController;
            if (selected) { controller = selected; continue; }
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
        badge.frame = CGRectMake(12.0, top, 46.0, 30.0);

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

static NSString *AGDStringFromDefaults(NSString *key) {
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:key];
    if (!value || value == [NSNull null]) return nil;
    if ([value isKindOfClass:NSString.class]) return (NSString *)value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return [value description];
}

static NSString *AGDStringFromKeychain(NSString *account) {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef item = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &item);
    if (status != errSecSuccess || !item) return nil;

    NSData *data = (__bridge_transfer NSData *)item;
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString *AGDResolveAccessToken(void) {
    NSArray<NSString *> *keys = @[@"user_access_token", @"access_token", @"accessToken"];
    for (NSString *key in keys) {
        NSString *value = AGDStringFromDefaults(key);
        if (value.length > 0) return value;
    }
    for (NSString *key in keys) {
        NSString *value = AGDStringFromKeychain(key);
        if (value.length > 0) return value;
    }
    return nil;
}

static NSString *AGDResolveSubscriptionID(void) {
    NSArray<NSString *> *keys = @[@"selected_subscription_id", @"subscriptionId", @"subscription_id"];
    for (NSString *key in keys) {
        NSString *value = AGDStringFromDefaults(key);
        if (value.length > 0) return value;
    }
    for (NSString *key in keys) {
        NSString *value = AGDStringFromKeychain(key);
        if (value.length > 0) return value;
    }
    return nil;
}

static void AGDSendGraceDays(unsigned long long value) {
    NSString *token = AGDResolveAccessToken();
    NSString *subscriptionID = AGDResolveSubscriptionID();

    if (token.length == 0) {
        AGDShowMessage(@"MK Send", @"Access token was not found in the app storage. No request was sent.");
        return;
    }
    if (subscriptionID.length == 0) {
        AGDShowMessage(@"MK Send", @"Selected subscription ID was not found in the app storage. No request was sent.");
        return;
    }

    NSString *escapedID = [subscriptionID stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLPathAllowedCharacterSet];
    NSString *urlString = [NSString stringWithFormat:@"https://api.ftth.iq/api/Subscriptions/%@/grace-days", escapedID];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        AGDShowMessage(@"MK Send", @"Could not build the Grace Days URL.");
        return;
    }

    NSDictionary *payload = @{@"graceDaysCount": @(value)};
    NSError *jsonError = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    if (!body || jsonError) {
        AGDShowMessage(@"MK Send", [NSString stringWithFormat:@"JSON error: %@", jsonError.localizedDescription ?: @"unknown"]);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    request.HTTPBody = body;
    request.timeoutInterval = 30.0;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];

    NSString *auth = token;
    if (![auth.lowercaseString hasPrefix:@"bearer "]) {
        auth = [@"Bearer " stringByAppendingString:auth];
    }
    [request setValue:auth forHTTPHeaderField:@"Authorization"];

    NSLog(@"[AlwataniGraceDev] POST %@ graceDaysCount=%llu", urlString, value);
    AGDShowMessage(@"MK Send", [NSString stringWithFormat:@"Sending graceDaysCount: %llu\nSubscription: %@", value, subscriptionID]);

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request
                                                                completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            AGDShowMessage(@"MK Server Response", [NSString stringWithFormat:@"Network error:\n%@", error.localizedDescription ?: @"unknown"]);
            return;
        }

        NSInteger status = 0;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) {
            status = ((NSHTTPURLResponse *)response).statusCode;
        }

        NSString *bodyText = data.length > 0 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"<empty body>";
        if (!bodyText) bodyText = [NSString stringWithFormat:@"<%lu bytes>", (unsigned long)data.length];

        NSString *message = [NSString stringWithFormat:@"Requested: %llu\nHTTP: %ld\n\n%@", value, (long)status, bodyText];
        NSLog(@"[AlwataniGraceDev] response HTTP=%ld body=%@", (long)status, bodyText);
        AGDShowMessage(@"MK Server Response", message);
    }];
    [task resume];
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

    NSLog(@"[AlwataniGraceDev] Send tapped. Requested graceDaysCount=%llu", value);
    AGDSendGraceDays(value);
}

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) {
            NSLog(@"[AlwataniGraceDev] no active view controller");
            return;
        }

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV"
                                                                       message:@"MK injection active. Enter a custom positive number of days. Server validation remains unchanged."
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

        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
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
