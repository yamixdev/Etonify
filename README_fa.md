# Etonify

<div dir="rtl" align="center">

[English](README.md) / [Русский](README_ru.md) / [Українська](README_uk.md) / [简体中文](README_cn.md) / [فارسی](README_fa.md)

<img width="1672" height="941" alt="صفحهٔ اصلی Etonify" src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" />

[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android)](https://github.com/yamixdev/Etonify/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.0-02569B?style=flat-square&logo=flutter)](https://flutter.dev/)
[![Core](https://img.shields.io/badge/etonify--core-1.14.0--rc.1-blue?style=flat-square)](https://github.com/yamixdev/etonify-core/tree/etonify-dev)
[![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue?style=flat-square)](LICENSE)
[![Telegram](https://img.shields.io/badge/Telegram-@etonify-26A5E4?style=flat-square&logo=telegram)](https://t.me/etonify)

**کلاینت VPN متن‌باز برای Android، مبتنی بر نسخه‌ای نگهداری‌شده از sing-box.**

[دانلود](https://github.com/yamixdev/Etonify/releases) · [تاریخچهٔ تغییرات](CHANGELOG.md) · [گزارش مشکل](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

</div>

Etonify برای افرادی ساخته شده است که از قبل اشتراک VPN، لینک سرور یا فایل پیکربندی دارند و به مسیریابی دقیق، عیب‌یابی و کنترل اتصال در Android نیاز دارند. کلاینت و بخش‌های Android آن همراه با [**yamixdev/etonify-core**](https://github.com/yamixdev/etonify-core/tree/etonify-dev) توسعه داده می‌شوند؛ هسته‌ای بر پایهٔ نسخهٔ پایدار sing-box با تغییراتی که مخصوص Etonify نگهداری می‌شوند.

> [!IMPORTANT]
> Etonify سرور VPN نمی‌فروشد و ارائه نمی‌کند. فقط از اشتراک‌ها و پیکربندی‌هایی استفاده کنید که مالک آن‌ها هستید یا اجازهٔ استفاده از آن‌ها را دارید.

## وضعیت فعلی

| بخش | مقدار فعلی |
| --- | --- |
| نسخهٔ کد کلاینت | `0.3.1+21` |
| نسخهٔ Android | Android 8.0 و جدیدتر (API 26+) |
| هستهٔ داخلی | `v1.14.0-etonify.1` بر پایهٔ نسخهٔ پایدار sing-box 1.14.0 |
| زبان‌های رابط برنامه | انگلیسی و روسی |
| پلتفرم انتشار | فقط Android |

نسخهٔ `0.3.0` نسخهٔ پایدار فعلی است. پوشه‌های سایر پلتفرم‌های Flutter برای ابزارها و توسعهٔ آینده در مخزن باقی مانده‌اند، اما نسخه‌های Windows، Linux، macOS و iOS در حال حاضر پشتیبانی نمی‌شوند.

## نمای کلی پشتیبانی

| قابلیت | پشتیبانی |
| --- | --- |
| VPN سیستمی از طریق Android TUN | بله |
| پروکسی محلی HTTP و SOCKS | بله |
| اجرای هم‌زمان VPN TUN و پروکسی محلی | بله |
| اشتراک از URL، فایل، clipboard، QR و deep link | بله |
| مسیریابی جداگانه برای برنامه‌ها | بله |
| preset قوانین ترافیک و rule-set محلی | بله |
| فیلتر DNS از AdGuard | بله |
| بررسی به‌روزرسانی و نصب APK در برنامه | بله |
| سرور رایگان داخلی | خیر |
| نسخهٔ قابل انتشار برای Windows، iOS و سایر پلتفرم‌ها | خیر |

## پیکربندی‌های پشتیبانی‌شده

Etonify لینک سرورها، sing-box JSON، Xray JSON، Clash YAML، SIP008 و فایل پیکربندی WireGuard را وارد می‌کند. parserهای داخلی این موارد را می‌شناسند:

- VLESS، VMess و Trojan؛
- Shadowsocks و ShadowsocksR؛
- Hysteria و Hysteria2؛
- TUIC، WireGuard، AnyTLS و NaiveProxy؛
- پروکسی‌های بالادستی HTTP و SOCKS.

سازگاری دقیق به فیلدها، transportها و extensionهای استفاده‌شده توسط ارائه‌دهنده بستگی دارد. outbound ناشناخته یا نامعتبر در گزارش خطا نمایش داده می‌شود و برنامه یک profile ناقص را بی‌صدا اجرا نمی‌کند.

## قابلیت‌های اصلی

### اتصال و یکپارچگی با Android

- Android VPN TUN با گزینه‌های stack شامل `gVisor`، `system` و `mixed`.
- mixed proxy محلی با احراز هویت برای کلاینت‌های HTTP و SOCKS و امکان دسترسی اختیاری از LAN.
- VPN TUN و پروکسی محلی را می‌توان جداگانه یا هم‌زمان فعال کرد.
- foreground service برای حفظ tunnel هنگام بسته بودن رابط یا ایجاد دوبارهٔ پردازش Flutter توسط Android.
- مدیریت متمرکز تغییر Wi‑Fi، اینترنت موبایل، sleep، resume و default network.
- اعلان وضعیت شامل سرور انتخاب‌شده، latency، سرعت فعلی یا مجموع ترافیک، همراه با کنترل تازه‌سازی latency و توقف VPN.

### اشتراک‌ها و profileها

- import از HTTPS URL، QR code، فایل، clipboard، منوی Share اندروید و deep linkهای پشتیبانی‌شده.
- پشتیبانی از فرمت‌های sing-box، Xray، Clash، SIP008، WireGuard و لینک‌های رایج تک‌سرور.
- پشتیبانی از لینک‌های `etonify://`، `happ://add`، `happ://crypt*` و `sing-box://import-remote-profile`.
- رمزگشایی محلی variantهای پشتیبانی‌شدهٔ Happ از `crypt` تا `crypt5`؛ اگر ارائه‌دهنده HWID بخواهد، ابتدا رضایت صریح گرفته می‌شود.
- دادهٔ سازگاری Happ `crypt5` در buildهای رسمی وجود دارد، اما به‌صورت plaintext در source tree عمومی نگهداری نمی‌شود.
- به‌روزرسانی امن: پاسخ خالی، خراب، HTML یا خطای شبکه آخرین profile سالم را جایگزین نمی‌کند.
- backup و restore مرز profileها، نام‌ها، سرورها، outbound انتخاب‌شده، زمان‌بندی به‌روزرسانی و URL منبع را حفظ می‌کند.
- پاسخ‌های بزرگ خارج از UI isolate پردازش می‌شوند و داده‌های حجیم جدا از metadata فشردهٔ profile ذخیره می‌شوند.

اشتراک راه‌دور باید از HTTPS استفاده کند. HTTP معمولی فقط برای آدرس‌های loopback صریح `localhost`، `127.0.0.1` و `::1` مجاز است.

### سرورها و عیب‌یابی

- URLTest هدفمند برای سرور انتخاب‌شده و بررسی گروهی asynchronous برای تمام profile.
- نتیجهٔ هر سرور به محض دریافت نمایش داده می‌شود و session قدیمی نمی‌تواند نتیجهٔ جدید را بازنویسی کند.
- گزینهٔ `lowest` انتخاب واقعی URLTest هسته را نشان می‌دهد و latency یا پرچم جعلی نمایش نمی‌دهد.
- مرتب‌سازی بر اساس ترتیب منبع، دسترس‌پذیری، latency، نام یا کشور.
- سرور ناموفق با وضعیت هشدار روشن نمایش داده می‌شود؛ جزئیات DNS، TLS، EOF و timeout در diagnostics باقی می‌ماند.
- تشخیص IP خروجی، ترافیک اتصال، سرعت زنده، مجموع session و نمودار سبک ترافیک.
- امکان export لاگ‌های runtime، شبکه، حافظه و ساخت پیکربندی.

URLTest یک درخواست HTTP از داخل پروکسی است، نه ICMP ping. نتیجه شامل برقراری اتصال پروکسی، TLS و زمان پاسخ سرور آزمایشی است.

### مسیریابی و DNS

- split tunneling برای برنامه‌ها در حالت‌های «از VPN» و «دور زدن VPN».
- در هر لحظه فقط یک preset قانون ترافیک فعال است: سرویس‌های روسی مستقیم، سرویس‌های AI از VPN یا شبکه‌های اجتماعی از VPN.
- فایل‌های geo-resource محلی `.srs` با نسخه‌بندی، جایگزینی تأییدشده و استفادهٔ آفلاین پس از دانلود.
- فیلتر DNS از AdGuard که روی دستگاه ساخته می‌شود.
- دور زدن شبکهٔ محلی، strict routing و گزینه‌های جلوگیری از leak.
- DNS دستگاه و resolverهای سفارشی UDP، TCP، DoT و DoH با bootstrap امن.
- FakeIP، TCP Fast Open، TCP MultiPath، TLS fragmentation و سایر تنظیمات آزمایشی که به‌روشنی علامت‌گذاری شده‌اند.
- proxy chain برای اتصال یک outbound انتخاب‌شده از طریق outbound دیگر در همان profile.

قوانین ترافیک و split tunneling در دو لایهٔ متفاوت عمل می‌کنند. اگر هر دو با یک ترافیک تطبیق داشته باشند، ابتدا سیاست برنامه‌های انتخاب‌شدهٔ Android و سپس قوانین فعال sing-box اعمال می‌شوند.

### به‌روزرسانی و امنیت

- updater مبتنی بر GitHub Releases، APK متناسب با ABI دستگاه را انتخاب می‌کند و پیشرفت دانلود را نشان می‌دهد.
- قبل از نصب، نام package، حداقل نسخهٔ Android، گواهی امضا، اندازهٔ فایل و SHA-256 موجود در manifest انتشار بررسی می‌شود.
- تنظیمات، اشتراک‌ها، credentialها و کلیدها با AES-GCM رمزگذاری می‌شوند؛ wrapping key در Android Keystore نگهداری می‌شود.
- اطلاعات حساس شناخته‌شده در لاگ Flutter، diagnostics اندروید و گزارش‌های exportشده پنهان می‌شوند.
- گزینهٔ پذیرش گواهی نامعتبر برای اتصال پروکسی و دانلود اشتراک جداست؛ هر دو به‌طور پیش‌فرض خاموش‌اند و هشدار امنیتی روشن دارند.
- redirect به origin دیگر headerهای حساس را حذف می‌کند و downgrade از HTTPS به HTTP مسدود است.

## محدودیت‌ها و انتظارها

- Etonify کلاینت است، نه ارائه‌دهندهٔ VPN.
- Android تنها پلتفرم انتشار پشتیبانی‌شده است.
- بعضی extensionهای اختصاصی ارائه‌دهندگان ممکن است به نسخهٔ جدیدتر هسته یا parser نیاز داشته باشند.
- اشتراک‌های بسیار بزرگ و بررسی کامل سرورها می‌توانند موقتاً مصرف CPU، حافظه، شبکه و باتری را افزایش دهند.
- تنظیمات آزمایشی شبکه ممکن است سازگاری را کاهش دهند. اگر دلیل تغییر را نمی‌دانید، مقدار پیش‌فرض را حفظ کنید.
- برنامه‌ها و دستگاه‌های LAN باید به‌صورت دستی با آدرس، port و credential نمایش‌داده‌شده در Etonify تنظیم شوند.

## نصب

APK را از [GitHub Releases](https://github.com/yamixdev/Etonify/releases) دریافت کنید. بهتر است split APK متناسب با ABI دستگاه را انتخاب کنید؛ بیشتر گوشی‌های جدید Android از `arm64-v8a` استفاده می‌کنند. Android ممکن است برای نصب از مرورگر یا file manager مجوز بخواهد.

تنظیمات موجود تا حد امکان migrate می‌شوند. پیش از یک به‌روزرسانی بزرگ یا تغییر گزینه‌های پیشرفتهٔ DNS و routing، یک backup رمزگذاری‌شده تهیه کنید.

## توسعه

پیکربندی فعلی CI از این موارد استفاده می‌کند:

- Flutter 3.47.0 و Dart 3.11.4 یا جدیدتر؛
- Android SDK 36؛
- JDK 21 برای build کلاینت؛
- Gradle 9.1 و Android Gradle Plugin 9.0.1.

مخزن را همراه submodule هسته clone کنید و سپس اجرا کنید:

```powershell
git clone --recurse-submodules https://github.com/yamixdev/Etonify.git
cd Etonify
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

بررسی‌های Android در Windows:

```powershell
cd android
.\gradlew.bat :app:testDebugUnitTest :app:lintDebug
```

برای build عمومی release، یک release keystore واقعی در `android/key.properties` تنظیم کنید. APK نسخهٔ release با debug signature فقط برای آزمایش محلی است.

## هسته و build قابل بازتولید

فایل داخلی `android/app/libs/libbox.aar` از commit دقیق submodule `etonify-core` ساخته می‌شود. نسخه، commit بالادستی sing-box، toolchain، build tags و SHA-256 در [`libbox.provenance.json`](android/app/libs/libbox.provenance.json) ثبت و همراه با [`libbox.sha256`](android/app/libs/libbox.sha256) بررسی می‌شوند.

workflow مخزن می‌تواند چهار artifact هسته را دوباره از source ثابت‌شده بسازد:

- `libbox.aar`؛
- `libbox-sources.jar`؛
- `libbox.provenance.json`؛
- `libbox.sha256`.

## جامعه و مشارکت

- کانال Telegram: [@etonify](https://t.me/etonify)
- ارتباط مستقیم: [Etonify Direct](https://t.me/etonify?direct)
- گزارش خطا و پیشنهاد قابلیت: [فرم‌های GitHub Issues](https://github.com/yamixdev/Etonify/issues/new/choose)
- راهنمای مشارکت: [CONTRIBUTING.md](CONTRIBUTING.md)
- گزارش امنیتی: [SECURITY.md](SECURITY.md)

MeowTeam پروژه را نگهداری می‌کند: [yamixdev](https://github.com/yamixdev) روی کلاینت Android، انتشارها و etonify-core کار می‌کند و [dudosxdev](https://github.com/dudosxdev) در شبکه و پروتکل‌ها همکاری دارد.

## مجوز

Etonify با [GNU General Public License v3.0 یا جدیدتر](LICENSE) منتشر می‌شود. اطلاعات componentهای داخلی، اقتباس‌شده و شخص ثالث در [NOTICE.md](NOTICE.md) و [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) آمده است.
