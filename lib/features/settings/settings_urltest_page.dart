import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsUrlTestPage extends StatefulWidget {
  const SettingsUrlTestPage({
    super.key,
    required this.currentConfig,
    required this.onChanged,
  });

  final UrlTestConfig currentConfig;
  final ValueChanged<UrlTestConfig> onChanged;

  @override
  State<SettingsUrlTestPage> createState() => _SettingsUrlTestPageState();
}

class _SettingsUrlTestPageState extends State<SettingsUrlTestPage> {
  late final TextEditingController _urlController;
  late final TextEditingController _intervalController;
  late final TextEditingController _timeoutController;
  late final TextEditingController _concurrencyController;
  late final TextEditingController _unavailableCheckIntervalController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.currentConfig.url ?? '',
    );
    _intervalController = TextEditingController(
      text: widget.currentConfig.intervalSeconds?.toString() ?? '',
    );
    _timeoutController = TextEditingController(
      text: widget.currentConfig.timeoutSeconds?.toString() ?? '',
    );
    _concurrencyController = TextEditingController(
      text: widget.currentConfig.concurrency?.toString() ?? '',
    );
    _unavailableCheckIntervalController = TextEditingController(
      text:
          widget.currentConfig.unavailableCheckIntervalSeconds?.toString() ??
          '',
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _intervalController.dispose();
    _timeoutController.dispose();
    _concurrencyController.dispose();
    _unavailableCheckIntervalController.dispose();
    super.dispose();
  }

  void _commit() {
    final url = _urlController.text.trim();
    final interval = int.tryParse(_intervalController.text.trim());
    final timeout = int.tryParse(_timeoutController.text.trim());
    final concurrency = int.tryParse(_concurrencyController.text.trim());
    final unavailableCheckInterval = int.tryParse(
      _unavailableCheckIntervalController.text.trim(),
    );
    widget.onChanged(
      UrlTestConfig(
        url: url.isEmpty ? null : url,
        intervalSeconds: interval,
        timeoutSeconds: timeout,
        concurrency: concurrency?.clamp(1, 10),
        unavailableCheckIntervalSeconds: unavailableCheckInterval?.clamp(
          120,
          3600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.urlTestTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          progressiveHeaderTopPadding(context, 12),
          16,
          appBottomSafePadding(context, 24),
        ),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _urlController,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    onSubmitted: (_) => _commit(),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'[\r\n]')),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.urlTestUrlTitle,
                      helperText: l10n.urlTestUrlSubtitle,
                      hintText: defaultUrlTestUrl,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _intervalController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    onSubmitted: (_) => _commit(),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.urlTestIntervalTitle,
                      helperText: l10n.urlTestIntervalSubtitle,
                      hintText: '180',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _unavailableCheckIntervalController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    onSubmitted: (_) => _commit(),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.urlTestSingleRetestTitle,
                      helperText: l10n.urlTestSingleRetestSubtitle,
                      hintText: '2',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _timeoutController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    onSubmitted: (_) => _commit(),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.urlTestTimeoutTitle,
                      helperText: l10n.urlTestTimeoutSubtitle,
                      hintText: '15',
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _concurrencyController,
                    keyboardType: TextInputType.number,
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    onSubmitted: (_) => _commit(),
                    onEditingComplete: () {
                      FocusScope.of(context).unfocus();
                      _commit();
                    },
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.urlTestConcurrencyTitle,
                      helperText: l10n.urlTestConcurrencySubtitle,
                      hintText: '10',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
