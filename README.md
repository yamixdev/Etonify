# Etonify

<div align="center">

[English](README.md) / [Русский](README_ru.md) / [Українська](README_uk.md) / [简体中文](README_cn.md) / [فارسی](README_fa.md)

<img width="1672" height="941" alt="Etonify main screen" src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" />

[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android)](https://github.com/yamixdev/Etonify/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![Core](https://img.shields.io/badge/etonify--core-1.13.19-blue?style=flat-square)](https://github.com/yamixdev/etonify-core/tree/etonify-dev)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue?style=flat-square)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-@etonify-26A5E4?style=flat-square&logo=telegram)](https://t.me/etonify)

**An open-source Android VPN client powered by a maintained sing-box fork.**

[Download](https://github.com/yamixdev/Etonify/releases) · [Changelog](CHANGELOG.md) · [Report a problem](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

</div>

Etonify is built for people who already have a VPN subscription, share link, or configuration and want detailed routing, diagnostics, and control over the Android connection. The app and its Android runtime are developed together with [**yamixdev/etonify-core**](https://github.com/yamixdev/etonify-core/tree/etonify-dev), a stable sing-box base with changes maintained for Etonify.

> [!IMPORTANT]
> Etonify does not sell or provide VPN servers. Use only subscriptions and configurations that you own or are authorized to use.

## Current status

| Component | Current value |
| --- | --- |
| App source version | `0.3.0+20` |
| Android support | Android 8.0 and newer (API 26+) |
| Bundled core | `v1.13.19-etonify.1`, based on sing-box 1.13.19 |
| App languages | English and Russian |
| Release target | Android only |

`0.3.0` is the current stable release. Other Flutter platform folders remain in the repository for tooling and future work, but Windows, Linux, macOS, and iOS builds are not supported releases.

## Support at a glance

| Capability | Support |
| --- | --- |
| System VPN through Android TUN | Yes |
| Local HTTP and SOCKS proxy | Yes |
| VPN TUN and local proxy at the same time | Yes |
| Subscriptions by URL, file, clipboard, QR, and deep link | Yes |
| Per-app split tunneling | Yes |
| Traffic-rule presets and local rule sets | Yes |
| AdGuard DNS filtering | Yes |
| In-app update checks and APK installation | Yes |
| Built-in free servers | No |
| Windows, iOS, and other release targets | No |

## Supported configurations

Etonify can import share links, sing-box JSON, Xray JSON, Clash YAML, SIP008, and WireGuard configuration files. The built-in parsers currently recognize:

- VLESS, VMess, and Trojan;
- Shadowsocks and ShadowsocksR;
- Hysteria and Hysteria2;
- TUIC, WireGuard, AnyTLS, and NaiveProxy;
- HTTP and SOCKS upstream proxies.

Exact compatibility depends on the fields, transports, and extensions used by a provider. Unknown or invalid outbounds are reported instead of silently starting a partially broken profile.

## Main features

### Connection and Android integration

- Android VPN TUN with `gVisor`, `system`, and `mixed` stack options.
- Authenticated local mixed proxy for HTTP and SOCKS clients, with optional LAN access.
- VPN TUN and the local proxy can be enabled separately or together.
- Foreground service designed to keep the tunnel alive while the UI is closed or Android recreates the Flutter process.
- Central handling of Wi-Fi, mobile-data, sleep, resume, and default-network changes.
- Status notification with the selected server, latency, traffic speed or totals, refresh controls, and a stop action.

### Subscriptions and profiles

- Import from HTTPS URL, QR code, file, clipboard, Android share sheet, and supported deep links.
- Import of sing-box, Xray, Clash, SIP008, WireGuard, and common share-link formats.
- Support for `etonify://`, `happ://add`, `happ://crypt*`, and `sing-box://import-remote-profile` links.
- Local decoding of supported Happ `crypt` through `crypt5` variants, with explicit HWID consent when a provider requires it.
- Happ `crypt5` compatibility data is included in official builds but is not stored in plaintext in the public source tree.
- Safe refresh: an empty, invalid, HTML, or failed response does not replace the last working profile.
- Separate profiles preserve their names, servers, selected outbound, update schedule, and source URL during backup and restore.
- Large payloads are parsed outside the UI isolate and stored separately from compact profile metadata.

Remote subscriptions must use HTTPS. Plain HTTP is accepted only for literal loopback addresses such as `localhost`, `127.0.0.1`, and `::1`.

### Servers and diagnostics

- Targeted URLTest for the selected server and asynchronous group checks for a full profile.
- Results appear as each server answers; stale sessions cannot overwrite a newer check.
- `lowest` follows the core's actual URLTest choice instead of displaying a fabricated latency or flag.
- Sorting by source order, availability, latency, name, or country.
- Failed servers use a clear warning state; detailed DNS, TLS, EOF, and timeout causes remain in diagnostics.
- External-IP lookup, connection traffic, live speed, session totals, and a lightweight traffic graph.
- Exportable logs with runtime, network, memory, and configuration diagnostics.

URLTest is an HTTP request through the proxy, not ICMP ping. Its result includes proxy negotiation, TLS, and test-server response time.

### Routing and DNS

- Per-app split tunneling in “through VPN” and “bypass VPN” modes.
- One active traffic-rule preset at a time: Russian services direct, AI services through VPN, or social networks through VPN.
- Versioned local `.srs` geo-resource files with verified replacement and offline use after download.
- Locally compiled AdGuard DNS filter.
- Local-network bypass, stricter routing, and leak-protection controls.
- Device DNS and custom UDP, TCP, DoT, and DoH resolvers with safe bootstrap handling.
- Optional FakeIP, TCP Fast Open, TCP MultiPath, TLS fragmentation, and other clearly marked experimental settings.
- Proxy chains that route one selected outbound through another outbound in the same profile.

Traffic rules and split tunneling affect different layers. If both match the same traffic, Android's selected-app policy is applied first, followed by the active sing-box route rules.

### Updates and security

- GitHub Releases updater selects an APK for the device ABI and displays download progress.
- Before installation, Etonify verifies the package name, minimum Android version, signing certificate, file size, and SHA-256 from the release manifest.
- App settings, subscriptions, credentials, and keys are encrypted with AES-GCM; the wrapping key is kept in Android Keystore.
- Known secrets are redacted from Flutter logs, native Android diagnostics, and exported reports.
- Unsafe certificate options for proxy connections and subscription downloads are separate, disabled by default, and explicitly marked as security risks.
- Cross-origin redirects drop sensitive headers, and HTTPS-to-HTTP subscription redirects are blocked.

## Limits and expectations

- Etonify is a client, not a VPN provider.
- Android is the only supported release platform.
- Some provider-specific extensions may require a newer core or parser update.
- Very large subscriptions and full server checks can temporarily increase CPU, memory, network, and battery use.
- Experimental networking options can reduce compatibility. Keep their defaults unless you know why a change is needed.
- Local proxy clients and LAN devices must be configured manually with the address, port, and credentials shown by Etonify.

## Install

Download an APK from [GitHub Releases](https://github.com/yamixdev/Etonify/releases). Prefer the split APK matching your device ABI; most current Android phones use `arm64-v8a`. Android may ask for permission to install apps from your browser or file manager.

Existing settings are migrated when possible. Keep an encrypted backup before installing a major update or changing advanced routing and DNS options.

## Development

The CI configuration currently uses:

- Flutter 3.47.0 with Dart 3.11.4 or newer;
- Android SDK 36;
- JDK 21 for the client build;
- Gradle 9.1 and Android Gradle Plugin 9.0.1.

Clone the repository with its core submodule, then run:

```powershell
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Android checks on Windows:

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug
```

For a public release build, configure a real release keystore in `android/key.properties`. Debug-signed release APKs are intended only for local testing.

## Core and reproducible builds

The bundled `android/app/libs/libbox.aar` is built from the exact `etonify-core` submodule commit. Its version, upstream sing-box commit, toolchain, build tags, and SHA-256 are recorded in [`libbox.provenance.json`](android/app/libs/libbox.provenance.json) and verified together with [`libbox.sha256`](android/app/libs/libbox.sha256).

The repository workflow can rebuild the four tracked core artifacts from the pinned source:

- `libbox.aar`;
- `libbox-sources.jar`;
- `libbox.provenance.json`;
- `libbox.sha256`.

## Community and contributing

- Telegram channel: [@etonify](https://t.me/etonify)
- Direct contact: [Etonify Direct](https://t.me/etonify?direct)
- Bug reports and feature requests: [GitHub issue forms](https://github.com/yamixdev/Etonify/issues/new/choose)
- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Security reports: [SECURITY.md](SECURITY.md)

MeowTeam maintains the project: [yamixdev](https://github.com/yamixdev) develops the Android client, releases, and etonify-core; [dudosxdev](https://github.com/dudosxdev) contributes networking and protocol expertise.

## License

Etonify is licensed under the [GNU General Public License v3.0 or later](LICENSE). See [NOTICE.md](NOTICE.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for bundled, adapted, and third-party components.
