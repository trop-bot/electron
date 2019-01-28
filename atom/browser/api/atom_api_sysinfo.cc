// Copyright (c) 2019 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/common/native_mate_converters/file_path_converter.h"
#include "atom/common/node_bindings.h"
#include "atom/common/node_includes.h"
#include "atom/common/promise_util.h"
#include "base/system/sys_info.h"
#include "base/threading/thread_restrictions.h"
#include "native_mate/arguments.h"
#include "native_mate/dictionary.h"

namespace {

int64_t AmountOfFreeDiskSpace(const base::FilePath& path) {
  base::ThreadRestrictions::ScopedAllowIO allow_io;
  return base::SysInfo::AmountOfFreeDiskSpace(path);
}

int64_t AmountOfTotalDiskSpace(const base::FilePath& path) {
  base::ThreadRestrictions::ScopedAllowIO allow_io;
  return base::SysInfo::AmountOfTotalDiskSpace(path);
}

double Uptime() {
  return base::SysInfo::Uptime().InSecondsF();
}

void GetHardwareInfoCallback(const v8::Global<v8::Context>& context,
                             scoped_refptr<atom::util::Promise> promise,
                             base::SysInfo::HardwareInfo info) {
  v8::Isolate* isolate = promise->isolate();
  mate::Locker locker(isolate);
  v8::HandleScope handle_scope(isolate);
  v8::MicrotasksScope script_scope(isolate,
                                   v8::MicrotasksScope::kRunMicrotasks);
  v8::Context::Scope context_scope(
      v8::Local<v8::Context>::New(isolate, context));

  mate::Dictionary dict = mate::Dictionary::CreateEmpty(isolate);
  dict.SetHidden("simple", true);
  dict.Set("manufacturer", info.manufacturer);
  dict.Set("model", info.model);
  dict.Set("serialNumber", info.serial_number);

  promise->Resolve(dict.GetHandle());
}

v8::Local<v8::Promise> GetHardwareInfo(v8::Isolate* isolate) {
  scoped_refptr<atom::util::Promise> promise = new atom::util::Promise(isolate);
  v8::Global<v8::Context> context(isolate, isolate->GetCurrentContext());
  base::SysInfo::GetHardwareInfo(
      base::BindOnce(&GetHardwareInfoCallback, std::move(context), promise));
  return promise->GetHandle();
}

void Initialize(v8::Local<v8::Object> exports,
                v8::Local<v8::Value> unused,
                v8::Local<v8::Context> context,
                void* priv) {
  mate::Dictionary dict(context->GetIsolate(), exports);
  dict.SetMethod("numberOfProcessors", &base::SysInfo::NumberOfProcessors);
  dict.SetMethod("amountOfPhysicalMemory",
                 &base::SysInfo::AmountOfPhysicalMemory);
  dict.SetMethod("amountOfAvailablePhysicalMemory",
                 &base::SysInfo::AmountOfAvailablePhysicalMemory);
  dict.SetMethod("amountOfVirtualMemory",
                 &base::SysInfo::AmountOfVirtualMemory);
  dict.SetMethod("amountOfFreeDiskSpace", &AmountOfFreeDiskSpace);
  dict.SetMethod("amountOfTotalDiskSpace", &AmountOfTotalDiskSpace);
  dict.SetMethod("uptime", &Uptime);
  dict.SetMethod("getHardwareInfo", &GetHardwareInfo);
  dict.SetMethod("operatingSystemName", &base::SysInfo::OperatingSystemName);
  dict.SetMethod("operatingSystemVersion",
                 &base::SysInfo::OperatingSystemVersion);
  dict.SetMethod("operatingSystemArchitecture",
                 &base::SysInfo::OperatingSystemArchitecture);
  dict.SetMethod("cpuModelName", &base::SysInfo::CPUModelName);
  dict.SetMethod("vmAllocationGranularity",
                 &base::SysInfo::VMAllocationGranularity);
  dict.SetMethod("isLowEndDevice", &base::SysInfo::IsLowEndDevice);
}

}  // namespace

NODE_BUILTIN_MODULE_CONTEXT_AWARE(atom_browser_sysinfo, Initialize)
