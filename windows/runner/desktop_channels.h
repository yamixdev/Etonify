#ifndef RUNNER_DESKTOP_CHANNELS_H_
#define RUNNER_DESKTOP_CHANNELS_H_
#include <windows.h>
#include <flutter/binary_messenger.h>
#include <memory>

class DesktopChannels {
 public:
  DesktopChannels(HWND window, flutter::BinaryMessenger* messenger);
  ~DesktopChannels();
  bool HandleMessage(UINT message);
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
#endif
