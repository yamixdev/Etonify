import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/data/update/app_update_channel.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/release_notes_card.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({
    super.key,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.updateChannel = AppUpdateChannel.stable,
    this.initialInfo,
  });

  final String currentVersion;
  final int currentBuildNumber;
  final AppUpdateChannel updateChannel;
  final AppUpdateInfo? initialInfo;

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  AppUpdateInfo? _info;
  String? _errorMessage;
  Animation<double>? _routeAnimation;
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    _info = widget.initialInfo;
    if (_info == null) unawaited(_load());
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
    final l10n = AppLocalizations.of(context);
    return ProgressiveBlurScaffold(
      appBar: AppBar(title: Text(l10n.updatesReleaseNotesTitle)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          10,
          progressiveHeaderTopPadding(context, 8),
          10,
          MediaQuery.paddingOf(context).bottom + 24,
        ),
        children: [
          if (_info case final info?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                info.displayVersion,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(8),
            if (_contentReady)
              ReleaseNotesCard(
                body: info.body,
                showHeading: false,
                useCard: false,
                limitBody: false,
                allowImages: true,
              )
            else
              const _ChangelogLoadingCard(),
          ] else if (_errorMessage case final error?)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                error,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            )
          else
            const _ChangelogLoadingCard(),
        ],
      ),
    );
  }
}

class _ChangelogLoadingCard extends StatelessWidget {
  const _ChangelogLoadingCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 104,
    child: Center(child: CircularProgressIndicator(strokeWidth: 3)),
  );
}
