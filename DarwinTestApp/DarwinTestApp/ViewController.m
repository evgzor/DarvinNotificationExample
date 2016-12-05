//
//  ViewController.m
//  DarwinTestApp
//
//

#import "ViewController.h"
#import "DeviceAccessibilityCheck.h"

@interface ViewController ()

@property (nonatomic, strong) DeviceAccessibilityCheck *deviceAccessibilityCheck;
@property (weak, nonatomic) IBOutlet UILabel *currentStateLabel;
@property (weak, nonatomic) IBOutlet UIButton *getDeviceButton;
@property (strong, nonatomic) NSArray *statesArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.deviceAccessibilityCheck = [[DeviceAccessibilityCheck alloc] init];
    self.statesArray = [NSArray arrayWithObjects:@"NEW", @"PENDING", @"USING", @"WAIT", @"BUSY", @"INACTIVE", @"INVALID", nil];
    self.getDeviceButton.enabled = NO;
    
    [self.deviceAccessibilityCheck checkDeviceUseFlag:^(DeviceCallbacks deviceStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI];
        });
    }];
}

- (void)updateUI {
    NSString *currentState = [self.statesArray objectAtIndex:self.deviceAccessibilityCheck.currentApplicationState];
    self.currentStateLabel.text = [NSString stringWithFormat:@"Current State: %@", currentState];
    self.getDeviceButton.enabled = [currentState isEqualToString:@"NEW"] || [currentState isEqualToString:@"INACTIVE"];
}

- (IBAction)getDeviceButtonTouched:(id)sender {
    [self.deviceAccessibilityCheck checkDeviceUseFlag:^(DeviceCallbacks deviceStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI];
        });
    }];
}

- (IBAction)releaseDeviceButtonTouched:(id)sender {
    [self.deviceAccessibilityCheck unregisterDeviceCheck];
    [self updateUI];
}

@end
