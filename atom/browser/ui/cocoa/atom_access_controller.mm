#include "atom/browser/ui/cocoa/atom_access_controller.h"

#import <AVFoundation/AVFoundation.h>
#import <Cocoa/Cocoa.h>

@implementation AtomAccessController

+ (instancetype)sharedController {
  static dispatch_once_t once;
  static AtomAccessController* sharedController;
  dispatch_once(&once, ^{
    sharedController = [[self alloc] init];
  });
  return sharedController;
}

- (instancetype)init {
  if ((self = [super init])) {
    if (@available(macOS 10.14, *)) {
      switch (
          [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
          cameraAccessStatus_ = AccessStateGranted;
          break;
        case AVAuthorizationStatusRestricted:
          cameraAccessStatus_ = AccessStateRestricted;
          break;
        case AVAuthorizationStatusDenied:
          cameraAccessStatus_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusNotDetermined:
          cameraAccessStatus_ = AccessStateUnknown;
      }
      switch (
          [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized:
          microphoneAccessStatus_ = AccessStateGranted;
          break;
        case AVAuthorizationStatusRestricted:
          microphoneAccessStatus_ = AccessStateRestricted;
          break;
        case AVAuthorizationStatusDenied:
          microphoneAccessStatus_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusNotDetermined:
          microphoneAccessStatus_ = AccessStateUnknown;
      }
      [[[NSWorkspace sharedWorkspace] notificationCenter]
          addObserver:self
             selector:@selector(applicationLaunched:)
                 name:NSWorkspaceDidLaunchApplicationNotification
               object:nil];
    } else {
      // access is always allowed pre-10.14 Mojave
      cameraAccessStatus_ = AccessStateGranted;
      microphoneAccessStatus_ = AccessStateGranted;
    }
  }
  return self;
}

// pops up an alert to change mic prefs (restart required to take effect)
- (void)alertForMicrophoneAccess {
  if (microphoneAccessStatus_ == AccessStateDenied) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"This app needs access to the microphone.";
    [alert addButtonWithTitle:@"Change Preferences"];
    [alert addButtonWithTitle:@"Cancel"];
    NSInteger modalResponse = [alert runModal];
    if (modalResponse == NSAlertFirstButtonReturn) {
      [[NSWorkspace sharedWorkspace]
          openURL:[NSURL
                      URLWithString:@"x-apple.systempreferences:com.apple."
                                    @"preference.security?Privacy_Microphone"]];
    }
  }
}

// pops up an alert to change camera prefs (restart required to take effect)
- (void)alertForCameraAccess {
  if (cameraAccessStatus_ == AccessStateDenied) {
    NSAlert* alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleWarning;
    alert.messageText = @"This app needs access to the camera.";
    [alert addButtonWithTitle:@"Change Preferences"];
    [alert addButtonWithTitle:@"Cancel"];
    NSInteger modalResponse = [alert runModal];
    if (modalResponse == NSAlertFirstButtonReturn) {
      [[NSWorkspace sharedWorkspace]
          openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple."
                                       @"preference.security?Privacy_Camera"]];
    }
  }
}

// requests camera/mic access from the user, optionally asking again if denied
- (void)askForMediaAccess:(BOOL)askAgain
               completion:(void (^)(BOOL))accessGranted {
  if (@available(macOS 10.14, *)) {
    [AVCaptureDevice
        requestAccessForMediaType:AVMediaTypeAudio
                completionHandler:^(BOOL granted) {
                  microphoneAccessStatus_ =
                      (granted) ? AccessStateGranted : AccessStateDenied;
                  [AVCaptureDevice
                      requestAccessForMediaType:AVMediaTypeVideo
                              completionHandler:^(BOOL granted) {
                                cameraAccessStatus_ = (granted)
                                                          ? AccessStateGranted
                                                          : AccessStateDenied;
                                if (askAgain) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                    [self alertForMicrophoneAccess];
                                    [self alertForCameraAccess];
                                  });
                                }
                                dispatch_async(dispatch_get_main_queue(), ^{
                                  accessGranted(self.hasFullMediaAccess);
                                });
                              }];
                }];
  } else {
    // access always allowed pre-10.14 Mojave
    accessGranted(self.hasFullMediaAccess);
  }
}

// requests camera access from the user, optionally asking again if denied
- (void)askForCameraAccess:(BOOL)askAgain
                completion:(void (^)(BOOL))accessGranted {
  if (@available(macOS 10.14, *)) {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                             completionHandler:^(BOOL granted) {
                               cameraAccessStatus_ = (granted)
                                                         ? AccessStateGranted
                                                         : AccessStateDenied;
                               if (askAgain) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                   [self alertForCameraAccess];
                                 });
                               }
                               dispatch_async(dispatch_get_main_queue(), ^{
                                 accessGranted(self.hasCameraAccess);
                               });
                             }];
  } else {
    // access always allowed pre-10.14 Mojave
    accessGranted(self.hasCameraAccess);
  }
}

// requests mic access from the user, optionally asking again if denied
- (void)askForMicrophoneAccess:(BOOL)askAgain
                    completion:(void (^)(BOOL))accessGranted {
  if (@available(macOS 10.14, *)) {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio
                             completionHandler:^(BOOL granted) {
                               microphoneAccessStatus_ =
                                   (granted) ? AccessStateGranted
                                             : AccessStateDenied;
                               if (askAgain) {
                                 dispatch_async(dispatch_get_main_queue(), ^{
                                   [self alertForMicrophoneAccess];
                                 });
                               }
                               dispatch_async(dispatch_get_main_queue(), ^{
                                 accessGranted(self.hasMicrophoneAccess);
                               });
                             }];
  } else {
    // access always allowed pre-10.14 Mojave
    accessGranted(self.hasMicrophoneAccess);
  }
}

// whether or not the user has given consent for camera access
- (BOOL)hasCameraAccess {
  if (@available(macOS 10.14, *))
    return (cameraAccessStatus_ == AccessStateGranted);
  return YES;
}

// whether or not the user has given consent for mic access
- (BOOL)hasMicrophoneAccess {
  if (@available(macOS 10.14, *))
    return (microphoneAccessStatus_ == AccessStateGranted);
  return YES;
}

// whether or not the user has given consent for mic access
- (BOOL)hasFullMediaAccess {
  return (self.hasCameraAccess && self.hasMicrophoneAccess);
}

- (NSString*)getMediaAccessStatusForType:(NSString*)mediaType {
  NSString* status = nil;

  if ([mediaType isEqualToString:@"camera"])
    status = [self accessStateToString:cameraAccessStatus_];
  else if ([mediaType isEqualToString:@"microphone"])
    status = [self accessStateToString:microphoneAccessStatus_];
  else
    [NSException raise:NSGenericException format:@"Invalid mediaType passed."];

  return status;
}

- (NSString*)accessStateToString:(AccessState)accessState {
  NSString* result = nil;
  switch (accessState) {
    case AccessStateGranted:
      result = @"granted";
      break;
    case AccessStateDenied:
      result = @"denied";
      break;
    case AccessStateRestricted:
      result = @"restricted";
      break;
    case AccessStateUnknown:
      result = @"unknown";
      break;
    default:
      [NSException raise:NSGenericException format:@"Unexpected AccessState."];
  }
  return result;
}

@end
