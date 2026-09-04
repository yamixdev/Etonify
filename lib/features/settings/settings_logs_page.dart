import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meow_client/app/providers/app_settings_commands_provider.dart';
import 'package:meow_client/app/providers/app_settings_provider.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/logging/app_log_store.dart';
import 'package:meow_client/singbox/singbox_runtime.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class SettingsLogsPage extends ConsumerStatefulWidget {
  const SettingsLogsPage({super.key});

  @override
  ConsumerState<SettingsLogsPage> createState() => _SettingsLogsPageState();
}

class _SettingsLogsPageState extends ConsumerState<SettingsLogsPage> {
  static const _menuDisplayLevel = 'display-level';
  static const _menuSingBoxLevel = 'sing-box-level';
  static const _menuClear = 'clear';

  static const _logLevelOrder = <String>[
    'trace',
    'debug',
    'info',
    'warn',
    'error',
  ];
  String _levelFilter = 'all';

  static const _visibleLevelOrder = <String>[
    'all',
    'error',
    'warning',
    'info',
    'debug',
  ];

  Future<void> _exportVisibleLogs(BuildContext context) async {
    final output = _buildVisibleLogsText();
    String? exportUri;
    try {
      exportUri = await SingboxRuntime.instance.exportLogs(
        content: output,
        suggestedName: 'meow-logs-${DateTime.now().millisecondsSinceEpoch}.txt',
      );
    } catch (_) {
      exportUri = null;
    }
    if (!context.mounted) return;
    AppNotice.show(
      context,
      exportUri == null
          ? 'Export failed or cancelled'
          : 'Logs saved: $exportUri',
      tone: exportUri == null ? AppNoticeTone.error : AppNoticeTone.success,
    );
  }

  String _buildVisibleLogsText() {
    final filtered = AppLogStore.entries.value
        .where(_matchesFilter)
        .toList(growable: false);
    return filtered
        .map((entry) {
          return '[${entry.level.toUpperCase()}] '
              '${entry.timestamp.toIso8601String()} '
              '${entry.title}\n'
              '${entry.message}';
        })
        .join('\n\n');
  }

  bool _matchesFilter(AppLogEntry entry) {
    if (_levelFilter == 'all') {
      return true;
    }
    return entry.level == _levelFilter;
  }

