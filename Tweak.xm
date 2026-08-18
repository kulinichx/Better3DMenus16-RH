#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <objc/runtime.h>
#import <math.h>

static CFStringRef const kB3MPrefsDomain = CFSTR("com.kulinichx.better3dmenus16rh");
static CFStringRef const kB3MNotification = CFSTR("com.kulinichx.better3dmenus16rh/preferences.changed");

static BOOL gB3MHideSeparators = YES;
static BOOL gB3MReduceBlur = YES;
static BOOL gB3MHideShareApp = YES;
static BOOL gB3MHideRemoveApp = YES;
static BOOL gB3MHideSectionGap = NO;
static BOOL gB3MGlassMenuTint = NO;
static BOOL gB3MGlassTextTint = NO;
static CGFloat gB3MBlurFactor = 0.55;

static char kB3MSeparatorCapturedKey;
static char kB3MSeparatorHiddenKey;
static char kB3MSeparatorAlphaKey;
static char kB3MBlurCapturedKey;
static char kB3MBlurAlphaKey;
static char kB3MTintCapturedKey;
static char kB3MTintColorKey;
static char kB3MTextCapturedKey;
static char kB3MTextColorKey;

static BOOL B3MReadBool(CFStringRef key, BOOL fallback)
{
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, kB3MPrefsDomain);
    if (!value) return fallback;

    BOOL result = fallback;
    CFTypeID type = CFGetTypeID(value);

    if (type == CFBooleanGetTypeID()) {
        result = CFBooleanGetValue((CFBooleanRef)value);
    } else if (type == CFNumberGetTypeID()) {
        int number = fallback ? 1 : 0;
        if (CFNumberGetValue((CFNumberRef)value, kCFNumberIntType, &number)) {
            result = (number != 0);
        }
    }

    CFRelease(value);
    return result;
}

static double B3MReadDouble(CFStringRef key, double fallback, double minimum, double maximum)
{
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, kB3MPrefsDomain);
    if (!value) return fallback;

    double result = fallback;
    if (CFGetTypeID(value) == CFNumberGetTypeID()) {
        double number = fallback;
        if (CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &number)) {
            if (number < minimum) number = minimum;
            if (number > maximum) number = maximum;
            result = number;
        }
    }

    CFRelease(value);
    return result;
}

static void B3MLoadPreferences(void)
{
    CFPreferencesAppSynchronize(kB3MPrefsDomain);

    gB3MHideSeparators = B3MReadBool(CFSTR("HideSeparators"), YES);
    gB3MReduceBlur = B3MReadBool(CFSTR("ReduceBlur"), YES);
    gB3MHideShareApp = B3MReadBool(CFSTR("HideShareApp"), YES);
    gB3MHideRemoveApp = B3MReadBool(CFSTR("HideRemoveApp"), YES);
    gB3MHideSectionGap = B3MReadBool(CFSTR("HideSectionGap"), NO);
    gB3MGlassMenuTint = B3MReadBool(CFSTR("GlassMenuTint"), NO);
    gB3MGlassTextTint = B3MReadBool(CFSTR("GlassTextTint"), NO);
    gB3MBlurFactor = (CGFloat)B3MReadDouble(CFSTR("BlurFactor"), 0.55, 0.20, 1.00);
}

static void B3MPreferencesChanged(CFNotificationCenterRef center,
                                  void *observer,
                                  CFStringRef name,
                                  const void *object,
                                  CFDictionaryRef userInfo)
{
    (void)center;
    (void)observer;
    (void)name;
    (void)object;
    (void)userInfo;

    B3MLoadPreferences();
}

