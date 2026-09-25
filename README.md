<div align="center">

# Etonify

**Android-first open-source VPN client built around a modified sing-box core.**

[English](README.md) • [Русский](README_ru.md) • [Українська](README_uk.md) • [简体中文](README_cn.md) • [فارسی](README_fa.md)

<p align="center">
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-34A853?logo=android&logoColor=white" alt="Android"></a>
  <a href="https://github.com/yamixdev/etonify-core"><img src="https://img.shields.io/badge/Core-v1.15.0--alpha.3--etonify.5-E53935?logo=box&logoColor=white" alt="Core"></a>
  <a href="https://github.com/yamixdev/Etonify/releases"><img src="https://img.shields.io/badge/Version-0.3.6%2B26-FF6F00?logo=github&logoColor=white" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL%20v3-blue.svg" alt="License"></a>
</p>

[Download APK](https://github.com/yamixdev/Etonify/releases) • [Changelog](CHANGELOG.md) • [Report a problem](https://github.com/yamixdev/Etonify/issues/new/choose) • [Support the project](https://t.me/tribute/app?startapp=dQAQ) • [Telegram](https://t.me/etonify)

<br/>

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" alt="Etonify interface" width="720">

</div>

Etonify is an open-source VPN client for Android, built with Flutter and [etonify-core](https://github.com/yamixdev/etonify-core), a maintained fork of sing-box. It manages subscriptions, server selection, DNS and traffic routing.

The application does not provide VPN servers. You need your own server or a subscription from a provider.

## Versions and requirements

| Component | Version or requirement |
| :--- | :--- |
| Client source | `0.3.6+26` |
| Bundled core | `v1.15.0-alpha.3-etonify.5`, based on sing-box `1.15.0-alpha.3` |
| Flutter SDK | `3.47.5` (Dart 3.13) |
| Android | 8.0 or later (API 26+) |
| APK architectures | `arm64-v8a`, `armeabi-v7a` |
| Interface languages | English and Russian |

The source version comes from [pubspec.yaml](pubspec.yaml); the bundled core version comes from [libbox.provenance.json](android/app/libs/libbox.provenance.json). The source tree may contain changes that are not yet published. Check [Releases](https://github.com/yamixdev/Etonify/releases) for available APKs and release notes.

Android is the supported release platform. Other Flutter platform directories do not imply supported desktop or iOS builds.

## Getting started

1. Download an APK for your device from Releases and install it.
2. Add a subscription or import a server configuration.
3. Select a server or an automatic selection group.
4. Start the connection and approve Android's VPN permission request.

In-app updates are available under **About > Updates**. Use the menu in that section to select **Stable** or **Beta**. Beta includes prereleases intended for testing; the version displayed in the app may not contain a “beta” suffix.

## Features

- **Connections:** Android VPN through TUN, local HTTP/SOCKS proxy, or both.
- **Subscriptions:** import from a URL, file, clipboard, QR code or supported deep link; refresh profiles and view provider-supplied traffic and expiry information.
- **Servers:** manual selection, automatic selection groups, proxy chains and latency testing through the proxy connection.
- **Routing:** per-app routing, local network bypass, traffic rules and local rule sets.
- **DNS:** direct and proxied resolvers, encrypted DNS options and AdGuard DNS filtering.
- **Core settings:** network strategy, connection timeouts, TCP keepalive and UDP/NAT controls. The section includes explanations, a first-visit notice and its own reset action. See [Core settings](docs/core-settings.md).
- **Diagnostics:** connection logs and runtime information for troubleshooting.

Latency tests measure a request through the proxy, not ICMP ping. A missing result does not by itself establish whether a server works.

## Configuration compatibility

Import formats include server links, sing-box JSON, Xray JSON, Clash YAML and SIP008. Supported protocols include VLESS, VMess, Trojan, Shadowsocks, Hysteria/Hysteria2, TUIC, AnyTLS, NaiveProxy, HTTP and SOCKS. Compatibility depends on the protocol, transport and fields used in the configuration.

Importing an Xray or Clash profile does not mean every feature of its original core is supported. Etonify converts supported settings to its own sing-box configuration. See [sing-box 1.14 compatibility](docs/schema-1.14-compatibility.md) for migration details.

WireGuard has not been supported since Etonify 0.3.1 because of problems with its operation in the client.

Multiplexing requires compatible server support. It is not automatically negotiated for every server, and sing-box multiplexing is not interchangeable with Xray Mux. Provider-supplied settings and manual overrides are explained in the core settings section.

## Privacy and security

- **Send HWID to provider** in General settings controls the global device-identification option for subscription requests. Individual subscriptions can also have saved consent. Review these settings before adding a subscription.
- Untrusted proxy certificates are a separate security setting. Enabling it bypasses certificate verification; it should not be a general fix for connection problems.
- Logs and screenshots can contain subscription URLs, server addresses, credentials or device identifiers. Check and redact attachments before sharing them, even if the application has already masked some fields.

Report vulnerabilities privately using the [security policy](SECURITY.md), not a public issue.

## Building and development

The client CI uses Flutter `3.47.5` and JDK `21`. Dart constraints are defined in [pubspec.yaml](pubspec.yaml), and Android build tools are pinned in the Gradle files. Rebuilding the core uses a separate toolchain recorded in [ETONIFY_BASELINE](etonify-core/release/ETONIFY_BASELINE).

```powershell
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
flutter build apk --debug
```

For release builds, configure your signing key in `android/key.properties`. Some Happ encrypted-subscription compatibility assets are not public; see [private build inputs](.github/private/README.md) before expecting a local build to match official builds in that area.

The bundled AAR's source commit, version, toolchain and checksum are recorded in [libbox.provenance.json](android/app/libs/libbox.provenance.json). Do not infer the binary's source revision from the current submodule HEAD. See [bundled core documentation](android/app/libs/README.md) for replacement requirements and [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## Support

For bugs and suggestions, use the [issue forms](https://github.com/yamixdev/Etonify/issues/new/choose). Include the application version, device model, Android version and vendor software version, reproduction steps and relevant redacted logs. If the problem started after an update, mention the last working version.

Project news: [@etonify](https://t.me/etonify). Questions and private support: [Etonify Direct](https://t.me/etonify?direct).

## Support the project

Etonify is an independent open-source project. If you like the app, you can [support the developer through Tribute](https://t.me/tribute/app?startapp=dQAQ). I would appreciate it, and your support helps me continue working on the project.

## License and acknowledgements

Etonify is maintained by MeowTeam: [yamixdev](https://github.com/yamixdev) and [dudosxdev](https://github.com/dudosxdev). The project uses [sing-box](https://github.com/SagerNet/sing-box) and other open-source components.

Licensed under the [GNU GPL v3.0 or later](LICENSE). See [NOTICE.md](NOTICE.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and third-party notices.
