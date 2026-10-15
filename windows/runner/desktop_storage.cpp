#include "desktop_storage.h"
#include <windows.h>
#include <aclapi.h>
#include <shlobj.h>
#include <wincrypt.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <filesystem>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
using Bytes = std::vector<uint8_t>;

std::wstring Wide(const std::string& text) {
  if (text.find('\0') != std::string::npos) throw std::runtime_error("Invalid path");
  const int size = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
      text.data(), static_cast<int>(text.size()), nullptr, 0);
  if (size <= 0) throw std::runtime_error("Invalid UTF-8 path");
  std::wstring result(size, 0);
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), size);
  return result;
}
std::string Utf8(const std::wstring& text) {
  const int size = WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS,
      text.data(), static_cast<int>(text.size()), nullptr, 0, nullptr, nullptr);
  if (size <= 0) throw std::runtime_error("Invalid Windows path");
  std::string result(size, 0);
  WideCharToMultiByte(CP_UTF8, WC_ERR_INVALID_CHARS, text.data(),
      static_cast<int>(text.size()), result.data(), size, nullptr, nullptr);
  return result;
}

void Validate(const std::filesystem::path& path) {
  // No relative, UNC, device or root-only paths. Never trust the process CWD.
  const auto text = path.wstring();
  if (text.size() < 4 || text[1] != L':' ||
      text.find(L':', 2) != std::wstring::npos ||
      (text[2] != L'\\' && text[2] != L'/') ||
      !((text[0] >= L'A' && text[0] <= L'Z') ||
        (text[0] >= L'a' && text[0] <= L'z'))) {
    throw std::runtime_error("Expected an absolute local user-data path");
  }
  for (const auto& part : path) {
    if (part == L".." || part == L".") throw std::runtime_error("Path traversal denied");
  }
  const auto drive = path.root_path().wstring();
  if (GetFileAttributesW(drive.c_str()) == INVALID_FILE_ATTRIBUTES) {
    throw std::runtime_error("User storage volume is unavailable");
  }
  std::filesystem::path current = path.root_path();
  for (const auto& part : path.relative_path()) {
    current /= part;
    const DWORD attributes = GetFileAttributesW(current.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
      const DWORD error = GetLastError();
      if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND) {
        throw std::runtime_error("Cannot inspect user storage");
      }
    } else if ((attributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0) {
      throw std::runtime_error("Reparse traversal in user storage is denied");
    }
  }
}

bool Exists(const std::filesystem::path& path) {
  std::error_code error;
  const bool exists = std::filesystem::exists(path, error);
  if (error) throw std::runtime_error("Cannot inspect storage metadata");
  return exists;
}

void Restrict(const std::filesystem::path& path, bool portable,
              bool inherit = false) {
  Validate(path);
  std::vector<uint8_t> buffer;
  PSID sid = nullptr;
  if (portable) {
    // A well-known SID travels with the drive; an origin TokenUser SID does
    // not. Portable storage deliberately has no account isolation.
    DWORD size = SECURITY_MAX_SID_SIZE;
    buffer.resize(size);
    if (!CreateWellKnownSid(WinAuthenticatedUserSid, nullptr,
                           buffer.data(), &size)) {
      throw std::runtime_error("Cannot create portable storage permission policy");
    }
    sid = buffer.data();
  } else {
    HANDLE token = nullptr;
    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &token)) {
      throw std::runtime_error("Cannot inspect storage owner");
    }
    DWORD size = 0;
    GetTokenInformation(token, TokenUser, nullptr, 0, &size);
    buffer.resize(size);
    const BOOL loaded = GetTokenInformation(token, TokenUser, buffer.data(), size, &size);
    CloseHandle(token);
    if (!loaded) throw std::runtime_error("Cannot inspect storage owner");
    auto user = reinterpret_cast<TOKEN_USER*>(buffer.data());
    sid = user->User.Sid;
  }
  EXPLICIT_ACCESSW access{};
  access.grfAccessPermissions = GENERIC_ALL;
  access.grfAccessMode = SET_ACCESS;
  access.grfInheritance = inherit
      ? SUB_CONTAINERS_AND_OBJECTS_INHERIT : NO_INHERITANCE;
  access.Trustee.TrusteeForm = TRUSTEE_IS_SID;
  access.Trustee.TrusteeType = portable
      ? TRUSTEE_IS_WELL_KNOWN_GROUP : TRUSTEE_IS_USER;
  access.Trustee.ptstrName = reinterpret_cast<LPWSTR>(sid);
  PACL acl = nullptr;
  if (SetEntriesInAclW(1, &access, nullptr, &acl) != ERROR_SUCCESS) {
    throw std::runtime_error("Cannot restrict storage key permissions");
  }
  const DWORD status = SetNamedSecurityInfoW(
      const_cast<LPWSTR>(path.c_str()), SE_FILE_OBJECT,
      DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION,
      nullptr, nullptr, acl, nullptr);
  LocalFree(acl);
  if (status != ERROR_SUCCESS) {
    throw std::runtime_error("Cannot restrict storage key permissions");
  }
}

