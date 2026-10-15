#ifndef RUNNER_DESKTOP_STORAGE_H_
#define RUNNER_DESKTOP_STORAGE_H_
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_call.h>
#include <flutter/method_result.h>
#include <memory>

flutter::EncodableMap DesktopStorageLaunchContext();
void HandleDesktopStorageCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

// Compatibility alias and canonical system channel delegate to one dispatcher.
void RegisterDesktopStorage(flutter::BinaryMessenger* messenger);
#endif
