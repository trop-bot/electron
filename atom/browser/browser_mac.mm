// Copyright (c) 2013 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/browser/browser.h"

#include "atom/browser/mac/atom_application.h"
#include "atom/browser/mac/atom_application_delegate.h"
#include "atom/browser/mac/dict_util.h"
#include "atom/browser/native_window.h"
#include "atom/browser/window_list.h"
#include "atom/common/platform_util.h"
#include "base/mac/bundle_locations.h"
#include "base/mac/foundation_util.h"
#include "base/mac/mac_util.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/sys_string_conversions.h"
#include "brightray/common/application_info.h"
#include "net/base/mac/url_conversions.h"
#include "ui/gfx/image/image.h"
#include "url/gurl.h"

namespace atom {

void Browser::SetShutdownHandler(base::Callback<bool()> handler) {
  [[AtomApplication sharedApplication] setShutdownHandler:std::move(handler)];
}

void Browser::Focus() {
  [[AtomApplication sharedApplication] activateIgnoringOtherApps:YES];
}

void Browser::Hide() {
  [[AtomApplication sharedApplication] hide:nil];
}

void Browser::Show() {
  [[AtomApplication sharedApplication] unhide:nil];
}

void Browser::AddRecentDocument(const base::FilePath& path) {
  NSString* path_string = base::mac::FilePathToNSString(path);
  if (!path_string)
    return;
  NSURL* u = [NSURL fileURLWithPath:path_string];
  if (!u)
    return;
  [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:u];
}

void Browser::ClearRecentDocuments() {
  [[NSDocumentController sharedDocumentController] clearRecentDocuments:nil];
}

bool Browser::RemoveAsDefaultProtocolClient(const std::string& protocol,
                                            mate::Arguments* args) {
  NSString* identifier = [base::mac::MainBundle() bundleIdentifier];
  if (!identifier)
    return false;

  if (!Browser::IsDefaultProtocolClient(protocol, args))
    return false;

  NSString* protocol_ns = [NSString stringWithUTF8String:protocol.c_str()];
  CFStringRef protocol_cf = base::mac::NSToCFCast(protocol_ns);
  CFArrayRef bundleList = LSCopyAllHandlersForURLScheme(protocol_cf);
  if (!bundleList) {
    return false;
  }
  // On macOS, we can't query the default, but the handlers list seems to put
  // Apple's defaults first, so we'll use the first option that isn't our bundle
  CFStringRef other = nil;
  for (CFIndex i = 0; i < CFArrayGetCount(bundleList); ++i) {
    other =
        base::mac::CFCast<CFStringRef>(CFArrayGetValueAtIndex(bundleList, i));
    if (![identifier isEqualToString:(__bridge NSString*)other]) {
      break;
    }
  }

  // No other app was found set it to none instead of setting it back to itself.
  if ([identifier isEqualToString:(__bridge NSString*)other]) {
    other = base::mac::NSToCFCast(@"None");
  }

  OSStatus return_code = LSSetDefaultHandlerForURLScheme(protocol_cf, other);
  return return_code == noErr;
}

bool Browser::SetAsDefaultProtocolClient(const std::string& protocol,
                                         mate::Arguments* args) {
  if (protocol.empty())
    return false;

  NSString* identifier = [base::mac::MainBundle() bundleIdentifier];
  if (!identifier)
    return false;

  NSString* protocol_ns = [NSString stringWithUTF8String:protocol.c_str()];
  OSStatus return_code = LSSetDefaultHandlerForURLScheme(
      base::mac::NSToCFCast(protocol_ns), base::mac::NSToCFCast(identifier));
  return return_code == noErr;
}

bool Browser::IsDefaultProtocolClient(const std::string& protocol,
                                      mate::Arguments* args) {
  if (protocol.empty())
    return false;

  NSString* identifier = [base::mac::MainBundle() bundleIdentifier];
  if (!identifier)
    return false;

  NSString* protocol_ns = [NSString stringWithUTF8String:protocol.c_str()];

  CFStringRef bundle =
      LSCopyDefaultHandlerForURLScheme(base::mac::NSToCFCast(protocol_ns));
  NSString* bundleId =
      static_cast<NSString*>(base::mac::CFTypeRefToNSObjectAutorelease(bundle));
  if (!bundleId)
    return false;

  // Ensure the comparison is case-insensitive
  // as LS does not persist the case of the bundle id.
  NSComparisonResult result = [bundleId caseInsensitiveCompare:identifier];
  return result == NSOrderedSame;
}

void Browser::SetAppUserModelID(const base::string16& name) {}

bool Browser::SetBadgeCount(int count) {
  DockSetBadgeText(count != 0 ? base::IntToString(count) : "");
  badge_count_ = count;
  return true;
}

void Browser::SetUserActivity(const std::string& type,
                              const base::DictionaryValue& user_info,
                              mate::Arguments* args) {
  std::string url_string;
  args->GetNext(&url_string);

  [[AtomApplication sharedApplication]
      setCurrentActivity:base::SysUTF8ToNSString(type)
            withUserInfo:DictionaryValueToNSDictionary(user_info)
          withWebpageURL:net::NSURLWithGURL(GURL(url_string))];
}

std::string Browser::GetCurrentActivityType() {
  if (@available(macOS 10.10, *)) {
    NSUserActivity* userActivity =
        [[AtomApplication sharedApplication] getCurrentActivity];
    return base::SysNSStringToUTF8(userActivity.activityType);
  } else {
    return std::string();
  }
}

void Browser::InvalidateCurrentActivity() {
  [[AtomApplication sharedApplication] invalidateCurrentActivity];
}

void Browser::UpdateCurrentActivity(const std::string& type,
                                    const base::DictionaryValue& user_info) {
  [[AtomApplication sharedApplication]
      updateCurrentActivity:base::SysUTF8ToNSString(type)
               withUserInfo:DictionaryValueToNSDictionary(user_info)];
}

bool Browser::WillContinueUserActivity(const std::string& type) {
  bool prevent_default = false;
  for (BrowserObserver& observer : observers_)
    observer.OnWillContinueUserActivity(&prevent_default, type);
  return prevent_default;
}

void Browser::DidFailToContinueUserActivity(const std::string& type,
                                            const std::string& error) {
  for (BrowserObserver& observer : observers_)
    observer.OnDidFailToContinueUserActivity(type, error);
}

bool Browser::ContinueUserActivity(const std::string& type,
                                   const base::DictionaryValue& user_info) {
  bool prevent_default = false;
  for (BrowserObserver& observer : observers_)
    observer.OnContinueUserActivity(&prevent_default, type, user_info);
  return prevent_default;
}

void Browser::UserActivityWasContinued(const std::string& type,
                                       const base::DictionaryValue& user_info) {
  for (BrowserObserver& observer : observers_)
    observer.OnUserActivityWasContinued(type, user_info);
}

bool Browser::UpdateUserActivityState(const std::string& type,
                                      const base::DictionaryValue& user_info) {
  bool prevent_default = false;
  for (BrowserObserver& observer : observers_)
    observer.OnUpdateUserActivityState(&prevent_default, type, user_info);
  return prevent_default;
}

static LSSharedFileListItemRef GetItemFromLoginItems(
    NSURL* wantedURL,
    LSSharedFileListRef fileList) {
  if (wantedURL == NULL || fileList == NULL)
    return NULL;

  CFArrayRef listSnapshot = LSSharedFileListCopySnapshot(fileList, NULL);
  for (id itemObject in (__bridge NSArray*)listSnapshot) {
    LSSharedFileListItemRef item = (__bridge LSSharedFileListItemRef)itemObject;
    UInt32 resolutionFlags =
        kLSSharedFileListNoUserInteraction | kLSSharedFileListDoNotMountVolumes;

    CFURLRef currentItemURL = NULL;
    if (@available(macOS 10.10, *))
      currentItemURL =
          LSSharedFileListItemCopyResolvedURL(item, resolutionFlags, NULL);

    if (currentItemURL &&
        CFEqual(currentItemURL, (__bridge CFTypeRef)(wantedURL))) {
      CFRetain(item);
      CFRelease(currentItemURL);
      CFRelease(listSnapshot);
      return item;
    }
    if (currentItemURL)
      CFRelease(currentItemURL);
  }

  if (listSnapshot)
    CFRelease(listSnapshot);

  return NULL;
}

bool CheckLoginItemStatus(bool* hide_on_startup) {
  LSSharedFileListRef list = LSSharedFileListCreate(
      kCFAllocatorDefault, kLSSharedFileListSessionLoginItems, NULL);
  NSURL* targetUrl = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
  LSSharedFileListItemRef item(GetItemFromLoginItems(targetUrl, list));

  CFBooleanRef isHiddenRef = (CFBooleanRef)LSSharedFileListItemCopyProperty(
      item, (CFStringRef) @"com.apple.loginitem.HideOnLaunch");

  if (isHiddenRef) {
    *hide_on_startup = CFBooleanGetValue(isHiddenRef);
    CFRelease(isHiddenRef);
  }

  return item != NULL;
}

Browser::LoginItemSettings Browser::GetLoginItemSettings(
    const LoginItemSettings& options) {
  LoginItemSettings settings;
#if defined(MAS_BUILD)
  settings.open_at_login = platform_util::GetLoginItemEnabled();
#else
  settings.open_at_login = CheckLoginItemStatus(&settings.open_as_hidden);
  settings.restore_state = base::mac::WasLaunchedAsLoginItemRestoreState();
  settings.opened_at_login = base::mac::WasLaunchedAsLoginOrResumeItem();
  settings.opened_as_hidden = base::mac::WasLaunchedAsHiddenLoginItem();
#endif
  return settings;
}

void RemoveFromLoginItems() {
  LSSharedFileListRef list =
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);
  if (list) {
    NSURL* targetUrl =
        [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    if (GetItemFromLoginItems(targetUrl, list) != NULL) {
      CFURLRef url = (__bridge CFURLRef)
          [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
      if (url) {
        UInt32 seed;
        CFArrayRef items = LSSharedFileListCopySnapshot(list, &seed);
        if (items) {
          for (id item in (__bridge NSArray*)items) {
            LSSharedFileListItemRef itemRef =
                (__bridge LSSharedFileListItemRef)item;
            if (LSSharedFileListItemResolve(itemRef, 0, &url, NULL) == noErr) {
              if ([[(__bridge NSURL*)url path]
                      hasPrefix:[[NSBundle mainBundle] bundlePath]])
                LSSharedFileListItemRemove(list, itemRef);
            }
          }
          CFRelease(items);
        } else {
          printf("No items in list of auto-loaded apps\n");
        }
      } else {
        printf("Unable to find url for bundle\n");
      }
    }
    CFRelease(list);
  } else {
    printf("Unable to access shared file list\n");
  }
}

void AddToLoginItems(bool hide_on_startup) {
  NSURL* url = [NSURL fileURLWithPath:[base::mac::MainBundle() bundlePath]];
  base::ScopedCFTypeRef<LSSharedFileListRef> login_items(
      LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL));
  base::ScopedCFTypeRef<LSSharedFileListItemRef> item(
      GetItemFromLoginItems(url, login_items));

  if (!login_items.get()) {
    printf("Couldn't get a Login Items list.\n");
    return;
  }

  if (item.get())
    RemoveFromLoginItems();

  BOOL hide = hide_on_startup ? YES : NO;
  NSDictionary* properties =
      [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:hide]
                                  forKey:@"com.apple.loginitem.HideOnLaunch"];

