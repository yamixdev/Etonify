import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/release_notes_card.dart';

class ChangelogSheet extends StatefulWidget {
  const ChangelogSheet({
    super.key,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.updateChannel = AppUpdateChannel.stable,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final AppUpdateChannel updateChannel;

  @override
  State<ChangelogSheet> createState() => _ChangelogSheetState();
}

class _ChangelogSheetState extends State<ChangelogSheet> {
  AppUpdateInfo? _info;
  String? _errorMessage;
  Animation<double>? _routeAnimation;
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (identical(animation, _routeAnimation)) return;
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    _routeAnimation = animation;
    if (animation == null || animation.status == AnimationStatus.completed) {
      _contentReady = true;
    } else {
      animation.addStatusListener(_handleRouteAnimation);
    }
  }

  void _handleRouteAnimation(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted || _contentReady) {
      return;
    }
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    setState(() => _contentReady = true);
  }

  Future<void> _load() async {
    final service = AppUpdateService.instance;
    try {
      final metadata = await service.loadMetadata();
      final cached = metadata.channel == widget.updateChannel
          ? metadata.latestInfo
          : null;
      if (mounted && cached != null) {
        setState(() => _info = cached);
      }

      final result = await service.checkForUpdates(
        currentVersion: widget.currentVersion,
        currentBuildNumber: widget.currentBuildNumber,
        manual: false,
        channel: widget.updateChannel,
      );
      if (!mounted) return;
      final nextInfo = result.info;
      final currentInfo = _info;
      final infoChanged =
          nextInfo != null &&
          (currentInfo == null ||
              nextInfo.version != currentInfo.version ||
              nextInfo.buildNumber != currentInfo.buildNumber ||
              nextInfo.body != currentInfo.body);
      final nextError = currentInfo == null && nextInfo == null
          ? result.error
          : null;
      if (!infoChanged && nextError == _errorMessage) return;
      setState(() {
        _info = nextInfo ?? currentInfo;
        _errorMessage = nextError;
      });
    } catch (error) {
      if (mounted && _info == null) {
        setState(() => _errorMessage = error.toString());
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleRouteAnimation);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final l10n = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .56,
      minChildSize: .34,
      maxChildSize: .90,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomPadding),
            children: [
              Center(
                child: Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withValues(alpha: .38),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const Gap(18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.updatesReleaseNotesTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Gap(12),
              if (_info case final info?) ...[
                Text(
                  info.displayVersion,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const Gap(10),
                if (_contentReady)
                  ReleaseNotesCard(body: info.body)
                else
                  const _ChangelogLoadingCard(),
              ] else if (_errorMessage case final error?)
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      error,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              else
                const _ChangelogLoadingCard(),
            ],
          ),
        );
      },
    );
  }
}

class _ChangelogLoadingCard extends StatelessWidget {
  const _ChangelogLoadingCard();

  @override
  Widget build(BuildContext context) => const Card(
    margin: EdgeInsets.zero,
    child: SizedBox(
      height: 104,
      child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
    ),
  );
}
