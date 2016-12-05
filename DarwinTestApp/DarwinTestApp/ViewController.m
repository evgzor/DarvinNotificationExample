//
//  ViewController.m
//  DarwinTestApp
//
//

#import "ViewController.h"
#import "AccessoryAccessibilityCheck.h"

@interface ViewController ()

@property (nonatomic, strong) AccessoryAccessibilityCheck *accessoryAccessibilityCheck;
@property (weak, nonatomic) IBOutlet UILabel *currentStateLabel;
@property (weak, nonatomic) IBOutlet UIButton *getAccessoryButton;
@property (strong, nonatomic) NSArray *statesArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.

    self.accessoryAccessibilityCheck = [[AccessoryAccessibilityCheck alloc] init];
    self.statesArray = [NSArray arrayWithObjects:@"NEW", @"PENDING", @"USING_ACCESSORY", @"WAIT", @"BUSY", @"INACTIVE", @"INVALID", nil];
    self.getAccessoryButton.enabled = NO;
    
    [self.accessoryAccessibilityCheck checkAccessoryUseFlag:^(AccessoryCallbacks accessoryStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI];
        });
    }];
}

- (void)updateUI {
    NSString *currentState = [self.statesArray objectAtIndex:self.accessoryAccessibilityCheck.currentApplicationState];
    self.currentStateLabel.text = [NSString stringWithFormat:@"Current State: %@", currentState];
    self.getAccessoryButton.enabled = [currentState isEqualToString:@"NEW"] || [currentState isEqualToString:@"INACTIVE"];
}

- (IBAction)getAccessoryButtonTouched:(id)sender {
    [self.accessoryAccessibilityCheck checkAccessoryUseFlag:^(AccessoryCallbacks accessoryStatus) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateUI];
        });
    }];
}

- (IBAction)releaseAccessoryButtonTouched:(id)sender {
    [self.accessoryAccessibilityCheck unregisterAccessoryCheck];
    [self updateUI];
}

@end
