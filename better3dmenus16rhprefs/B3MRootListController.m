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

@property (nonatomic, strong)
    UISlider *b3mCustomSlider;

@property (nonatomic, strong)
    UIImpactFeedbackGenerator *b3mImpactFeedback;

@property (nonatomic, assign)
    NSInteger b3mLastDetent;

@property (nonatomic, assign)
    NSInteger b3mPendingDetent;

@property (nonatomic, assign)
    BOOL b3mDidLoadInitialValue;

@end


@implementation B3MPercentSliderCell

- (NSInteger)b3mDetentForValue:(float)value
{
    NSInteger detent =
        (NSInteger)lroundf(value / 5.0f) * 5;

    return MAX(0, MIN(100, detent));
}

- (double)b3mReadActiveStrength
{
    CFPreferencesAppSynchronize(kB3MPrefsDomain);

    CFPropertyListRef value =
        CFPreferencesCopyAppValue(
            B3MActiveStrengthKey(),
            kB3MPrefsDomain
        );

    double strength =
        B3MActiveStrengthFallback();

    if (value) {
        if (CFGetTypeID(value) ==
            CFNumberGetTypeID()) {

            double number = strength;

            if (CFNumberGetValue(
                    (CFNumberRef)value,
                    kCFNumberDoubleType,
                    &number)) {
                strength = number;
            }
        }

        CFRelease(value);
    }

    return MAX(0.0, MIN(100.0, strength));
}

- (void)b3mEnsureControls
{
    /*
     * PSSliderTableCell owns a private/native UISlider whose layout is
     * recalculated by Preferences after our cell layout pass. Trying to move
     * that control is why previous gutter fixes appeared to do nothing.
     *
     * Keep the Preferences cell for integration, but hide its native slider
     * and render a dedicated UISlider whose frame is entirely ours.
     */
    UIControl *nativeControl = [self control];

    if ([nativeControl isKindOfClass:[UISlider class]]) {
        nativeControl.hidden = YES;
        nativeControl.userInteractionEnabled = NO;
    }

    if (!self.b3mPercentLabel) {
        UILabel *label =
            [[UILabel alloc] initWithFrame:CGRectZero];

        label.textAlignment = NSTextAlignmentCenter;
        label.textColor = UIColor.secondaryLabelColor;
        label.font =
            [UIFont monospacedDigitSystemFontOfSize:15.0
                                             weight:UIFontWeightSemibold];
        label.backgroundColor = UIColor.clearColor;
        label.userInteractionEnabled = NO;
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.85;

        [self.contentView addSubview:label];
        self.b3mPercentLabel = label;
    }

    if (!self.b3mCustomSlider) {
        UISlider *slider =
            [[UISlider alloc] initWithFrame:CGRectZero];

        slider.minimumValue = 0.0f;
        slider.maximumValue = 100.0f;
        slider.continuous = YES;
        slider.accessibilityLabel = @"Strength";

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

        [self.contentView addSubview:slider];
        self.b3mCustomSlider = slider;

        self.b3mLastDetent = NSIntegerMin;
        self.b3mPendingDetent = NSIntegerMin;
    }

    if (!self.b3mDidLoadInitialValue &&
        !self.b3mCustomSlider.tracking) {

        float value =
            (float)[self b3mReadActiveStrength];

        self.b3mCustomSlider.value = value;

        NSInteger detent =
            [self b3mDetentForValue:value];

        self.b3mLastDetent = detent;
        self.b3mPendingDetent = detent;
        self.b3mDidLoadInitialValue = YES;
    }
}

- (void)b3mEnsureImpactGenerator
{
    if (!self.b3mImpactFeedback) {
        self.b3mImpactFeedback =
            [[UIImpactFeedbackGenerator alloc]
                initWithStyle:UIImpactFeedbackStyleRigid];
    }
}

- (void)b3mUpdatePercentLabel
{
    if (!self.b3mCustomSlider) {
        self.b3mPercentLabel.text = @"";
        return;
    }

    NSInteger detent =
        [self b3mDetentForValue:
            self.b3mCustomSlider.value];

    self.b3mPercentLabel.text =
        [NSString stringWithFormat:@"%ld%%",
                                   (long)detent];
}

