// Copyright (c) 2016 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/browser/api/atom_api_system_preferences.h"

#include <map>

#import <Cocoa/Cocoa.h>

#include "atom/browser/mac/atom_application.h"
#include "atom/browser/mac/dict_util.h"
#include "atom/browser/ui/cocoa/atom_access_controller.h"
#include "atom/common/native_mate_converters/gurl_converter.h"
#include "atom/common/native_mate_converters/value_converter.h"
#include "base/strings/sys_string_conversions.h"
#include "base/values.h"
#include "native_mate/object_template_builder.h"
#include "net/base/mac/url_conversions.h"

namespace mate {
template <>
struct Converter<NSAppearance*> {
  static bool FromV8(v8::Isolate* isolate,
                     v8::Local<v8::Value> val,
                     NSAppearance** out) {
    if (val->IsNull()) {
      *out = nil;
      return true;
    }

    std::string name;
    if (!mate::ConvertFromV8(isolate, val, &name)) {
      return false;
    }

    if (name == "light") {
      *out = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
      return true;
    } else if (name == "dark") {
      if (@available(macOS 10.14, *)) {
        *out = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
      } else {
        *out = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
      }
      return true;
    }

    return false;
  }

  static v8::Local<v8::Value> ToV8(v8::Isolate* isolate, NSAppearance* val) {
    if (val == nil) {
      return v8::Null(isolate);
    }

    if (val.name == NSAppearanceNameAqua) {
      return mate::ConvertToV8(isolate, "light");
    }
    if (@available(macOS 10.14, *)) {
      if (val.name == NSAppearanceNameDarkAqua) {
        return mate::ConvertToV8(isolate, "dark");
      }
    }

    return mate::ConvertToV8(isolate, "unknown");
  }
};
}  // namespace mate

