#include "desktop_pipe.h"
#include <windows.h>
#include <bcrypt.h>
#include <sddl.h>
#include <algorithm>
#include <array>
#include <filesystem>
#include <mutex>
#include <stdexcept>

namespace {
constexpr uint32_t kMaximumBody = 16 * 1024 * 1024;
[[noreturn]] void Fail() { throw std::runtime_error("Windows agent transport unavailable"); }
void Require(bool condition) { if (!condition) Fail(); }
class Handle {
 public:
  explicit Handle(HANDLE handle = nullptr) : value_(handle) {}
  ~Handle() { Reset(); }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
  HANDLE get() const { return value_; }
  void Reset(HANDLE next = nullptr) {
    if (value_ && value_ != INVALID_HANDLE_VALUE) CloseHandle(value_);
    value_ = next;
  }
 private:
  HANDLE value_;
};
std::string Hex(const uint8_t* data, size_t length) {
  const char digits[] = "0123456789abcdef";
  std::string out;
  out.reserve(length * 2);
  for (size_t i = 0; i < length; ++i) {
    out += digits[data[i] >> 4]; out += digits[data[i] & 15];
  }
  return out;
}
std::array<uint8_t, 32> Hash(HANDLE file, const std::string* text = nullptr) {
  BCRYPT_ALG_HANDLE algorithm = nullptr;
  Require(BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) >= 0);
  struct AlgorithmExit { BCRYPT_ALG_HANDLE value; ~AlgorithmExit() { BCryptCloseAlgorithmProvider(value, 0); } } close_algorithm{algorithm};
  BCRYPT_HASH_HANDLE hash = nullptr;
  Require(BCryptCreateHash(algorithm, &hash, nullptr, 0, nullptr, 0, 0) >= 0);
  struct HashExit { BCRYPT_HASH_HANDLE value; ~HashExit() { BCryptDestroyHash(value); } } close_hash{hash};
  if (text) {
    Require(BCryptHashData(hash, reinterpret_cast<PUCHAR>(const_cast<char*>(text->data())), static_cast<ULONG>(text->size()), 0) >= 0);
  } else {
    LARGE_INTEGER length{};
    Require(GetFileSizeEx(file, &length) && length.QuadPart > 0 && length.QuadPart <= 512LL * 1024 * 1024);
    std::array<uint8_t, 65536> buffer{};
    DWORD read = 0;
    do {
      Require(ReadFile(file, buffer.data(), static_cast<DWORD>(buffer.size()), &read, nullptr) != 0);
      if (read) Require(BCryptHashData(hash, buffer.data(), read, 0) >= 0);
    } while (read);
  }
  std::array<uint8_t, 32> result{};
  Require(BCryptFinishHash(hash, result.data(), static_cast<ULONG>(result.size()), 0) >= 0);
  return result;
}
std::wstring Ascii(const std::string& value) {
  Require(value.find('\0') == std::string::npos);
  for (const auto c : value) Require(static_cast<unsigned char>(c) < 128);
  return std::wstring(value.begin(), value.end());
}
std::wstring Quote(const std::wstring& value) {
  Require(value.find(L'\0') == std::wstring::npos);
  std::wstring out = L"\"";
  size_t backslashes = 0;
  for (const auto c : value) {
    if (c == L'\\') { ++backslashes; continue; }
    out.append(backslashes * (c == L'"' ? 2 : 1), L'\\');
    backslashes = 0;
    if (c == L'"') out += L'\\';
    out += c;
  }
  out.append(backslashes * 2, L'\\');
  return out + L'"';
}
void RejectReparse(const std::filesystem::path& path) {
  Require(path.is_absolute() && !path.root_name().empty());
  std::filesystem::path part;
  for (const auto& segment : path) {
    Require(segment != L".." && segment != L".");
    part /= segment;
    const auto attrs = GetFileAttributesW(part.c_str());
    Require(attrs != INVALID_FILE_ATTRIBUTES && !(attrs & FILE_ATTRIBUTE_REPARSE_POINT));
  }
}
std::wstring Image(HANDLE process) {
  std::wstring name(32768, L'\0');
  DWORD size = static_cast<DWORD>(name.size());
  Require(QueryFullProcessImageNameW(process, 0, name.data(), &size) != 0);
  name.resize(size);
  return name;
}
struct Identity { std::wstring sid, logon; DWORD session; };
Identity IdentityOf(HANDLE process) {
  HANDLE raw = nullptr;
  Require(OpenProcessToken(process, TOKEN_QUERY, &raw) != 0);
  Handle token(raw);
  auto information = [&](TOKEN_INFORMATION_CLASS type) {
    DWORD length = 0;
    GetTokenInformation(token.get(), type, nullptr, 0, &length);
    Require(length > 0 && length < 1024 * 1024);
    std::vector<uint8_t> bytes(length);
    Require(GetTokenInformation(token.get(), type, bytes.data(), length, &length) != 0);
    return bytes;
  };
  auto sid_string = [](PSID sid) {
    LPWSTR text = nullptr;
    Require(ConvertSidToStringSidW(sid, &text) != 0);
    std::wstring result(text); LocalFree(text); return result;
  };
  Identity result{};
  const auto user = information(TokenUser);
  result.sid = sid_string(reinterpret_cast<const TOKEN_USER*>(user.data())->User.Sid);
  const auto groups = information(TokenGroups);
  const auto* values = reinterpret_cast<const TOKEN_GROUPS*>(groups.data());
  for (DWORD i = 0; i < values->GroupCount; ++i) {
    if ((values->Groups[i].Attributes & SE_GROUP_LOGON_ID) == SE_GROUP_LOGON_ID) {
      result.logon = sid_string(values->Groups[i].Sid); break;
    }
  }
  Require(!result.logon.empty());
  DWORD length = 0;
  Require(GetTokenInformation(token.get(), TokenSessionId, &result.session, sizeof(result.session), &length) != 0);
  return result;
}
bool SameImage(const std::wstring& left, const std::wstring& right) {
  return CompareStringOrdinal(left.c_str(), -1, right.c_str(), -1, TRUE) == CSTR_EQUAL;
}
}  // namespace

