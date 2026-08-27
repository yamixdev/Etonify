part of 'subscriptions_page.dart';

class _AddSubscriptionSheet extends StatefulWidget {
  const _AddSubscriptionSheet({
    required this.onAdd,
    required this.scrollController,
    required this.onClose,
    required this.onModeChanged,
    required this.onHeaderDragStart,
    required this.onHeaderDragUpdate,
    required this.onHeaderDragEnd,
  });

  final Future<bool> Function(_AddResult result) onAdd;
  final ScrollController scrollController;
  final ValueChanged<bool> onClose;
  final ValueChanged<_AddSubscriptionSheetMode> onModeChanged;
  final ValueChanged<DragStartDetails> onHeaderDragStart;
  final ValueChanged<DragUpdateDetails> onHeaderDragUpdate;
  final ValueChanged<DragEndDetails> onHeaderDragEnd;

  @override
  State<_AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

enum _AddSubscriptionSheetMode { quick, manual }

class _AddSubscriptionSheetState extends State<_AddSubscriptionSheet> {
  final _urlController = TextEditingController();
  final _nameController = TextEditingController();
  final _customUserAgentController = TextEditingController();
  final _customHwidController = TextEditingController();
  _AddSubscriptionSheetMode _mode = _AddSubscriptionSheetMode.quick;
  bool _busy = false;
  bool _useCustomUserAgent = false;
  bool _sendHwid = false;
  bool _useCustomHwid = false;
  int _autoRefreshMinutes = 360;
  String? _stage;
  bool _cancelRequested = false;

  @override
  void dispose() {
    _urlController.dispose();
    _nameController.dispose();
    _customUserAgentController.dispose();
    _customHwidController.dispose();
    super.dispose();
  }

  SubscriptionInfo? _manualRequestInfo() {
    final customUserAgent = _useCustomUserAgent
        ? _customUserAgentController.text.trim()
        : '';
    final customHwid = _sendHwid && _useCustomHwid
        ? _customHwidController.text.trim()
        : '';
    if (customUserAgent.isEmpty && !_sendHwid && customHwid.isEmpty) {
      return null;
    }
    return SubscriptionInfo(
      customUserAgent: customUserAgent.isEmpty ? null : customUserAgent,
      requireHwid: _sendHwid,
      customHwid: customHwid.isEmpty ? null : customHwid,
    );
  }

  void _setError(String message) {
    setState(() {
      _busy = false;
      _stage = null;
    });
    AppNotice.show(context, message, tone: AppNoticeTone.error);
  }

  Future<void> _submitResult(
    _AddResult result, {
    bool keepCurrentStage = false,
  }) async {
    if (_busy && !keepCurrentStage) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    if (!keepCurrentStage) {
      setState(() {
        _busy = true;
        _stage = l10n.addSubscriptionImporting;
      });
    } else {
      setState(() {
        _stage = l10n.addSubscriptionImporting;
      });
    }
    try {
      final added = await widget.onAdd(
        result.withCancellation(() => _cancelRequested),
      );
      if (!mounted) {
        return;
      }
      if (!added) {
        setState(() {
          _busy = false;
          _stage = null;
        });
        return;
      }
      setState(() => _stage = l10n.addSubscriptionDone);
      await Future<void>.delayed(const Duration(milliseconds: 260));
      if (mounted) {
        widget.onClose(true);
      }
    } on SubscriptionImportCancelledException {
      if (mounted && !_cancelRequested) {
        setState(() {
          _busy = false;
          _stage = null;
        });
      }
    } on _LocalizedSubscriptionPageError catch (e) {
      if (mounted) {
        _setError(e.message);
      }
    } catch (e) {
      if (mounted) {
        _setError(subscriptionErrorMessage(e, l10n));
      }
    }
  }

  void _submit() {
    final input = _urlController.text.trim();
    if (input.isEmpty) {
      _setError(AppLocalizations.of(context).invalidUrl);
      return;
    }
    final name = _nameController.text.trim();
    if (HappCryptoLinkDecoder.isSupportedSubscriptionUrl(input)) {
      unawaited(
        _submitResult(
          _AddResult.url(
            input,
            name,
            requestInfo: _manualRequestInfo(),
            autoRefreshMinutes: _autoRefreshMinutes,
          ),
        ),
      );
      return;
    }
    unawaited(
      _submitResult(
        _AddResult.file(
          name: name,
          fileContent: input,
          sourceName: 'manual import',
        ),
      ),
    );
  }

