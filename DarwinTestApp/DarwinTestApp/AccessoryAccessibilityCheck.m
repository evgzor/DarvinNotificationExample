//
//  AccessoryAccessibilityCheck.m
//  DarwinTestApp
//
//

#import "AccessoryAccessibilityCheck.h"
@import UIKit;

// Static constants and enumerations

static NSTimeInterval const kTimeOut = 0.05;

static NSString* const kGetAccessoryStatus = @"darwin.get.accessory.status";
static NSString* const kMsgAccessoryInUse = @"darwin.msg.accessory.in.use";
static NSString* const kMsgAccessoryWait1 = @"darwin.msg.accessory.wait1";
static NSString* const KMsgAccessoryReleased = @"darwin.msg.accessory.released";
// Message to handle termination of application in "Wait" state
static NSString* const kMsgApplicationInWaitStateTerminated = @"darwin.msg.waiting.application.terminated";

static NSUInteger accessoryStatus;

// Application States (based on accessory state) enum
typedef enum : NSUInteger {
    NEW = 0,
    PENDING,
    USING_ACCESSORY,
    WAIT,
    BUSY,
    INACTIVE,
    INVALID
} ApplicationStates;

@interface AccessoryAccessibilityCheck()

@property (readwrite) NSUInteger currentApplicationState;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) BOOL isTimerStopped;
@property (nonatomic, strong) NSMutableSet *receivedNotifications;
@property (nonatomic, copy) AccessoryCallback callback;

@end

@implementation AccessoryAccessibilityCheck

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    
    if (self) {
        // Init properties
        _currentApplicationState = NEW;
        _isTimerStopped = NO;
        _receivedNotifications = [[NSMutableSet alloc] init];
        
        // Subsribe for notifications, request accessory status and start listening for reply
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
    [self updateAccessoryState];
}

- (void)stopTimer {
    [self.timer invalidate];
    self.isTimerStopped = YES;
}

#pragma mark - Termination Handler
- (void)terminationHandler {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self unregisterAccessoryCheck];
}

#pragma mark - Foreground Switch handler
- (void)foregroundSwitchHandler {
    if (self.currentApplicationState == BUSY) {
        [self updateAccessoryState];
    }
}

