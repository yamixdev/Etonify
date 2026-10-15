#include "desktop_pipe.h"
#include "desktop_callbacks.h"
#include <windows.h>
#include <algorithm>
#include <chrono>
#include <filesystem>
#include <future>
#include <iostream>
#include <stdexcept>

static void Check(bool value, const char* description) {
  if (!value) throw std::runtime_error(description);
}
template <typename F> static void Reject(F operation, const char* description) {
  bool rejected = false;
  try { operation(); } catch (const std::exception&) { rejected = true; }
  Check(rejected, description);
}
int main() {
  try {
    DesktopFrameGuard split;
    const uint8_t frame[] = {3, 0, 0, 0, '{', '}', ' '};
    for (const auto byte : frame) split.Add(&byte, 1);
    split.Finish();
    Check(split.completed() == 1, "partial_header_and_body");
    DesktopFrameGuard oversized;
    const uint8_t bad[] = {1, 0, 0, 1};
    Reject([&] { oversized.Add(bad, 4); }, "oversized_length_before_allocation");
    DesktopFrameGuard truncated;
    truncated.Add(frame, 5);
    Reject([&] { truncated.Finish(); }, "truncated_body");

    HWND window = CreateWindowExW(0, L"STATIC", L"IPC test", 0, 0, 0, 0, 0,
        HWND_MESSAGE, nullptr, GetModuleHandleW(nullptr), nullptr);
    Check(window != nullptr, "message-only window");
    DesktopCallbacks callbacks(window);
    bool touched_engine = false;
    Check(callbacks.Post([&] { touched_engine = true; }), "queue completion");
    callbacks.Invalidate();
    callbacks.Drain();
    Check(!touched_engine, "callbacks_do_not_touch_destroyed_flutter_engine");
    Check(!callbacks.Post([&] { touched_engine = true; }), "late_callback_rejected");
    DesktopCallbacks nested(window);
    Check(nested.Post([&] { nested.Invalidate(); }), "queue destroy callback");
    Check(nested.Post([&] { touched_engine = true; }), "queue callback behind destroy");
    nested.Drain();
    Check(!touched_engine, "destroy_during_batch_retires_remaining_callbacks");
    DestroyWindow(window);

    const auto root = std::filesystem::temp_directory_path() /
        (L"Etonify IPC тест " + std::to_wstring(GetCurrentProcessId()));
    std::filesystem::create_directories(root);
    DesktopPipe pipe;
    pipe.Open({"12345678-1234-1234-1234-123456789abc", root.wstring()});
    const std::string json = "{\"version\":1,\"kind\":\"request\",\"id\":\"1\",\"sessionId\":\"\",\"configGeneration\":0,\"networkGeneration\":0,\"method\":\"snapshot\",\"payload\":{}}";
    std::vector<uint8_t> request(4 + json.size());
    const auto length = static_cast<uint32_t>(json.size());
    for (size_t i = 0; i < 4; ++i) request[i] = static_cast<uint8_t>(length >> (i * 8));
    std::copy(json.begin(), json.end(), request.begin() + 4);
    pipe.Write(request);
    DesktopFrameGuard replies;
    while (replies.completed() == 0) {
      const auto bytes = pipe.Read();
      Check(!bytes.empty(), "real_owned_agent_snapshot");
      replies.Add(bytes.data(), bytes.size());
    }
    auto reading = std::async(std::launch::async, [&] {
      try { pipe.Read(); } catch (const std::exception&) { return true; }
      return false;
    });
    pipe.Cancel();
    Check(reading.wait_for(std::chrono::seconds(3)) == std::future_status::ready,
        "disconnect_cancels_pending_read");
    Check(reading.get(), "cancelled_read_is_not_success");
    std::cout << "native pipe, framing and callback lifetime tests passed\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
