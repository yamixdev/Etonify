<div align="center">

# Etonify

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" width="640" alt="Etonify by MeowTeam">

**An open-source VPN client for Android, powered by sing-box.**

<p dir="ltr">
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B-14684D?style=flat&amp;logo=android&amp;logoColor=white" alt="Android 8.0+"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.47.5-145D86?style=flat&amp;logo=flutter&amp;logoColor=white" alt="Flutter 3.47.5"></a>
</p>

**[Download APK](https://github.com/yamixdev/Etonify/releases/latest)** · [Changelog](CHANGELOG.md) · [Telegram](https://t.me/etonify)

<p dir="ltr">
<b>English</b> · <a href="README_ru.md">Русский</a> · <a href="README_uk.md">Українська</a> · <a href="README_cn.md">简体中文</a> · <a href="README_fa.md">فارسی</a>
</p>

</div>

<a id="quick-start"></a>

## Getting started

1. Install the [latest APK](https://github.com/yamixdev/Etonify/releases/latest). Use the universal APK if you are unsure which one to pick.
2. Add a subscription or import a server configuration.
3. Pick a server or an automatic selection group, then connect and approve Android's VPN permission request.

You need your own server or a subscription from a VPN provider.

<a id="features"></a>

## Features

- Import subscriptions from links, files, the clipboard or QR codes.
- Check latency, use automatic server selection, build proxy chains and exclude servers by country, protocol, security or transport.
- Choose which apps use the VPN. Configure DNS and traffic rules or run a local HTTP/SOCKS proxy.
- See connection speed, traffic, external IP and diagnostic logs.

<a id="compatibility"></a>

## Compatibility

**Import formats** · sing-box JSON, Xray JSON, Clash YAML, SIP008 and server links.

**Protocols** · VLESS, VMess, Trojan, Shadowsocks, Hysteria, Hysteria2, TUIC, AnyTLS, NaiveProxy, HTTP and SOCKS. Xray and Clash compatibility depends on the fields used in the profile.

**Android** · 8.0 or later. APKs are available for `arm64-v8a` and `armeabi-v7a`, plus a universal APK.

See [proxy selection and nested groups](docs/proxy-selection-contract.md) and [core settings](docs/core-settings.md).

<a id="privacy"></a>

<details>
<summary>Privacy and safe sharing</summary>

Etonify sends VPN traffic through the server you choose. The app has no advertising or analytics SDKs.

Profiles, settings and logs stay on the device unless you export or share them. Subscription and settings databases use encryption backed by Android Keystore. Redact subscription URLs, credentials and device identifiers before sharing logs or exports.

The app contacts your subscription provider and DNS resolver, the configured latency test URL, and the sources for updates and rules. The external IP panel uses Cloudflare. HWID sharing is enabled by default and can be managed in [app and subscription settings](docs/subscription-hwid.md).

Report vulnerabilities privately using [SECURITY.md](SECURITY.md).

</details>

<a id="versions"></a>
<a id="development"></a>

## Development

The source tree contains client [`0.3.13+45`](pubspec.yaml) and libbox [`v1.15.0-alpha.10-etonify.7`](android/app/libs/libbox.provenance.json). CI uses Flutter `3.47.5` and JDK `21`. Local builds also require the Android SDK and Python 3.

<details>
<summary>Set up and check the client</summary>

```sh
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
dart run pigeon --input pigeons/singbox_api.dart
python scripts/verify_libbox.py
flutter analyze
flutter test
```

Android builds use the [bundled libbox AAR](android/app/libs/README.md). See the [Android release workflow](.github/workflows/android-release.yml) and [private build inputs](.github/private/README.md) for release builds.

</details>

See [CONTRIBUTING.md](CONTRIBUTING.md) before sending a patch.

<a id="support"></a>

## Support

[Report a problem](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram support](https://t.me/etonify?direct) · [Tribute](https://t.me/tribute/app?startapp=dQAQ) · [DonationAlerts](https://dalink.to/yamix31)

<a id="license"></a>

## License

[GPL-3.0-or-later](LICENSE). Maintained by MeowTeam, [yamixdev](https://github.com/yamixdev) and [dudosxdev](https://github.com/dudosxdev). Built on [sing-box](https://github.com/SagerNet/sing-box). See [attribution](NOTICE.md) and [third-party licenses](THIRD_PARTY_NOTICES.md).
