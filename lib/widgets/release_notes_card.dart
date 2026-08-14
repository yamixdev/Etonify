import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ReleaseNotesLinkHandler = void Function(Uri uri);

class ReleaseNotesCard extends StatefulWidget {
  const ReleaseNotesCard({
    super.key,
    required this.body,
    this.margin = EdgeInsets.zero,
    this.onOpenLink,
  });

  final String body;
  final EdgeInsetsGeometry margin;
  final ReleaseNotesLinkHandler? onOpenLink;

  @override
  State<ReleaseNotesCard> createState() => _ReleaseNotesCardState();
}

class _ReleaseNotesCardState extends State<ReleaseNotesCard> {
  late String _releaseNotes;
  ThemeData? _styleTheme;
  TextStyle? _bodyStyle;
  TextStyle? _titleStyle;
  MarkdownStyleSheet? _markdownStyleSheet;

  @override
  void initState() {
    super.initState();
    _releaseNotes = _limitedReleaseNotes(widget.body);
  }

  @override
  void didUpdateWidget(ReleaseNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.body != oldWidget.body) {
      _releaseNotes = _limitedReleaseNotes(widget.body);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    if (identical(theme, _styleTheme)) {
      return;
    }
    _styleTheme = theme;
    final colors = theme.colorScheme;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colors.onSurfaceVariant,
      height: 1.35,
    );
    final headingStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w900,
      color: colors.onSurface,
    );
    _bodyStyle = bodyStyle;
    _titleStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );
    _markdownStyleSheet = MarkdownStyleSheet(
      p: bodyStyle,
      pPadding: const EdgeInsets.only(bottom: 8),
      a: bodyStyle?.copyWith(
        color: colors.primary,
        decoration: TextDecoration.underline,
        decorationColor: colors.primary.withValues(alpha: .7),
        fontWeight: FontWeight.w700,
      ),
      h1: headingStyle,
      h2: headingStyle,
      h3: headingStyle,
      h4: headingStyle,
      h5: headingStyle,
      h6: headingStyle,
      h1Padding: const EdgeInsets.only(top: 8, bottom: 6),
      h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
      h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
      strong: bodyStyle?.copyWith(fontWeight: FontWeight.w800),
      em: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
      del: bodyStyle?.copyWith(decoration: TextDecoration.lineThrough),
      code: bodyStyle?.copyWith(
        color: colors.onSurface,
        backgroundColor: colors.surfaceContainerHighest,
        fontFamily: 'monospace',
        fontSize: (bodyStyle.fontSize ?? 14) * .94,
      ),
      codeblockPadding: const EdgeInsets.all(12),
      codeblockDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
      ),
      blockquote: bodyStyle?.copyWith(fontStyle: FontStyle.italic),
      blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
      blockquoteDecoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        border: Border(left: BorderSide(color: colors.primary, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
      ),
      listBullet: bodyStyle?.copyWith(
        color: colors.primary,
        fontWeight: FontWeight.w800,
      ),
      listIndent: 22,
      blockSpacing: 8,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .65)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: widget.margin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updatesReleaseNotesTitle, style: _titleStyle),
            const Gap(12),
            if (_releaseNotes.isEmpty)
              Text(l10n.updatesNoReleaseNotes, style: _bodyStyle)
            else
              RepaintBoundary(
                child: MarkdownBody(
                  data: _releaseNotes,
                  // Long-press selection intercepts drag gestures in the
                  // updater and changelog sheet, making the surrounding list
                  // feel stuck. Links remain tappable through onTapLink.
                  selectable: false,
                  fitContent: true,
                  shrinkWrap: true,
                  onTapLink: (_, href, _) => _openLink(href),
                  imageBuilder: _blockedImageBuilder,
                  styleSheet: _markdownStyleSheet,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openLink(String? href) {
    final uri = Uri.tryParse(href?.trim() ?? '');
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return;
    }
    final handler = widget.onOpenLink;
    if (handler != null) {
      handler(uri);
      return;
    }
    unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
  }
}

Widget _blockedImageBuilder(Uri uri, String? title, String? alt) {
  final label = alt?.trim();
  return Text(
    label == null || label.isEmpty ? '[image]' : '[$label]',
    overflow: TextOverflow.ellipsis,
  );
}

String _limitedReleaseNotes(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final lines = trimmed.split(RegExp(r'\r?\n'));
  var limited = lines.take(64).join('\n');
  var truncated = lines.length > 64;
  if (limited.length > 6000) {
    var cutoff = limited.lastIndexOf('\n', 6000);
    if (cutoff < 3000) {
      cutoff = 6000;
    }
    limited = limited.substring(0, cutoff).trimRight();
    truncated = true;
  }
  return truncated ? '$limited\n\n…' : limited;
}
