#include "desktop_channels.h"
#include "desktop_callbacks.h"
#include "desktop_pipe.h"
#include "desktop_storage.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <condition_variable>
#include <deque>
#include <functional>
#include <mutex>
#include <stdexcept>
#include <thread>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Result = flutter::MethodResult<Value>;

class Worker {
 public:
  explicit Worker(size_t limit) : limit_(limit), thread_([this] { Run(); }) {}
  ~Worker() { Stop(); }
  bool Schedule(std::function<void()> operation) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (stopping_ || queue_.size() >= limit_) return false;
    queue_.push_back(std::move(operation)); ready_.notify_one(); return true;
  }
  void Stop() {
    { std::lock_guard<std::mutex> lock(mutex_); stopping_ = true; ready_.notify_all(); }
    if (thread_.joinable()) thread_.join();
  }
 private:
  void Run() {
    const auto initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
    for (;;) {
      std::function<void()> operation;
      {
        std::unique_lock<std::mutex> lock(mutex_);
        ready_.wait(lock, [this] { return stopping_ || !queue_.empty(); });
        if (queue_.empty()) break;
        operation = std::move(queue_.front()); queue_.pop_front();
      }
      operation();
    }
    if (SUCCEEDED(initialized)) CoUninitialize();
  }
  const size_t limit_;
  std::mutex mutex_;
  std::condition_variable ready_;
  std::deque<std::function<void()>> queue_;
  bool stopping_ = false;
  std::thread thread_;
};
const Value& Field(const Map& map, const char* name) {
  const auto found = map.find(Value(name));
  if (found == map.end()) throw std::runtime_error("Missing native argument");
  return found->second;
}
int64_t Lease(const Map& map) {
  const auto& value = Field(map, "lease");
  if (const auto* wide = std::get_if<int64_t>(&value)) return *wide;
  if (const auto* int32_value = std::get_if<int32_t>(&value)) return *int32_value;
  throw std::runtime_error("Invalid transport lease");
}
DesktopPipeLaunch Launch() {
  const auto context = DesktopStorageLaunchContext();
  const auto& root = std::get<std::string>(Field(context, "dataRoot"));
  const auto length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      root.data(), static_cast<int>(root.size()), nullptr, 0);
  if (length <= 0 || root.find('\0') != std::string::npos) throw std::runtime_error("Invalid native root");
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, root.data(), static_cast<int>(root.size()), wide.data(), length);
  return {std::get<std::string>(Field(context, "installationId")), wide};
}
}  // namespace

struct DesktopChannels::Impl {
  flutter::MethodChannel<Value> runtime, system;
  std::shared_ptr<DesktopCallbacks> callbacks;
  Worker writes{8}, reads{1};
  std::shared_ptr<DesktopPipe> pipe;
  int64_t next_lease = 0, lease = 0;
  bool opened = false, reading = false;
  size_t pending_writes = 0, pending_bytes = 0;

