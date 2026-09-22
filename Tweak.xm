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

static NSString *AGDStringify(id value) {
    if (!value || value == [NSNull null]) return nil;
    if ([value isKindOfClass:NSString.class]) return value;
    if ([value isKindOfClass:NSData.class]) return [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding];
    if ([value respondsToSelector:@selector(stringValue)]) return [value stringValue];
    return [value description];
}

static BOOL AGDContainsAny(NSString *candidate, NSArray<NSString *> *needles) {
    NSString *c = candidate.lowercaseString;
    if (!c.length) return NO;
    for (NSString *needle in needles) {
        if ([c containsString:needle.lowercaseString]) return YES;
    }
    return NO;
}

static NSDictionary *AGDDefaultsInfo(void) {
    NSDictionary *defaults = NSUserDefaults.standardUserDefaults.dictionaryRepresentation;
    NSArray<NSString *> *tokenHints = @[@"token", @"access", @"auth", @"jwt", @"bearer"];
    NSArray<NSString *> *subHints = @[@"subscription", @"selected_subscription", @"selectedsubscription", @"subscriptionid"];
    NSMutableArray *tokenKeys = [NSMutableArray array];
    NSMutableArray *subKeys = [NSMutableArray array];
    for (NSString *key in defaults.allKeys) {
        if (AGDContainsAny(key, tokenHints)) [tokenKeys addObject:key];
        if (AGDContainsAny(key, subHints)) [subKeys addObject:key];
    }
    return @{ @"tokenKeys": tokenKeys, @"subKeys": subKeys };
}

static NSArray<NSDictionary *> *AGDAllKeychainItems(void) {
    NSDictionary *query = @{
        (__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecReturnAttributes:@YES,
        (__bridge id)kSecMatchLimit:(__bridge id)kSecMatchLimitAll
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess || !result) return @[];
    id obj = CFBridgingRelease(result);
    if ([obj isKindOfClass:NSArray.class]) return obj;
    if ([obj isKindOfClass:NSDictionary.class]) return @[obj];
    return @[];
}

static NSString *AGDKeychainSummary(void) {
    NSArray<NSString *> *tokenHints = @[@"token", @"access", @"auth", @"jwt", @"bearer"];
    NSArray<NSString *> *subHints = @[@"subscription", @"selected_subscription", @"selectedsubscription", @"subscriptionid"];
    NSMutableArray<NSString *> *hits = [NSMutableArray array];
    for (NSDictionary *item in AGDAllKeychainItems()) {
        NSString *account = AGDStringify(item[(__bridge id)kSecAttrAccount]) ?: @"";
        NSString *service = AGDStringify(item[(__bridge id)kSecAttrService]) ?: @"";
        if (AGDContainsAny(account, tokenHints) || AGDContainsAny(service, tokenHints) || AGDContainsAny(account, subHints) || AGDContainsAny(service, subHints)) {
            NSString *masked = [NSString stringWithFormat:@"acct=%@ svc=%@", account.length ? account : @"-", service.length ? service : @"-"];
            [hits addObject:masked];
        }
    }
    return hits.count ? [hits componentsJoinedByString:@"\n"] : @"No matching Keychain metadata";
}

static NSString *AGDStorageDiagnostic(void) {
    NSDictionary *info = AGDDefaultsInfo();
    NSArray *tokenKeys = info[@"tokenKeys"];
    NSArray *subKeys = info[@"subKeys"];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"NSUserDefaults token-like keys: %lu", (unsigned long)tokenKeys.count]];
    if (tokenKeys.count) [lines addObject:[NSString stringWithFormat:@"%@", [tokenKeys componentsJoinedByString:@", "]]];
    [lines addObject:[NSString stringWithFormat:@"NSUserDefaults subscription-like keys: %lu", (unsigned long)subKeys.count]];
    if (subKeys.count) [lines addObject:[NSString stringWithFormat:@"%@", [subKeys componentsJoinedByString:@", "]]];
    [lines addObject:@"Keychain metadata matches:"];
    [lines addObject:AGDKeychainSummary()];
    [lines addObject:@"Secret values are not displayed."];
    return [lines componentsJoinedByString:@"\n"];
}

static void AGDShowPanel(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIViewController *root = AGDTopViewController();
        if (!root) return;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Grace Days — DEV" message:@"Storage diagnostics updated after the first device check. This version searches broader session/subscription metadata names without displaying secrets." preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Storage Check" style:UIAlertActionStyleDefault handler:^(__unused UIAlertAction *action) { AGDShowMessage(@"MK Storage Check", AGDStorageDiagnostic()); }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}

%ctor {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ AGDInstallMKBadge(); });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ AGDShowPanel(); });
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { AGDInstallMKBadge(); }];
}
