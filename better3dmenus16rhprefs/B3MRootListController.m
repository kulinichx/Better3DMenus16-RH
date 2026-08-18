#import "B3MRootListController.h"
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSSliderTableCell.h>
#import <math.h>

static CFStringRef const kB3MPrefsDomain =
    CFSTR("com.kulinichx.better3dmenus16rh");

static CFStringRef const kB3MPreferencesChanged =
    CFSTR("com.kulinichx.better3dmenus16rh/preferences.changed");

static NSInteger B3MCurrentGlassStyle(void)
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

static CFStringRef B3MActiveStrengthKey(void)
{
    return B3MCurrentGlassStyle() == 0
        ? CFSTR("ClearStrength")
        : CFSTR("LiquidGlassStrength");
}

static double B3MActiveStrengthFallback(void)
{
    return B3MCurrentGlassStyle() == 0
        ? 55.0
        : 72.0;
}

static void B3MPostPreferencesChanged(void)
{
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        kB3MPreferencesChanged,
        NULL,
        NULL,
        true
    );
}


@interface B3MPercentSliderCell : PSSliderTableCell

@property (nonatomic, strong)
    UILabel *b3mPercentLabel;

@property (nonatomic, weak)
    UISlider *b3mBoundSlider;

@property (nonatomic, strong)
    UIImpactFeedbackGenerator *b3mImpactFeedback;

@property (nonatomic, assign)
    NSInteger b3mLastDetent;

@property (nonatomic, assign)
    NSInteger b3mPendingDetent;

@end


@implementation B3MPercentSliderCell

- (void)b3mEnsurePercentLabel
{
    if (self.b3mPercentLabel) {
        return;
    }

    UILabel *label =
        [[UILabel alloc] initWithFrame:CGRectZero];

    label.textAlignment =
        NSTextAlignmentCenter;

    label.textColor =
        UIColor.secondaryLabelColor;

    label.font =
        [UIFont monospacedDigitSystemFontOfSize:15.0
                                         weight:UIFontWeightSemibold];

    /*
     * Exact GlassFolders layout idea:
     * opaque dynamic badge masks Preferences' internal track beneath it.
     */
    label.backgroundColor =
        UIColor.secondarySystemGroupedBackgroundColor;

    label.layer.cornerRadius = 7.0;
    label.clipsToBounds = YES;
    label.userInteractionEnabled = NO;

    [self.contentView addSubview:label];

    self.b3mPercentLabel = label;
    self.b3mLastDetent = NSIntegerMin;
    self.b3mPendingDetent = NSIntegerMin;
}

- (UISlider *)b3mSlider
{
    UIControl *control = [self control];

    if ([control isKindOfClass:[UISlider class]]) {
        return (UISlider *)control;
    }

    return nil;
}

- (NSInteger)b3mDetentForValue:(float)value
{
    NSInteger detent =
        (NSInteger)lroundf(value / 5.0f) * 5;

    return MAX(0, MIN(100, detent));
}

- (void)b3mPersistDetent:(NSInteger)detent
{
    detent = MAX(0, MIN(100, detent));

    double storedValue =
        (double)detent;

    CFNumberRef number =
        CFNumberCreate(
            kCFAllocatorDefault,
            kCFNumberDoubleType,
            &storedValue
        );

    if (number) {
        CFPreferencesSetAppValue(
            B3MActiveStrengthKey(),
            number,
            kB3MPrefsDomain
        );

        CFPreferencesAppSynchronize(
            kB3MPrefsDomain
        );

        CFRelease(number);
    }

    B3MPostPreferencesChanged();
}

- (void)b3mEnsureImpactGenerator
{
    if (!self.b3mImpactFeedback) {
        /*
         * Same feedback type as GlassFolders:
         * crisp mechanical tick at each 5% threshold.
         */
        self.b3mImpactFeedback =
            [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleRigid];
    }
}

- (void)b3mBindSliderIfNeeded
{
    UISlider *slider =
        [self b3mSlider];

    if (!slider) {
        return;
    }

    if (self.b3mBoundSlider != slider) {
        if (self.b3mBoundSlider) {
            [self.b3mBoundSlider
                removeTarget:self
                      action:NULL
            forControlEvents:UIControlEventAllEvents];
        }

        self.b3mBoundSlider = slider;
        slider.continuous = YES;

        [slider addTarget:self
                   action:@selector(b3mSliderTouchDown:)
         forControlEvents:UIControlEventTouchDown];

        [slider addTarget:self
                   action:@selector(b3mSliderChanged:)
         forControlEvents:UIControlEventValueChanged];

        [slider addTarget:self
                   action:@selector(b3mSliderTouchEnded:)
         forControlEvents:(
             UIControlEventTouchUpInside |
             UIControlEventTouchUpOutside |
             UIControlEventTouchCancel
         )];

        NSInteger initial =
            [self b3mDetentForValue:slider.value];

        self.b3mLastDetent = initial;
        self.b3mPendingDetent = initial;
    }
}

- (void)b3mUpdatePercentLabel
{
    UISlider *slider =
        [self b3mSlider];

    if (!slider) {
        self.b3mPercentLabel.text = @"";
        return;
    }

    NSInteger detent =
        [self b3mDetentForValue:slider.value];

    self.b3mPercentLabel.text =
        [NSString stringWithFormat:@"%ld%%",
                                   (long)detent];
}

