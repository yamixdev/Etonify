<div align="center" dir="rtl">

<img src="docs/assets/etonify-mark.svg" width="88" height="88" alt="Etonify">

# Etonify

**کلاینت VPN متن‌باز برای Android.**

ساخته‌شده با Flutter و هستهٔ اصلاح‌شدهٔ sing-box.

<p dir="ltr">
<a href="README.md">English</a> · <a href="README_ru.md">Русский</a> · <a href="README_uk.md">Українська</a> · <a href="README_cn.md">简体中文</a> · <b>فارسی</b>
</p>

<p dir="ltr">
  <a href="https://github.com/yamixdev/Etonify/releases"><img src="https://img.shields.io/badge/Client-0.3.7%2B37-74452B?style=flat-square" alt="کلاینت: 0.3.7+37"></a>
  <a href="android/app/libs/libbox.provenance.json"><img src="https://img.shields.io/badge/Core-1.15.0--alpha.10--etonify.1-53473E?style=flat-square" alt="هستهٔ داخلی: 1.15.0-alpha.10-etonify.1"></a>
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B-2E5C46?style=flat-square&amp;logo=android&amp;logoColor=white" alt="Android 8.0+"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--or--later-3B4C63?style=flat-square" alt="GPL-3.0-or-later"></a>
</p>

