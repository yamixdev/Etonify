import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/app/deep_link_import.dart';
import 'package:meow_client/data/subscription/happ_crypto_link.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

enum DeepLinkImportDecision { import, sendHwid, importWithoutHwid }

class DeepLinkImportCopy {
  const DeepLinkImportCopy({
    required this.title,
    required this.message,
    required this.nameLabel,
    required this.importAction,
    required this.importedTextBuilder,
  });

  factory DeepLinkImportCopy.fromContext(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DeepLinkImportCopy(
      title: l10n.deepLinkImportTitle,
      message: l10n.deepLinkImportMessage,
      nameLabel: l10n.deepLinkImportNameLabel,
      importAction: l10n.deepLinkImportAction,
      importedTextBuilder: l10n.deepLinkImportSuccess,
    );
  }

  final String title;
  final String message;
  final String nameLabel;
  final String importAction;
  final String Function(String name) importedTextBuilder;

  String imported(String name) {
    return importedTextBuilder(name);
  }
}

class DeepLinkImportPreview {
  const DeepLinkImportPreview({
    required this.sourceUrl,
    required this.resolvedUrl,
    required this.requestInfo,
  });

  final String sourceUrl;
  final String resolvedUrl;
  final SubscriptionInfo? requestInfo;

  bool get isHapp =>
      requestInfo?.happCryptoLink != null ||
      requestInfo?.requireHwid == true ||
      requestInfo?.customUserAgent?.trim().isNotEmpty == true;

  static Future<DeepLinkImportPreview> build(
    DeepLinkImportRequest request,
  ) async {
    if (HappCryptoLinkDecoder.isSupportedLink(request.url)) {
      final prepared = await HappCryptoLinkDecoder.prepare(request.url);
      return DeepLinkImportPreview(
        sourceUrl: request.url,
        resolvedUrl: prepared.resolvedUrl,
        requestInfo: prepared.requestInfo,
      );
    }

    final isHappDeepLink = request.isHapp;

    return DeepLinkImportPreview(
      sourceUrl: request.url,
      resolvedUrl: request.url,
      requestInfo: isHappDeepLink
          ? HappCryptoLinkDecoder.happRequestInfo()
          : null,
    );
  }
}

class DeepLinkImportSheet extends StatelessWidget {
  const DeepLinkImportSheet({
    super.key,
    required this.request,
    required this.preview,
    required this.copy,
    required this.l10n,
    this.hwidSharingEnabled = false,
  });

  final DeepLinkImportRequest request;
  final DeepLinkImportPreview preview;
  final DeepLinkImportCopy copy;
  final AppLocalizations l10n;
  final bool hwidSharingEnabled;

  String _summarizeSourceUrl(String value) {
    if (value.length <= 72) {
      return value;
    }
    return '${value.substring(0, 72)}...';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = request.name;
    final isHapp = preview.isHapp;
    final happInfo = preview.requestInfo;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(copy.title, style: theme.textTheme.titleLarge),
                      const Gap(12),
                      Text(copy.message, style: theme.textTheme.bodyLarge),
                      if (isHapp) ...[
                        const Gap(12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: .10,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.deepLinkImportHappBadge,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const Gap(16),
                      SizedBox(
                        width: double.infinity,
                        child: Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (name != null && name.isNotEmpty) ...[
                                  Text(
                                    copy.nameLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(name, style: theme.textTheme.titleSmall),
                                  const Gap(12),
                                ],
                                if (isHapp) ...[
                                  Text(
                                    l10n.deepLinkImportResolvedUrlLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    preview.resolvedUrl,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const Gap(16),
                                  Text(
                                    l10n.deepLinkImportSourceLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    _summarizeSourceUrl(preview.sourceUrl),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ] else ...[
                                  Text(
                                    l10n.subscriptionUrl,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    preview.sourceUrl,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isHapp && !hwidSharingEnabled) ...[
                        const Gap(12),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n.deepLinkImportHappNotice,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ),
                        ),
                        const Gap(12),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            margin: EdgeInsets.zero,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.deepLinkImportHwidLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  Text(
                                    l10n.deepLinkImportHwidValue,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const Gap(12),
                                  Text(
                                    l10n.deepLinkImportUserAgentLabel,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                  const Gap(4),
                                  SelectableText(
                                    happInfo?.customUserAgent ??
                                        happLatestUserAgent,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Gap(16),
              if (isHapp && !hwidSharingEnabled)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(DeepLinkImportDecision.sendHwid),
                      child: Text(l10n.deepLinkImportHappSendHwidAction),
                    ),
                    const Gap(8),
                    FilledButton.tonal(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(DeepLinkImportDecision.importWithoutHwid),
                      child: Text(l10n.deepLinkImportHappWithoutHwidAction),
                    ),
                    const Gap(8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancel),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const Gap(12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pop(DeepLinkImportDecision.import),
                        child: Text(copy.importAction),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
