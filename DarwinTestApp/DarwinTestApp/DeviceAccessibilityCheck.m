//
//  DarwinTestApp
//
//

#import "DeviceAccessibilityCheck.h"
@import UIKit;

// Static constants and enumerations

static NSTimeInterval const kTimeOut = 0.05;

static NSString* const kGetDeviceStatus = @"darwin.get.device.status";
static NSString* const kMsgDeviceInUse = @"darwin.msg.device.in.use";
static NSString* const kMsgDeviceWait1 = @"darwin.msg.device.wait1";
static NSString* const KMsgDeviceReleased = @"darwin.msg.device.released";
// Message to handle termination of application in "Wait" state
static NSString* const kMsgApplicationInWaitStateTerminated = @"darwin.msg.waiting.application.terminated";

static NSUInteger deviceStatus;

// Application States (based on device state) enum
typedef enum : NSUInteger {
    NEW = 0,
    PENDING,
    USING,
    WAIT,
    BUSY,
    INACTIVE,
    INVALID
} ApplicationStates;

@interface DeviceAccessibilityCheck()

@property (readwrite) NSUInteger currentApplicationState;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL isTimerStopped;
@property (nonatomic, strong) NSMutableSet *receivedNotifications;
@property (nonatomic, copy) DeviceCallback callback;

@end

@implementation DeviceAccessibilityCheck

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Init properties
        _currentApplicationState = NEW;
        _isTimerStopped = NO;
        _receivedNotifications = [[NSMutableSet alloc] init];
        
        // Subsribe for notifications, request device status and start listening for reply
        [self registerNotificationReceiver];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(terminationHandler) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foregroundSwitchHandler) name:UIApplicationWillEnterForegroundNotification object:nil];
    }
    
    return self;
}

#pragma mark - Timer Handler

- (void)timerDidFire {
    // There are no messages received, stop timer and go on
    [self stopTimer];
    [self updateDeviceState];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.isTimerStopped = YES;
}

#pragma mark - Termination Handler
- (void)terminationHandler {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self unregisterDeviceCheck];
}

#pragma mark - Foreground Switch handler
- (void)foregroundSwitchHandler {
    if (self.currentApplicationState == BUSY) {
        [self updateDeviceState];
    }
}

#pragma mark - Update Device State method
- (void)updateDeviceState {
    switch (self.currentApplicationState) {
        case PENDING:
        {
            NSLog(@"Current State: PENDING");
            if ([self.receivedNotifications containsObject:kMsgDeviceInUse] && [self.receivedNotifications containsObject:kMsgDeviceWait1] && self.isTimerStopped) {
                self.currentApplicationState = BUSY;
                NSLog(@"State changed to: BUSY");
            } else if ([self.receivedNotifications containsObject:kMsgDeviceInUse] && self.isTimerStopped) {
                self.currentApplicationState = WAIT;
                NSLog(@"State changed to: WAIT");
                [self sendEventWithIdentifier:kMsgDeviceWait1];
            } else if (self.isTimerStopped) {
                self.currentApplicationState = USING;
                NSLog(@"State changed to: USING");
                [self sendEventWithIdentifier:kMsgDeviceInUse];
            } else {
                self.currentApplicationState = INVALID;
                NSLog(@"State changed to: INVALID");
            }
        }
            break;
        case USING:
        {
            NSLog(@"Current State: USING");
            if (deviceStatus == DEVICE_FREE) {
                self.currentApplicationState = INACTIVE;
                NSLog(@"State changed to: INACTIVE");
            }
        }
            break;
        case WAIT:
        {
            NSLog(@"Current State: WAIT");
            if (deviceStatus == DEVICE_FREE) {
                self.currentApplicationState = USING;
                NSLog(@"State changed to: USING");
                [self sendEventWithIdentifier:kMsgDeviceInUse];
            }
        }
            break;
        case BUSY:
        {
            NSLog(@"Current State: BUSY");
            if (![self.receivedNotifications containsObject:kMsgDeviceWait1]) {
                if ([self.receivedNotifications containsObject:kMsgApplicationInWaitStateTerminated] || [self.receivedNotifications containsObject:kMsgDeviceInUse]) {
                    self.currentApplicationState = WAIT;
                    [self sendEventWithIdentifier:kMsgDeviceWait1];
                    NSLog(@"State changed to: WAIT");
                }
            }
        }
            break;
        case INACTIVE:
        {
            NSLog(@"Current State: INACTIVE");
        }
            break;
        case INVALID:
            NSLog(@"Something went wrong");
        default:
            break;
    }
    
    if (self.callback) {
        self.callback(deviceStatus);
    }
    
    [self.receivedNotifications removeAllObjects];
}

