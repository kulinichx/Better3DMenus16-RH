#import "B3MRootListController.h"
#import <Preferences/PSSpecifier.h>

@implementation B3MRootListController

- (NSArray *)specifiers
{
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

@end
