import 'dart:async';

import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:material_ui/material_ui.dart';
import 'package:meow_client/data/update/app_update_service.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/widgets/app_loading_indicator.dart';
import 'package:meow_client/widgets/progressive_blur_scaffold.dart';
import 'package:meow_client/widgets/release_notes_card.dart';

class ChangelogPage extends StatefulWidget {
  const ChangelogPage({
    super.key,
    required this.currentVersion,
    this.initialInfo,
  });

  final String currentVersion;
  final AppUpdateInfo? initialInfo;

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  String? _body;
  Animation<double>? _routeAnimation;
  bool _contentReady = false;

  @override
  void initState() {
    super.initState();
    _body = widget.initialInfo?.body;
    if (_body == null) unawaited(_loadInstalledNotes());
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

  Future<void> _loadInstalledNotes() async {
    var notes = '';
    try {
      notes = installedReleaseNotes(
        await rootBundle.loadString('CHANGELOG.md'),
        widget.currentVersion,
      );
    } on FlutterError {
      // The empty state still shows the installed version.
    }
    if (mounted) setState(() => _body = notes);
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
          if (_body case final body?) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                widget.initialInfo?.displayVersion ?? widget.currentVersion,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Gap(8),
            if (_contentReady)
              ReleaseNotesCard(
                body: body,
                showHeading: false,
                useCard: false,
                limitBody: false,
                allowImages: true,
              )
            else
              const _ChangelogLoadingCard(),
          ] else
            const _ChangelogLoadingCard(),
        ],
      ),
    );
  }
}

String installedReleaseNotes(String changelog, String version) {
  String releaseTag(String value) =>
      value.trim().replaceFirst(RegExp(r'^[vV](?=\d)'), '').split('+').first;

  final installed = releaseTag(version);
  if (installed.isEmpty) return '';
  final headings = RegExp(
    r'^## \[([^\]]+)\][^\r\n]*',
    multiLine: true,
  ).allMatches(changelog).toList();
  for (var index = 0; index < headings.length; index++) {
    final heading = headings[index];
    if (releaseTag(heading[1]!) != installed) continue;
    final end = index + 1 < headings.length
        ? headings[index + 1].start
        : changelog.length;
    return changelog.substring(heading.end, end).trim();
  }
  return '';
}

class _ChangelogLoadingCard extends StatelessWidget {
  const _ChangelogLoadingCard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 104,
    child: Center(child: AppLoadingIndicator(contained: true)),
  );
}
