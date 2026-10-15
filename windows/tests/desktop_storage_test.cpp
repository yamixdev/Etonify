#include "desktop_storage.h"
#include <windows.h>
#include <algorithm>
#include <iostream>
#include <stdexcept>
#include <vector>

using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
struct Reply {
  bool success = false, error = false;
  Value value;
};
class CaptureResult : public flutter::MethodResult<Value> {
 public:
  explicit CaptureResult(Reply& reply) : reply_(reply) {}
 protected:
  void SuccessInternal(const Value* value) override {
    reply_.success = true;
    if (value) reply_.value = *value;
  }
  void ErrorInternal(const std::string&, const std::string&, const Value*) override { reply_.error = true; }
  void NotImplementedInternal() override { throw std::runtime_error("Missing native storage method"); }
 private:
  Reply& reply_;
};
static Reply Call(const std::string& name, std::vector<uint8_t> bytes) {
  Reply reply;
  flutter::MethodCall<Value> call(name, std::make_unique<Value>(Map{
    {Value("key"), Value(std::move(bytes))}
  }));
  HandleDesktopStorageCall(call, std::make_unique<CaptureResult>(reply));
  return reply;
}
int main() {
  try {
    const std::vector<uint8_t> key(32, 0x71);
    const auto protected_key = Call("protectKey", key);
    if (!protected_key.success || protected_key.error) throw std::runtime_error("actual_user_dpapi_protect");
    const auto encrypted = std::get<std::vector<uint8_t>>(protected_key.value);
    if (encrypted == key) throw std::runtime_error("dpapi_is_not_plaintext");
    const auto restored = Call("unprotectKey", encrypted);
    if (!restored.success || std::get<std::vector<uint8_t>>(restored.value) != key) throw std::runtime_error("actual_user_dpapi_roundtrip");
    auto corrupt = encrypted;
    std::fill(corrupt.begin(), corrupt.end(), uint8_t{0});
    const auto failed = Call("unprotectKey", corrupt);
    if (!failed.error || failed.success) throw std::runtime_error("storage_key_dpapi_failure_is_not_plaintext");
    std::cout << "native DPAPI tests passed; cross-user/ACL/reparse acceptance remains UNVERIFIED\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n'; return 1;
  }
}
