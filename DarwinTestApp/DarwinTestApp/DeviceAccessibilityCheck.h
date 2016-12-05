//
//
//

#import <Foundation/Foundation.h>

/**
 Device Callbacks enumeration.
 Possible device states are listed below.
 */
typedef enum : NSUInteger {
    DEVICE_FREE = 0,
    DEVICE_WAIT,
    DEVICE_BUSY,
    APPLICATION_IN_BACKGROUND
} DeviceCallbacks;

// Shortened form of a callback block used in API method below
typedef void(^DeviceCallback)(DeviceCallbacks deviceStatus);

@interface DeviceAccessibilityCheck : NSObject

@property (readonly) NSUInteger currentApplicationState;

// API methods
/**
 *  Call this method in order to request the access to connected device.
 *  Based on returned value, specify corresponding behaviour of your application.
 *
 *  @param deviceAvailabilityCallback Callback block which will be called after receiving current device state.
 */
- (void)checkDeviceUseFlag:(DeviceCallback)deviceAvailabilityCallback;
/**
 *  Call this method to finish use of device.
 *  Other applications based on app will be notified that device have been released.
 */
- (void)unregisterDeviceCheck;

@end
