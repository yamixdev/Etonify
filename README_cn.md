<div align="center">

# Etonify

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" width="640" alt="Etonify by MeowTeam">

**开源 Android VPN 客户端。**

使用 Flutter 和修改版 sing-box 核心。

<p dir="ltr">
<a href="README.md">English</a> · <a href="README_ru.md">Русский</a> · <a href="README_uk.md">Українська</a> · <b>简体中文</b> · <a href="README_fa.md">فارسی</a>
</p>

<p dir="ltr">
  <a href="https://github.com/yamixdev/Etonify/releases"><img src="https://img.shields.io/badge/Client-0.3.7%2B37-blue?style=for-the-badge&amp;logo=flutter&amp;logoColor=white" alt="客户端: 0.3.7+37"></a>
  <a href="android/app/libs/libbox.provenance.json"><img src="https://img.shields.io/badge/Core-1.15.0--alpha.10--etonify.1-blue?style=for-the-badge" alt="内置核心: 1.15.0-alpha.10-etonify.1"></a>
  <br>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B-brightgreen?style=for-the-badge&amp;logo=android&amp;logoColor=white" alt="Android 8.0+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--or--later-blue?style=for-the-badge" alt="GPL-3.0-or-later"></a>
</p>

**[下载 APK](https://github.com/yamixdev/Etonify/releases)** · [更新记录](CHANGELOG.md) · [报告问题](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

[功能](#features) · [快速开始](#quick-start) · [兼容性](#compatibility) · [开发](#development)

</div>

Etonify 将订阅、代理选择、路由和连接诊断整合到一个 Android 应用中。界面支持浅色、深色主题和动态配色。

> [!IMPORTANT]
> Etonify 不提供 VPN 服务器，也不出售订阅。你需要自己的服务器或服务商提供的订阅。

<a id="features"></a>

## 功能

| 模块 | 你可以做什么 |
| :--- | :--- |
| 订阅 | 通过 URL、文件、剪贴板、二维码或支持的深层链接导入。更新配置，并查看服务商提供的流量和到期信息。 |
| 节点与分组 | 手动选择节点或使用自动选择组。按订阅顺序查看嵌套分组、分享节点或分组，并将配置导出为 JSON，以便从文件导入。 |
| 延迟测试 | 测试单个节点、分组成员或整个订阅。查看测试结果和可用节点计数，不将未经测试的节点视为不可用。 |
| 路由 | 选择通过 VPN 或直连的应用，两种模式各有独立列表。配置流量规则、绕过局域网及本地规则集。 |
| 流量面板 | 查看上传与下载速度、会话流量和运行时间。刷新当前出口 IP 及其国家旗帜。 |
| DNS 与核心设置 | 配置直连或经代理访问的 DNS、加密 DNS 和 AdGuard DNS 过滤。调整网络策略、连接超时、TCP Keep Alive 和 UDP/NAT 参数。 |
| 连接与诊断 | 使用 Android TUN VPN、本地 HTTP/SOCKS 代理，或同时使用两种模式。查看日志、核心兼容性、已应用配置的状态和进程资源。 |

延迟测试通过代理发送请求，不是 ICMP ping。没有结果不等于已测得连接失败。分组结果和计数取决于成员已完成的测试。


<a id="quick-start"></a>

## 四步开始连接

1. 从 [Releases](https://github.com/yamixdev/Etonify/releases) 安装适合设备的 APK。
2. 添加订阅或导入节点配置。
3. 选择节点或自动选择组。
4. 启动连接，并允许 Android 创建 VPN。

在 **关于 → 更新** 页面的菜单中选择 **Stable** 或 **Beta**。Beta 包含用于测试的预发布版本，应用显示的版本号不一定带有“beta”后缀。

如果更新后出现分应用路由设置已重置的提示，请先进入该页面重新选择应用，再启用此功能。

<a id="versions"></a>

## 版本与要求

| 组件 | 当前源码 |
| :--- | :--- |
| 客户端 | `0.3.7+37` |
| 内置核心 | `v1.15.0-alpha.10-etonify.1` |
| sing-box 基线 | `v1.15.0-alpha.10` |
| Flutter SDK | `3.47.5` · Dart `3.13` |
| Android | 8.0 及以上 · API 26+ |
| APK 架构 | `arm64-v8a` · `armeabi-v7a` |
| 应用界面语言 | 英语和俄语 |

> [!NOTE]
> 这些是源码版本，不代表对应 APK 已经发布。已发布的 APK 请查看 [Releases](https://github.com/yamixdev/Etonify/releases)。核心基于 sing-box 的预发布版本。

客户端版本见 [pubspec.yaml](pubspec.yaml)。核心二进制的版本与源码提交见 [libbox.provenance.json](android/app/libs/libbox.provenance.json)。目前支持的发布平台为 Android；其他 Flutter 平台目录不代表存在受支持的构建。

<a id="compatibility"></a>

## 配置兼容性

**导入格式**

`sing-box JSON` · `Xray JSON` · `Clash YAML` · `SIP008` · 节点链接

**协议**

`VLESS` · `VMess` · `Trojan` · `Shadowsocks` · `Hysteria / Hysteria2` · `TUIC` · `AnyTLS` · `NaiveProxy` · `HTTP` · `SOCKS`

Etonify 将支持的 Xray 和 Clash 参数转换为自身的 sing-box 配置。导入配置并不意味着启用原核心的所有功能。兼容性取决于协议、传输方式和所用字段。

- Android 构建不包含 WireGuard。
- 多路复用需要服务器支持。sing-box multiplex 与 Xray Mux 不能互换。
- 嵌套分组由配置中的引用关系确定，而不是根据 `cand-*` 等名称推断。导出分组时会保留其引用的成员和相关依赖。

详细说明：[代理选择与嵌套分组](docs/proxy-selection-contract.md)、[核心设置与多路复用](docs/core-settings.md)、[早期 sing-box 配置迁移](docs/schema-1.14-compatibility.md)。

<a id="privacy"></a>

## 隐私与安全分享

Etonify 连接你选择的 VPN 服务器。你的流量不会经过 MeowTeam 的服务器。客户端没有广告或数据分析 SDK。

- **设备上的数据：**订阅、配置、已选服务器、设置、诊断日志和下载的规则在本地处理。在 Android 上，订阅和设置数据库使用受 Android Keystore 保护的密钥加密。这并不意味着导出的文件也已加密。
- **发送给开发者的数据：**客户端不会自动发送配置或诊断日志。联系支持时，由你决定分享哪些数据。
- **外部服务：**导入和刷新订阅会访问订阅 URL；客户端更新、规则和更新日志图片从 GitHub 及相应来源下载。延迟检测访问所配置的测试 URL，DNS 查询发送至所选解析器。这些服务能看到相关网络请求的信息，包括出口 IP 地址。
- **“你的 IP”：**打开面板或手动刷新时，客户端向 Cloudflare 请求外部 IP 地址和国家信息。请求遵循设备当前的路由，包括 VPN 和分应用路由规则。

VPN 本身不能保证匿名性：VPN 和 DNS 提供商能看到哪些数据，取决于协议、加密方式和你的设置。

- 全局 HWID 发送默认开启，可在设置中关闭。关闭全局设置后，单个订阅保存的授权仍可能为该配置启用发送。添加订阅前，请检查全局设置、订阅设置和自定义请求头。
- 允许不受信任的代理证书会跳过证书验证。请勿将其作为连接问题的通用修复方法。
- 配置导出、备份、日志和截图可能包含订阅链接、访问密钥、密码、服务器地址或设备标识。分享前请检查并移除这些信息。

请通过 [SECURITY.md](SECURITY.md) 中的联系方式私下报告漏洞，不要在公开 issue 中发布利用细节。

<a id="development"></a>

## 开发

客户端使用仓库内已提交的 AAR，正常构建应用不会重新编译 Go 核心。CI 使用 Flutter `3.47.5` 和 JDK `21`；还需要安装 Android SDK 和 Python 3。

<details>
<summary>查看客户端准备、检查和 debug 构建步骤</summary>

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

发布构建需要在 `android/key.properties` 中配置签名。官方构建可能恢复用于 Happ 加密订阅兼容性的私有资源；如果希望在本地验证该功能，请阅读 [私有构建输入](.github/private/README.md)。

</details>

<details>
<summary>内置核心如何固定版本</summary>

子模块固定核心源码，而 Android 使用 `android/app/libs/libbox.aar` 进行编译。两者必须与源码 JAR、校验和及构建元数据一同更新。`scripts/verify_libbox.py` 检查提交是否一致以及 Android Java API 契约。

核心替换要求：[内置 AAR 文档](android/app/libs/README.md)。独立的核心构建工具链：[ETONIFY_BASELINE](etonify-core/release/ETONIFY_BASELINE)。发布自动化：[GitHub Actions 指南](docs/github-actions.md)。

</details>

提交修改前，请阅读 [CONTRIBUTING.md](CONTRIBUTING.md)。

<a id="support"></a>

## 获取帮助或支持开发

报告问题时，请提供应用版本、设备型号、Android 和厂商系统版本、复现步骤及已脱敏的日志。如果问题出现在更新之后，请注明最后一个正常工作的版本。

[创建 issue](https://github.com/yamixdev/Etonify/issues/new/choose) · [项目动态](https://t.me/etonify) · [私下支持](https://t.me/etonify?direct)

你可以通过 [Tribute](https://t.me/tribute/app?startapp=dQAQ) 或 [DonationAlerts](https://dalink.to/yamix31) 支持项目开发。

<a id="license"></a>

## 开发者与许可证

由 MeowTeam 维护：[yamixdev](https://github.com/yamixdev) 和 [dudosxdev](https://github.com/dudosxdev)。基于 [sing-box](https://github.com/SagerNet/sing-box) 及其他开源组件。

采用 [GNU GPL v3.0 或更新版本](LICENSE)。作者归属和第三方许可证见 [NOTICE.md](NOTICE.md) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
