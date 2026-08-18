#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <stdint.h>
#import <math.h>

/*
 * A16 / iOS 16.6 pressure-signal diagnostic.
 *
 * Read-only by design:
 * - does not modify minimumPressDuration
 * - does not hook SBIconView long-press behavior
 * - does not change UIContextMenuInteraction activation
 * - does not synthesize force or pressure
 *
 * It samples the private UITouch HID event only while a touch belongs to a
 * SpringBoard icon view and prints [B3M-PRESS] lines for calibration.
 */

typedef const void *B3MIOHIDEventRef;
typedef uint32_t B3MIOHIDEventType;
typedef uint32_t B3MIOHIDEventField;
typedef double B3MIOHIDFloat;

typedef B3MIOHIDEventType (*B3MIOHIDEventGetTypeFn)(B3MIOHIDEventRef event);
typedef B3MIOHIDFloat (*B3MIOHIDEventGetFloatValueFn)(B3MIOHIDEventRef event,
                                                       B3MIOHIDEventField field);

/* IOHIDEventTypes: Digitizer event type is 11 and fields are type << 16 + offset. */
static const B3MIOHIDEventType kB3MHIDEventTypeDigitizer = 11;
static const B3MIOHIDEventField kB3MHIDDigitizerFieldBase = (11u << 16);
static const B3MIOHIDEventField kB3MHIDFieldQuality = (11u << 16) + 17u;
static const B3MIOHIDEventField kB3MHIDFieldDensity = (11u << 16) + 18u;
static const B3MIOHIDEventField kB3MHIDFieldMajorRadius = (11u << 16) + 20u;

static void *gB3MIOKitHandle = NULL;
static B3MIOHIDEventGetTypeFn gB3MIOHIDEventGetType = NULL;
static B3MIOHIDEventGetFloatValueFn gB3MIOHIDEventGetFloatValue = NULL;
static char kB3MPressureStateKey;

@interface B3MPressureDiagnosticState : NSObject
@property (nonatomic, assign) BOOL hasBaseline;
@property (nonatomic, assign) CGFloat baselineDensity;
@property (nonatomic, assign) CGFloat baselineQuality;
@property (nonatomic, assign) CGFloat baselineRadius;
@property (nonatomic, assign) NSTimeInterval lastLogTimestamp;
@property (nonatomic, assign) NSUInteger sampleIndex;
@end

@implementation B3MPressureDiagnosticState
@end

static BOOL B3MResolveIOHIDSymbols(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gB3MIOHIDEventGetType =
            (B3MIOHIDEventGetTypeFn)dlsym(RTLD_DEFAULT, "IOHIDEventGetType");
        gB3MIOHIDEventGetFloatValue =
            (B3MIOHIDEventGetFloatValueFn)dlsym(RTLD_DEFAULT, "IOHIDEventGetFloatValue");

        if (!gB3MIOHIDEventGetType || !gB3MIOHIDEventGetFloatValue) {
            gB3MIOKitHandle =
                dlopen("/System/Library/Frameworks/IOKit.framework/IOKit",
                       RTLD_LAZY | RTLD_LOCAL);

            if (gB3MIOKitHandle) {
                if (!gB3MIOHIDEventGetType) {
                    gB3MIOHIDEventGetType =
                        (B3MIOHIDEventGetTypeFn)dlsym(gB3MIOKitHandle,
                                                     "IOHIDEventGetType");
                }
                if (!gB3MIOHIDEventGetFloatValue) {
                    gB3MIOHIDEventGetFloatValue =
                        (B3MIOHIDEventGetFloatValueFn)dlsym(gB3MIOKitHandle,
                                                           "IOHIDEventGetFloatValue");
                }
            }
        }
    });

    return gB3MIOHIDEventGetType && gB3MIOHIDEventGetFloatValue;
}

static B3MIOHIDEventRef B3MHIDEventForTouch(UITouch *touch)
{
    if (!touch) return NULL;

    SEL selector = NSSelectorFromString(@"_hidEvent");
    if (![touch respondsToSelector:selector]) return NULL;

    IMP implementation = [touch methodForSelector:selector];
    if (!implementation) return NULL;

    typedef B3MIOHIDEventRef (*B3MHIDEventGetter)(id, SEL);
    B3MHIDEventGetter getter = (B3MHIDEventGetter)implementation;
    return getter(touch, selector);
}

static UIView *B3MIconAncestorForTouch(UITouch *touch)
{
    UIView *view = touch.view;
    if (!view) return nil;

    Class iconViewClass = NSClassFromString(@"SBIconView");

    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if (iconViewClass && [candidate isKindOfClass:iconViewClass]) {
            return candidate;
        }

        NSString *className = NSStringFromClass(candidate.class);
        if ([className rangeOfString:@"IconView" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return candidate;
        }
    }

    return nil;
}