void DesktopFrameGuard::Add(const uint8_t* data, size_t size) {
  size_t offset = 0;
  while (offset < size) {
    if (remaining_ == 0) {
      while (header_used_ < 4 && offset < size) header_[header_used_++] = data[offset++];
      if (header_used_ < 4) return;
      remaining_ = static_cast<uint32_t>(header_[0]) |
          (static_cast<uint32_t>(header_[1]) << 8) |
          (static_cast<uint32_t>(header_[2]) << 16) |
          (static_cast<uint32_t>(header_[3]) << 24);
      Require(remaining_ > 0 && remaining_ <= kMaximumBody);
      header_used_ = 0;
    }
    const auto consumed = (std::min)(size - offset, static_cast<size_t>(remaining_));
    remaining_ -= static_cast<uint32_t>(consumed); offset += consumed;
    if (remaining_ == 0) ++completed_;
  }
}
void DesktopFrameGuard::Finish() const { Require(header_used_ == 0 && remaining_ == 0); }

struct DesktopPipe::Impl {
  Handle cancelled{CreateEventW(nullptr, TRUE, FALSE, nullptr)};
  Handle process, job, image, pipe;
  std::mutex mutex;
  DesktopFrameGuard incoming;
  Impl() { Require(cancelled.get() != nullptr); }
  void Check() const { Require(WaitForSingleObject(cancelled.get(), 0) == WAIT_TIMEOUT); }
  void Cancel() noexcept {
    SetEvent(cancelled.get());
    std::lock_guard<std::mutex> lock(mutex);
    if (pipe.get()) CancelIoEx(pipe.get(), nullptr);
  }
  DWORD Transfer(bool writing, uint8_t* data, DWORD length, DWORD timeout) {
    Check();
    OVERLAPPED overlapped{};
    Handle event(CreateEventW(nullptr, TRUE, FALSE, nullptr));
    Require(event.get() != nullptr);
    overlapped.hEvent = event.get();
    DWORD transferred = 0;
    BOOL success = writing ? WriteFile(pipe.get(), data, length, &transferred, &overlapped)
                           : ReadFile(pipe.get(), data, length, &transferred, &overlapped);
    if (!success) {
      const auto error = GetLastError();
      if (!writing && error == ERROR_BROKEN_PIPE) return 0;
      Require(error == ERROR_IO_PENDING);
      const HANDLE waits[] = {cancelled.get(), event.get(), process.get()};
      const auto state = WaitForMultipleObjects(3, waits, FALSE, timeout);
      if (state != WAIT_OBJECT_0 + 1) {
        CancelIoEx(pipe.get(), &overlapped);
        GetOverlappedResult(pipe.get(), &overlapped, &transferred, TRUE);
        Fail();
      }
      success = GetOverlappedResult(pipe.get(), &overlapped, &transferred, FALSE);
      if (!success && !writing && GetLastError() == ERROR_BROKEN_PIPE) return 0;
      Require(success != 0);
    }
    Check();
    return transferred;
  }
};
DesktopPipe::DesktopPipe() : impl_(std::make_unique<Impl>()) {}
DesktopPipe::~DesktopPipe() {
  impl_->Cancel();
  // Closing our endpoint lets the agent release its host first. The job is the
  // bounded fallback and also kills the agent if the GUI itself crashes.
  impl_->pipe.Reset();
  if (impl_->process.get() && WaitForSingleObject(impl_->process.get(), 2000) == WAIT_TIMEOUT) {
    TerminateJobObject(impl_->job.get(), 1);
  }
}
void DesktopPipe::Cancel() noexcept { impl_->Cancel(); }