  base::ScopedCFTypeRef<LSSharedFileListItemRef> new_item;
  new_item.reset(LSSharedFileListInsertItemURL(
      login_items, kLSSharedFileListItemLast, NULL, NULL,
      reinterpret_cast<CFURLRef>(url),
      reinterpret_cast<CFDictionaryRef>(properties), NULL));

  if (!new_item.get())
    printf("Couldn't insert current app into Login Items list.");
}

void Browser::SetLoginItemSettings(LoginItemSettings settings) {
#if defined(MAS_BUILD)
  platform_util::SetLoginItemEnabled(settings.open_at_login);
#else
  if (settings.open_at_login)
    AddToLoginItems(settings.open_as_hidden);
  else {
    if (@available(macOS 10.10, *))
      RemoveFromLoginItems();
    else
      base::mac::RemoveFromLoginItems();
  }
#endif
}

std::string Browser::GetExecutableFileVersion() const {
  return brightray::GetApplicationVersion();
}

std::string Browser::GetExecutableFileProductName() const {
  return brightray::GetApplicationName();
}

int Browser::DockBounce(BounceType type) {
  return [[AtomApplication sharedApplication]
      requestUserAttention:static_cast<NSRequestUserAttentionType>(type)];
}

void Browser::DockCancelBounce(int request_id) {
  [[AtomApplication sharedApplication] cancelUserAttentionRequest:request_id];
}

