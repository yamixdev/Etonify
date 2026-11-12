<div align="center">

# Etonify

<img src="https://github.com/user-attachments/assets/c5a9780c-6b26-45e1-9458-42c23e204dde" width="640" alt="Etonify by MeowTeam">

**VPN-клиент для Android с открытым кодом на базе sing-box.**

<p dir="ltr">
  <a href="https://developer.android.com"><img src="https://img.shields.io/badge/Android-8.0%2B-14684D?style=flat&amp;logo=android&amp;logoColor=white" alt="Android 8.0+"></a>
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.50.0-145D86?style=flat&amp;logo=flutter&amp;logoColor=white" alt="Flutter 3.50.0"></a>
</p>

**[Скачать APK](https://github.com/yamixdev/Etonify/releases/latest)** · [Что нового](CHANGELOG.md) · [Telegram](https://t.me/etonify)

<p dir="ltr">
<a href="README.md">English</a> · <b>Русский</b> · <a href="README_uk.md">Українська</a> · <a href="README_cn.md">简体中文</a> · <a href="README_fa.md">فارسی</a>
</p>

</div>

<a id="quick-start"></a>

## Как подключиться

1. Установите [последний APK](https://github.com/yamixdev/Etonify/releases/latest). Если сомневаетесь, какой файл выбрать, скачайте универсальный APK.
2. Добавьте подписку или импортируйте конфигурацию сервера.
3. Выберите сервер или группу автовыбора. Включите VPN и подтвердите запрос Android.

Для подключения нужен свой сервер или подписка VPN-провайдера.

<a id="features"></a>

## Возможности

- Импорт подписок по ссылке, из файла, буфера обмена и по QR-коду.
- Проверка задержки, автовыбор сервера, цепочки прокси и исключения по стране, протоколу, защите или транспорту.
- Раздельная маршрутизация для приложений, настройки DNS и правил трафика, локальный HTTP/SOCKS-прокси.
- Скорость, расход трафика, внешний IP и логи подключения.

<a id="compatibility"></a>

## Совместимость

**Форматы импорта** · sing-box JSON, Xray JSON, Clash YAML, SIP008 и ссылки на серверы.

**Протоколы** · VLESS, VMess, Trojan, Shadowsocks, Hysteria, Hysteria2, TUIC, AnyTLS, NaiveProxy, HTTP и SOCKS. Совместимость Xray и Clash зависит от полей профиля.

**Android** · 8.0 и новее. Доступны APK для `arm64-v8a` и `armeabi-v7a`, а также универсальный APK.

Подробнее в документации по [выбору прокси и вложенным группам](docs/proxy-selection-contract.md) и [настройкам ядра](docs/core-settings.md).

<a id="privacy"></a>

<details>
<summary>Конфиденциальность и безопасная отправка данных</summary>

VPN-трафик идёт через выбранный вами сервер. В приложении нет рекламных и аналитических SDK.

Профили, настройки и логи остаются на устройстве, пока вы сами их не экспортируете или не отправите. Базы подписок и настроек зашифрованы с помощью ключа в Android Keystore. Перед отправкой логов и экспортированных файлов скройте ссылки подписок, данные доступа и идентификаторы устройства.

Клиент обращается к провайдеру подписки, DNS-серверу, заданному URL проверки задержки и источникам обновлений и правил. Панель внешнего IP использует Cloudflare. Отправка HWID включена по умолчанию и управляется в [настройках приложения и подписки](docs/subscription-hwid.md).

Об уязвимостях сообщайте приватно через контакты в [SECURITY.md](SECURITY.md).

</details>

<a id="versions"></a>
<a id="development"></a>

## Разработка

В исходниках клиент [`0.3.13+45`](pubspec.yaml) и libbox [`v1.15.0-alpha.10-etonify.7`](android/app/libs/libbox.provenance.json). CI использует Flutter `3.50.0` и JDK `21`. Для локальной сборки также нужны Android SDK и Python 3.

<details>
<summary>Подготовка и проверки клиента</summary>

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

Для сборки Android используется [готовый libbox AAR](android/app/libs/README.md). Настройки релизных сборок описаны в [процессе выпуска Android](.github/workflows/android-release.yml) и [документации закрытых ресурсов](.github/private/README.md).

</details>

Перед отправкой правок прочитайте [CONTRIBUTING.md](CONTRIBUTING.md).

<a id="support"></a>

## Поддержка

[Сообщить об ошибке](https://github.com/yamixdev/Etonify/issues/new/choose) · [Поддержка в Telegram](https://t.me/etonify?direct) · [Tribute](https://t.me/tribute/app?startapp=dQAQ) · [DonationAlerts](https://dalink.to/yamix31)

<a id="license"></a>

## Лицензия

[GPL-3.0-or-later](LICENSE). Проект MeowTeam развивают [yamixdev](https://github.com/yamixdev) и [dudosxdev](https://github.com/dudosxdev). В основе [sing-box](https://github.com/SagerNet/sing-box). См. [сведения об авторах](NOTICE.md) и [лицензии сторонних компонентов](THIRD_PARTY_NOTICES.md).