namespace atom {

namespace api {

namespace {

int g_next_id = 0;

// The map to convert |id| to |int|.
std::map<int, id> g_id_map;

}  // namespace

void SystemPreferences::PostNotification(
    const std::string& name,
    const base::DictionaryValue& user_info) {
  DoPostNotification(name, user_info, kNSDistributedNotificationCenter);
}

int SystemPreferences::SubscribeNotification(
    const std::string& name,
    const NotificationCallback& callback) {
  return DoSubscribeNotification(name, callback,
                                 kNSDistributedNotificationCenter);
}

void SystemPreferences::UnsubscribeNotification(int request_id) {
  DoUnsubscribeNotification(request_id, kNSDistributedNotificationCenter);
}

void SystemPreferences::PostLocalNotification(
    const std::string& name,
    const base::DictionaryValue& user_info) {
  DoPostNotification(name, user_info, kNSNotificationCenter);
}

int SystemPreferences::SubscribeLocalNotification(
    const std::string& name,
    const NotificationCallback& callback) {
  return DoSubscribeNotification(name, callback, kNSNotificationCenter);
}

void SystemPreferences::UnsubscribeLocalNotification(int request_id) {
  DoUnsubscribeNotification(request_id, kNSNotificationCenter);
}

void SystemPreferences::PostWorkspaceNotification(
    const std::string& name,
    const base::DictionaryValue& user_info) {
  DoPostNotification(name, user_info, kNSWorkspaceNotificationCenter);
}

int SystemPreferences::SubscribeWorkspaceNotification(
    const std::string& name,
    const NotificationCallback& callback) {
  return DoSubscribeNotification(name, callback,
                                 kNSWorkspaceNotificationCenter);
}

void SystemPreferences::UnsubscribeWorkspaceNotification(int request_id) {
  DoUnsubscribeNotification(request_id, kNSWorkspaceNotificationCenter);
}

void SystemPreferences::DoPostNotification(
    const std::string& name,
    const base::DictionaryValue& user_info,
    NotificationCenterKind kind) {
  NSNotificationCenter* center;
  switch (kind) {
    case kNSDistributedNotificationCenter:
      center = [NSDistributedNotificationCenter defaultCenter];
      break;
    case kNSNotificationCenter:
      center = [NSNotificationCenter defaultCenter];
      break;
    case kNSWorkspaceNotificationCenter:
      center = [[NSWorkspace sharedWorkspace] notificationCenter];
      break;
    default:
      break;
  }
  [center postNotificationName:base::SysUTF8ToNSString(name)
                        object:nil
                      userInfo:DictionaryValueToNSDictionary(user_info)];
}

int SystemPreferences::DoSubscribeNotification(
    const std::string& name,
    const NotificationCallback& callback,
    NotificationCenterKind kind) {
  int request_id = g_next_id++;
  __block NotificationCallback copied_callback = callback;
  NSNotificationCenter* center;
  switch (kind) {
    case kNSDistributedNotificationCenter:
      center = [NSDistributedNotificationCenter defaultCenter];
      break;
    case kNSNotificationCenter:
      center = [NSNotificationCenter defaultCenter];
      break;
    case kNSWorkspaceNotificationCenter:
      center = [[NSWorkspace sharedWorkspace] notificationCenter];
      break;
    default:
      break;
  }

  g_id_map[request_id] = [center
      addObserverForName:base::SysUTF8ToNSString(name)
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification* notification) {
                std::unique_ptr<base::DictionaryValue> user_info =
                    NSDictionaryToDictionaryValue(notification.userInfo);
                if (user_info) {
                  copied_callback.Run(
                      base::SysNSStringToUTF8(notification.name), *user_info);
                } else {
                  copied_callback.Run(
                      base::SysNSStringToUTF8(notification.name),
                      base::DictionaryValue());
                }
              }];
  return request_id;
}

void SystemPreferences::DoUnsubscribeNotification(int request_id,
                                                  NotificationCenterKind kind) {
  auto iter = g_id_map.find(request_id);
  if (iter != g_id_map.end()) {
    id observer = iter->second;
    NSNotificationCenter* center;
    switch (kind) {
      case kNSDistributedNotificationCenter:
        center = [NSDistributedNotificationCenter defaultCenter];
        break;
      case kNSNotificationCenter:
        center = [NSNotificationCenter defaultCenter];
        break;
      case kNSWorkspaceNotificationCenter:
        center = [[NSWorkspace sharedWorkspace] notificationCenter];
        break;
      default:
        break;
    }
    [center removeObserver:observer];
    g_id_map.erase(iter);
  }
}

v8::Local<v8::Value> SystemPreferences::GetUserDefault(
    const std::string& name,
    const std::string& type) {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSString* key = base::SysUTF8ToNSString(name);
  if (type == "string") {
    return mate::StringToV8(
        isolate(), base::SysNSStringToUTF8([defaults stringForKey:key]));
  } else if (type == "boolean") {
    return v8::Boolean::New(isolate(), [defaults boolForKey:key]);
  } else if (type == "float") {
    return v8::Number::New(isolate(), [defaults floatForKey:key]);
  } else if (type == "integer") {
    return v8::Integer::New(isolate(), [defaults integerForKey:key]);
  } else if (type == "double") {
    return v8::Number::New(isolate(), [defaults doubleForKey:key]);
  } else if (type == "url") {
    return mate::ConvertToV8(isolate(),
                             net::GURLWithNSURL([defaults URLForKey:key]));
  } else if (type == "array") {
    std::unique_ptr<base::ListValue> list =
        NSArrayToListValue([defaults arrayForKey:key]);
    if (list == nullptr)
      list.reset(new base::ListValue());
    return mate::ConvertToV8(isolate(), *list);
  } else if (type == "dictionary") {
    std::unique_ptr<base::DictionaryValue> dictionary =
        NSDictionaryToDictionaryValue([defaults dictionaryForKey:key]);
    if (dictionary == nullptr)
      dictionary.reset(new base::DictionaryValue());
    return mate::ConvertToV8(isolate(), *dictionary);
  } else {
    return v8::Undefined(isolate());
  }
}

void SystemPreferences::RegisterDefaults(mate::Arguments* args) {
  base::DictionaryValue value;

  if (!args->GetNext(&value)) {
    args->ThrowError("Invalid userDefault data provided");
  } else {
    @try {
      NSDictionary* dict = DictionaryValueToNSDictionary(value);
      for (id key in dict) {
        id value = [dict objectForKey:key];
        if ([value isKindOfClass:[NSNull class]] || value == nil) {
          args->ThrowError("Invalid userDefault data provided");
          return;
        }
      }
      [[NSUserDefaults standardUserDefaults] registerDefaults:dict];
    } @catch (NSException* exception) {
      args->ThrowError("Invalid userDefault data provided");
    }
  }
}

void SystemPreferences::SetUserDefault(const std::string& name,
                                       const std::string& type,
                                       mate::Arguments* args) {
  const auto throwConversionError = [&] {
    args->ThrowError("Unable to convert value to: " + type);
  };

  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  NSString* key = base::SysUTF8ToNSString(name);
  if (type == "string") {
    std::string value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    [defaults setObject:base::SysUTF8ToNSString(value) forKey:key];
  } else if (type == "boolean") {
    bool value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    [defaults setBool:value forKey:key];
  } else if (type == "float") {
    float value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    [defaults setFloat:value forKey:key];
  } else if (type == "integer") {
    int value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    [defaults setInteger:value forKey:key];
  } else if (type == "double") {
    double value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    [defaults setDouble:value forKey:key];
  } else if (type == "url") {
    GURL value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    if (NSURL* url = net::NSURLWithGURL(value)) {
      [defaults setURL:url forKey:key];
    }
  } else if (type == "array") {
    base::ListValue value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    if (NSArray* array = ListValueToNSArray(value)) {
      [defaults setObject:array forKey:key];
    }
  } else if (type == "dictionary") {
    base::DictionaryValue value;
    if (!args->GetNext(&value)) {
      throwConversionError();
      return;
    }

    if (NSDictionary* dict = DictionaryValueToNSDictionary(value)) {
      [defaults setObject:dict forKey:key];
    }
  } else {
    args->ThrowError("Invalid type: " + type);
    return;
  }
}

// whether the system has access to both microphone and camera
std::string SystemPreferences::GetMediaAccessStatus(
    const std::string& media_type) {
  NSString* type = [NSString stringWithFormat:@"%s", media_type.c_str()];

  NSString* status = [[AtomAccessController sharedController]
      getMediaAccessStatusForType:type];
  return std::string([status UTF8String]);
}

// ask for access to camera and/or microphone
v8::Local<v8::Promise> SystemPreferences::AskForMediaAccess(
    v8::Isolate* isolate,
    const std::string& media_type) {
  scoped_refptr<util::Promise> promise = new util::Promise(isolate);

  if (media_type == "microphone") {
    [[AtomAccessController sharedController]
        askForMicrophoneAccess:^(BOOL granted) {
          promise->Resolve(granted == YES);
        }];
  } else if (media_type == "camera") {
    [[AtomAccessController sharedController]
        askForCameraAccess:^(BOOL granted) {
          promise->Resolve(granted == YES);
        }];
  } else if (media_type == "all") {
    [[AtomAccessController sharedController] askForMediaAccess:^(BOOL granted) {
      promise->Resolve(granted == YES);
    }];
  } else {
    promise->RejectWithErrorMessage(
        "Invalid media type, use 'camera', 'microphone', or 'all'.");
  }
  return promise->GetHandle();
}

void SystemPreferences::RemoveUserDefault(const std::string& name) {
  NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:base::SysUTF8ToNSString(name)];
}