**[دانلود APK](https://github.com/yamixdev/Etonify/releases)** · [تغییرات](CHANGELOG.md) · [گزارش مشکل](https://github.com/yamixdev/Etonify/issues/new/choose) · [Telegram](https://t.me/etonify)

[قابلیت‌ها](#features) · [شروع سریع](#quick-start) · [سازگاری](#compatibility) · [توسعه](#development)

</div>

<div dir="rtl" align="right">

Etonify مدیریت اشتراک‌ها، انتخاب پروکسی، مسیریابی و عیب‌یابی اتصال را در یک برنامهٔ Android گرد هم می‌آورد. رابط برنامه از تم روشن، تیره و رنگ‌های پویا پشتیبانی می‌کند.

> [!IMPORTANT]
> Etonify سرور VPN ارائه نمی‌کند و اشتراک نمی‌فروشد. برای اتصال به سرور شخصی یا اشتراک یک سرویس‌دهنده نیاز دارید.

<a id="features"></a>

## قابلیت‌ها

| بخش | چه کاری می‌توانید انجام دهید |
| :--- | :--- |
| اشتراک‌ها | ورود از URL، فایل، کلیپ‌بورد، کد QR یا پیوند عمیق پشتیبانی‌شده. به‌روزرسانی پروفایل‌ها و مشاهدهٔ مصرف ترافیک و تاریخ انقضا، در صورت ارائهٔ این اطلاعات توسط سرویس‌دهنده. |
| سرورها و گروه‌ها | انتخاب دستی سرور یا استفاده از گروه انتخاب خودکار. مشاهدهٔ گروه‌های تودرتو به ترتیب اشتراک، اشتراک‌گذاری سرور یا گروه و خروجی گرفتن از پروفایل در قالب JSON برای ورود از فایل. |
| آزمون تأخیر | آزمایش یک سرور، اعضای گروه یا کل اشتراک. مشاهدهٔ نتایج و شمارش سرورهای فعال، بدون اینکه سرورهای آزمایش‌نشده خراب محسوب شوند. |
| مسیریابی | انتخاب برنامه‌هایی که از VPN یا اتصال مستقیم استفاده می‌کنند. هر حالت فهرست جداگانه‌ای دارد. تنظیم قوانین ترافیک، عبور مستقیم شبکهٔ محلی و مجموعه‌قوانین محلی. |
| پایش ترافیک | مشاهدهٔ سرعت دریافت و ارسال، ترافیک نشست و مدت اتصال. تازه‌سازی IP خارجی فعلی و پرچم کشور آن. |
| DNS و تنظیمات هسته | تنظیم DNS مستقیم یا از طریق پروکسی، DNS رمزگذاری‌شده و فیلتر DNS از AdGuard. تغییر راهبرد شبکه، مهلت اتصال، TCP Keep Alive و پارامترهای UDP/NAT. |
| اتصال و عیب‌یابی | استفاده از Android VPN با TUN، پروکسی محلی HTTP/SOCKS یا هر دو حالت. مشاهدهٔ گزارش‌ها، سازگاری هسته، وضعیت پیکربندی اعمال‌شده و منابع پردازش. |

آزمون تأخیر درخواست را از طریق پروکسی می‌فرستد و ICMP ping نیست. نبود نتیجه به معنی شکست اندازه‌گیری‌شده نیست. نتایج گروه و شمارنده‌ها به آزمون‌های تکمیل‌شدهٔ اعضای آن بستگی دارند.

<details>
<summary>مشاهدهٔ رابط برنامه</summary>

ظاهر برنامه ممکن است با نسخه و تم انتخاب‌شده تفاوت داشته باشد.

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" alt="مشاهدهٔ رابط برنامه" width="720">

</details>

<a id="quick-start"></a>

## اتصال در چهار گام

1. APK مناسب دستگاه را از [Releases](https://github.com/yamixdev/Etonify/releases) نصب کنید.
2. اشتراک خود را اضافه یا پیکربندی سرور را وارد کنید.
3. یک سرور یا گروه انتخاب خودکار را انتخاب کنید.
4. اتصال را روشن کنید و درخواست مجوز VPN در Android را بپذیرید.

در بخش **دربارهٔ برنامه ← به‌روزرسانی‌ها**، از منو **Stable** یا **Beta** را انتخاب کنید. Beta شامل نسخه‌های پیش‌انتشار برای آزمایش است؛ شمارهٔ نسخه در برنامه ممکن است پسوند «beta» نداشته باشد.

اگر پس از به‌روزرسانی پیام بازنشانی مسیریابی تفکیک‌شده را دیدید، پیش از فعال کردن آن به این بخش بروید و برنامه‌ها را دوباره انتخاب کنید.

<a id="versions"></a>

## نسخه‌ها و پیش‌نیازها

| بخش | کد فعلی مخزن |
| :--- | :--- |
| کلاینت | <code dir="ltr">0.3.7+37</code> |
| هستهٔ داخلی | <code dir="ltr">v1.15.0-alpha.10-etonify.1</code> |
| نسخهٔ پایهٔ sing-box | <code dir="ltr">v1.15.0-alpha.10</code> |
| Flutter SDK | <code dir="ltr">3.47.5</code> · Dart <code dir="ltr">3.13</code> |
| Android | نسخهٔ ۸٫۰ و بالاتر · API 26+ |
| معماری APK | <code dir="ltr">arm64-v8a</code> · <code dir="ltr">armeabi-v7a</code> |
| زبان‌های رابط برنامه | انگلیسی و روسی |

> [!NOTE]
> این‌ها نسخه‌های موجود در کد مخزن هستند، نه تضمین انتشار APK. نسخه‌های منتشرشده را در [Releases](https://github.com/yamixdev/Etonify/releases) بررسی کنید. هسته بر پایهٔ نسخهٔ پیش‌انتشار sing-box است.

نسخهٔ کلاینت: [pubspec.yaml](pubspec.yaml). نسخهٔ هستهٔ باینری و کامیت کد آن: [libbox.provenance.json](android/app/libs/libbox.provenance.json). پلتفرم انتشار پشتیبانی‌شده Android است؛ پوشه‌های دیگر پلتفرم‌های Flutter به معنی وجود ساخت پشتیبانی‌شده نیستند.

<a id="compatibility"></a>

## سازگاری پیکربندی

**قالب‌های ورودی**

<code dir="ltr">sing-box JSON</code> · <code dir="ltr">Xray JSON</code> · <code dir="ltr">Clash YAML</code> · <code dir="ltr">SIP008</code> · لینک سرور

**پروتکل‌ها**

<code dir="ltr">VLESS</code> · <code dir="ltr">VMess</code> · <code dir="ltr">Trojan</code> · <code dir="ltr">Shadowsocks</code> · <code dir="ltr">Hysteria / Hysteria2</code> · <code dir="ltr">TUIC</code> · <code dir="ltr">AnyTLS</code> · <code dir="ltr">NaiveProxy</code> · <code dir="ltr">HTTP</code> · <code dir="ltr">SOCKS</code>

Etonify تنظیمات پشتیبانی‌شدهٔ Xray و Clash را به پیکربندی sing-box خود تبدیل می‌کند. وارد کردن پروفایل همهٔ قابلیت‌های هستهٔ اصلی آن را فعال نمی‌کند. سازگاری به پروتکل، روش انتقال و فیلدهای استفاده‌شده بستگی دارد.

- WireGuard در ساخت Android گنجانده نشده است.
- چندگانه‌سازی اتصال به پشتیبانی سرور نیاز دارد. sing-box multiplex و Xray Mux قابل جایگزینی نیستند.
- عضویت در گروه‌های تودرتو از ارجاع‌های پیکربندی تعیین می‌شود، نه نام‌هایی مانند `cand-*`. خروجی گروه اعضای ارجاع‌شده و وابستگی‌های مرتبط را حفظ می‌کند.

توضیحات بیشتر: [انتخاب پروکسی و گروه‌های تودرتو](docs/proxy-selection-contract.md)، [تنظیمات هسته و چندگانه‌سازی](docs/core-settings.md) و [تغییرات پیشین قالب sing-box](docs/schema-1.14-compatibility.md).

<a id="privacy"></a>

## حریم خصوصی و اشتراک‌گذاری امن

Etonify به سرورهای VPN انتخابی شما وصل می‌شود. ترافیک شما از سرورهای MeowTeam عبور نمی‌کند. کلاینت SDK تبلیغات یا تحلیل رفتار ندارد.

- **روی دستگاه:** اشتراک‌ها، پروفایل‌ها، سرورهای انتخاب‌شده، تنظیمات، گزارش‌های تشخیصی و قواعد دانلودشده به‌صورت محلی پردازش می‌شوند. در Android، پایگاه‌های دادهٔ اشتراک‌ها و تنظیمات با کلیدی محافظت‌شده توسط Android Keystore رمزگذاری می‌شوند. این به معنای رمزگذاری فایل‌های خروجی نیست.
- **برای توسعه‌دهندگان:** کلاینت پروفایل‌ها یا گزارش‌های تشخیصی را خودکار ارسال نمی‌کند. هنگام تماس با پشتیبانی، خودتان انتخاب می‌کنید چه داده‌هایی را به اشتراک بگذارید.
- **سرویس‌های خارجی:** افزودن و تازه‌سازی اشتراک به URL آن مراجعه می‌کند؛ به‌روزرسانی کلاینت، قواعد و تصاویر فهرست تغییرات از GitHub و منابع مربوط دانلود می‌شوند. بررسی تأخیر به URL آزمایش تنظیم‌شده و درخواست‌های DNS به حل‌کنندهٔ انتخاب‌شده فرستاده می‌شوند. این سرویس‌ها اطلاعات درخواست‌های شبکهٔ خود، از جمله IP خروجی را می‌بینند.
- **«IP شما»:** با باز کردن پنل یا تازه‌سازی دستی، کلاینت برای یافتن نشانی خارجی و کشور به Cloudflare مراجعه می‌کند. درخواست از مسیرهای فعلی دستگاه، با در نظر گرفتن VPN و قواعد مسیریابی تفکیک‌شده، عبور می‌کند.

VPN به‌تنهایی ناشناس‌بودن را تضمین نمی‌کند؛ داده‌های قابل مشاهده برای ارائه‌دهندگان VPN و DNS به پروتکل، رمزگذاری و تنظیمات شما بستگی دارد.

- ارسال سراسری HWID به‌صورت پیش‌فرض روشن است و می‌توان آن را در تنظیمات خاموش کرد. پس از خاموش کردن تنظیم سراسری، رضایت ذخیره‌شده برای یک اشتراک همچنان می‌تواند ارسال را برای آن پروفایل فعال کند. پیش از افزودن اشتراک، تنظیمات عمومی، تنظیمات پروفایل و سرآیندهای سفارشی را بررسی کنید.
- اجازه دادن به گواهی نامعتبر پروکسی، بررسی گواهی را غیرفعال می‌کند. آن را راه‌حل عمومی مشکلات اتصال در نظر نگیرید.
- خروجی پروفایل، نسخهٔ پشتیبان، گزارش‌ها و تصاویر صفحه ممکن است شامل لینک اشتراک، کلید دسترسی، رمز، آدرس سرور یا شناسهٔ دستگاه باشند. پیش از اشتراک‌گذاری، این اطلاعات را بررسی و حذف کنید.

آسیب‌پذیری‌ها را خصوصی و از طریق اطلاعات تماس در [SECURITY.md](SECURITY.md) گزارش کنید. جزئیات سوءاستفاده را در issue عمومی منتشر نکنید.

<a id="development"></a>

## توسعه

کلاینت از AAR ثبت‌شده در مخزن استفاده می‌کند؛ ساخت معمول برنامه هستهٔ Go را دوباره نمی‌سازد. CI از Flutter `3.47.5` و JDK `21` استفاده می‌کند؛ Android SDK و Python 3 نیز لازم هستند.

<details>
<summary>نمایش آماده‌سازی کلاینت، بررسی‌ها و ساخت debug</summary>

<div dir="ltr" align="left">

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

</div>

برای ساخت انتشار، امضا را در `android/key.properties` تنظیم کنید. ساخت‌های رسمی ممکن است منابع خصوصی سازگاری با اشتراک‌های رمزگذاری‌شدهٔ Happ را بازیابی کنند؛ برای آزمایش محلی این قابلیت، [ورودی‌های خصوصی ساخت](.github/private/README.md) را بخوانید.

</details>

<details>
<summary>نسخهٔ هستهٔ داخلی چگونه ثابت می‌شود</summary>

ساب‌ماژول کد هسته را به یک کامیت مشخص متصل می‌کند. Android با `android/app/libs/libbox.aar` کامپایل می‌شود. هر دو باید همراه با JAR کد، چک‌سام و اطلاعات ساخت به‌روزرسانی شوند. `scripts/verify_libbox.py` تطابق کامیت‌ها و قرارداد Android Java API را بررسی می‌کند.

الزامات جایگزینی هسته: [مستندات AAR داخلی](android/app/libs/README.md). ابزارهای جداگانهٔ ساخت هسته: [ETONIFY_BASELINE](etonify-core/release/ETONIFY_BASELINE). خودکارسازی انتشار: [راهنمای GitHub Actions](docs/github-actions.md).

</details>

پیش از ارسال تغییرات، [CONTRIBUTING.md](CONTRIBUTING.md) را بخوانید.

<a id="support"></a>

## دریافت کمک یا حمایت از توسعه

برای گزارش مشکل، نسخهٔ برنامه، مدل دستگاه، نسخهٔ Android و رابط سازنده، مراحل تکرار و گزارش‌های بدون اطلاعات محرمانه را ارائه کنید. اگر مشکل پس از به‌روزرسانی شروع شده، آخرین نسخهٔ سالم را مشخص کنید.

[ایجاد issue](https://github.com/yamixdev/Etonify/issues/new/choose) · [اخبار پروژه](https://t.me/etonify) · [پشتیبانی خصوصی](https://t.me/etonify?direct)

می‌توانید از طریق [Tribute](https://t.me/tribute/app?startapp=dQAQ) یا [DonationAlerts](https://dalink.to/yamix31) از توسعهٔ پروژه حمایت کنید.

<a id="license"></a>

## توسعه‌دهندگان و مجوزها

نگهداری توسط MeowTeam: [yamixdev](https://github.com/yamixdev) و [dudosxdev](https://github.com/dudosxdev). بر پایهٔ [sing-box](https://github.com/SagerNet/sing-box) و دیگر اجزای متن‌باز.

مجوز: [GNU GPL v3.0 یا جدیدتر](LICENSE). اطلاعات پدیدآورندگان و مجوزهای شخص ثالث در [NOTICE.md](NOTICE.md) و [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) آمده است.

</div>
