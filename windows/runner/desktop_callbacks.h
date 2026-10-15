#ifndef RUNNER_DESKTOP_CALLBACKS_H_
#define RUNNER_DESKTOP_CALLBACKS_H_

#include <windows.h>
#include <deque>
#include <functional>
#include <mutex>

// Queue contains the ownership, never a raw pointer carried in a window message.
class DesktopCallbacks {
 public:
  static constexpr UINT kMessage = WM_APP + 0x318;
  explicit DesktopCallbacks(HWND window) : window_(window) {}
  bool Post(std::function<void()> completion);
  // Drain/Invalidate belong to the owning window thread; Post is worker-safe.
  void Drain();
  void Invalidate();
 private:
  HWND window_;
  std::mutex mutex_;
  bool alive_ = true;
  std::deque<std::function<void()>> pending_;
};
#endif