- (void)b3mPersistDetent:(NSInteger)detent
{
    detent = MAX(0, MIN(100, detent));

    double storedValue = (double)detent;

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
    NSInteger detent = self.b3mPendingDetent;

    if (detent == NSIntegerMin) {
        detent =
            [self b3mDetentForValue:sender.value];
    }

    detent = MAX(0, MIN(100, detent));

    [sender setValue:(float)detent
            animated:YES];

    [self b3mPersistDetent:detent];

    self.b3mPercentLabel.text =
        [NSString stringWithFormat:@"%ld%%",
                                   (long)detent];

    self.b3mPendingDetent = detent;
    self.b3mLastDetent = detent;
}

- (void)prepareForReuse
{
    [super prepareForReuse];

    /*
     * The same cell can become the other style after the segmented control is
     * changed and specifiers are reloaded. Force a fresh value read then.
     */
    self.b3mDidLoadInitialValue = NO;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self b3mEnsureControls];

    CGRect bounds = self.contentView.bounds;

    /*
     * Explicit, non-overlapping columns:
     *
     *   | 16 | percentage 64 | 18 gap | slider ........ | 18 |
     *
     * The UISlider track/thumb cannot enter the percentage column because it
     * is a separate control whose frame starts after the reserved gutter.
     */
    const CGFloat leftInset = 16.0;
    const CGFloat valueWidth = 64.0;
    const CGFloat gap = 18.0;
    const CGFloat rightInset = 18.0;

    CGFloat sliderX =
        leftInset + valueWidth + gap;

    CGFloat sliderWidth =
        MAX(
            100.0,
            CGRectGetWidth(bounds) -
            sliderX -
            rightInset
        );

    CGFloat contentHeight =
        CGRectGetHeight(bounds);

    self.b3mPercentLabel.frame =
        CGRectMake(
            leftInset,
            0.0,
            valueWidth,
            contentHeight
        );

    self.b3mCustomSlider.frame =
        CGRectMake(
            sliderX,
            floor((contentHeight - 44.0) * 0.5),
            sliderWidth,
            44.0
        );

    self.b3mPercentLabel.hidden = NO;
    self.b3mCustomSlider.hidden = NO;

    [self.contentView
        bringSubviewToFront:self.b3mCustomSlider];
    [self.contentView
        bringSubviewToFront:self.b3mPercentLabel];

    if (!self.b3mCustomSlider.tracking) {
        /*
         * Keep the visible value in sync after Clear/Liquid specifier reloads.
         */
        float activeValue =
            (float)[self b3mReadActiveStrength];

        if (fabsf(self.b3mCustomSlider.value - activeValue) > 0.01f) {
            self.b3mCustomSlider.value = activeValue;
        }
    }

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

- (void)b3mUpdateActiveStrengthLabelForStyle:(NSInteger)style
{
    PSSpecifier *labelSpecifier =
        [self b3mSpecifierWithIdentifier:
            @"ActiveStrengthLabel"];

    if (!labelSpecifier) {
        return;
    }

    NSString *label =
        style == 0
            ? @"Clear Strength"
            : @"Liquid Glass Strength";

    [labelSpecifier setProperty:label
                        forKey:@"label"];
}

- (void)b3mUpdateActiveStrengthLabel
{
    [self b3mUpdateActiveStrengthLabelForStyle:
        B3MCurrentGlassStyle()];
}

- (void)setPreferenceValue:(id)value
                 specifier:(PSSpecifier *)specifier
{
    [super setPreferenceValue:value
                    specifier:specifier];

    NSString *key =
        [specifier propertyForKey:@"key"];

    if ([key isEqualToString:@"GlassStyle"]) {
        NSInteger style =
            [value respondsToSelector:@selector(integerValue)]
                ? [value integerValue]
                : B3MCurrentGlassStyle();

        style = (style == 0) ? 0 : 1;

        /*
         * Use the segment's new value directly for the visible heading.
         * This avoids a one-step stale CFPreferences read while the
         * Preferences framework is still committing the segment change.
         */
        [self b3mUpdateActiveStrengthLabelForStyle:style];

        long long storedStyle =
            (long long)style;

        CFNumberRef styleNumber =
            CFNumberCreate(
                kCFAllocatorDefault,
                kCFNumberLongLongType,
                &storedStyle
            );

        if (styleNumber) {
            CFPreferencesSetAppValue(
                CFSTR("GlassStyle"),
                styleNumber,
                kB3MPrefsDomain
            );

            CFPreferencesAppSynchronize(
                kB3MPrefsDomain
            );

            CFRelease(styleNumber);
        }

        /*
         * Recreate the single strength row so it immediately reads the
         * selected style's own saved value.
         */
        [self reloadSpecifiers];
        B3MPostPreferencesChanged();
    }
}

@end
