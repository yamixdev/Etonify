part of 'subscriptions_page.dart';

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DetailsBlock extends StatelessWidget {
  const _DetailsBlock({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final trailingWidget = trailing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: .42),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ...switch (trailingWidget) {
                    final widget? => [widget],
                    null => const <Widget>[],
                  },
                ],
              ),
              const Gap(10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SubscriptionUrlEditDialog extends StatefulWidget {
  const _SubscriptionUrlEditDialog({
    required this.initialValue,
    required this.validate,
  });

  final String initialValue;
  final ({String? url, String? error}) Function(String input) validate;

  @override
  State<_SubscriptionUrlEditDialog> createState() =>
      _SubscriptionUrlEditDialogState();
}

class _SubscriptionUrlEditDialogState
    extends State<_SubscriptionUrlEditDialog> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final result = widget.validate(_controller.text);
    if (result.error case final error?) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.of(context).pop(result.url);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editSubscriptionUrlAction),
      content: SizedBox(
        width: 520,
        child: TextField(
          key: const ValueKey('subscription_url_editor'),
          controller: _controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          decoration: InputDecoration(
            labelText: l10n.subscriptionUrl,
            helperText: l10n.subscriptionUrlEditHint,
            helperMaxLines: 4,
            errorText: _errorText,
            errorMaxLines: 3,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            if (_errorText != null) {
              setState(() => _errorText = null);
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.saveAction)),
      ],
    );
  }
}

class _OutboundRow extends StatelessWidget {
  const _OutboundRow({super.key, required this.outbound, required this.onTap});

  final Outbound outbound;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = [
      outbound.type.toUpperCase(),
      ...[
        _securityLabel(outbound),
        _transportLabel(outbound),
      ].whereType<String>().map((value) => value.toUpperCase()),
    ].join(' · ');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            CountryFlagBadge(
              countryCode: outboundDisplayCountryCode(
                outbound,
                markAllServersRussia: false,
              ),
              size: 34,
            ),
            const Gap(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outbound.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Gap(3),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

String? _securityLabel(Outbound outbound) {
  final tls = outbound.config['tls'];
  if (tls is! Map) {
    return null;
  }
  final reality = tls['reality'];
  if (reality is Map && reality['enabled'] == true) {
    return 'reality';
  }
  if (tls['enabled'] == true) {
    return 'tls';
  }
  return null;
}

String? _transportLabel(Outbound outbound) {
  final transport = outbound.config['transport'];
  final rawType = transport is Map
      ? (transport['type'] as String?)?.trim().toLowerCase()
      : null;
  if (rawType == null || rawType.isEmpty) {
    return null;
  }
  if (rawType == 'http') {
    return _securityLabel(outbound) == 'tls' ||
            _securityLabel(outbound) == 'reality'
        ? 'https'
        : 'http';
  }
  return rawType;
}

String _endpointWithPath(Outbound outbound) {
  final buffer = StringBuffer();
  if (outbound.server.isNotEmpty) {
    buffer.write(outbound.server);
    if (outbound.port > 0) {
      buffer.write(':${outbound.port}');
    }
  } else {
    buffer.write(outbound.tag);
  }
  final transport = outbound.config['transport'];
  final path = transport is Map ? (transport['path'] as String?)?.trim() : null;
  if (path != null && path.isNotEmpty) {
    buffer.write(path.startsWith('/') ? path : '/$path');
  }
  return buffer.toString();
}

class _AddResult {
  const _AddResult.url(
    this.url,
    this.name, {
    this.requestInfo,
    this.autoRefreshMinutes = 360,
    this.isCancelled,
  }) : fileContent = null,
       sourceName = null;

  const _AddResult.file({
    required this.name,
    required this.fileContent,
    required this.sourceName,
    this.isCancelled,
  }) : url = '',
       requestInfo = null,
       autoRefreshMinutes = 0;

  final String url;
  final String name;
  final SubscriptionInfo? requestInfo;
  final int autoRefreshMinutes;
  final String? fileContent;
  final String? sourceName;
  final bool Function()? isCancelled;

  _AddResult withCancellation(bool Function() isCancelled) {
    if (fileContent != null) {
      return _AddResult.file(
        name: name,
        fileContent: fileContent!,
        sourceName: sourceName,
        isCancelled: isCancelled,
      );
    }
    return _AddResult.url(
      url,
      name,
      requestInfo: requestInfo,
      autoRefreshMinutes: autoRefreshMinutes,
      isCancelled: isCancelled,
    );
  }
}

// ---------------------------------------------------------------------------
// Add-subscription sheet
// ---------------------------------------------------------------------------