#pragma mark - Send Events method

- (void)sendEventWithIdentifier:(NSString *)eventIdentifier {
    NSLog(@"Sending Notification: %@", eventIdentifier);
    
    if ([eventIdentifier isEqualToString:kGetDeviceStatus] && self.currentApplicationState == NEW) {
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        if (currentState != UIApplicationStateBackground) {
            self.currentApplicationState = PENDING;
            NSLog(@"State changed to: PENDING");
        } else {
            self.currentApplicationState = INACTIVE;
            NSLog(@"State changed to: INACTIVE");
        }
    }
    CFStringRef event = (__bridge CFStringRef)eventIdentifier;
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), event, NULL, NULL, true);
}

- (void)updateDeviceStatusWithReceivedIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:kMsgDeviceInUse]) {
        deviceStatus = DEVICE_WAIT;
    } else if ([identifier isEqualToString:kMsgDeviceWait1]) {
        deviceStatus = DEVICE_BUSY;
    } else if ([identifier isEqualToString:KMsgDeviceReleased]) {
        deviceStatus = DEVICE_FREE;
    } else if ([identifier isEqualToString:kGetDeviceStatus]) {
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        if (currentState == UIApplicationStateBackground) {
            deviceStatus = APPLICATION_IN_BACKGROUND;
        }
    }
}

#pragma mark - Subscribe for Darwin Notifications

- (void)registerNotificationReceiver {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kGetDeviceStatus, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kMsgDeviceInUse, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kMsgDeviceWait1, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)KMsgDeviceReleased, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kMsgApplicationInWaitStateTerminated, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    
    // Add background task to prevent app from going to "sleep" mode
    UIBackgroundTaskIdentifier bgTask = 0;
    UIApplication *app = [UIApplication sharedApplication];
    bgTask = [app beginBackgroundTaskWithExpirationHandler:^{
        [app endBackgroundTask:bgTask];
    }];
}

#pragma mark - Notification Received Callback

static void notificationReceivedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
    NSString *notificationReceived = (__bridge NSString*)name;
    NSLog(@"Notification Received: %@", notificationReceived);
    
    DeviceAccessibilityCheck *weakself = (__bridge DeviceAccessibilityCheck*)observer;

    [weakself updateDeviceStatusWithReceivedIdentifier:notificationReceived];
    
    if ([notificationReceived isEqualToString:kGetDeviceStatus]) {
        // Depending on current device state send or do not send reply notifications
        switch (weakself.currentApplicationState) {
            case USING:
                [weakself sendEventWithIdentifier:kMsgDeviceInUse];
                break;
            case WAIT:
                [weakself sendEventWithIdentifier:kMsgDeviceWait1];
                break;
            default:
                break;
        }
    } else {
        [weakself.receivedNotifications addObject:notificationReceived];
    }
    
    if ([notificationReceived isEqualToString:KMsgDeviceReleased]) {
        [weakself updateDeviceState];
    }
}

#pragma mark - app API's methods

// Check device state with callback
- (void)checkDeviceUseFlag:(DeviceCallback)deviceAvailabilityCallback {
    if (deviceAvailabilityCallback) {
        if (self.currentApplicationState == INACTIVE) {
            self.currentApplicationState = NEW;
        }
        [self sendEventWithIdentifier:kGetDeviceStatus];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimeOut target:self selector:@selector(timerDidFire) userInfo:nil repeats:YES];
        self.callback = deviceAvailabilityCallback;
    }
}

// Unregister device check
- (void)unregisterDeviceCheck {
    if (self.currentApplicationState == USING) {
        [self sendEventWithIdentifier:KMsgDeviceReleased];
    } else if (self.currentApplicationState == WAIT) {
        [self sendEventWithIdentifier:kMsgApplicationInWaitStateTerminated];
    }
    self.currentApplicationState = INACTIVE;
    [self stopTimer];
    [self.receivedNotifications removeAllObjects];
}

@end
