#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <Security/Security.h>

static NSInteger const kAGDBadgeTag = 0x4D4B44;

static UIWindow *AGDActiveWindow(void) {
    UIApplication *app = UIApplication.sharedApplication;
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        if (windowScene.activationState != UISceneActivationStateForegroundActive && windowScene.activationState != UISceneActivationStateForegroundInactive) continue;
        for (UIWindow *window in windowScene.windows) if (window.isKeyWindow) return window;
        for (UIWindow *window in windowScene.windows) if (!window.hidden && window.alpha > 0.0 && window.windowLevel == UIWindowLevelNormal) return window;
    }
    return nil;
}

static UIViewController *AGDTopViewController(void) {
    UIViewController *controller = AGDActiveWindow().rootViewController;
    if (!controller) return nil;
    while (YES) {
        if (controller.presentedViewController) { controller = controller.presentedViewController; continue; }
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

static void AGDShowMessage(NSString *title, NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

static void AGDInstallMKBadge(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = AGDActiveWindow();
        if (!window) return;
        UIView *existing = [window viewWithTag:kAGDBadgeTag];
        if (existing) { [window bringSubviewToFront:existing]; return; }
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(12.0, MAX(window.safeAreaInsets.top + 8.0, 12.0), 46.0, 30.0)];
        badge.tag = kAGDBadgeTag;
        badge.text = @"MK";
        badge.textAlignment = NSTextAlignmentCenter;
        badge.font = [UIFont boldSystemFontOfSize:16.0];
        badge.textColor = UIColor.whiteColor;
        badge.backgroundColor = [UIColor colorWithRed:0.78 green:0.04 blue:0.08 alpha:0.95];
        badge.layer.cornerRadius = 9.0;
        badge.layer.masksToBounds = YES;
        [window addSubview:badge];
    });
}

static NSData *AGDKeychainData(NSString *account, NSString *service) {
    NSDictionary *query = @{
        (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount:account,
        (__bridge id)kSecAttrService:service,
        (__bridge id)kSecReturnData:@YES,
        (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) {
        if (result) CFRelease(result);
        return nil;
    }
    id obj = CFBridgingRelease(result);
    return [obj isKindOfClass:NSData.class] ? obj : nil;
}

static NSString *AGDSelectedSubscriptionID(void) {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:@"flutter.selected_subscription_id"];
    if (!value || value == [NSNull null]) return nil;
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return [value description];
}

static NSDictionary *AGDGraceReadiness(void) {
    NSString *subscriptionID = AGDSelectedSubscriptionID();
    NSData *sessionData = AGDKeychainData(@"auth_session", @"flutter_secure_storage_service");
    return @{
        @"subscriptionPresent": @(subscriptionID.length > 0),
        @"sessionPresent": @(sessionData.length > 0),
        @"sessionLength": @(sessionData.length)
    };
}

static NSString *AGDGraceReadinessMessage(void) {
    NSDictionary *state = AGDGraceReadiness();
    BOOL sub = [state[@"subscriptionPresent"] boolValue];
    BOOL session = [state[@"sessionPresent"] boolValue];
    NSUInteger length = [state[@"sessionLength"] unsignedIntegerValue];
    return [NSString stringWithFormat:@"Selected subscription: %@\nAuthenticated session: %@\nSession payload length: %lu bytes\n\nCredentials are used in-memory only for the app's own request and are not displayed.", sub ? @"FOUND" : @"not found", session ? @"FOUND" : @"not found", (unsigned long)length];
}

static NSString *AGDAccessTokenFromSessionData(NSData *data) {
    if (!data.length) return nil;
    id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if ([json isKindOfClass:NSDictionary.class]) {
        NSDictionary *dict = (NSDictionary *)json;
        NSArray *keys = @[@"access_token", @"accessToken", @"token", @"jwt"];
        for (NSString *key in keys) {
            id value = dict[key];
            if ([value isKindOfClass:NSString.class] && [value length] > 0) return value;
        }
        for (id value in dict.allValues) {
            if ([value isKindOfClass:NSDictionary.class]) {
                for (NSString *key in keys) {
                    id nested = value[key];
                    if ([nested isKindOfClass:NSString.class] && [nested length] > 0) return nested;
                }
            }
        }
    }
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string.length > 0 && [string rangeOfString:@" "].location == NSNotFound && [string componentsSeparatedByString:@"."].count >= 3) return string;
    return nil;
}

