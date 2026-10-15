#ifndef RUNNER_DESKTOP_PIPE_H_
#define RUNNER_DESKTOP_PIPE_H_

#include <cstdint>
#include <cstddef>
#include <memory>
#include <string>
#include <vector>

struct DesktopPipeLaunch {
  std::string installation_id;
  std::wstring data_root;
};

// Incremental validation without allocating a body from an untrusted length.
class DesktopFrameGuard {
 public:
  void Add(const uint8_t* data, size_t size);
  void Finish() const;
  size_t completed() const { return completed_; }
 private:
  uint8_t header_[4]{};
  size_t header_used_ = 0;
  uint32_t remaining_ = 0;
  size_t completed_ = 0;
};

// Blocking operations run only on native workers. Cancel is non-blocking and
// safe during Open/Read/Write; destruction waits for the owned child to exit.
class DesktopPipe {
 public:
  DesktopPipe();
  ~DesktopPipe();
  DesktopPipe(const DesktopPipe&) = delete;
  DesktopPipe& operator=(const DesktopPipe&) = delete;
  void Open(const DesktopPipeLaunch& launch);
  std::vector<uint8_t> Read();
  void Write(const std::vector<uint8_t>& frame);
  void Cancel() noexcept;
 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};
#endif
