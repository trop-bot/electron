// Copyright (c) 2014 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "atom/browser/node_debugger.h"

#include <memory>
#include <string>
#include <vector>

#include "base/command_line.h"
#include "base/logging.h"
#include "base/strings/utf_string_conversions.h"
#include "libplatform/libplatform.h"
#include "native_mate/dictionary.h"

#include "atom/common/node_includes.h"

namespace atom {

NodeDebugger::NodeDebugger(node::Environment* env) : env_(env) {}

NodeDebugger::~NodeDebugger() {}

void NodeDebugger::Start() {
  auto* inspector = env_->inspector_agent();
  if (inspector == nullptr)
    return;

  std::vector<std::string> args;
  for (auto& arg : base::CommandLine::ForCurrentProcess()->argv()) {
#if defined(OS_WIN)
    const std::string nice_arg = base::UTF16ToUTF8(arg);
#else
    const std::string& nice_arg = arg;
#endif
    // Stop handling arguments after a "--" to be consistent with Chromium
    // This is here for security reasons, do not remove
    if (nice_arg == "--")
      break;

    args.push_back(nice_arg);
  }

  auto options = std::make_shared<node::DebugOptions>();
  std::vector<std::string> exec_args;
  std::vector<std::string> v8_args;
  std::string error;

  node::options_parser::DebugOptionsParser::instance.Parse(
      &args, &exec_args, &v8_args, options.get(),
      node::options_parser::kDisallowedInEnvironment, &error);

  if (!error.empty()) {
    LOG(ERROR) << "Error parsing node options: " << error;
  }

  // Set process._debugWaitConnect if --inspect-brk was specified to stop
  // the debugger on the first line
  if (options->wait_for_connect()) {
    mate::Dictionary process(env_->isolate(), env_->process_object());
    process.Set("_breakFirstLine", true);
  }

  const char* path = "";
  if (inspector->Start(path, options)) {
    DCHECK(env_->inspector_agent()->IsListening());
  }
}

}  // namespace atom