  Future<void> _pasteUrl() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim() ?? '';
    if (!mounted || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _importFromClipboard() async {
    if (_busy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _stage = l10n.addSubscriptionReadingClipboard;
    });
    final data = await Clipboard.getData('text/plain');
    if (!mounted) {
      return;
    }
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _setError(l10n.clipboardEmpty);
      return;
    }
    final name = _nameController.text.trim();
    if (HappCryptoLinkDecoder.isSupportedSubscriptionUrl(text)) {
      await _submitResult(
        _AddResult.url(text, name, autoRefreshMinutes: _autoRefreshMinutes),
        keepCurrentStage: true,
      );
      return;
    }
    await _submitResult(
      _AddResult.file(name: name, fileContent: text, sourceName: 'clipboard'),
      keepCurrentStage: true,
    );
  }

  Future<void> _scanQr() async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    final scannedUrl = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _SubscriptionQrScannerPage()),
    );
    if (!mounted || scannedUrl == null || scannedUrl.isEmpty) return;
    if (!HappCryptoLinkDecoder.isSupportedSubscriptionUrl(scannedUrl)) {
      _setError(AppLocalizations.of(context).invalidQrSubscription);
      return;
    }
    await _submitResult(
      _AddResult.url(
        scannedUrl,
        _nameController.text.trim(),
        autoRefreshMinutes: _autoRefreshMinutes,
      ),
    );
  }

  Future<void> _pickFile() async {
    if (_busy) {
      return;
    }
    FocusScope.of(context).unfocus();
    final l10n = AppLocalizations.of(context);
    try {
      final result = await FilePicker.pickFiles(
        withData: false,
        withReadStream: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      _cancelRequested = false;
      setState(() {
        _busy = true;
        _stage = l10n.addSubscriptionReadingFile;
      });
      final file = result.files.single;
      final content = await readSubscriptionFile(file);
      if (!mounted || _cancelRequested) return;
      if (content.contains(EtonifyBackupService.profileMagic) ||
          content.contains(EtonifyBackupService.settingsMagic)) {
        _setError(l10n.backupUseSettingsImport);
        return;
      }
      await _submitResult(
        _AddResult.file(
          name: _nameController.text.trim(),
          fileContent: content,
          sourceName: file.name,
        ),
        keepCurrentStage: true,
      );
    } catch (error) {
      AppLogStore.warning(
        'subscription',
        'Selected subscription file could not be read: '
            '${error.runtimeType}: $error',
      );
      if (mounted && !_cancelRequested) {
        _setError(l10n.invalidSubscriptionFile);
      }
    }
  }

  void _cancelAndClose() {
    _cancelRequested = true;
    widget.onClose(false);
  }

  void _showManual() {
    if (_busy) {
      return;
    }
    setState(() {
      _mode = _AddSubscriptionSheetMode.manual;
    });
    widget.onModeChanged(_mode);
  }

  void _showQuick() {
    if (_busy || _mode == _AddSubscriptionSheetMode.quick) {
      return;
    }
    setState(() {
      _mode = _AddSubscriptionSheetMode.quick;
    });
    widget.onModeChanged(_mode);
  }

  Future<void> _showHelp() {
    final l10n = AppLocalizations.of(context);
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.subscriptionImportHelpTitle),
        content: Text(l10n.subscriptionImportHelpBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatRefreshInterval(AppLocalizations l10n, int minutes) {
    if (minutes <= 0) {
      return l10n.disabledLabel;
    }
    if (minutes % (60 * 24) == 0) {
      return l10n.refreshIntervalDaysShort(minutes ~/ (60 * 24));
    }
    if (minutes % 60 == 0) {
      return l10n.refreshIntervalHoursShort(minutes ~/ 60);
    }
    return l10n.refreshIntervalMinutesShort(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding =
        mediaQuery.padding.bottom + mediaQuery.viewInsets.bottom;

    return LayoutBuilder(
      builder: (context, constraints) {
        final quickButtonHeight = _addSubscriptionQuickButtonHeight(
          constraints.maxWidth,
        );
        final quickContentHeight = _addSubscriptionQuickContentHeight(
          availableWidth: constraints.maxWidth,
          bottomPadding: bottomPadding,
        );
        final contentCanScroll =
            _mode == _AddSubscriptionSheetMode.manual ||
            quickContentHeight > constraints.maxHeight + .5;
        return PopScope(
          canPop: _mode == _AddSubscriptionSheetMode.quick || _busy,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) {
              _cancelRequested = true;
              return;
            }
            if (!didPop && !_busy) {
              _showQuick();
            }
          },
          child: Stack(
            children: [
              SingleChildScrollView(
                controller: widget.scrollController,
                physics: contentCanScroll
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  18,
                  _kAddSubscriptionSheetHeaderHeight + 8,
                  18,
                  18 + bottomPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: _kSubscriptionSheetAnimationDuration,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      layoutBuilder: (currentChild, previousChildren) =>
                          currentChild ?? const SizedBox.shrink(),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: RepaintBoundary(child: child),
                      ),
                      child: _busy
                          ? _AddSubscriptionLoadingCard(
                              key: const ValueKey('loading'),
                              stage: _stage ?? l10n.addSubscriptionImporting,
                            )
                          : _mode == _AddSubscriptionSheetMode.quick
                          ? _AddSubscriptionQuickOptions(
                              key: const ValueKey('quick'),
                              buttonHeight: quickButtonHeight,
                              onScanQr: _scanQr,
                              onClipboard: _importFromClipboard,
                              onPickFile: _pickFile,
                              onManual: _showManual,
                              onHelp: _showHelp,
                            )
                          : _AddSubscriptionManualCard(
                              key: const ValueKey('manual'),
                              urlController: _urlController,
                              nameController: _nameController,
                              customUserAgentController:
                                  _customUserAgentController,
                              customHwidController: _customHwidController,
                              contentLabel: _manualImportLabel(l10n),
                              contentHint: _manualImportHint(l10n),
                              nameLabel: l10n.subscriptionName,
                              customUserAgentLabel: l10n.customUserAgentTitle,
                              customUserAgentSubtitle:
                                  l10n.customUserAgentSubtitle,
                              userAgentHint:
                                  SubscriptionFetcher.defaultUserAgent,
                              sendHwidLabel: l10n.sendHwidTitle,
                              sendHwidSubtitle: l10n.sendHwidSubtitle,
                              customHwidLabel: l10n.customHwidTitle,
                              customHwidSubtitle: l10n.customHwidSubtitle,
                              customHwidSwitchLabel: l10n.useCustomHwidTitle,
                              customHwidSwitchSubtitle:
                                  l10n.useCustomHwidSubtitle,
                              pasteTooltip: l10n.pasteAction,
                              addLabel: l10n.add,
                              autoUpdateLabel: l10n.autoUpdateTitle,
                              autoUpdateValue: l10n.refreshesEvery(
                                _formatRefreshInterval(
                                  l10n,
                                  _autoRefreshMinutes,
                                ),
                              ),
                              autoRefreshMinutes: _autoRefreshMinutes,
                              formatAutoRefreshOption: (minutes) =>
                                  _formatRefreshInterval(l10n, minutes),
                              useCustomUserAgent: _useCustomUserAgent,
                              sendHwid: _sendHwid,
                              useCustomHwid: _useCustomHwid,
                              onPasteUrl: _pasteUrl,
                              onSubmit: _submit,
                              onUseCustomUserAgentChanged: (value) {
                                setState(() => _useCustomUserAgent = value);
                              },
                              onSendHwidChanged: (value) {
                                setState(() {
                                  _sendHwid = value;
                                  if (!value) {
                                    _useCustomHwid = false;
                                  }
                                });
                              },
                              onUseCustomHwidChanged: (value) {
                                setState(() => _useCustomHwid = value);
                              },
                              onAutoRefreshMinutesChanged: (value) {
                                setState(() => _autoRefreshMinutes = value);
                              },
                              onUrlChanged: () {},
                            ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: widget.onHeaderDragStart,
                  onVerticalDragUpdate: widget.onHeaderDragUpdate,
                  onVerticalDragEnd: widget.onHeaderDragEnd,
                  child: SizedBox(
                    height: _kAddSubscriptionSheetHeaderHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            cs.surface,
                            cs.surface.withValues(alpha: .97),
                            cs.surface.withValues(alpha: .0),
                          ],
                          stops: const [0, .78, 1],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                        child: Column(
                          children: [
                            const AppBottomSheetDragHandle(),
                            const Gap(14),
                            Row(
                              children: [
                                if (_mode == _AddSubscriptionSheetMode.manual)
                                  IconButton(
                                    tooltip: MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                    onPressed: _busy ? null : _showQuick,
                                    icon: const Icon(Icons.arrow_back_rounded),
                                  )
                                else
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _mode == _AddSubscriptionSheetMode.quick
                                            ? l10n.addSubscriptionQuickTitle
                                            : l10n.addSubscriptionManual,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0,
                                            ),
                                      ),
                                      const Gap(4),
                                      Text(
                                        _mode == _AddSubscriptionSheetMode.quick
                                            ? l10n.addSubscriptionQuickSubtitle
                                            : l10n.subscriptionUrlOrContentHint,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: l10n.close,
                                  onPressed: _cancelAndClose,
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _manualImportLabel(AppLocalizations l10n) =>
      l10n.subscriptionUrlOrContent;

  String _manualImportHint(AppLocalizations l10n) =>
      l10n.subscriptionUrlOrContentHint;
}

class _AddSubscriptionQuickOptions extends StatelessWidget {
  const _AddSubscriptionQuickOptions({
    super.key,
    required this.buttonHeight,
    required this.onScanQr,
    required this.onClipboard,
    required this.onPickFile,
    required this.onManual,
    required this.onHelp,
  });

  final double buttonHeight;
  final VoidCallback onScanQr;
  final VoidCallback onClipboard;
  final VoidCallback onPickFile;
  final VoidCallback onManual;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: _AddSubscriptionQuickCard(
                height: buttonHeight,
                icon: Icons.qr_code_scanner_rounded,
                color: cs.primary,
                title: l10n.scanQrCode,
                onTap: onScanQr,
              ),
            ),
            const Gap(10),
            Expanded(
              child: _AddSubscriptionQuickCard(
                height: buttonHeight,
                icon: Icons.content_paste_rounded,
                color: cs.secondary,
                title: l10n.addSubscriptionFromClipboard,
                onTap: onClipboard,
              ),
            ),
            const Gap(10),
            Expanded(
              child: _AddSubscriptionQuickCard(
                height: buttonHeight,
                icon: Icons.add_rounded,
                color: cs.primary,
                title: l10n.addSubscriptionManual,
                onTap: onManual,
              ),
            ),
          ],
        ),
        const Gap(16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.file_open_rounded),
                label: Text(
                  l10n.importFromFile,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const Gap(8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onHelp,
                icon: const Icon(Icons.help_outline_rounded),
                label: Text(
                  l10n.subscriptionImportHelpTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddSubscriptionQuickCard extends StatelessWidget {
  const _AddSubscriptionQuickCard({
    required this.height,
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
  });

  final double height;
  final IconData icon;
  final Color color;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingsLeadingIcon(
                  icon: icon,
                  color: color,
                  size: 48,
                  iconSize: 24,
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddSubscriptionLoadingCard extends StatelessWidget {
  const _AddSubscriptionLoadingCard({super.key, required this.stage});

  final String stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: cs.primary,
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: Text(
                    stage,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(16),
            const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _AddSubscriptionManualCard extends StatelessWidget {
  const _AddSubscriptionManualCard({
    super.key,
    required this.urlController,
    required this.nameController,
    required this.customUserAgentController,
    required this.customHwidController,
    required this.contentLabel,
    required this.contentHint,
    required this.nameLabel,
    required this.customUserAgentLabel,
    required this.customUserAgentSubtitle,
    required this.userAgentHint,
    required this.sendHwidLabel,
    required this.sendHwidSubtitle,
    required this.customHwidLabel,
    required this.customHwidSubtitle,
    required this.customHwidSwitchLabel,
    required this.customHwidSwitchSubtitle,
    required this.pasteTooltip,
    required this.addLabel,
    required this.autoUpdateLabel,
    required this.autoUpdateValue,
    required this.autoRefreshMinutes,
    required this.formatAutoRefreshOption,
    required this.useCustomUserAgent,
    required this.sendHwid,
    required this.useCustomHwid,
    required this.onPasteUrl,
    required this.onSubmit,
    required this.onUseCustomUserAgentChanged,
    required this.onSendHwidChanged,
    required this.onUseCustomHwidChanged,
    required this.onAutoRefreshMinutesChanged,
    required this.onUrlChanged,
  });

  final TextEditingController urlController;
  final TextEditingController nameController;
  final TextEditingController customUserAgentController;
  final TextEditingController customHwidController;
  final String contentLabel;
  final String contentHint;
  final String nameLabel;
  final String customUserAgentLabel;
  final String customUserAgentSubtitle;
  final String userAgentHint;
  final String sendHwidLabel;
  final String sendHwidSubtitle;
  final String customHwidLabel;
  final String customHwidSubtitle;
  final String customHwidSwitchLabel;
  final String customHwidSwitchSubtitle;
  final String pasteTooltip;
  final String addLabel;
  final String autoUpdateLabel;
  final String autoUpdateValue;
  final int autoRefreshMinutes;
  final String Function(int minutes) formatAutoRefreshOption;
  final bool useCustomUserAgent;
  final bool sendHwid;
  final bool useCustomHwid;
  final VoidCallback onPasteUrl;
  final VoidCallback onSubmit;
  final ValueChanged<bool> onUseCustomUserAgentChanged;
  final ValueChanged<bool> onSendHwidChanged;
  final ValueChanged<bool> onUseCustomHwidChanged;
  final ValueChanged<int> onAutoRefreshMinutesChanged;
  final VoidCallback onUrlChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: .36)),
    );
    final focusedFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: cs.primary, width: 1.4),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: urlController,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                isDense: true,
                alignLabelWithHint: true,
                labelText: contentLabel,
                hintText: contentHint,
                prefixIcon: const Icon(Icons.link_rounded),
                suffixIcon: IconButton(
                  tooltip: pasteTooltip,
                  onPressed: onPasteUrl,
                  icon: const Icon(Icons.content_paste_rounded),
                ),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: focusedFieldBorder,
              ),
              onChanged: (_) => onUrlChanged(),
              onSubmitted: (_) => onSubmit(),
            ),
            const Gap(10),
            TextField(
              controller: nameController,
              textInputAction: TextInputAction.done,
              inputFormatters: [_kSingleLineFormatter],
              decoration: InputDecoration(
                isDense: true,
                labelText: nameLabel,
                prefixIcon: const Icon(Icons.label_outline_rounded),
                filled: true,
                fillColor: cs.surfaceContainerLowest,
                border: fieldBorder,
                enabledBorder: fieldBorder,
                focusedBorder: focusedFieldBorder,
              ),
              onSubmitted: (_) => onSubmit(),
            ),
            const Gap(12),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: .36),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          autoUpdateLabel,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Text(
                        autoUpdateValue,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const Gap(10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final minutes in _kAutoRefreshOptions)
                        ChoiceChip(
                          label: Text(formatAutoRefreshOption(minutes)),
                          selected: autoRefreshMinutes == minutes,
                          onSelected: (_) =>
                              onAutoRefreshMinutesChanged(minutes),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Gap(8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune_rounded),
              title: Text(
                customUserAgentLabel,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              subtitle: Text('$customUserAgentSubtitle · HWID'),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(customUserAgentLabel),
                  subtitle: Text(customUserAgentSubtitle),
                  value: useCustomUserAgent,
                  onChanged: onUseCustomUserAgentChanged,
                ),
                if (useCustomUserAgent) ...[
                  TextField(
                    controller: customUserAgentController,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [_kSingleLineFormatter],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: customUserAgentLabel,
                      hintText: userAgentHint,
                      prefixIcon: const Icon(Icons.badge_outlined),
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: focusedFieldBorder,
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                  const Gap(8),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(sendHwidLabel),
                  subtitle: Text(sendHwidSubtitle),
                  value: sendHwid,
                  onChanged: onSendHwidChanged,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(customHwidSwitchLabel),
                  subtitle: Text(customHwidSwitchSubtitle),
                  value: sendHwid && useCustomHwid,
                  onChanged: sendHwid ? onUseCustomHwidChanged : null,
                ),
                if (sendHwid && useCustomHwid) ...[
                  TextField(
                    controller: customHwidController,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [_kSingleLineFormatter],
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: customHwidLabel,
                      helperText: customHwidSubtitle,
                      prefixIcon: const Icon(Icons.fingerprint_rounded),
                      filled: true,
                      fillColor: cs.surfaceContainerLowest,
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: focusedFieldBorder,
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                  const Gap(8),
                ],
              ],
            ),
            const Gap(14),
            FilledButton.icon(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(addLabel),
            ),
          ],
        ),
      ),
    );
  }
}