void ConfigureRoot(const std::filesystem::path& root, bool portable) {
  Validate(root);
  if (portable) Restrict(root, true, true);
}

Bytes Read(const std::filesystem::path& path, size_t maximum) {
  Validate(path);
  HANDLE file = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ,
      nullptr, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, nullptr);
  if (file == INVALID_HANDLE_VALUE) throw std::runtime_error("Cannot read storage metadata");
  LARGE_INTEGER size{};
  if (!GetFileSizeEx(file, &size) || size.QuadPart <= 0 ||
      size.QuadPart > static_cast<LONGLONG>(maximum)) {
    CloseHandle(file);
    throw std::runtime_error("Storage metadata is corrupt");
  }
  Bytes bytes(static_cast<size_t>(size.QuadPart));
  DWORD read = 0;
  const BOOL ok = ReadFile(file, bytes.data(), static_cast<DWORD>(bytes.size()), &read, nullptr);
  CloseHandle(file);
  if (!ok || read != bytes.size()) throw std::runtime_error("Cannot read storage metadata");
  return bytes;
}

std::string InstallationId(const std::filesystem::path& root, bool portable) {
  const auto lock_path = root / L"installation.id.lock";
  Validate(lock_path);
  HANDLE lock = CreateFileW(lock_path.c_str(), GENERIC_READ | GENERIC_WRITE,
      0, nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (lock == INVALID_HANDLE_VALUE) throw std::runtime_error("Installation identity is busy or unavailable");
  struct CloseHandleOnExit {
    HANDLE handle;
    ~CloseHandleOnExit() { CloseHandle(handle); }
  } locked{lock};
  const auto target = root / L"installation.id";
  const auto pending = root / L"installation.id.pending";
  if (!Exists(target)) {
    Validate(pending);
    if (!Exists(pending)) {
      GUID guid{};
      if (FAILED(CoCreateGuid(&guid))) throw std::runtime_error("Cannot create installation identity");
      wchar_t text[39]{};
      if (StringFromGUID2(guid, text, 39) != 39) throw std::runtime_error("Cannot create installation identity");
      const std::string id = Utf8(std::wstring(text + 1, 36));
      HANDLE file = CreateFileW(pending.c_str(), GENERIC_WRITE, 0, nullptr,
          CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
      if (file == INVALID_HANDLE_VALUE) throw std::runtime_error("Cannot persist installation identity");
      DWORD written = 0;
      const BOOL ok = WriteFile(file, id.data(), static_cast<DWORD>(id.size()), &written, nullptr);
      const BOOL flushed = FlushFileBuffers(file);
      CloseHandle(file);
      if (!ok || !flushed || written != id.size()) throw std::runtime_error("Cannot persist installation identity");
      Restrict(pending, portable);
    }
    const Bytes saved = Read(pending, 36);
    if (saved.size() != 36) throw std::runtime_error("Installation identity is corrupt");
    if (!MoveFileExW(pending.c_str(), target.c_str(), MOVEFILE_WRITE_THROUGH)) {
      throw std::runtime_error("Cannot commit installation identity");
    }
  }
  if (portable) Restrict(target, true);
  const Bytes bytes = Read(target, 36);
  const std::string id(bytes.begin(), bytes.end());
  if (id.size() != 36) throw std::runtime_error("Installation identity is corrupt");
  for (size_t i = 0; i < id.size(); ++i) {
    const bool separator = i == 8 || i == 13 || i == 18 || i == 23;
    const char c = id[i];
    if (separator ? c != '-' : !((c >= '0' && c <= '9') ||
        (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
      throw std::runtime_error("Installation identity is corrupt");
    }
  }
  return id;
}

Map LaunchContext() {
  std::vector<wchar_t> module(32768);
  const DWORD length = GetModuleFileNameW(nullptr, module.data(), static_cast<DWORD>(module.size()));
  if (length == 0 || length >= module.size()) throw std::runtime_error("Cannot locate executable");
  const auto exe = std::filesystem::path(std::wstring(module.data(), length)).parent_path();
  const auto marker = exe / L"portable.mode";
  Validate(marker);
  const DWORD attributes = GetFileAttributesW(marker.c_str());
  const bool portable = attributes != INVALID_FILE_ATTRIBUTES;
  if (portable && (attributes & FILE_ATTRIBUTE_DIRECTORY)) throw std::runtime_error("Invalid portable marker");
  std::filesystem::path root;
  if (portable) {
    root = exe / L"data" / L"user";
  } else {
    PWSTR local = nullptr;
    if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, KF_FLAG_DEFAULT, nullptr, &local))) {
      throw std::runtime_error("Cannot locate per-user storage");
    }
    root = std::filesystem::path(local) / L"Etonify" / L"user";
    CoTaskMemFree(local);
  }
  Validate(root);
  std::error_code create_error;
  std::filesystem::create_directories(root, create_error);
  if (create_error) throw std::runtime_error("Cannot create user storage");
  Validate(root);
  ConfigureRoot(root, portable);
  return Map{
    {Value("installationId"), Value(InstallationId(root, portable))},
    {Value("distribution"), Value(portable ? "portable" : "installed")},
    {Value("dataRoot"), Value(Utf8(root.wstring()))},
    {Value("startedAtLogin"), Value(false)},
    {Value("minimized"), Value(false)},
    {Value("ownerPid"), Value(static_cast<int64_t>(GetCurrentProcessId()))},
  };
}

Bytes Protect(const Bytes& input, bool decrypt) {
  if ((!decrypt && input.size() != 32) || input.empty() || input.size() > 4096) {
    throw std::runtime_error("Invalid storage key");
  }
  DATA_BLOB source{static_cast<DWORD>(input.size()), const_cast<BYTE*>(input.data())};
  DATA_BLOB output{};
  // Deliberately no CRYPTPROTECT_LOCAL_MACHINE: scope is the current user.
  const BOOL ok = decrypt
      ? CryptUnprotectData(&source, nullptr, nullptr, nullptr, nullptr,
          CRYPTPROTECT_UI_FORBIDDEN, &output)
      : CryptProtectData(&source, L"Etonify Hive data key", nullptr, nullptr,
          nullptr, CRYPTPROTECT_UI_FORBIDDEN, &output);
  if (!ok) throw std::runtime_error("Cannot access current-user protected storage key");
  Bytes result(output.pbData, output.pbData + output.cbData);
  SecureZeroMemory(output.pbData, output.cbData);
  LocalFree(output.pbData);
  if (decrypt && result.size() != 32) throw std::runtime_error("Invalid protected storage key");
  return result;
}
const Map& Arguments(const flutter::MethodCall<Value>& call) {
  if (call.arguments() == nullptr || !std::holds_alternative<Map>(*call.arguments())) {
    throw std::runtime_error("Invalid storage arguments");
  }
  return std::get<Map>(*call.arguments());
}
const Value& Argument(const Map& args, const char* key) {
  const auto found = args.find(Value(key));
  if (found == args.end()) throw std::runtime_error("Missing storage argument");
  return found->second;
}
std::string StringArgument(const Map& args, const char* key) {
  const auto* value = std::get_if<std::string>(&Argument(args, key));
  if (value == nullptr) throw std::runtime_error("Invalid storage argument");
  return *value;
}
const Bytes& BytesArgument(const Map& args, const char* key) {
  const auto* value = std::get_if<Bytes>(&Argument(args, key));
  if (value == nullptr) throw std::runtime_error("Invalid storage argument");
  return *value;
}
bool BoolArgument(const Map& args, const char* key) {
  const auto* value = std::get_if<bool>(&Argument(args, key));
  if (value == nullptr) throw std::runtime_error("Invalid storage argument");
  return *value;
}
}  // namespace

