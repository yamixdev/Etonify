import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';

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

class _LegalConsentPageState extends State<LegalConsentPage> {
  bool _accepted = false;
  bool _openingDocuments = false;

  void _accept() {
    if (_accepted) return;
    setState(() => _accepted = true);
    widget.onAccept();
  }

  Future<void> _openDocuments() async {
    if (_openingDocuments || _accepted) return;
    _openingDocuments = true;
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LegalDocumentsPage()),
      );
    } finally {
      _openingDocuments = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Material(
                  key: const ValueKey('legal-disclaimer'),
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(
                                    l10n.legalGateTitle,
                                    style: theme.textTheme.headlineSmall,
                                  ),
                                ),
                                const Gap(20),
                                Text(
                                  l10n.legalGateBody,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.45,
                                  ),
                                ),
                                const Gap(16),
                                Text(
                                  l10n.legalAcceptHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Gap(24),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          spacing: 8,
                          overflowSpacing: 8,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _accepted ? null : _openDocuments,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              child: Text(l10n.documentationGroupDocuments),
                            ),
                            FilledButton(
                              onPressed: _accepted ? null : _accept,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(96, 48),
                              ),
                              child: Text(l10n.legalAcceptAction),
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
        ),
      ),
    );
  }
}

class LegalDocumentsPage extends StatelessWidget {
  const LegalDocumentsPage({super.key});

  void _openDocument(BuildContext context, {required bool privacy}) {
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentPage(
          title: privacy ? l10n.legalPrivacyTitle : l10n.legalTermsTitle,
          body: privacy ? l10n.legalPrivacyBody : l10n.legalTermsBody,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentationGroupDocuments)),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LegalDocumentTile(
                  icon: Icons.description_outlined,
                  title: l10n.legalTermsTitle,
                  subtitle: l10n.legalTermsSummary,
                  onTap: () => _openDocument(context, privacy: false),
                ),
                const Gap(12),
                _LegalDocumentTile(
                  icon: Icons.privacy_tip_outlined,
                  title: l10n.legalPrivacyTitle,
                  subtitle: l10n.legalPrivacySummary,
                  onTap: () => _openDocument(context, privacy: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LegalDocumentPage extends StatelessWidget {
  const LegalDocumentPage({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final cs = theme.colorScheme;
    final lines = body.split('\n');
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SelectionArea(
                    child: ListView.builder(
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
                                fontWeight: FontWeight.w800,
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                        final bullet = line.startsWith('- ');
                        return Padding(
                          padding: EdgeInsets.only(
                            left: bullet ? 4 : 0,
                            bottom: 3,
                          ),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _LegalDocumentTile extends StatelessWidget {
  const _LegalDocumentTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
