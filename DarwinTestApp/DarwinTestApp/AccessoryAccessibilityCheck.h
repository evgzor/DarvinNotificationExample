//
//  AccessoryAccessibilityCheck.h
//  DarwinTestApp
//
//

#import <Foundation/Foundation.h>

/**
 Accessory Callbacks enumeration.
 Possible accessory states are listed below.
 */
typedef enum : NSUInteger {
    ACCESSORY_FREE = 0,
    ACCESSORY_WAIT,
    ACCESSORY_BUSY,
    APP_IN_BACKGROUND
} AccessoryCallbacks;

// Shortened form of a callback block used in API method below
typedef void(^AccessoryCallback)(AccessoryCallbacks accessoryStatus);

@interface AccessoryAccessibilityCheck : NSObject

@property (readonly) NSUInteger currentApplicationState;

// API methods
/**
 *  Call this method in order to request the access to connected accessory.
 *  Based on returned value, specify corresponding behaviour of your application.
 *
 *  @param accessoryAvailabilityCallback Callback block which will be called after receiving current accessory state.
 */
- (void)checkAccessoryUseFlag:(AccessoryCallback)accessoryAvailabilityCallback;
/**
 *  Call this method to finish use of accessory.
 *  Other applications based on app will be notified that accessory have been released.
 */
- (void)unregisterAccessoryCheck;

@end
