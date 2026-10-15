#include "desktop_callbacks.h"

bool DesktopCallbacks::Post(std::function<void()> completion) {
  std::lock_guard<std::mutex> lock(mutex_);
  if (!alive_ || pending_.size() >= 16) return false;
  pending_.push_back(std::move(completion));
  if (!PostMessageW(window_, kMessage, 0, 0)) {
    pending_.pop_back();
    return false;
  }
  return true;
}
void DesktopCallbacks::Drain() {
  std::deque<std::function<void()>> pending;
  {
    std::lock_guard<std::mutex> lock(mutex_);
    if (!alive_) return;
    pending.swap(pending_);
  }
  for (auto& completion : pending) {
    {
      std::lock_guard<std::mutex> lock(mutex_);
      if (!alive_) return;
    }
    completion();
  }
}
void DesktopCallbacks::Invalidate() {
  std::lock_guard<std::mutex> lock(mutex_);
  alive_ = false;
  pending_.clear();
}