static void B3MApplySeparatorState(UIView *view)
{
    if (!view) return;

    NSNumber *captured = objc_getAssociatedObject(view, &kB3MSeparatorCapturedKey);

    if (gB3MHideSeparators) {
        if (![captured boolValue]) {
            objc_setAssociatedObject(view, &kB3MSeparatorHiddenKey, @(view.hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kB3MSeparatorAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kB3MSeparatorCapturedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        if (!view.hidden) view.hidden = YES;
        if (view.alpha != 0.0) view.alpha = 0.0;
    } else if ([captured boolValue]) {
        NSNumber *oldHidden = objc_getAssociatedObject(view, &kB3MSeparatorHiddenKey);
        NSNumber *oldAlpha = objc_getAssociatedObject(view, &kB3MSeparatorAlphaKey);

        if (oldHidden) view.hidden = oldHidden.boolValue;
        if (oldAlpha) view.alpha = oldAlpha.doubleValue;

        objc_setAssociatedObject(view, &kB3MSeparatorCapturedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kB3MSeparatorHiddenKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(view, &kB3MSeparatorAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static BOOL B3MClassNameLooksLikeBackground(UIView *view)
{
    NSString *name = NSStringFromClass(view.class);
    return [name rangeOfString:@"Background" options:NSCaseInsensitiveSearch].location != NSNotFound;
}

static void B3MApplyBlurRecursively(UIView *view, BOOL backgroundAncestor)
{
    if (!view) return;

    BOOL isBackgroundBranch = backgroundAncestor || B3MClassNameLooksLikeBackground(view);

    if ([view isKindOfClass:UIVisualEffectView.class] && isBackgroundBranch) {
        NSNumber *captured = objc_getAssociatedObject(view, &kB3MBlurCapturedKey);

        if (gB3MReduceBlur) {
            if (![captured boolValue]) {
                objc_setAssociatedObject(view, &kB3MBlurAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                objc_setAssociatedObject(view, &kB3MBlurCapturedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }

            NSNumber *original = objc_getAssociatedObject(view, &kB3MBlurAlphaKey);
            CGFloat originalAlpha = original ? original.doubleValue : 1.0;
            CGFloat wanted = originalAlpha * gB3MBlurFactor;

            if (fabs(view.alpha - wanted) > 0.001) {
                view.alpha = wanted;
            }
        } else if ([captured boolValue]) {
            NSNumber *original = objc_getAssociatedObject(view, &kB3MBlurAlphaKey);
            if (original) view.alpha = original.doubleValue;

            objc_setAssociatedObject(view, &kB3MBlurCapturedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(view, &kB3MBlurAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    for (UIView *subview in view.subviews) {
        B3MApplyBlurRecursively(subview, isBackgroundBranch);
    }
}


static UIColor *B3MGlassMenuColor(void)
{
    // Subtle cool-blue glass tint, intentionally low alpha.
    return [UIColor colorWithRed:0.10 green:0.42 blue:0.82 alpha:0.11];
}

static UIColor *B3MGlassTextColor(void)
{
    // Icy cyan-white accent chosen to match the new glass "3" icon.
    return [UIColor colorWithRed:0.73 green:0.90 blue:1.00 alpha:1.00];
}

static BOOL B3MColorLooksDestructive(UIColor *color, UITraitCollection *traits)
{
    if (!color) return NO;

    UIColor *resolved = color;
    if ([color respondsToSelector:@selector(resolvedColorWithTraitCollection:)]) {
        resolved = [color resolvedColorWithTraitCollection:traits];
    }

    CGFloat r = 0.0, g = 0.0, b = 0.0, a = 0.0;
    if (![resolved getRed:&r green:&g blue:&b alpha:&a]) {
        return NO;
    }

    // Preserve system/destructive reds instead of recoloring them.
    return (r > 0.65 && r > (g * 1.45) && r > (b * 1.25));
}

static void B3MApplyGlassTintRecursively(UIView *view, BOOL backgroundAncestor)
{
    if (!view) return;

    BOOL isBackgroundBranch =
        backgroundAncestor || B3MClassNameLooksLikeBackground(view);

    if ([view isKindOfClass:UIVisualEffectView.class] && isBackgroundBranch) {
        UIVisualEffectView *effectView = (UIVisualEffectView *)view;
        UIView *contentView = effectView.contentView;

        NSNumber *captured =
            objc_getAssociatedObject(contentView, &kB3MTintCapturedKey);

        if (gB3MGlassMenuTint) {
            if (![captured boolValue]) {
                UIColor *oldColor = contentView.backgroundColor;
                objc_setAssociatedObject(
                    contentView,
                    &kB3MTintColorKey,
                    oldColor ?: (id)[NSNull null],
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC
                );
                objc_setAssociatedObject(
                    contentView,
                    &kB3MTintCapturedKey,
                    @YES,
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC
                );
            }

            contentView.backgroundColor = B3MGlassMenuColor();
        } else if ([captured boolValue]) {
            id oldColor =
                objc_getAssociatedObject(contentView, &kB3MTintColorKey);

            contentView.backgroundColor =
                (oldColor == [NSNull null]) ? nil : (UIColor *)oldColor;

            objc_setAssociatedObject(
                contentView, &kB3MTintCapturedKey, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            objc_setAssociatedObject(
                contentView, &kB3MTintColorKey, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
        }
    }

    for (UIView *subview in view.subviews) {
        B3MApplyGlassTintRecursively(subview, isBackgroundBranch);
    }
}

static void B3MApplyGlassTextRecursively(UIView *view)
{
    if (!view) return;

    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        NSNumber *captured =
            objc_getAssociatedObject(label, &kB3MTextCapturedKey);

        if (gB3MGlassTextTint) {
            UIColor *current = label.textColor;

            if (!B3MColorLooksDestructive(current, label.traitCollection)) {
                if (![captured boolValue]) {
                    objc_setAssociatedObject(
                        label,
                        &kB3MTextColorKey,
                        current ?: (id)[NSNull null],
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    );
                    objc_setAssociatedObject(
                        label,
                        &kB3MTextCapturedKey,
                        @YES,
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC
                    );
                }

                label.textColor = B3MGlassTextColor();
            }
        } else if ([captured boolValue]) {
            id oldColor =
                objc_getAssociatedObject(label, &kB3MTextColorKey);

            label.textColor =
                (oldColor == [NSNull null]) ? nil : (UIColor *)oldColor;

            objc_setAssociatedObject(
                label, &kB3MTextCapturedKey, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
            objc_setAssociatedObject(
                label, &kB3MTextColorKey, nil,
                OBJC_ASSOCIATION_RETAIN_NONATOMIC
            );
        }
    }

    for (UIView *subview in view.subviews) {
        B3MApplyGlassTextRecursively(subview);
    }
}

static BOOL B3MActionIdentifierLooksLikeShareApp(NSString *identifier)
{
    if (identifier.length == 0) return NO;

    NSString *lower = identifier.lowercaseString;

    if ([lower isEqualToString:@"com.apple.springboard.application-shortcut-item.share"] ||
        [lower isEqualToString:@"com.apple.springboardhome.application-shortcut-item.share"]) {
        return YES;
    }

    BOOL springBoardOwned = ([lower rangeOfString:@"springboard"].location != NSNotFound);
    BOOL shortcutItem = ([lower rangeOfString:@"application-shortcut-item"].location != NSNotFound);
    BOOL share = ([lower hasSuffix:@".share"] ||
                  [lower rangeOfString:@".share-"].location != NSNotFound);

    return springBoardOwned && shortcutItem && share;
}

static BOOL B3MTitleLooksLikeShareApp(NSString *title)
{
    if (title.length == 0) return NO;

    static NSSet<NSString *> *knownTitles;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        knownTitles = [NSSet setWithArray:@[
            @"Share App",
            @"共享 App",
            @"分享 App",
            @"共享应用",
            @"分享应用"
        ]];
    });

    return [knownTitles containsObject:title];
}

static BOOL B3MIsShareAppElement(UIMenuElement *element)
{
    if (!gB3MHideShareApp || ![element isKindOfClass:UIAction.class]) {
        return NO;
    }

    UIAction *action = (UIAction *)element;
    NSString *identifier = nil;

    if ([action respondsToSelector:@selector(identifier)]) {
        identifier = action.identifier;
    }

    if (B3MActionIdentifierLooksLikeShareApp(identifier)) {
        return YES;
    }

    return B3MTitleLooksLikeShareApp(action.title);
}


static BOOL B3MActionIdentifierLooksLikeRemoveApp(NSString *identifier)
{
    if (identifier.length == 0) return NO;

    NSString *lower = identifier.lowercaseString;

    static NSSet<NSString *> *knownIdentifiers;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        knownIdentifiers = [NSSet setWithArray:@[
            @"com.apple.springboard.application-shortcut-item.remove",
            @"com.apple.springboard.application-shortcut-item.remove-app",
            @"com.apple.springboard.application-shortcut-item.delete",
            @"com.apple.springboard.application-shortcut-item.delete-app",
            @"com.apple.springboardhome.application-shortcut-item.remove",
            @"com.apple.springboardhome.application-shortcut-item.remove-app",
            @"com.apple.springboardhome.application-shortcut-item.delete",
            @"com.apple.springboardhome.application-shortcut-item.delete-app"
        ]];
    });

    if ([knownIdentifiers containsObject:lower]) {
        return YES;
    }

    BOOL springBoardOwned =
        ([lower rangeOfString:@"springboard"].location != NSNotFound);
    BOOL shortcutItem =
        ([lower rangeOfString:@"application-shortcut-item"].location != NSNotFound);
    BOOL removeOrDelete =
        ([lower hasSuffix:@".remove"] ||
         [lower hasSuffix:@".remove-app"] ||
         [lower hasSuffix:@".delete"] ||
         [lower hasSuffix:@".delete-app"]);

    return springBoardOwned && shortcutItem && removeOrDelete;
}

static BOOL B3MTitleLooksLikeRemoveApp(NSString *title)
{
    if (title.length == 0) return NO;

    static NSSet<NSString *> *knownTitles;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        knownTitles = [NSSet setWithArray:@[
            @"Remove App",
            @"移除 App",
            @"移除App"
        ]];
    });

    return [knownTitles containsObject:title];
}

static BOOL B3MIsRemoveAppElement(UIMenuElement *element)
{
    if (!gB3MHideRemoveApp || ![element isKindOfClass:UIAction.class]) {
        return NO;
    }

    UIAction *action = (UIAction *)element;
    NSString *identifier = nil;

    if ([action respondsToSelector:@selector(identifier)]) {
        identifier = action.identifier;
    }

    if (B3MActionIdentifierLooksLikeRemoveApp(identifier)) {
        return YES;
    }

    return B3MTitleLooksLikeRemoveApp(action.title);
}

static __thread BOOL gB3MInsideMenuRewrite = NO;

static NSArray<UIMenuElement *> *B3MFilterMenuElements(NSArray<UIMenuElement *> *children)
{
    if ((!gB3MHideShareApp && !gB3MHideRemoveApp && !gB3MHideSectionGap) || children.count == 0) {
        return children;
    }

    NSMutableArray<UIMenuElement *> *result =
        [NSMutableArray arrayWithCapacity:children.count];

    BOOL changed = NO;

    for (UIMenuElement *element in children) {
        if (B3MIsShareAppElement(element) ||
            B3MIsRemoveAppElement(element)) {
            changed = YES;
            continue;
        }

        if ([element isKindOfClass:UIMenu.class]) {
            UIMenu *menu = (UIMenu *)element;
            NSArray<UIMenuElement *> *originalChildren = menu.children;
            NSArray<UIMenuElement *> *filteredChildren =
                B3MFilterMenuElements(originalChildren);

            /*
             * iOS 16 experimental section-gap removal.
             *
             * Untitled UIMenuOptionsDisplayInline menus are commonly used as
             * visual groups. Flatten only these groups so UIKit no longer
             * creates the large inter-section gap.
             *
             * We deliberately do not touch gesture recognizers, frames,
             * constraints, or global UIKit views here.
             */
            if (gB3MHideSectionGap &&
                menu.title.length == 0 &&
                (menu.options & UIMenuOptionsDisplayInline) &&
                !(menu.options & UIMenuOptionsDestructive)) {

                [result addObjectsFromArray:filteredChildren];
                changed = YES;
                continue;
            }

            if (filteredChildren != originalChildren) {
                BOOL oldGuard = gB3MInsideMenuRewrite;
                gB3MInsideMenuRewrite = YES;

                UIMenu *replacement =
                    [menu menuByReplacingChildren:filteredChildren];

                gB3MInsideMenuRewrite = oldGuard;

                [result addObject:replacement ?: menu];
                changed = YES;
                continue;
            }
        }

        [result addObject:element];
    }

    return changed ? result.copy : children;
}

%hook _UIContextMenuActionsListSeparatorView

- (void)didMoveToWindow
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

%end

%hook _UIContextMenuReusableSeparatorView

- (void)didMoveToWindow
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

%end

%hook _UIContextMenuSeparatorView

- (void)didMoveToWindow
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

%end

%hook _UIInterfaceActionBlankSeparatorView

- (void)didMoveToWindow
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

%end

%hook _UIInterfaceActionVibrantSeparatorView

- (void)didMoveToWindow
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplySeparatorState((UIView *)self);
}

%end

%hook _UIElasticContextMenuBackgroundView

- (void)didMoveToWindow
{
    %orig;
    B3MApplyBlurRecursively((UIView *)self, YES);
    B3MApplyGlassTintRecursively((UIView *)self, YES);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplyBlurRecursively((UIView *)self, YES);
    B3MApplyGlassTintRecursively((UIView *)self, YES);
}

%end

%hook _UIContextMenuView

- (void)didMoveToWindow
{
    %orig;
    B3MApplyBlurRecursively((UIView *)self, NO);
    B3MApplyGlassTintRecursively((UIView *)self, NO);
    B3MApplyGlassTextRecursively((UIView *)self);
}

- (void)layoutSubviews
{
    %orig;
    B3MApplyBlurRecursively((UIView *)self, NO);
    B3MApplyGlassTintRecursively((UIView *)self, NO);
    B3MApplyGlassTextRecursively((UIView *)self);
}

%end

%hook UIMenu

+ (instancetype)menuWithChildren:(NSArray<UIMenuElement *> *)children
{
    if (gB3MInsideMenuRewrite ||
        (!gB3MHideShareApp && !gB3MHideRemoveApp && !gB3MHideSectionGap)) {
        return %orig;
    }

    NSArray<UIMenuElement *> *filtered =
        B3MFilterMenuElements(children);

    return %orig(filtered);
}

+ (instancetype)menuWithTitle:(NSString *)title
                     children:(NSArray<UIMenuElement *> *)children
{
    if (gB3MInsideMenuRewrite ||
        (!gB3MHideShareApp && !gB3MHideRemoveApp && !gB3MHideSectionGap)) {
        return %orig;
    }

    NSArray<UIMenuElement *> *filtered =
        B3MFilterMenuElements(children);

    return %orig(title, filtered);
}

+ (instancetype)menuWithTitle:(NSString *)title
                        image:(UIImage *)image
                   identifier:(UIMenuIdentifier)identifier
                      options:(UIMenuOptions)options
                     children:(NSArray<UIMenuElement *> *)children
{
    if (gB3MInsideMenuRewrite ||
        (!gB3MHideShareApp && !gB3MHideRemoveApp && !gB3MHideSectionGap)) {
        return %orig;
    }

    NSArray<UIMenuElement *> *filtered =
        B3MFilterMenuElements(children);

    return %orig(title, image, identifier, options, filtered);
}

- (instancetype)menuByReplacingChildren:(NSArray<UIMenuElement *> *)children
{
    if (gB3MInsideMenuRewrite ||
        (!gB3MHideShareApp && !gB3MHideRemoveApp && !gB3MHideSectionGap)) {
        return %orig;
    }

    NSArray<UIMenuElement *> *filtered =
        B3MFilterMenuElements(children);

    return %orig(filtered);
}

%end

%ctor
{
    @autoreleasepool {
        if (![[NSBundle mainBundle].bundleIdentifier
              isEqualToString:@"com.apple.springboard"]) {
            return;
        }

        B3MLoadPreferences();

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            B3MPreferencesChanged,
            kB3MNotification,
            NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately
        );

        %init;
    }
}
