// Copyright (c) 2018 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#ifndef ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_
#define ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_

typedef NS_ENUM(NSInteger, AccessState) {
  AccessStateUnknown,
  AccessStateGranted,
  AccessStateDenied,
  AccessStateRestricted
};

@interface AtomAccessController : NSObject {
  AccessState microphoneAccessStatus_;
  AccessState cameraAccessStatus_;
}

+ (instancetype)sharedController;

- (void)askForMicrophoneAccess:(void (^)(BOOL))accessGranted;
- (void)askForCameraAccess:(void (^)(BOOL))accessGranted;

- (BOOL)hasCameraAccess;
- (BOOL)hasMicrophoneAccess;

- (NSString*)getMediaAccessStatusForType:(NSString*)mediaType;

@end

#endif  // ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_
