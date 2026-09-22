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

static BOOL AGDKeychainEntryExists(NSString *account, NSString *service, NSUInteger *valueLength) {
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
        if (valueLength) *valueLength = 0;
        return NO;
    }
    NSData *data = CFBridgingRelease(result);
    if (valueLength) *valueLength = [data isKindOfClass:NSData.class] ? data.length : 0;
    return YES;
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
    NSUInteger sessionLength = 0;
    BOOL sessionPresent = AGDKeychainEntryExists(@"auth_session", @"flutter_secure_storage_service", &sessionLength);
    return @{
        @"subscriptionPresent": @(subscriptionID.length > 0),
        @"sessionPresent": @(sessionPresent),
        @"sessionLength": @(sessionLength)
    };
}

static NSString *AGDGraceReadinessMessage(void) {
    NSDictionary *state = AGDGraceReadiness();
    BOOL sub = [state[@"subscriptionPresent"] boolValue];
    BOOL session = [state[@"sessionPresent"] boolValue];
    NSUInteger length = [state[@"sessionLength"] unsignedIntegerValue];
    return [NSString stringWithFormat:@"Selected subscription: %@\nAuthenticated session: %@\nSession payload length: %lu bytes\n\nNo credential values are displayed.", sub ? @"FOUND" : @"not found", session ? @"FOUND" : @"not found", (unsigned long)length];
}

static NSString *AGDRequestPreview(NSInteger days) {
    NSString *subscriptionID = AGDSelectedSubscriptionID();
    if (!subscriptionID.length) return @"Selected subscription ID is not available.";
    NSString *path = [NSString stringWithFormat:@"/api/Subscriptions/%@/grace-days", subscriptionID];
    NSDictionary *body = @{ @"graceDaysCount": @(days) };
    NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    NSString *bodyString = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : @"{}";
    return [NSString stringWithFormat:@"Method: POST\nHost: api.ftth.iq\nPath: %@\nBody: %@\nAuthorization: present in app session (value hidden)\n\nPreview only — no network request was sent.", path, bodyString];
}

static void AGDShowGraceDaysPrompt(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) return;
        NSDictionary *state = AGDGraceReadiness();
        BOOL ready = [state[@"subscriptionPresent"] boolValue] && [state[@"sessionPresent"] boolValue];
        NSString *message = ready ? @"MK injection active. Enter a custom positive number of Grace Days. This development build validates local context and can preview the exact request shape. It does not send or bypass server-side validation." : @"Required app context is incomplete. Run Readiness Check first.";
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV" message:message preferredStyle:UIAlertControllerStyleAlert];
        [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
            field.placeholder = @"Custom days";
            field.keyboardType = UIKeyboardTypeNumberPad;
        }];
        [alert addAction:[UIAlertAction actionWithTitle:@"Readiness Check" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
            AGDShowMessage(@"Grace Days Readiness", AGDGraceReadinessMessage());
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Preview Request" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) {
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
            AGDShowMessage(@"Grace Days Request Preview", AGDRequestPreview(days));
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
