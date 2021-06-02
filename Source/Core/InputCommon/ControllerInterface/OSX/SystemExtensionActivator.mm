#include "Common/Logging/Log.h"
#include "InputCommon/GCAdapter.h"

#import <SystemExtensions/SystemExtensions.h>

@interface DolphinMacSystemExtensionActivator : NSObject <OSSystemExtensionRequestDelegate>
@property (nonatomic, assign, readwrite) BOOL extensionIsActivated;
+ (instancetype)sharedActivator;
- (void)requestActivation;
@end

@implementation DolphinMacSystemExtensionActivator

+ (instancetype)sharedActivator
{
    static DolphinMacSystemExtensionActivator *sharedActivator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedActivator = [self new];
        sharedActivator.extensionIsActivated = NO;
    });

    return sharedActivator;
}

- (void)requestActivation API_AVAILABLE(macosx(11.0))
{
    OSSystemExtensionRequest *activationRequest = [OSSystemExtensionRequest 
        activationRequestForExtension:@"com.secretkeys.gcadapterdriverkitext"
        queue:dispatch_get_main_queue()
    ];
        
    activationRequest.delegate = self;
        
    [OSSystemExtensionManager.sharedManager submitRequest:activationRequest];
}

- (void)requestNeedsUserApproval:(OSSystemExtensionRequest *)request API_AVAILABLE(macosx(11.0))
{
    NOTICE_LOG(SERIALINTERFACE, "macOS system extension requires user approval.");
}

- (void)request:(OSSystemExtensionRequest *)request
    didFailWithError:(NSError *)error API_AVAILABLE(macosx(11.0))
{
    const char *errorDesc = [error.localizedDescription UTF8String];
    ERROR_LOG(SERIALINTERFACE, "Failed to activate macOS system extension with error %s", errorDesc);
}

- (void)request:(OSSystemExtensionRequest *)request 
    didFinishWithResult:(OSSystemExtensionRequestResult)result API_AVAILABLE(macosx(11.0))
{
    if (result == OSSystemExtensionRequestCompleted) {
        self.extensionIsActivated = YES;
        NOTICE_LOG(SERIALINTERFACE, "macOS System Extension activated, starting GCAdapter scanner");
        GCAdapter::Init();

    }

    if (result == OSSystemExtensionRequestWillCompleteAfterReboot) {
        NOTICE_LOG(SERIALINTERFACE, "macOS System Extension requires reboot");
    }
}

- (OSSystemExtensionReplacementAction)request:(OSSystemExtensionRequest *)request 
    actionForReplacingExtension:(OSSystemExtensionProperties *)existing 
    withExtension:(nonnull OSSystemExtensionProperties *)ext API_AVAILABLE(macosx(11.0))
{
    //return OSSystemExtensionReplacementActionCancel;
    return OSSystemExtensionReplacementActionReplace;
}

@end

bool requestOSXSystemExtensionActivation() {
    // 10.15 has DriverKit, but it has some issues with regards to shipping a functioning dext.
    if (@available(macOS 11.0, *))
    {
        DolphinMacSystemExtensionActivator *sharedActivator = [DolphinMacSystemExtensionActivator sharedActivator];
        
        if (!sharedActivator.extensionIsActivated)
        {
            NOTICE_LOG(SERIALINTERFACE, "Requesting macOS GCAdapter System Extension Activation");
            [sharedActivator requestActivation];
            return false;
        }

        NOTICE_LOG(SERIALINTERFACE, "macOS GCAdapter System Extension Activated");
        return true;
    }

    // For anything prior to 11.0, just return true and let things proceed as normal.
    // (Prior to 11.0, the old school kext approach should be used by the end user).
    return true;
}