  Future<void> _openEntryDetails(AppLogEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _LogEntryDetailsPage(entry: entry)),
    );
  }

  String _filterLabel(AppLocalizations l10n, String level) {
    return switch (level) {
      'error' => l10n.logLevelError,
      'warning' => l10n.logLevelWarning,
      'info' => l10n.logLevelInfo,
      'debug' => l10n.logLevelDebug,
      _ => l10n.logsFilterAll,
    };
  }

  String _menuFilterLabel(AppLocalizations l10n, String level) {
    return _filterLabel(l10n, level).toUpperCase();
  }

  String _logLevelLabel(AppLocalizations l10n, String level) {
    return switch (level) {
      'trace' => l10n.logLevelTrace,
      'debug' => l10n.logLevelDebug,
      'info' => l10n.logLevelInfo,
      'warn' => l10n.logLevelWarning,
      'error' => l10n.logLevelError,
      _ => level,
    }.toUpperCase();
  }

  Future<void> _showVisibleLevelPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _visibleLevelOrder.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final level = _visibleLevelOrder[index];
              final selected = level == _levelFilter;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                title: Text(
                  _menuFilterLabel(l10n, level),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(level),
              );
            },
          ),
        );
      },
    );

    if (selected == null || selected == _levelFilter) {
      return;
    }
    setState(() {
      _levelFilter = selected;
    });
  }

  Future<void> _showSingBoxLogLevelPicker(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final currentSingBoxLogLevel =
        ref.read(appSettingsProvider).controller.singBoxLogLevel;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: _logLevelOrder.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final level = _logLevelOrder[index];
              final selected = level == currentSingBoxLogLevel;
              return ListTile(
                dense: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 2,
                ),
                title: Text(
                  _logLevelLabel(l10n, level),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: selected
                    ? Icon(
                        Icons.check_rounded,
                        color: theme.colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(context).pop(level),
              );
            },
          ),
        );
      },
    );

    if (selected == null || selected == currentSingBoxLogLevel) {
      return;
    }
    ref.read(appSettingsCommandsProvider).setSingBoxLogLevel(selected);
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case _menuDisplayLevel:
        await _showVisibleLevelPicker(context);
      case _menuSingBoxLevel:
        await _showSingBoxLogLevelPicker(context);
      case _menuClear:
        AppLogStore.clear();
        if (mounted) {
          setState(() {});
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentSingBoxLogLevel =
        ref.watch(appSettingsProvider).controller.singBoxLogLevel;

    return ProgressiveBlurScaffold(
      appBar: AppBar(
        title: Text(l10n.logsTitle),
        actions: [
          IconButton(
            onPressed: () => _exportVisibleLogs(context),
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Export logs',
          ),
          PopupMenuButton<String>(
            tooltip: MaterialLocalizations.of(context).showMenuTooltip,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => unawaited(_handleMenuSelection(value)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _menuDisplayLevel,
                child: _LogMenuItem(
                  icon: Icons.filter_list_rounded,
                  title: l10n.logsFilterTitle,
                  value: _menuFilterLabel(l10n, _levelFilter),
                ),
              ),
              PopupMenuItem(
                value: _menuSingBoxLevel,
                child: _LogMenuItem(
                  icon: Icons.terminal_rounded,
                  title: l10n.singBoxLogLevelTitle,
                  value: _logLevelLabel(l10n, currentSingBoxLogLevel),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _menuClear,
                child: _LogMenuItem(
                  icon: Icons.delete_sweep_rounded,
                  title: l10n.clearLogsTitle,
                ),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder<List<AppLogEntry>>(
        valueListenable: AppLogStore.entries,
        builder: (context, entries, _) {
          final filtered = entries
              .where(_matchesFilter)
              .toList(growable: false);

          return ColoredBox(
            color: const Color(0xFF111317),
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.noLogsTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .55),
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      progressiveHeaderTopPadding(context, 16),
                      16,
                      appBottomSafePadding(context, 16),
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: .06),
                    ),
                    itemBuilder: (context, index) {
                      final entry = filtered[index];
                      return _LogEntryRow(
                        entry: entry,
                        levelLabel: _filterLabel(l10n, entry.level),
                        color: switch (entry.level) {
                          'error' => const Color(0xFFFF8E8E),
                          'warning' => const Color(0xFFFFC27A),
                          'debug' => const Color(0xFF8FB4FF),
                          _ => const Color(0xFF9FD3B3),
                        },
                        onOpen: () => _openEntryDetails(entry),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

class _LogEntryRow extends StatelessWidget {
  const _LogEntryRow({
    required this.entry,
    required this.color,
    required this.levelLabel,
    required this.onOpen,
  });

  static const _previewLimit = 360;

  final AppLogEntry entry;
  final Color color;
  final String levelLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeOfDay = MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(entry.timestamp),
      alwaysUse24HourFormat: true,
    );
    final message = entry.message.trim();
    final preview = _previewText(message);
    final titleText = '[$levelLabel] $timeOfDay ${entry.title}';
    final titleStyle = theme.textTheme.labelMedium?.copyWith(
      color: color,
      fontFamily: 'monospace',
    );
    final previewStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: .9),
      fontFamily: 'monospace',
      height: 1.35,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = (constraints.maxWidth - 50).clamp(
          0.0,
          constraints.maxWidth,
        );
        final expandable =
            message.contains('\n') ||
            message.length > preview.length ||
            _textOverflowsOneLine(context, titleText, titleStyle, textWidth) ||
            _textOverflowsOneLine(context, preview, previewStyle, textWidth);
        final content = Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: previewStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 18,
                child: expandable
                    ? Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: .35),
                      )
                    : null,
              ),
            ],
          ),
        );
        if (!expandable) {
          return content;
        }
        return InkWell(onTap: onOpen, child: content);
      },
    );
  }

  String _previewText(String message) {
    if (message.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    var count = 0;
    for (final rune in message.runes) {
      if (count >= _previewLimit) {
        buffer.write('...');
        break;
      }
      final char = String.fromCharCode(rune);
      buffer.write(char == '\n' || char == '\r' || char == '\t' ? ' ' : char);
      count++;
    }
    return buffer.toString();
  }

  bool _textOverflowsOneLine(
    BuildContext context,
    String text,
    TextStyle? style,
    double maxWidth,
  ) {
    if (text.isEmpty || maxWidth <= 0) {
      return false;
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);
    return painter.didExceedMaxLines;
  }
}

class _LogEntryDetailsPage extends StatelessWidget {
  const _LogEntryDetailsPage({required this.entry});

  final AppLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = entry.timestamp.toIso8601String();
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(entry.title)),
      body: ColoredBox(
        color: const Color(0xFF111317),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            progressiveHeaderTopPadding(context, 16),
            16,
            appBottomSafePadding(context, 16),
          ),
          children: [
            Text(
              '[${entry.level.toUpperCase()}] $timestamp',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: .55),
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: .92),
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogMenuItem extends StatelessWidget {
  const _LogMenuItem({required this.icon, required this.title, this.value});

  final IconData icon;
  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (value != null) ...[
          const SizedBox(width: 16),
          Text(
            value!,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}