bool SystemPreferences::IsDarkMode() {
  NSString* mode = [[NSUserDefaults standardUserDefaults]
      stringForKey:@"AppleInterfaceStyle"];
  return [mode isEqualToString:@"Dark"];
}

bool SystemPreferences::IsSwipeTrackingFromScrollEventsEnabled() {
  return [NSEvent isSwipeTrackingFromScrollEventsEnabled];
}

v8::Local<v8::Value> SystemPreferences::GetEffectiveAppearance(
    v8::Isolate* isolate) {
  if (@available(macOS 10.14, *)) {
    return mate::ConvertToV8(
        isolate, [NSApplication sharedApplication].effectiveAppearance);
  }
  return v8::Null(isolate);
}

v8::Local<v8::Value> SystemPreferences::GetAppLevelAppearance(
    v8::Isolate* isolate) {
  if (@available(macOS 10.14, *)) {
    return mate::ConvertToV8(isolate,
                             [NSApplication sharedApplication].appearance);
  }
  return v8::Null(isolate);
}

void SystemPreferences::SetAppLevelAppearance(mate::Arguments* args) {
  if (@available(macOS 10.14, *)) {
    NSAppearance* appearance;
    if (args->GetNext(&appearance)) {
      [[NSApplication sharedApplication] setAppearance:appearance];
    } else {
      args->ThrowError("Invalid app appearance provided as first argument");
    }
  }
}

}  // namespace api

}  // namespace atom
