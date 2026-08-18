#import "B3MRootListController.h"
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSControlTableCell.h>
#import <Preferences/PSSliderTableCell.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>
#import <math.h>

static CFStringRef const kB3MPrefsDomain =
    CFSTR("com.kulinichx.better3dmenus16rh");

static CFStringRef const kB3MPreferencesChanged =
    CFSTR("com.kulinichx.better3dmenus16rh/preferences.changed");

static const double kB3MStrengthStep = 5.0;

static double B3MSnapStrength(double value)
{
    value = MAX(0.0, MIN(100.0, value));

    double snapped =
        round(value / kB3MStrengthStep) *
        kB3MStrengthStep;

    return MAX(0.0, MIN(100.0, snapped));
}

@interface PSListController (B3MReloadSpecifier)
- (void)reloadSpecifier:(PSSpecifier *)specifier;
@end

@interface B3MSteppedSliderCell : PSSliderTableCell
@end

@implementation B3MSteppedSliderCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style
              reuseIdentifier:(NSString *)reuseIdentifier
                    specifier:(PSSpecifier *)specifier
{
    self =
        [super initWithStyle:style
             reuseIdentifier:reuseIdentifier
                   specifier:specifier];

    if (self) {
        [self b3mInstallStepTarget];
    }

    return self;
}

- (void)didMoveToWindow
{
    [super didMoveToWindow];
    [self b3mInstallStepTarget];
}

- (void)b3mInstallStepTarget
{
    UIControl *control = [self control];

    if (![control isKindOfClass:UISlider.class]) {
        return;
    }

    UISlider *slider = (UISlider *)control;

    [slider removeTarget:self
                  action:@selector(b3mSliderValueChanged:)
        forControlEvents:UIControlEventValueChanged];

    [slider addTarget:self
               action:@selector(b3mSliderValueChanged:)
     forControlEvents:UIControlEventValueChanged];
}

- (void)b3mSliderValueChanged:(UISlider *)slider
{
    float snapped =
        (float)B3MSnapStrength(slider.value);

    if (fabsf(slider.value - snapped) > 0.001f) {
        slider.value = snapped;
    }
}

@end

@interface B3MRootListController ()

@property (nonatomic, strong)
    UISelectionFeedbackGenerator *b3mSelectionFeedback;

@property (nonatomic, assign)
    NSInteger b3mLastHapticStep;

@end

@implementation B3MRootListController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.b3mLastHapticStep = -1;

    self.b3mSelectionFeedback =
        [[UISelectionFeedbackGenerator alloc] init];

    [self.b3mSelectionFeedback prepare];
}

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

    return @(B3MSnapStrength(strength));
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

- (NSString *)activeStrengthDisplay:(PSSpecifier *)specifier
{
    (void)specifier;

    double strength =
        [[self readActiveStrength:nil] doubleValue];

    return [NSString stringWithFormat:@"%.0f%%", strength];
}

- (void)setActiveStrength:(id)value
                specifier:(PSSpecifier *)specifier
{
    (void)specifier;

    double rawValue =
        [value respondsToSelector:@selector(doubleValue)]
            ? [value doubleValue]
            : 0.0;

    double strength =
        B3MSnapStrength(rawValue);

    NSInteger step =
        (NSInteger)lround(
            strength / kB3MStrengthStep
        );

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

    if (step != self.b3mLastHapticStep) {
        [self.b3mSelectionFeedback selectionChanged];
        [self.b3mSelectionFeedback prepare];

        self.b3mLastHapticStep = step;

        PSSpecifier *valueSpecifier =
            [self b3mSpecifierWithIdentifier:
                @"ActiveStrengthLabel"];

        if (valueSpecifier) {
            [self reloadSpecifier:valueSpecifier];
        }
    }
}

- (void)b3mUpdateActiveStrengthLabel
{
    PSSpecifier *labelSpecifier =
        [self b3mSpecifierWithIdentifier:
            @"ActiveStrengthLabel"];

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
        self.b3mLastHapticStep = -1;

        [self b3mUpdateActiveStrengthLabel];
        [self reloadSpecifiers];
    }
}

@end