#pragma mark - Update Accessory State method
- (void)updateAccessoryState {
    switch (self.currentApplicationState) {
        case PENDING:
        {
            NSLog(@"Current State: PENDING");
            if ([self.receivedNotifications containsObject:kMsgAccessoryInUse] && [self.receivedNotifications containsObject:kMsgAccessoryWait1] && self.isTimerStopped) {
                self.currentApplicationState = BUSY;
                NSLog(@"State changed to: BUSY");
            } else if ([self.receivedNotifications containsObject:kMsgAccessoryInUse] && self.isTimerStopped) {
                self.currentApplicationState = WAIT;
                NSLog(@"State changed to: WAIT");
                [self sendEventWithIdentifier:kMsgAccessoryWait1];
            } else if (self.isTimerStopped) {
                self.currentApplicationState = USING_ACCESSORY;
                NSLog(@"State changed to: USING_ACCESSORY");
                [self sendEventWithIdentifier:kMsgAccessoryInUse];
            } else {
                self.currentApplicationState = INVALID;
                NSLog(@"State changed to: INVALID");
            }
        }
            break;
        case USING_ACCESSORY:
        {
            NSLog(@"Current State: USING_ACCESSORY");
            if (accessoryStatus == ACCESSORY_FREE) {
                self.currentApplicationState = INACTIVE;
                NSLog(@"State changed to: INACTIVE");
            }
        }
            break;
        case WAIT:
        {
            NSLog(@"Current State: WAIT");
            if (accessoryStatus == ACCESSORY_FREE) {
                self.currentApplicationState = USING_ACCESSORY;
                NSLog(@"State changed to: USING_ACCESSORY");
                [self sendEventWithIdentifier:kMsgAccessoryInUse];
            }
        }
            break;
        case BUSY:
        {
            NSLog(@"Current State: BUSY");
            if (![self.receivedNotifications containsObject:kMsgAccessoryWait1]) {
                if ([self.receivedNotifications containsObject:kMsgApplicationInWaitStateTerminated] || [self.receivedNotifications containsObject:kMsgAccessoryInUse]) {
                    self.currentApplicationState = WAIT;
                    [self sendEventWithIdentifier:kMsgAccessoryWait1];
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
        self.callback(accessoryStatus);
    }
    
    [self.receivedNotifications removeAllObjects];
}

#pragma mark - Send Events method

- (void)sendEventWithIdentifier:(NSString *)eventIdentifier {
    NSLog(@"Sending Notification: %@", eventIdentifier);
    
    if ([eventIdentifier isEqualToString:kGetAccessoryStatus] && self.currentApplicationState == NEW) {
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

- (void)updateAccessoryStatusWithReceivedIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:kMsgAccessoryInUse]) {
        accessoryStatus = ACCESSORY_WAIT;
    } else if ([identifier isEqualToString:kMsgAccessoryWait1]) {
        accessoryStatus = ACCESSORY_BUSY;
    } else if ([identifier isEqualToString:KMsgAccessoryReleased]) {
        accessoryStatus = ACCESSORY_FREE;
    } else if ([identifier isEqualToString:kGetAccessoryStatus]) {
        UIApplicationState currentState = [[UIApplication sharedApplication] applicationState];
        if (currentState == UIApplicationStateBackground) {
            accessoryStatus = APP_IN_BACKGROUND;
        }
    }
}

#pragma mark - Subscribe for Darwin Notifications

- (void)registerNotificationReceiver {
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kGetAccessoryStatus, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kMsgAccessoryInUse, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)kMsgAccessoryWait1, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge const void *)(self), notificationReceivedCallback, (__bridge CFStringRef)KMsgAccessoryReleased, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
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
    
    AccessoryAccessibilityCheck *weakself = (__bridge AccessoryAccessibilityCheck*)observer;

    [weakself updateAccessoryStatusWithReceivedIdentifier:notificationReceived];
    
    if ([notificationReceived isEqualToString:kGetAccessoryStatus]) {
        // Depending on current accessory state send or do not send reply notifications
        switch (weakself.currentApplicationState) {
            case USING_ACCESSORY:
                [weakself sendEventWithIdentifier:kMsgAccessoryInUse];
                break;
            case WAIT:
                [weakself sendEventWithIdentifier:kMsgAccessoryWait1];
                break;
            default:
                break;
        }
    } else {
        [weakself.receivedNotifications addObject:notificationReceived];
    }
    
    if ([notificationReceived isEqualToString:KMsgAccessoryReleased]) {
        [weakself updateAccessoryState];
    }
}

#pragma mark - app API's methods

// Check accessory state with callback
- (void)checkAccessoryUseFlag:(AccessoryCallback)accessoryAvailabilityCallback {
    if (accessoryAvailabilityCallback) {
        if (self.currentApplicationState == INACTIVE) {
            self.currentApplicationState = NEW;
        }
        [self sendEventWithIdentifier:kGetAccessoryStatus];
        self.timer = [NSTimer scheduledTimerWithTimeInterval:kTimeOut target:self selector:@selector(timerDidFire) userInfo:nil repeats:YES];
        self.callback = accessoryAvailabilityCallback;
    }
}

// Unregister accessory check
- (void)unregisterAccessoryCheck {
    if (self.currentApplicationState == USING_ACCESSORY) {
        [self sendEventWithIdentifier:KMsgAccessoryReleased];
    } else if (self.currentApplicationState == WAIT) {
        [self sendEventWithIdentifier:kMsgApplicationInWaitStateTerminated];
    }
    self.currentApplicationState = INACTIVE;
    [self stopTimer];
    [self.receivedNotifications removeAllObjects];
}

@end
