import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/theme/app_theme.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';

@Preview(name: 'Expressive loading · dark', size: Size(360, 480))
Widget loadingDarkPreview() => const LoadingPreviewGallery();

@Preview(name: 'Expressive loading · light', size: Size(360, 480))
Widget loadingLightPreview() =>
    const LoadingPreviewGallery(brightness: Brightness.light);

@Preview(name: 'Expressive loading · AMOLED', size: Size(360, 480))
Widget loadingAmoledPreview() => const LoadingPreviewGallery(amoled: true);

class LoadingPreviewGallery extends StatelessWidget {
  const LoadingPreviewGallery({
    super.key,
    this.brightness = Brightness.dark,
    this.amoled = false,
    this.reducedMotion = false,
  });

  final Brightness brightness;
  final bool amoled;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: amoled
          ? buildAmoledTheme(seedColor: const Color(0xff8b4c14))
          : buildAppTheme(brightness, seedColor: const Color(0xff8b4c14)),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: const [
            Text('Загрузка', style: TextStyle(fontSize: 24)),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                AppLoadingIndicator(),
                AppLoadingIndicator(size: 48, contained: true),
                AppLoadingIndicator.compact(),
              ],
            ),
            SizedBox(height: 32),
            Text('Подготавливаем подписку…'),
            SizedBox(height: 12),
            AppLinearProgressIndicator(),
            SizedBox(height: 32),
            Text('Скачиваем ресурсы · 25%'),
            SizedBox(height: 12),
            AppLinearProgressIndicator(value: .25),
            SizedBox(height: 32),
            Text('Скачиваем обновление · 70%'),
            SizedBox(height: 12),
            AppLinearProgressIndicator(value: .7),
            SizedBox(height: 32),
            Text('Готово'),
            SizedBox(height: 12),
            AppLinearProgressIndicator(value: 1),
          ],
        ),
      ),
    );
  }
}