static NSString *B3MPhaseName(UITouchPhase phase)
{
    switch (phase) {
        case UITouchPhaseBegan: return @"began";
        case UITouchPhaseMoved: return @"moved";
        case UITouchPhaseStationary: return @"stationary";
        case UITouchPhaseEnded: return @"ended";
        case UITouchPhaseCancelled: return @"cancelled";
        default: return @"unknown";
    }
}

static CGFloat B3MSafeRatio(CGFloat current, CGFloat baseline)
{
    if (!isfinite(current) || !isfinite(baseline) || fabs(baseline) < 0.000001) {
        return 0.0;
    }
    return current / baseline;
}

static B3MPressureDiagnosticState *B3MStateForTouch(UITouch *touch)
{
    B3MPressureDiagnosticState *state =
        objc_getAssociatedObject(touch, &kB3MPressureStateKey);

    if (!state) {
        state = [[B3MPressureDiagnosticState alloc] init];
        objc_setAssociatedObject(touch,
                                 &kB3MPressureStateKey,
                                 state,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    return state;
}

static void B3MLogPressureSample(UITouch *touch, UIView *iconView)
{
    if (!touch || !iconView || !B3MResolveIOHIDSymbols()) return;

    B3MIOHIDEventRef hidEvent = B3MHIDEventForTouch(touch);
    if (!hidEvent) return;

    B3MIOHIDEventType eventType = gB3MIOHIDEventGetType(hidEvent);
    if (eventType != kB3MHIDEventTypeDigitizer) return;

    CGFloat quality =
        (CGFloat)gB3MIOHIDEventGetFloatValue(hidEvent, kB3MHIDFieldQuality);
    CGFloat density =
        (CGFloat)gB3MIOHIDEventGetFloatValue(hidEvent, kB3MHIDFieldDensity);
    CGFloat rawRadius =
        (CGFloat)gB3MIOHIDEventGetFloatValue(hidEvent, kB3MHIDFieldMajorRadius);

    if (!isfinite(quality) || !isfinite(density) || !isfinite(rawRadius)) return;

    B3MPressureDiagnosticState *state = B3MStateForTouch(touch);
    NSTimeInterval timestamp = touch.timestamp;

    if (!state.hasBaseline || touch.phase == UITouchPhaseBegan) {
        state.hasBaseline = YES;
        state.baselineDensity = density;
        state.baselineQuality = quality;
        state.baselineRadius = rawRadius;
        state.lastLogTimestamp = 0.0;
        state.sampleIndex = 0;
    }

    BOOL terminal =
        touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled;

    /* About 30 Hz is enough to see a pressure ramp without flooding SpringBoard logs. */
    if (!terminal &&
        state.lastLogTimestamp > 0.0 &&
        (timestamp - state.lastLogTimestamp) < (1.0 / 30.0)) {
        return;
    }

    state.lastLogTimestamp = timestamp;
    state.sampleIndex += 1;

    CGFloat densityRatio = B3MSafeRatio(density, state.baselineDensity);
    CGFloat qualityRatio = B3MSafeRatio(quality, state.baselineQuality);
    CGFloat radiusRatio = B3MSafeRatio(rawRadius, state.baselineRadius);

    NSLog(@"[B3M-PRESS] #%lu phase=%@ icon=%p<%@> "
          "density=%.6f x%.3f quality=%.6f x%.3f radiusRaw=%.6f x%.3f "
          "radiusUIKit=%.3f±%.3f force=%.3f/%.3f t=%.4f",
          (unsigned long)state.sampleIndex,
          B3MPhaseName(touch.phase),
          iconView,
          NSStringFromClass(iconView.class),
          density,
          densityRatio,
          quality,
          qualityRatio,
          rawRadius,
          radiusRatio,
          touch.majorRadius,
          touch.majorRadiusTolerance,
          touch.force,
          touch.maximumPossibleForce,
          timestamp);

    if (terminal) {
        objc_setAssociatedObject(touch,
                                 &kB3MPressureStateKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void B3MInspectTouchEvent(UIEvent *event)
{
    if (!event || event.type != UIEventTypeTouches) return;

    NSSet<UITouch *> *touches = event.allTouches;
    for (UITouch *touch in touches) {
        UIView *iconView = B3MIconAncestorForTouch(touch);
        if (!iconView) continue;
        B3MLogPressureSample(touch, iconView);
    }
}

%hook UIApplication

- (void)sendEvent:(UIEvent *)event
{
    %orig;
    B3MInspectTouchEvent(event);
}

%end

%ctor
{
    BOOL available = B3MResolveIOHIDSymbols();
    NSLog(@"[B3M-PRESS] diagnostic loaded; IOHID symbols=%@ fieldBase=0x%X",
          available ? @"YES" : @"NO",
          (unsigned int)kB3MHIDDigitizerFieldBase);
}
