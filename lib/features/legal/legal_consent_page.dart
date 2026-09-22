import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/etonify_logo_badge.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalConsentPage extends StatefulWidget {
  const LegalConsentPage({
    super.key,
    required this.requiredVersion,
    required this.onAccept,
  });

  final String requiredVersion;
  final VoidCallback onAccept;

  @override
  State<LegalConsentPage> createState() => _LegalConsentPageState();
}

class _LegalConsentPageState extends State<LegalConsentPage>
    with SingleTickerProviderStateMixin {
  static final Uri _telegramUri = Uri.parse('https://t.me/etonify');
  static final Uri _contactUri = Uri.parse('https://t.me/etonify?direct');

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  bool _termsRead = false;
  bool _privacyRead = false;

  bool get _canAccept => _termsRead && _privacyRead;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(curve);
    _scale = Tween<double>(begin: .98, end: 1).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openDocument(_LegalDocumentType type) async {
    final l10n = AppLocalizations.of(context);
    final title = switch (type) {
      _LegalDocumentType.terms => l10n.legalTermsTitle,
      _LegalDocumentType.privacy => l10n.legalPrivacyTitle,
    };
    final body = switch (type) {
      _LegalDocumentType.terms => l10n.legalTermsBody,
      _LegalDocumentType.privacy => l10n.legalPrivacyBody,
    };

    final read = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => LegalDocumentPage(title: title, body: body),
      ),
    );
    if (!mounted || read != true) {
      return;
    }
    setState(() {
      switch (type) {
        case _LegalDocumentType.terms:
          _termsRead = true;
        case _LegalDocumentType.privacy:
          _privacyRead = true;
      }
    });
  }

  Future<void> _openUri(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: ColoredBox(
        color: isDark ? const Color(0xFF101113) : cs.surface,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  28,
                  22,
                  22 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  const Center(child: EtonifyLogoBadge(size: 96, logoSize: 38)),
                  const Gap(24),
                  Text(
                    l10n.legalGateTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const Gap(10),
                  Text(
                    l10n.legalGateSubtitle(widget.requiredVersion),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.38,
                    ),
                  ),
                  const Gap(22),
                  _LegalReadTile(
                    icon: Icons.description_rounded,
                    title: l10n.legalTermsTitle,
                    subtitle: l10n.legalTermsSummary,
                    read: _termsRead,
                    onTap: () => _openDocument(_LegalDocumentType.terms),
                  ),
                  const Gap(10),
                  _LegalReadTile(
                    icon: Icons.privacy_tip_rounded,
                    title: l10n.legalPrivacyTitle,
                    subtitle: l10n.legalPrivacySummary,
                    read: _privacyRead,
                    onTap: () => _openDocument(_LegalDocumentType.privacy),
                  ),
                  const Gap(18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openUri(_telegramUri),
                          icon: const Icon(Icons.send_rounded),
                          label: Text(l10n.telegramChannelLabel),
                        ),
                      ),
                      const Gap(10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openUri(_contactUri),
                          icon: const Icon(Icons.support_agent_rounded),
                          label: Text(l10n.legalContactAction),
                        ),
                      ),
                    ],
                  ),
                  const Gap(22),
                  FilledButton(
                    onPressed: _canAccept ? widget.onAccept : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(l10n.legalAcceptAction),
                  ),
                  if (!_canAccept) ...[
                    const Gap(8),
                    Text(
                      l10n.legalAcceptHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late final ScrollController _scrollController;
  bool _canConfirm = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _canConfirm) {
      return;
    }
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0 || position.extentAfter < 48) {
      setState(() => _canConfirm = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final lines = widget.body.split('\n');
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                itemCount: lines.length,
                itemBuilder: (context, index) {
                  final line = lines[index].trim();
                  if (line.isEmpty) return const Gap(10);
                  if (line.startsWith('# ')) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _LegalMarkdownText(
                        text: line.substring(2),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0,
                        ),
                      ),
                    );
                  }
                  if (line.startsWith('## ')) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 4),
                      child: _LegalMarkdownText(
                        text: line.substring(3),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    );
                  }
                  final bullet = line.startsWith('- ');
                  return Padding(
                    padding: EdgeInsets.only(left: bullet ? 4 : 0, bottom: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (bullet) ...[
                          Text('•', style: theme.textTheme.bodyMedium),
                          const Gap(10),
                        ],
                        Expanded(
                          child: _LegalMarkdownText(
                            text: bullet ? line.substring(2) : line,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.42,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: FilledButton(
                onPressed: _canConfirm
                    ? () => Navigator.of(context).pop(true)
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(l10n.legalDocumentReadAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Hoisted out of build(): the document view rebuilds on every scroll frame.
final RegExp _boldMarkdownPattern = RegExp(r'\*\*(.+?)\*\*');

class _LegalMarkdownText extends StatelessWidget {
  const _LegalMarkdownText({required this.text, required this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final match in _boldMarkdownPattern.allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) spans.add(TextSpan(text: text.substring(offset)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

enum _LegalDocumentType { terms, privacy }

class _LegalReadTile extends StatelessWidget {
  const _LegalReadTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.read,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool read;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: read ? cs.primary : cs.onSurfaceVariant),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: Icon(
          read ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
          color: read ? cs.primary : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