Map DesktopStorageLaunchContext() { return LaunchContext(); }

void HandleDesktopStorageCall(const flutter::MethodCall<Value>& call,
      std::unique_ptr<flutter::MethodResult<Value>> result) {
    try {
      if (call.method_name() == "getLaunchContext") {
        result->Success(Value(LaunchContext()));
      } else if (call.method_name() == "getLegacyHiveRoot") {
        PWSTR documents = nullptr;
        if (FAILED(SHGetKnownFolderPath(FOLDERID_Documents, KF_FLAG_DEFAULT, nullptr, &documents))) {
          result->Success();
          return;
        }
        const auto path = std::filesystem::path(documents) / L"meow_hive";
        CoTaskMemFree(documents);
        result->Success(Value(Utf8(path.wstring())));
      } else if (call.method_name() == "validateRoot") {
        Validate(Wide(StringArgument(Arguments(call), "root")));
        result->Success();
      } else if (call.method_name() == "restrictKeyFile") {
        const auto& args = Arguments(call);
        Restrict(Wide(StringArgument(args, "path")),
                 BoolArgument(args, "portable"));
        result->Success();
      } else if (call.method_name() == "configureRootPermissions") {
        const auto& args = Arguments(call);
        ConfigureRoot(Wide(StringArgument(args, "root")),
                      BoolArgument(args, "portable"));
        result->Success();
      } else if (call.method_name() == "protectKey" || call.method_name() == "unprotectKey") {
        result->Success(Value(Protect(BytesArgument(Arguments(call), "key"),
            call.method_name() == "unprotectKey")));
      } else {
        result->NotImplemented();
      }
    } catch (const std::exception&) {
      // Never include OS blobs, paths containing secrets, or key bytes in logs.
      result->Error("storage_unavailable", "Cannot safely access Windows user storage");
    }
}

void RegisterDesktopStorage(flutter::BinaryMessenger* messenger) {
  flutter::MethodChannel<Value> channel(messenger, "etonify/windows_storage",
      &flutter::StandardMethodCodec::GetInstance());
  channel.SetMethodCallHandler(HandleDesktopStorageCall);
}
