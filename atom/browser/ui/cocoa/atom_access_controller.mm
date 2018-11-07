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
        case AVAuthorizationStatusRestricted:
          cameraAccessState_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusDenied:
          cameraAccessState_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusNotDetermined:
          cameraAccessState_ = AccessStateDenied;
      }
      switch (
          [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio]) {
        case AVAuthorizationStatusAuthorized:
        case AVAuthorizationStatusRestricted:
          microphoneAccessState_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusDenied:
          microphoneAccessState_ = AccessStateDenied;
          break;
        case AVAuthorizationStatusNotDetermined:
          microphoneAccessState_ = AccessStateDenied;
      }
      [[[NSWorkspace sharedWorkspace] notificationCenter]
          addObserver:self
             selector:@selector(applicationLaunched:)
                 name:NSWorkspaceDidLaunchApplicationNotification
               object:nil];
    } else {
      cameraAccessState_ = AccessStateGranted;
      microphoneAccessState_ = AccessStateDenied;
    }
  }
  return self;
}

- (void)askForMicrophoneAccess {
  if (microphoneAccessState_ == AccessStateDenied) {
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

- (void)askForCameraAccess {
  if (cameraAccessState_ == AccessStateDenied) {
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

- (void)askForMediaAccess:(BOOL)askAgain
               completion:(void (^)(BOOL))allAccessGranted {
  if (@available(macOS 10.14, *)) {
    [AVCaptureDevice
        requestAccessForMediaType:AVMediaTypeAudio
                completionHandler:^(BOOL granted) {
                  microphoneAccessState_ =
                      (granted) ? AccessStateGranted : AccessStateDenied;
                  [AVCaptureDevice
                      requestAccessForMediaType:AVMediaTypeVideo
                              completionHandler:^(BOOL granted) {
                                cameraAccessState_ = (granted)
                                                         ? AccessStateGranted
                                                         : AccessStateDenied;
                                if (askAgain) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                    [self askForMicrophoneAccess];
                                    [self askForCameraAccess];
                                  });
                                }
                                dispatch_async(dispatch_get_main_queue(), ^{
                                  allAccessGranted(self.hasFullMediaAccess);
                                });
                              }];
                }];
  } else {
    allAccessGranted(self.hasFullMediaAccess);
  }
}

- (BOOL)hasCameraAccess {
  if (@available(macOS 10.14, *)) {
    return (cameraAccessState_ == AccessStateGranted);
  }
  return YES;
}

- (BOOL)hasMicrophoneAccess {
  if (@available(macOS 10.14, *)) {
    return (microphoneAccessState_ == AccessStateGranted);
  }
  return YES;
}

- (BOOL)hasFullMediaAccess {
  return (self.hasCameraAccess && self.hasMicrophoneAccess);
}

@end