  Impl(HWND window, flutter::BinaryMessenger* messenger)
      : runtime(messenger, "com.etonify.desktop/runtime", &flutter::StandardMethodCodec::GetInstance()),
        system(messenger, "com.etonify.desktop/system", &flutter::StandardMethodCodec::GetInstance()),
        callbacks(std::make_shared<DesktopCallbacks>(window)) {
    system.SetMethodCallHandler(HandleDesktopStorageCall);
    runtime.SetMethodCallHandler([this](const flutter::MethodCall<Value>& call,
        std::unique_ptr<Result> unique) { Dispatch(call, std::move(unique)); });
  }
  ~Impl() {
    runtime.SetMethodCallHandler(nullptr);
    system.SetMethodCallHandler(nullptr);
    callbacks->Invalidate();
    if (pipe) pipe->Cancel();
    writes.Stop(); reads.Stop(); pipe.reset();
  }
  void Release() {
    auto old = std::move(pipe);
    opened = false; reading = false; lease = 0;
    pending_writes = 0; pending_bytes = 0;
    if (old) {
      old->Cancel();
      // Keep the final destructor (bounded child wait) off the window thread.
      writes.Schedule([old] {});
    }
  }
  void Dispatch(const flutter::MethodCall<Value>& call, std::unique_ptr<Result> unique) {
    auto result = std::shared_ptr<Result>(std::move(unique));
    try {
      const auto method = call.method_name();
      if (method == "open") {
        if (pipe) { result->Error("busy", "Windows runtime already opened"); return; }
        pipe = std::make_shared<DesktopPipe>();
        lease = ++next_lease;
        const auto owner = pipe;
        const auto ticket = lease;
        const auto gate = callbacks;
        if (!writes.Schedule([this, owner, ticket, gate, result] {
          bool success = false;
          try { owner->Open(Launch()); success = true; } catch (const std::exception&) { owner->Cancel(); }
          gate->Post([this, owner, ticket, result, success] {
            if (ticket != lease || owner != pipe) { result->Error("cancelled", "Windows runtime closed"); return; }
            if (success) { opened = true; result->Success(Value(ticket)); }
            else { Release(); result->Error("unavailable", "Cannot open verified Windows core"); }
          });
        })) { Release(); result->Error("busy", "Windows runtime queue is full"); }
        return;
      }
      if (method != "read" && method != "write" && method != "close") {
        result->NotImplemented(); return;
      }
      if (!call.arguments() || !std::holds_alternative<Map>(*call.arguments())) throw std::runtime_error("Invalid native arguments");
      const auto& arguments = std::get<Map>(*call.arguments());
      const auto ticket = Lease(arguments);
      if (ticket != lease || !pipe) { result->Error("closed", "Windows runtime lease ended"); return; }
      if (method == "close") { Release(); result->Success(); return; }
      if (!opened) { result->Error("unavailable", "Windows runtime is not ready"); return; }
      const auto owner = pipe;
      const auto gate = callbacks;
      if (method == "read") {
        if (reading) { result->Error("busy", "Only one read may be pending"); return; }
        reading = true;
        if (!reads.Schedule([this, owner, ticket, gate, result] {
          std::vector<uint8_t> bytes;
          bool success = false;
          try { bytes = owner->Read(); success = true; } catch (const std::exception&) { owner->Cancel(); }
          gate->Post([this, owner, ticket, result, success, bytes = std::move(bytes)] {
            if (ticket == lease && owner == pipe) reading = false;
            if (!success || ticket != lease || owner != pipe) result->Error("transport_lost", "Windows runtime read ended");
            else if (bytes.empty()) result->Success();
            else result->Success(Value(bytes));
          });
        })) { reading = false; result->Error("busy", "Windows runtime read queue is full"); }
      } else {
        const auto& bytes = std::get<std::vector<uint8_t>>(Field(arguments, "frame"));
        if (bytes.size() < 5 || bytes.size() > 16 * 1024 * 1024 + 4) throw std::runtime_error("Invalid native frame");
        if (pending_writes >= 8 || pending_bytes + bytes.size() > 32 * 1024 * 1024) {
          result->Error("busy", "Windows runtime write budget is full"); return;
        }
        ++pending_writes; pending_bytes += bytes.size();
        if (!writes.Schedule([this, owner, ticket, gate, result, bytes] {
          bool success = false;
          try { owner->Write(bytes); success = true; } catch (const std::exception&) { owner->Cancel(); }
          gate->Post([this, owner, ticket, result, success, size = bytes.size()] {
            if (ticket == lease && owner == pipe) { --pending_writes; pending_bytes -= size; }
            if (!success || ticket != lease || owner != pipe) result->Error("transport_lost", "Windows runtime write ended");
            else result->Success();
          });
        })) {
          --pending_writes; pending_bytes -= bytes.size();
          result->Error("busy", "Windows runtime write queue is full");
        }
      }
    } catch (const std::exception&) {
      result->Error("invalid_request", "Invalid Windows transport request");
    }
  }
};

DesktopChannels::DesktopChannels(HWND window, flutter::BinaryMessenger* messenger)
    : impl_(std::make_unique<Impl>(window, messenger)) {}
DesktopChannels::~DesktopChannels() = default;
bool DesktopChannels::HandleMessage(UINT message) {
  if (message != DesktopCallbacks::kMessage) return false;
  impl_->callbacks->Drain(); return true;
}