static void AGDSendGraceDays(NSInteger days) {
    NSString *subscriptionID = AGDSelectedSubscriptionID();
    NSData *sessionData = AGDKeychainData(@"auth_session", @"flutter_secure_storage_service");
    NSString *token = AGDAccessTokenFromSessionData(sessionData);
    if (!subscriptionID.length || !token.length) {
        AGDShowMessage(@"Grace Days — DEV", @"Could not prepare the authenticated request from the current app session.");
        return;
    }

    NSString *urlString = [NSString stringWithFormat:@"https://api.ftth.iq/api/Subscriptions/%@/grace-days", subscriptionID];
    NSURL *url = [NSURL URLWithString:urlString];
    if (!url) {
        AGDShowMessage(@"Grace Days — DEV", @"Invalid request URL.");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", token] forHTTPHeaderField:@"Authorization"];
    NSDictionary *body = @{ @"graceDaysCount": @(days) };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            AGDShowMessage(@"Grace Days Response", [NSString stringWithFormat:@"Network error: %@", error.localizedDescription ?: @"Unknown error"]);
            return;
        }
        NSInteger status = 0;
        if ([response isKindOfClass:NSHTTPURLResponse.class]) status = ((NSHTTPURLResponse *)response).statusCode;
        NSString *responseBody = data.length ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
        if (responseBody.length > 1200) responseBody = [[responseBody substringToIndex:1200] stringByAppendingString:@"…"];
        NSString *message = [NSString stringWithFormat:@"HTTP %ld\n\n%@", (long)status, responseBody.length ? responseBody : @"(empty response)"];
        AGDShowMessage(@"Grace Days Response", message);
    }];
    [task resume];
}

static void AGDShowGraceDaysPrompt(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) return;
        NSDictionary *state = AGDGraceReadiness();
        BOOL ready = [state[@"subscriptionPresent"] boolValue] && [state[@"sessionPresent"] boolValue];
        NSString *message = ready ? @"MK injection active. Enter a custom positive number of Grace Days. Send will use the app's current authenticated session and the selected subscription. Server-side authorization and validation remain unchanged." : @"Required app context is incomplete. Run Readiness Check first.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"Custom days";
            field.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Readiness Check" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            AGDShowMessage(@"Grace Days Readiness", AGDGraceReadinessMessage());
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Send" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            NSString *raw = alert.textFields.firstObject.text ?: @"";
            NSInteger days = raw.integerValue;
            if (days <= 0) {
                AGDShowMessage(@"Grace Days — DEV", @"Enter a positive number of days.");
                return;
            }
            NSDictionary *current = AGDGraceReadiness();
            BOOL currentReady = [current[@"subscriptionPresent"] boolValue] && [current[@"sessionPresent"] boolValue];
            if (!currentReady) {
                AGDShowMessage(@"Grace Days — DEV", @"The app session/subscription context is not ready.");
                return;
            }
            UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Confirm Send" message:[NSString stringWithFormat:@"Send a real Grace Days request for %ld days using the current signed-in account and selected subscription?", (long)days] preferredStyle:UIAlertControllerStyleAlert];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
            [confirm addAction:[UIAlertAction actionWithTitle:@"Send" style:UIAlertActionStyleDestructive handler:^(__unused UIAlertAction *a) { AGDSendGraceDays(days); }]];
            [AGDTopViewController() presentViewController:confirm animated:YES completion:nil];
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ AGDInstallMKBadge(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ AGDShowGraceDaysPrompt(); });
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { AGDInstallMKBadge(); }];
}