void Browser::DockSetBadgeText(const std::string& label) {
  NSDockTile* tile = [[AtomApplication sharedApplication] dockTile];
  [tile setBadgeLabel:base::SysUTF8ToNSString(label)];
}

void Browser::DockDownloadFinished(const std::string& filePath) {
  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:@"com.apple.DownloadFileFinished"
                    object:base::SysUTF8ToNSString(filePath)];
}

std::string Browser::DockGetBadgeText() {
  NSDockTile* tile = [[AtomApplication sharedApplication] dockTile];
  return base::SysNSStringToUTF8([tile badgeLabel]);
}

void Browser::DockHide() {
  for (auto* const& window : WindowList::GetWindows())
    [window->GetNativeWindow() setCanHide:NO];

  ProcessSerialNumber psn = {0, kCurrentProcess};
  TransformProcessType(&psn, kProcessTransformToUIElementApplication);
}

bool Browser::DockIsVisible() {
  // Because DockShow has a slight delay this may not be true immediately
  // after that call.
  return ([[NSRunningApplication currentApplication] activationPolicy] ==
          NSApplicationActivationPolicyRegular);
}

void Browser::DockShow() {
  BOOL active = [[NSRunningApplication currentApplication] isActive];
  ProcessSerialNumber psn = {0, kCurrentProcess};
  if (active) {
    // Workaround buggy behavior of TransformProcessType.
    // http://stackoverflow.com/questions/7596643/
    NSArray* runningApps = [NSRunningApplication
        runningApplicationsWithBundleIdentifier:@"com.apple.dock"];
    for (NSRunningApplication* app in runningApps) {
      [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      break;
    }
    dispatch_time_t one_ms = dispatch_time(DISPATCH_TIME_NOW, USEC_PER_SEC);
    dispatch_after(one_ms, dispatch_get_main_queue(), ^{
      TransformProcessType(&psn, kProcessTransformToForegroundApplication);
      dispatch_time_t one_ms = dispatch_time(DISPATCH_TIME_NOW, USEC_PER_SEC);
      dispatch_after(one_ms, dispatch_get_main_queue(), ^{
        [[NSRunningApplication currentApplication]
            activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      });
    });
  } else {
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
  }
}

void Browser::DockSetMenu(AtomMenuModel* model) {
  AtomApplicationDelegate* delegate =
      (AtomApplicationDelegate*)[NSApp delegate];
  [delegate setApplicationDockMenu:model];
}

void Browser::DockSetIcon(const gfx::Image& image) {
  [[AtomApplication sharedApplication]
      setApplicationIconImage:image.AsNSImage()];
}

void Browser::ShowAboutPanel() {
  NSDictionary* options = DictionaryValueToNSDictionary(about_panel_options_);

  // Credits must be a NSAttributedString instead of NSString
  id credits = options[@"Credits"];
  if (credits != nil) {
    NSMutableDictionary* mutable_options = [options mutableCopy];
    mutable_options[@"Credits"] = [[[NSAttributedString alloc]
        initWithString:(NSString*)credits] autorelease];
    options = [NSDictionary dictionaryWithDictionary:mutable_options];
  }

  [[AtomApplication sharedApplication]
      orderFrontStandardAboutPanelWithOptions:options];
}

void Browser::SetAboutPanelOptions(const base::DictionaryValue& options) {
  about_panel_options_.Clear();

  // Upper case option keys for orderFrontStandardAboutPanelWithOptions format
  for (base::DictionaryValue::Iterator iter(options); !iter.IsAtEnd();
       iter.Advance()) {
    std::string key = iter.key();
    std::string value;
    if (!key.empty() && iter.value().GetAsString(&value)) {
      key[0] = base::ToUpperASCII(key[0]);
      about_panel_options_.SetString(key, value);
    }
  }
}

}  // namespace atom
