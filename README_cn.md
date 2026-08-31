# Etonify

<div align="center">

[English](README.md) / [Русский](README_ru.md) / [Українська](README_uk.md) / [简体中文](README_cn.md) / [فارسی](README_fa.md)

<img width="1672" height="941" alt="Etonify 主界面" src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" />

[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android)](https://github.com/yamixdev/Etonify/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![Core](https://img.shields.io/badge/etonify--core-1.14.0--rc.1-blue?style=flat-square)](https://github.com/yamixdev/etonify-core/tree/etonify-dev)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue?style=flat-square)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-@etonify-26A5E4?style=flat-square&logo=telegram)](https://t.me/etonify)

**基于持续维护的 sing-box 分支，为 Android 打造的开源 VPN 客户端。**

[下载](https://github.com/yamixdev/Etonify/releases) · [更新记录](CHANGELOG.md) · [报告问题](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

</div>

Etonify 面向已经拥有 VPN 订阅、节点链接或配置文件，并希望在 Android 上获得精细路由、诊断和连接控制的用户。客户端及其 Android 运行组件与 [**yamixdev/etonify-core**](https://github.com/yamixdev/etonify-core/tree/etonify-dev) 一同维护；该核心以稳定版 sing-box 为基础，并包含 Etonify 所需的专用改动。

> [!IMPORTANT]
> Etonify 不出售或提供 VPN 服务器。请仅使用你拥有或获准使用的订阅与配置。

## 当前状态

| 组件 | 当前值 |
| --- | --- |
| 客户端源码版本 | `0.3.1+21` |
| Android 支持 | Android 8.0 及以上（API 26+） |
| 内置核心 | `v1.14.0-etonify.1`，基于稳定版 sing-box 1.14.0 |
| 应用界面语言 | 英语和俄语 |
| 发布平台 | 仅 Android |

`0.3.0` 是当前稳定版本。仓库保留了其他 Flutter 平台目录用于工具和后续开发，但 Windows、Linux、macOS 与 iOS 目前不是受支持的发布目标。

## 支持概览

| 功能 | 支持情况 |
| --- | --- |
| 通过 Android TUN 提供系统 VPN | 支持 |
| 本地 HTTP 与 SOCKS 代理 | 支持 |
| VPN TUN 与本地代理同时运行 | 支持 |
| 通过 URL、文件、剪贴板、二维码与 deep link 导入订阅 | 支持 |
| 按应用分流 | 支持 |
| 流量规则预设与本地规则集 | 支持 |
| AdGuard DNS 过滤 | 支持 |
| 应用内检查更新与安装 APK | 支持 |
| 内置免费服务器 | 不提供 |
| Windows、iOS 等发布版本 | 不支持 |

## 支持的配置

Etonify 可以导入节点链接、sing-box JSON、Xray JSON、Clash YAML、SIP008 和 WireGuard 配置文件。内置解析器目前支持：

- VLESS、VMess 与 Trojan；
- Shadowsocks 与 ShadowsocksR；
- Hysteria 与 Hysteria2；
- TUIC、WireGuard、AnyTLS 与 NaiveProxy；
- 上游 HTTP 与 SOCKS 代理。

实际兼容性取决于服务提供方使用的字段、传输方式和扩展。未知或无效的 outbound 会显示在错误报告中，而不会静默启动一个部分损坏的配置。

## 主要功能

### 连接与 Android 集成

- Android VPN TUN，支持 `gVisor`、`system` 和 `mixed` 网络栈。
- 带身份验证的本地 mixed 代理，可供 HTTP/SOCKS 客户端使用，并可选择允许局域网访问。
- VPN TUN 与本地代理既可单独启用，也可同时启用。
- 前台服务用于在界面关闭或 Android 重建 Flutter 进程后继续维护隧道。
- 集中处理 Wi‑Fi、移动数据、休眠、恢复以及默认网络切换。
- 状态通知显示所选服务器、延迟、当前速度或累计流量，并提供刷新延迟和停止 VPN 操作。

### 订阅与配置文件

- 通过 HTTPS URL、二维码、文件、剪贴板、Android 分享菜单和受支持的 deep link 导入。
- 支持 sing-box、Xray、Clash、SIP008、WireGuard 以及常见的单节点链接格式。
- 支持 `etonify://`、`happ://add`、`happ://crypt*` 与 `sing-box://import-remote-profile` 链接。
- 在本地解码从 `crypt` 到 `crypt5` 的受支持 Happ 变体；如果服务方要求 HWID，客户端会先请求明确同意。
- 官方构建包含 Happ `crypt5` 兼容数据，但这些数据不会以明文形式存放在公开源码中。
- 安全刷新：空响应、损坏内容、HTML 页面或网络错误不会覆盖最后一个可用配置。
- 备份与恢复会保留配置边界、名称、服务器、所选 outbound、更新计划和来源 URL。
- 大型响应在 UI isolate 之外解析，大体积内容与精简的配置元数据分开保存。

远程订阅必须使用 HTTPS。普通 HTTP 仅允许用于明确的本机回环地址：`localhost`、`127.0.0.1` 和 `::1`。

### 服务器与诊断

- 对当前服务器执行定向 URLTest，并异步检查整个配置中的服务器。
- 服务器返回结果后立即更新；旧检查会话无法覆盖较新的结果。
- `lowest` 使用核心真实的 URLTest 选择，不伪造延迟或国家旗帜。
- 可按订阅原始顺序、可用性、延迟、名称或国家排序。
- 不可用服务器显示清晰的警告状态；DNS、TLS、EOF 与 timeout 详情保留在诊断中。
- 支持出口 IP 查询、连接流量、实时速度、会话统计和轻量流量图表。
- 可导出包含运行时、网络、内存和配置构建信息的日志。

URLTest 是通过代理发出的 HTTP 请求，并非 ICMP ping。结果包含代理协商、TLS 和测试服务器响应时间。

### 路由与 DNS

- 按应用设置“通过 VPN”或“绕过 VPN”的分流模式。
- 同一时间只启用一个流量规则预设：俄罗斯服务直连、AI 服务走 VPN，或社交网络走 VPN。
- 带版本的本地 `.srs` 地理资源，更新时进行校验，下载后可离线使用。
- 在设备上构建的 AdGuard DNS 过滤规则。
- 局域网绕过、严格路由和防泄漏选项。
- 支持设备 DNS，以及自定义 UDP、TCP、DoT 与 DoH 解析器，并安全处理 bootstrap DNS。
- 可选的 FakeIP、TCP Fast Open、TCP MultiPath、TLS 分片及其他明确标注的实验功能。
- 代理链可让同一配置中的一个 outbound 通过另一个 outbound 建立连接。

流量规则和按应用分流作用于不同层级。如果两者同时匹配，先应用 Android 的应用选择策略，再应用 sing-box 的活动路由规则。

### 更新与安全

- GitHub Releases 更新器会按设备 ABI 选择 APK 并显示下载进度。
- 安装前会验证包名、最低 Android 版本、签名证书、文件大小以及发布清单中的 SHA-256。
- 应用设置、订阅、凭据和密钥使用 AES-GCM 加密；包装密钥保存在 Android Keystore 中。
- Flutter 日志、Android 原生诊断和导出的报告会隐藏已知敏感信息。
- 代理连接与订阅下载分别提供“不验证证书”选项，两者默认关闭，并明确提示安全风险。
- 跨 origin 跳转会移除敏感请求头，并禁止从 HTTPS 降级到 HTTP。

## 限制与使用预期

- Etonify 是客户端，不是 VPN 服务提供商。
- Android 是唯一受支持的发布平台。
- 某些服务方专用扩展可能需要更新核心或解析器。
- 超大订阅和全量服务器检查会暂时增加 CPU、内存、网络与电量消耗。
- 实验性网络选项可能降低兼容性。不清楚用途时请保留默认值。
- 使用本地代理的应用或局域网设备需要手动填写 Etonify 显示的地址、端口和凭据。

## 安装

请从 [GitHub Releases](https://github.com/yamixdev/Etonify/releases) 下载 APK。建议选择与你设备 ABI 匹配的 split APK；大多数现代 Android 手机使用 `arm64-v8a`。Android 可能要求允许浏览器或文件管理器安装未知来源应用。

客户端会尽可能迁移已有设置。在安装重大更新或修改高级 DNS 与路由设置前，建议先创建加密备份。

## 开发

当前 CI 配置使用：

- Flutter 3.47.0，Dart 3.11.4 或更高版本；
- Android SDK 36；
- JDK 21 构建客户端；
- Gradle 9.1 与 Android Gradle Plugin 9.0.1。

克隆仓库及核心 submodule，然后执行：

```powershell
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

Windows 下的 Android 检查：

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug
```

公开发布时，请在 `android/key.properties` 中配置真实的发布签名。使用 debug 签名的 release APK 仅用于本地测试。

## 核心与可复现构建

内置的 `android/app/libs/libbox.aar` 由 `etonify-core` submodule 的精确提交构建。版本、上游 sing-box 提交、工具链、build tags 与 SHA-256 记录在 [`libbox.provenance.json`](android/app/libs/libbox.provenance.json) 中，并与 [`libbox.sha256`](android/app/libs/libbox.sha256) 一起校验。

仓库 workflow 可以从固定源码重新生成四个受跟踪的核心构建产物：

- `libbox.aar`；
- `libbox-sources.jar`；
- `libbox.provenance.json`；
- `libbox.sha256`。

## 社区与贡献

- Telegram 频道：[@etonify](https://t.me/etonify)
- 直接联系：[Etonify Direct](https://t.me/etonify?direct)
- 错误报告与功能建议：[GitHub Issue 表单](https://github.com/yamixdev/Etonify/issues/new/choose)
- 贡献指南：[CONTRIBUTING.md](CONTRIBUTING.md)
- 安全问题报告：[SECURITY.md](SECURITY.md)

项目由 MeowTeam 维护：[yamixdev](https://github.com/yamixdev) 负责 Android 客户端、发布与 etonify-core；[dudosxdev](https://github.com/dudosxdev) 提供网络和协议方面的支持。

## 许可证

Etonify 采用 [GNU General Public License v3.0 或更高版本](LICENSE)。内置、改编及第三方组件的说明见 [NOTICE.md](NOTICE.md) 和 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