- (void)b3mSliderTouchDown:(UISlider *)sender
{
    NSInteger detent =
        [self b3mDetentForValue:sender.value];

    self.b3mLastDetent = detent;
    self.b3mPendingDetent = detent;

    [self b3mEnsureImpactGenerator];
    [self.b3mImpactFeedback prepare];
}

- (void)b3mSliderChanged:(UISlider *)sender
{
    /*
     * Directly ported GlassFolders interaction:
     * - thumb remains smooth under the finger
     * - nearest 5% is displayed live
     * - each crossed 5% threshold emits one crisp tick
     * - exact magnetic settle happens only on release
     */
    NSInteger detent =
        [self b3mDetentForValue:sender.value];

    self.b3mPendingDetent = detent;

    if (self.b3mLastDetent != detent) {
        self.b3mLastDetent = detent;

        [self b3mEnsureImpactGenerator];

        [self.b3mImpactFeedback
            impactOccurredWithIntensity:0.68];

        [self.b3mImpactFeedback prepare];
    }

    self.b3mPercentLabel.text =
        [NSString stringWithFormat:@"%ld%%",
                                   (long)detent];
}

- (void)b3mSliderTouchEnded:(UISlider *)sender
{
    NSInteger detent =
        self.b3mPendingDetent;

    if (detent == NSIntegerMin) {
        detent =
            [self b3mDetentForValue:sender.value];
    }

    detent =
        MAX(0, MIN(100, detent));

    /*
     * Same GlassFolders magnetic settle:
     * smooth while dragging, exact 5% value on release.
     */
    [sender setValue:(float)detent
            animated:YES];

    [self b3mPersistDetent:detent];

    self.b3mPercentLabel.text =
        [NSString stringWithFormat:@"%ld%%",
                                   (long)detent];

    self.b3mPendingDetent = detent;
    self.b3mLastDetent = detent;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    [self b3mEnsurePercentLabel];
    [self b3mBindSliderIfNeeded];

    UISlider *slider =
        [self b3mSlider];

    if (!slider) {
        self.b3mPercentLabel.hidden = YES;
        return;
    }

    self.b3mPercentLabel.hidden = NO;

    CGRect bounds =
        self.contentView.bounds;

    /*
     * GlassFolders percentage column geometry.
     */
    const CGFloat leftInset = 14.0;
    const CGFloat valueWidth = 64.0;
    const CGFloat gap = 18.0;
    const CGFloat rightInset = 18.0;

    self.b3mPercentLabel.frame =
        CGRectMake(
            leftInset,
            5.0,
            valueWidth,
            MAX(
                28.0,
                CGRectGetHeight(bounds) - 10.0
            )
        );

    CGRect sliderFrame =
        slider.frame;

    sliderFrame.origin.x =
        leftInset +
        valueWidth +
        gap;

    sliderFrame.size.width =
        MAX(
            120.0,
            CGRectGetWidth(bounds) -
            sliderFrame.origin.x -
            rightInset
        );

    slider.frame =
        sliderFrame;

    [self.contentView
        bringSubviewToFront:self.b3mPercentLabel];

    [self b3mUpdatePercentLabel];
}

@end


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
    if (identifier.length == 0) {
        return nil;
    }

    for (PSSpecifier *specifier in _specifiers) {
        NSString *candidate =
            [specifier propertyForKey:@"id"];

        if ([candidate isEqualToString:identifier]) {
            return specifier;
        }
    }

    return nil;
}

- (NSNumber *)b3mStrengthForKey:(CFStringRef)key
                       fallback:(double)fallback
{
    CFPreferencesAppSynchronize(
        kB3MPrefsDomain
    );

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            key,
            kB3MPrefsDomain
        );

    double strength =
        fallback;

    if (value) {
        if (CFGetTypeID(value) ==
            CFNumberGetTypeID()) {

            double number =
                fallback;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number)) {

                strength = number;
            }
        }

        CFRelease(value);
    }

    strength =
        MAX(0.0, MIN(100.0, strength));

    return @(strength);
}

- (id)readActiveStrength:(PSSpecifier *)specifier
{
    (void)specifier;

    return
        [self b3mStrengthForKey:
            B3MActiveStrengthKey()
                        fallback:
            B3MActiveStrengthFallback()];
}

- (void)setActiveStrength:(id)value
                specifier:(PSSpecifier *)specifier
{
    (void)specifier;

    double strength =
        [value respondsToSelector:
            @selector(doubleValue)]
            ? [value doubleValue]
            : B3MActiveStrengthFallback();

    strength =
        MAX(0.0, MIN(100.0, strength));

    CFNumberRef number =
        CFNumberCreate(
            kCFAllocatorDefault,
            kCFNumberDoubleType,
            &strength
        );

    if (number) {
        CFPreferencesSetAppValue(
            B3MActiveStrengthKey(),
            number,
            kB3MPrefsDomain
        );

        CFPreferencesAppSynchronize(
            kB3MPrefsDomain
        );

        CFRelease(number);
    }

    B3MPostPreferencesChanged();
}

- (void)b3mUpdateActiveStrengthLabel
{
    PSSpecifier *labelSpecifier =
        [self b3mSpecifierWithIdentifier:
            @"ActiveStrengthLabel"];

    if (!labelSpecifier) {
        return;
    }

    NSString *label =
        B3MCurrentGlassStyle() == 0
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
         * Recreate the single strength row so the native slider requests
         * the newly selected style's saved value.
         */
        [self reloadSpecifiers];
    }
}

@end
