//
//  ViewController.m
//  GuidedAccessBug
//
//  Created by Bryan Hathaway on 29/04/2016.
//  Copyright © 2016 Bryan. All rights reserved.
//

#import "ViewController.h"

static NSString* const keychainIdentifier = @"keychainIdentifier";
static NSString* const keychainServiceName = @"keychainService";

@interface ViewController ()
@property (nonatomic, assign) BOOL locked;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
//  Set a junk data in keychain that has attributes requiring user passcode to read it.
        NSData* keychainData = [@"This data's content is irrelevant." dataUsingEncoding:NSUTF8StringEncoding];
        NSMutableDictionary	* attributes = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                            (__bridge id)(kSecClassGenericPassword), kSecClass,
                                            keychainIdentifier, kSecAttrAccount,
                                            keychainServiceName, kSecAttrService, nil];
    
    
        CFErrorRef accessControlError = NULL;
        SecAccessControlRef accessControlRef = SecAccessControlCreateWithFlags(
                                                                               kCFAllocatorDefault,
                                                                               kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                                                               kSecAccessControlUserPresence,
                                                                               &accessControlError);
        if (accessControlRef == NULL || accessControlError != NULL) {
            NSLog(@"Couldn't write password for identifier “%@” in keychain: %@.", keychainIdentifier, accessControlError);
            return;
        }
    
        // Set access control
        attributes[(__bridge id)kSecAttrAccessControl] = (__bridge id)accessControlRef;
        attributes[(__bridge id)kSecUseAuthenticationUI] = @YES;
        attributes[(__bridge id)kSecValueData] = keychainData;
        CFTypeRef result;
        OSStatus osStatus = SecItemAdd((__bridge CFDictionaryRef)attributes, &result);
        if (osStatus != noErr) {
            NSError * error = [[NSError alloc] initWithDomain:NSOSStatusErrorDomain code:osStatus userInfo:nil];
            NSLog(@"Couldn't add for identifier “%@” OSError %d: %@.", keychainIdentifier, (int)osStatus, error);
        }
}

- (BOOL)locked {
    return UIAccessibilityIsGuidedAccessEnabled();
}

- (IBAction)onForceUnlock:(UIButton *)sender {
    [self unlockDevice];
}

- (IBAction)onButtonTap:(UIButton *)sender {
    if (self.locked) {
        [self promptUnlock];
    } else {
        [self lockDevice];
    }

}

- (void)lockDevice {
    UIAccessibilityRequestGuidedAccessSession(YES, ^(BOOL didSucceed) {
        if (didSucceed) {
            self.lockButton.titleLabel.text = @"Unlock";
        } else {
            NSLog(@"Lock failed. Ensure MDM is setup correctly (Settings > General > Profiles & Device Management > \"Your MDM profile\" > Restrictions > \"Autonomous Single App Mode permissions added\"");
        }
    });
}

- (void)promptUnlock {
    NSString * secUseOperationPrompt = @"Enter device passcode to proceed";
    /* Attempt to read our junk data from keychain - will cause passcode prompt to appear.
     *  Bug occurs here. iOS cannot present the passcode screen while guided access is enabled.
     *
     */
    dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void) {
        NSMutableDictionary * query = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                       (__bridge id)(kSecClassGenericPassword), kSecClass,
                                       keychainIdentifier, kSecAttrAccount,
                                       keychainServiceName, kSecAttrService,
                                       secUseOperationPrompt, kSecUseOperationPrompt,
                                       nil];
        // Start the query and the fingerprint scan and/or device passcode validation
        CFTypeRef result = nil;
        OSStatus userPresenceStatus = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
        // Ignore the found content of the key chain entry (the dummy password) and only evaluate the return code.
        if (noErr == userPresenceStatus) {
            [self unlockDevice];
        } else {
            NSLog(@"Fingerprint or device passcode could not be validated. Status %d.", (int) userPresenceStatus);
        }
    });
}

- (void)unlockDevice {
    UIAccessibilityRequestGuidedAccessSession(NO, ^(BOOL didSucceed) {
        if (didSucceed) {
            self.lockButton.titleLabel.text = @"Lock";
        } else {
            NSLog(@"Unlock failed. Ensure MDM is setup correctly (Settings > General > Profiles & Device Management > \"Your MDM profile\" > Restrictions > \"Autonomous Single App Mode permissions added\"");
        }
    });
}

@end
