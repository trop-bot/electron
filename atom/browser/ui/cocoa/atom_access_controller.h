// Copyright (c) 2018 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#import <Cocoa/Cocoa.h>

#ifndef ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_
#define ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_

typedef NS_ENUM(NSInteger, AccessState) {
  AccessStateUnknown,
  AccessStateGranted,
  AccessStateDenied
};

@interface AtomAccessController : NSObject {
  AccessState microphoneAccessState_;
  AccessState cameraAccessState_;
}

+ (instancetype)sharedController;

- (void)askForMediaAccess:(BOOL)askAgain
               completion:(void (^)(BOOL))accessGranted;
- (void)askForMicrophoneAccess:(BOOL)askAgain
                    completion:(void (^)(BOOL))accessGranted;
- (void)askForCameraAccess:(BOOL)askAgain
                completion:(void (^)(BOOL))accessGranted;

- (void)alertForMicrophoneAccess;
- (void)alertForCameraAccess;

- (BOOL)hasMicrophoneAccess;
- (BOOL)hasCameraAccess;
- (BOOL)hasFullMediaAccess;

@end

#endif  // ATOM_BROWSER_UI_COCOA_ATOM_ACCESS_CONTROLLER_H_
