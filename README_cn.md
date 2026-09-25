<div align="center">

# Etonify

**基于 Flutter 和 sing-box 核心的 Android 开源 VPN 客户端。**

[English](README.md) • [Русский](README_ru.md) • [Українська](README_uk.md) • [简体中文](README_cn.md) • [فارسی](README_fa.md)

<p align="center">
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B%20(API%2026%2B)-34A853?logo=android&logoColor=white" alt="Android"></a>
  <a href="https://github.com/yamixdev/etonify-core"><img src="https://img.shields.io/badge/Core-v1.15.0--alpha.3--etonify.5-E53935?logo=box&logoColor=white" alt="Core"></a>
  <a href="https://github.com/yamixdev/Etonify/releases"><img src="https://img.shields.io/badge/版本-0.3.6%2B26-FF6F00?logo=github&logoColor=white" alt="版本"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL%20v3-blue.svg" alt="License"></a>
</p>

[下载 APK](https://github.com/yamixdev/Etonify/releases) • [更新记录](CHANGELOG.md) • [报告问题](https://github.com/yamixdev/Etonify/issues/new/choose) • [支持项目](https://t.me/tribute/app?startapp=dQAQ) • [Telegram](https://t.me/etonify)

</div>

Etonify 是面向 Android 的开源 VPN 客户端，使用 Flutter 和 [etonify-core](https://github.com/yamixdev/etonify-core)（基于 sing-box 维护的分支），用于管理订阅、选择节点、配置 DNS 和流量路由。应用不提供 VPN 服务器，需要自行准备服务器或服务商订阅。

## 版本与要求

| 组件 | 版本或要求 |
| :--- | :--- |
| 客户端源码版本 | `0.3.6+26` |
| Flutter SDK | `3.47.5` (Dart `3.13`) |
| 内置核心 | `v1.15.0-alpha.3-etonify.5`，基于 sing-box `1.15.0-alpha.3` |
| Android | 8.0 及以上 (API 26+) |
| APK 架构 | `arm64-v8a`、`armeabi-v7a` |
| 应用界面语言 | 英语、俄语 |

版本信息分别见 [pubspec.yaml](pubspec.yaml) 和 [AAR 构建元数据](android/app/libs/libbox.provenance.json)。源码可能包含尚未发布的更改，请在 Releases 查看可下载版本。当前支持的发布平台为 Android。

## 开始使用

1. 从 Releases 安装适合设备架构的 APK。
2. 添加订阅或导入配置。
3. 选择节点或自动选择组。
4. 启动连接并允许 Android 创建 VPN。

在应用更新页面的菜单中可以选择 Stable 或 Beta 渠道。Beta 包含供测试使用的预发布版本，应用显示的版本号不一定带有“beta”后缀。

## 功能与限制

- Android TUN VPN、本地 HTTP/SOCKS 代理，或同时运行两种模式。
- 通过 URL、文件、剪贴板、二维码和支持的深层链接导入配置。
- 手动或自动选择节点、代理链及延迟测试。
- 按应用分流、绕过局域网和本地规则集。
- 直连或通过代理访问 DNS、加密 DNS 和 AdGuard DNS 过滤。
- [核心设置](docs/core-settings.md)：网络策略、连接超时、TCP Keep Alive、UDP/NAT，以及参数说明和独立重置操作。

导入格式包括节点链接、sing-box JSON、Xray JSON、Clash YAML 和 SIP008。兼容性取决于协议、传输方式和配置字段；导入配置不代表支持原核心的所有功能。详见 [sing-box 1.14 兼容性说明](docs/schema-1.14-compatibility.md)。

由于协议在客户端中的运行问题，Etonify 从 0.3.1 起不再支持 WireGuard。多路复用需要服务器支持，sing-box multiplex 与 Xray Mux 不能互换。延迟测试通过代理发送请求，不是 ICMP ping；没有测试结果不一定代表节点不可用。

## 隐私与支持

常规设置中的全局 HWID 选项控制订阅请求是否向服务商发送设备识别信息，单个订阅也可能保存了授权。允许不受信任的代理证书会跳过证书验证，不应作为通用的连接修复方法。

分享日志前，请移除订阅链接、密钥、密码和设备标识。在 [issue](https://github.com/yamixdev/Etonify/issues/new/choose) 中提供应用版本、手机型号、Android 及厂商系统版本和复现步骤。私下联系：[Etonify Direct](https://t.me/etonify?direct)。安全漏洞请按 [SECURITY.md](SECURITY.md) 私下报告。

## 支持项目

Etonify 是一个独立维护的开源项目。如果你喜欢这个应用，可以通过 [Tribute 赞助开发者](https://t.me/tribute/app?startapp=dQAQ)。这份支持对我意义重大，也能帮助我继续开发 Etonify。

## 开发与许可证

构建步骤和完整说明见 [英文 README](README.md) 或 [俄文 README](README_ru.md)。贡献指南：[CONTRIBUTING.md](CONTRIBUTING.md)。内置核心信息：[libbox](android/app/libs/README.md)。

项目由 MeowTeam 维护：[yamixdev](https://github.com/yamixdev) 和 [dudosxdev](https://github.com/dudosxdev)。许可证为 [GNU GPL v3.0 或更新版本](LICENSE)。第三方声明见 [NOTICE.md](NOTICE.md) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
