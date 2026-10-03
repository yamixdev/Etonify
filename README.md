<div align="center">

# Etonify

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" width="640" alt="Etonify by MeowTeam">

**An open-source VPN client for Android.**

Built with Flutter and a modified sing-box core.

<p dir="ltr">
<b>English</b> · <a href="README_ru.md">Русский</a> · <a href="README_uk.md">Українська</a> · <a href="README_cn.md">简体中文</a> · <a href="README_fa.md">فارسی</a>
</p>

<p dir="ltr">
  <a href="https://github.com/yamixdev/Etonify/releases"><img src="https://img.shields.io/badge/Client-0.3.7%2B37-blue?style=for-the-badge&amp;logo=flutter&amp;logoColor=white" alt="Client: 0.3.7+37"></a>
  <a href="android/app/libs/libbox.provenance.json"><img src="https://img.shields.io/badge/Core-1.15.0--alpha.10--etonify.1-blue?style=for-the-badge" alt="Bundled core: 1.15.0-alpha.10-etonify.1"></a>
  <br>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B-brightgreen?style=for-the-badge&amp;logo=android&amp;logoColor=white" alt="Android 8.0+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--or--later-blue?style=for-the-badge" alt="GPL-3.0-or-later"></a>
</p>

**[Download APK](https://github.com/yamixdev/Etonify/releases)** · [Changelog](CHANGELOG.md) · [Report a problem](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

[Features](#features) · [Quick start](#quick-start) · [Compatibility](#compatibility) · [Development](#development)

</div>

Etonify brings subscriptions, proxy selection, routing and connection diagnostics into one Android app. The interface supports light, dark and dynamic color themes.

> [!IMPORTANT]
> Etonify does not provide VPN servers or sell subscriptions. Connect your own server or use a subscription from a provider.

<a id="features"></a>

## Features

| Area | What you can do |
| :--- | :--- |
| Subscriptions | Import from a URL, file, clipboard, QR code or supported deep link. Refresh profiles and see provider-supplied traffic and expiry information. |
| Servers and groups | Choose a server manually or use an automatic group. Browse nested groups in subscription order, share a server or group, and export a profile to JSON for file import. |
| Latency checks | Check a server, a group's members or the subscription. View measured results and working-server counters without treating untested servers as failed. |
| Routing | Choose apps that use VPN or bypass it. Each mode has its own selection. Configure traffic rules, local network bypass and local rule sets. |
| Traffic dashboard | Follow upload/download speed, session traffic and uptime. Refresh the current external IP and its country flag. |
| DNS and core settings | Configure direct or proxied DNS, encrypted DNS and AdGuard DNS filtering. Adjust network strategy, timeouts, TCP keepalive and UDP/NAT controls. |
| Connection and diagnostics | Use Android TUN VPN, a local HTTP/SOCKS proxy or both. Inspect logs, core compatibility, applied configuration and runtime resources. |

Latency checks send a request through the proxy; they are not ICMP ping. A missing result is not a measured failure. Group results and counters depend on completed checks of their members.


<a id="quick-start"></a>

## Connect in four steps

1. Install an APK for your device from [Releases](https://github.com/yamixdev/Etonify/releases).
2. Add your subscription or import a server configuration.
3. Select a server or an automatic selection group.
4. Start the connection and approve Android's VPN permission request.

In **About → Updates**, choose **Stable** or **Beta** from the menu. Beta includes prereleases for testing; the displayed app version may not have a “beta” suffix.

If an update reports that split-tunneling settings were reset, review the section and select apps again before enabling it.

<a id="versions"></a>

## Versions and requirements

| Component | Current source tree |
| :--- | :--- |
| Client | `0.3.7+37` |
| Bundled core | `v1.15.0-alpha.10-etonify.1` |
| Upstream baseline | `v1.15.0-alpha.10` |
| Flutter SDK | `3.47.5` · Dart `3.13` |
| Android | 8.0 or later · API 26+ |
| APK architectures | `arm64-v8a` · `armeabi-v7a` |
| App interface languages | English and Russian |

> [!NOTE]
> These versions refer to the source code. Available APKs are listed in [Releases](https://github.com/yamixdev/Etonify/releases). The core is based on a prerelease version of sing-box.

Client version: [pubspec.yaml](pubspec.yaml). Binary version and source commit: [libbox.provenance.json](android/app/libs/libbox.provenance.json). Android is the supported release platform; other Flutter platform directories do not imply supported builds.

<a id="compatibility"></a>

## Configuration compatibility

**Import formats**

`sing-box JSON` · `Xray JSON` · `Clash YAML` · `SIP008` · server links

**Protocols**

`VLESS` · `VMess` · `Trojan` · `Shadowsocks` · `Hysteria / Hysteria2` · `TUIC` · `AnyTLS` · `NaiveProxy` · `HTTP` · `SOCKS`

Etonify converts supported Xray and Clash settings to its sing-box configuration. Importing a profile does not enable every feature of the original core. Compatibility depends on the protocol, transport and fields used.

- WireGuard is not included in the Android build.
- Multiplexing requires compatible server support. sing-box multiplexing and Xray Mux are not interchangeable.
- Nested group membership comes from configuration references, not names such as `cand-*`. Group exports retain their referenced members and dependencies.

Read about [proxy selection and nested groups](docs/proxy-selection-contract.md), [core settings and multiplexing](docs/core-settings.md), and [earlier sing-box schema migrations](docs/schema-1.14-compatibility.md).

<a id="privacy"></a>

## Privacy and safe sharing

Etonify connects to the VPN servers you choose. Your traffic does not pass through MeowTeam servers. The client has no advertising or analytics SDKs.

- **On your device:** subscriptions, profiles, selected servers, settings, diagnostic logs and downloaded rules are handled locally. On Android, subscription and settings databases are encrypted with a key protected by Android Keystore. This does not encrypt exported files.
- **To developers:** the client does not automatically send profiles or diagnostic logs. You choose what to share when contacting support.
- **To external services:** subscription imports and refreshes contact the subscription URL; client updates, rules and changelog images are downloaded from GitHub and their respective sources. Latency checks contact the configured test URL, and DNS queries go to the selected resolver. These services see information from their network requests, including the exit IP address.
- **“Your IP”:** the client contacts Cloudflare to determine the external address and country when you open the panel or refresh manually. The request follows the device's current routes, including VPN and split-tunneling rules.

A VPN alone does not guarantee anonymity: what your VPN and DNS providers can see depends on the protocol, encryption and your settings.

- HWID sharing is enabled globally by default and can be turned off in settings. When the global setting is off, per-subscription consent can still enable it for a profile. Review global, profile and custom-header settings before adding a subscription.
- Allowing untrusted proxy certificates bypasses certificate verification. Do not use it as a general fix for connection problems.
- Profile exports, backups, logs and screenshots may contain subscription URLs, access keys, passwords, server addresses or device identifiers. Review and redact them before sharing.

Report vulnerabilities privately using the contact information in [SECURITY.md](SECURITY.md). Do not publish exploit details in a public issue.

<a id="development"></a>

## Development

The client uses the committed AAR: a normal client build does not rebuild the Go core. CI uses Flutter `3.47.5` and JDK `21`; install the Android SDK and Python 3 as well.

<details>
<summary>Show client setup, checks and a debug build</summary>

```powershell
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
dart run pigeon --input pigeons/singbox_api.dart
python scripts/verify_libbox.py
flutter analyze
flutter test
flutter build apk --debug
```

For release builds, configure signing in `android/key.properties`. Official builds may restore private Happ encrypted-subscription compatibility assets; read [private build inputs](.github/private/README.md) before expecting a local build to match that behavior.

</details>

<details>
<summary>How the bundled core is pinned</summary>

The submodule pins the core source. Android compiles against `android/app/libs/libbox.aar`. Both must be updated together with the sources JAR, checksum and provenance. `scripts/verify_libbox.py` checks this pairing and the Android Java API contract.

Core replacement requirements: [bundled core documentation](android/app/libs/README.md). Separate core toolchain: [ETONIFY_BASELINE](etonify-core/release/ETONIFY_BASELINE). Release automation: [GitHub Actions guide](docs/github-actions.md).

</details>

Read [CONTRIBUTING.md](CONTRIBUTING.md) before sending a patch.

<a id="support"></a>

## Get help or support development

For a bug report, include the app version, device model, Android and vendor OS versions, reproduction steps and redacted logs. If it started after an update, name the last working version.

[Open an issue](https://github.com/yamixdev/Etonify/issues/new/choose) · [Project news](https://t.me/etonify) · [Private support](https://t.me/etonify?direct)

You can support development through [Tribute](https://t.me/tribute/app?startapp=dQAQ) or [DonationAlerts](https://dalink.to/yamix31).

<a id="license"></a>

## People and licenses

Maintained by MeowTeam: [yamixdev](https://github.com/yamixdev) and [dudosxdev](https://github.com/dudosxdev). Built on [sing-box](https://github.com/SagerNet/sing-box) and other open-source components.

Licensed under [GNU GPL v3.0 or later](LICENSE). See [NOTICE.md](NOTICE.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for attribution and third-party licenses.