void DesktopPipe::Open(const DesktopPipeLaunch& launch) {
  auto& state = *impl_;
  state.Check();
  Require(!state.process.get() && launch.installation_id.size() == 36 && !launch.data_root.empty());
  std::wstring module(32768, L'\0');
  const auto size = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
  Require(size > 0 && size < module.size()); module.resize(size);
  const auto directory = std::filesystem::path(module).parent_path();
  const auto executable = directory / L"etonify-desktop.exe";
  const auto digest_file = directory / L"etonify-desktop.sha256";
  RejectReparse(executable); RejectReparse(digest_file);
  state.image.Reset(CreateFileW(executable.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  Require(state.image.get() != INVALID_HANDLE_VALUE);
  Handle digest(CreateFileW(digest_file.c_str(), GENERIC_READ, FILE_SHARE_READ, nullptr,
      OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr));
  Require(digest.get() != INVALID_HANDLE_VALUE);
  std::array<char, 67> expected{};
  DWORD read = 0;
  Require(ReadFile(digest.get(), expected.data(), static_cast<DWORD>(expected.size()), &read, nullptr) != 0 && read >= 64 && read <= 66);
  for (DWORD i = 64; i < read; ++i) Require(expected[i] == '\r' || expected[i] == '\n');
  const auto hash = Hash(state.image.get());
  Require(std::string(expected.data(), 64) == Hex(hash.data(), hash.size()));
  // The sidecar binds co-packaged files, not a signature or a trust boundary
  // against a user who can rewrite the portable directory. B3 never uses it.
  const auto identity = IdentityOf(GetCurrentProcess());
  std::string logon;
  logon.reserve(identity.logon.size());
  for (const wchar_t character : identity.logon) {
    Require(static_cast<uint32_t>(character) <= 0x7f);
    logon.push_back(static_cast<char>(character));
  }
  const auto logon_hash = Hash(nullptr, &logon);
  std::array<uint8_t, 32> nonce{};
  Require(BCryptGenRandom(nullptr, nonce.data(), static_cast<ULONG>(nonce.size()), BCRYPT_USE_SYSTEM_PREFERRED_RNG) >= 0);
  const auto nonce_hex = Hex(nonce.data(), nonce.size());
  const auto name = L"\\\\.\\pipe\\Etonify-v1-" + Ascii(launch.installation_id) + L"-" +
      Ascii(Hex(logon_hash.data(), 8)) + L"-" + std::to_wstring(identity.session) + L"-" + Ascii(nonce_hex);
  std::wstring command = Quote(executable.wstring()) + L" agent --parent-pid " +
      std::to_wstring(GetCurrentProcessId()) + L" --install-id " + Quote(Ascii(launch.installation_id)) +
      L" --data-root " + Quote(launch.data_root) + L" --nonce " + Quote(Ascii(nonce_hex));
  state.job.Reset(CreateJobObjectW(nullptr, nullptr));
  Require(state.job.get() != nullptr);
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  Require(SetInformationJobObject(state.job.get(), JobObjectExtendedLimitInformation, &limits, sizeof(limits)) != 0);
  STARTUPINFOW startup{}; startup.cb = sizeof(startup);
  PROCESS_INFORMATION child{};
  Require(CreateProcessW(executable.c_str(), command.data(), nullptr, nullptr, FALSE,
      CREATE_NO_WINDOW | CREATE_SUSPENDED, nullptr, directory.c_str(), &startup, &child) != 0);
  state.process.Reset(child.hProcess);
  Handle thread(child.hThread);
  if (!AssignProcessToJobObject(state.job.get(), state.process.get())) {
    TerminateProcess(state.process.get(), 1); Fail();
  }
  state.Check();
  Require(ResumeThread(thread.get()) != static_cast<DWORD>(-1));
  const ULONGLONG deadline = GetTickCount64() + 10000;
  for (;;) {
    state.Check();
    Require(WaitForSingleObject(state.process.get(), 0) == WAIT_TIMEOUT && GetTickCount64() < deadline);
    HANDLE opened = CreateFileW(name.c_str(), GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_EXISTING,
        FILE_FLAG_OVERLAPPED | SECURITY_SQOS_PRESENT | SECURITY_IDENTIFICATION, nullptr);
    if (opened != INVALID_HANDLE_VALUE) {
      std::lock_guard<std::mutex> lock(state.mutex);
      state.pipe.Reset(opened); break;
    }
    const auto error = GetLastError();
    Require(error == ERROR_PIPE_BUSY || error == ERROR_FILE_NOT_FOUND);
    const HANDLE waits[] = {state.cancelled.get(), state.process.get()};
    Require(WaitForMultipleObjects(2, waits, FALSE, 20) == WAIT_TIMEOUT);
  }
  ULONG pid = 0;
  Require(GetNamedPipeServerProcessId(state.pipe.get(), &pid) && pid == child.dwProcessId);
  Require(WaitForSingleObject(state.process.get(), 0) == WAIT_TIMEOUT);
  const auto peer = IdentityOf(state.process.get());
  Require(peer.sid == identity.sid && peer.logon == identity.logon && peer.session == identity.session &&
      SameImage(Image(state.process.get()), executable.wstring()));
  size_t offset = 0;
  while (offset < nonce.size()) {
    const auto count = state.Transfer(true, nonce.data() + offset, static_cast<DWORD>(nonce.size() - offset), 5000);
    Require(count > 0); offset += count;
  }
  std::array<uint8_t, 8> ack{}; offset = 0;
  while (offset < ack.size()) {
    const auto count = state.Transfer(false, ack.data() + offset, static_cast<DWORD>(ack.size() - offset), 5000);
    Require(count > 0); offset += count;
  }
  Require(std::string(ack.begin(), ack.end()) == "ETNYIPC1");
  state.Check();
}
std::vector<uint8_t> DesktopPipe::Read() {
  Require(impl_->pipe.get() != nullptr);
  std::vector<uint8_t> bytes(65536);
  const auto read = impl_->Transfer(false, bytes.data(), static_cast<DWORD>(bytes.size()), INFINITE);
  bytes.resize(read);
  if (bytes.empty()) impl_->incoming.Finish();
  else impl_->incoming.Add(bytes.data(), bytes.size());
  return bytes;
}
void DesktopPipe::Write(const std::vector<uint8_t>& frame) {
  Require(impl_->pipe.get() != nullptr && frame.size() >= 5 && frame.size() <= kMaximumBody + 4);
  DesktopFrameGuard guard;
  guard.Add(frame.data(), frame.size()); guard.Finish(); Require(guard.completed() == 1);
  size_t offset = 0;
  while (offset < frame.size()) {
    const auto written = impl_->Transfer(true, const_cast<uint8_t*>(frame.data()) + offset,
        static_cast<DWORD>((std::min)(frame.size() - offset, size_t{65536})), 15000);
    Require(written > 0); offset += written;
  }
}
