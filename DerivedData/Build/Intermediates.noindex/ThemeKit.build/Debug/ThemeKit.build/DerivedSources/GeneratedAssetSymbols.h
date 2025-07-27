#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"themekit.ThemeKit";

/// The "bubblegum" asset catalog color resource.
static NSString * const ACColorNameBubblegum AC_SWIFT_PRIVATE = @"bubblegum";

/// The "buttercup" asset catalog color resource.
static NSString * const ACColorNameButtercup AC_SWIFT_PRIVATE = @"buttercup";

/// The "indigo" asset catalog color resource.
static NSString * const ACColorNameIndigo AC_SWIFT_PRIVATE = @"indigo";

/// The "lavender" asset catalog color resource.
static NSString * const ACColorNameLavender AC_SWIFT_PRIVATE = @"lavender";

/// The "magenta" asset catalog color resource.
static NSString * const ACColorNameMagenta AC_SWIFT_PRIVATE = @"magenta";

/// The "navy" asset catalog color resource.
static NSString * const ACColorNameNavy AC_SWIFT_PRIVATE = @"navy";

/// The "orange" asset catalog color resource.
static NSString * const ACColorNameOrange AC_SWIFT_PRIVATE = @"orange";

/// The "oxblood" asset catalog color resource.
static NSString * const ACColorNameOxblood AC_SWIFT_PRIVATE = @"oxblood";

/// The "periwinkle" asset catalog color resource.
static NSString * const ACColorNamePeriwinkle AC_SWIFT_PRIVATE = @"periwinkle";

/// The "poppy" asset catalog color resource.
static NSString * const ACColorNamePoppy AC_SWIFT_PRIVATE = @"poppy";

/// The "purple" asset catalog color resource.
static NSString * const ACColorNamePurple AC_SWIFT_PRIVATE = @"purple";

/// The "seafoam" asset catalog color resource.
static NSString * const ACColorNameSeafoam AC_SWIFT_PRIVATE = @"seafoam";

/// The "sky" asset catalog color resource.
static NSString * const ACColorNameSky AC_SWIFT_PRIVATE = @"sky";

/// The "tan" asset catalog color resource.
static NSString * const ACColorNameTan AC_SWIFT_PRIVATE = @"tan";

/// The "teal" asset catalog color resource.
static NSString * const ACColorNameTeal AC_SWIFT_PRIVATE = @"teal";

/// The "yellow" asset catalog color resource.
static NSString * const ACColorNameYellow AC_SWIFT_PRIVATE = @"yellow";

#undef AC_SWIFT_PRIVATE
