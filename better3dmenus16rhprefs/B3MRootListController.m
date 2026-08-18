#import "B3MRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <CoreFoundation/CoreFoundation.h>

static CFStringRef const kB3MPrefsDomain =
    CFSTR("com.kulinichx.better3dmenus16rh");

static CFStringRef const kB3MPreferencesChanged =
    CFSTR("com.kulinichx.better3dmenus16rh/preferences.changed");

@implementation B3MRootListController

- (NSArray *)specifiers
{
    if (!_specifiers) {
        _specifiers =
            [self loadSpecifiersFromPlistName:@"Root"
                                       target:self];

        [self b3mUpdateActiveStrengthLabel];
    }

    return _specifiers;
}

- (PSSpecifier *)b3mSpecifierWithIdentifier:(NSString *)identifier
{
    if (identifier.length == 0) return nil;

    for (PSSpecifier *specifier in _specifiers) {
        NSString *candidate =
            [specifier propertyForKey:@"id"];

        if ([candidate isEqualToString:identifier]) {
            return specifier;
        }
    }

    return nil;
}

- (NSInteger)b3mCurrentGlassStyle
{
    CFPreferencesAppSynchronize(kB3MPrefsDomain);

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            CFSTR("GlassStyle"),
            kB3MPrefsDomain
        );

    NSInteger style = 1;

    if (value) {
        if (CFGetTypeID(value) == CFNumberGetTypeID()) {
            long long number = 1;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberLongLongType,
                    &number)) {
                style = (number == 0) ? 0 : 1;
            }
        }

        CFRelease(value);
    }

    return style;
}

- (NSNumber *)b3mStrengthForKey:(CFStringRef)key
                       fallback:(double)fallback
{
    CFPreferencesAppSynchronize(kB3MPrefsDomain);

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            key,
            kB3MPrefsDomain
        );

    double strength = fallback;

    if (value) {
        if (CFGetTypeID(value) == CFNumberGetTypeID()) {
            double number = fallback;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number)) {
                strength = number;
            }
        }

        CFRelease(value);
    }

    strength = MAX(0.0, MIN(100.0, strength));

    return @(strength);
}

- (id)readActiveStrength:(PSSpecifier *)specifier
{
    (void)specifier;

    if ([self b3mCurrentGlassStyle] == 0) {
        return [self b3mStrengthForKey:CFSTR("ClearStrength")
                              fallback:55.0];
    }

    return [self b3mStrengthForKey:CFSTR("LiquidGlassStrength")
                          fallback:72.0];
}

- (void)setActiveStrength:(id)value
                specifier:(PSSpecifier *)specifier
{
    (void)specifier;

    double strength =
        [value respondsToSelector:@selector(doubleValue)]
            ? [value doubleValue]
            : 0.0;

    strength = MAX(0.0, MIN(100.0, strength));

    CFStringRef key =
        ([self b3mCurrentGlassStyle] == 0)
            ? CFSTR("ClearStrength")
            : CFSTR("LiquidGlassStrength");

    CFNumberRef number =
        CFNumberCreate(
            kCFAllocatorDefault,
            kCFNumberDoubleType,
            &strength
        );

    if (number) {
        CFPreferencesSetAppValue(
            key,
            number,
            kB3MPrefsDomain
        );

        CFRelease(number);
    }

    CFPreferencesAppSynchronize(kB3MPrefsDomain);

    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        kB3MPreferencesChanged,
        NULL,
        NULL,
        true
    );
}

- (void)b3mUpdateActiveStrengthLabel
{
    PSSpecifier *labelSpecifier =
        [self b3mSpecifierWithIdentifier:@"ActiveStrengthLabel"];

    if (!labelSpecifier) return;

    NSString *label =
        ([self b3mCurrentGlassStyle] == 0)
            ? @"Clear Strength"
            : @"Liquid Glass Strength";

    [labelSpecifier setProperty:label
                        forKey:@"label"];
}

- (void)setPreferenceValue:(id)value
                 specifier:(PSSpecifier *)specifier
{
    [super setPreferenceValue:value
                    specifier:specifier];

    NSString *key =
        [specifier propertyForKey:@"key"];

    if ([key isEqualToString:@"GlassStyle"]) {
        [self b3mUpdateActiveStrengthLabel];

        /*
         * Refresh the two standard Preferences rows so the single slider
         * immediately reads the newly selected style's saved strength.
         */
        [self reloadSpecifiers];
    }
}

@end
