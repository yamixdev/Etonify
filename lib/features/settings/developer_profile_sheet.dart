import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class DeveloperProfile {
  const DeveloperProfile({
    required this.name,
    required this.role,
    required this.avatarAsset,
    this.bioUri,
    required this.telegramUri,
    required this.githubUri,
  });

  final String name;
  final String role;
  final String avatarAsset;
  final Uri? bioUri;
  final Uri telegramUri;
  final Uri githubUri;
}

abstract final class AppDevelopers {
  static DeveloperProfile yamixdev(AppLocalizations l10n) => DeveloperProfile(
    name: 'yamixdev',
    role: l10n.teamDeveloperYamixdevRole,
    avatarAsset: 'assets/images/team/yamixdev.jpg',
    bioUri: Uri.parse('https://yamixdev.github.io/bio'),
    telegramUri: Uri.parse('https://t.me/Ilushadev'),
    githubUri: Uri.parse('https://github.com/yamixdev'),
  );

  static DeveloperProfile dudosxdev(AppLocalizations l10n) => DeveloperProfile(
    name: 'dudosxdev',
    role: l10n.teamDeveloperDdosxdRole,
    avatarAsset: 'assets/images/team/ddosxd.jpg',
    telegramUri: Uri.parse('https://t.me/dddosxd'),
    githubUri: Uri.parse('https://github.com/dudosxdev'),
  );
}

Future<void> showDeveloperProfileSheet(
  BuildContext context,
  DeveloperProfile profile,
) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _DeveloperProfileSheet(profile: profile),
  );
}

class _DeveloperProfileSheet extends StatefulWidget {
  const _DeveloperProfileSheet({required this.profile});

  final DeveloperProfile profile;

  @override
  State<_DeveloperProfileSheet> createState() => _DeveloperProfileSheetState();
}

class _DeveloperProfileSheetState extends State<_DeveloperProfileSheet> {
  bool _showVerification = false;

  Future<void> _open(Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      AppNotice.show(context, uri.toString(), tone: AppNoticeTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final profile = widget.profile;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - value)),
                    child: Transform.scale(
                      scale: .94 + (.06 * value),
                      child: child,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.surfaceContainerHighest,
                        border: Border.all(
                          color: cs.outlineVariant.withValues(alpha: .8),
                        ),
                      ),
                      child: ClipOval(
                        child: Image(
                          image: ResizeImage(
                            AssetImage(profile.avatarAsset),
                            width: 220,
                            height: 220,
                          ),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                    const Gap(14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            profile.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const Gap(4),
                        IconButton(
                          tooltip: l10n.trafficRulesVerified,
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(
                            () => _showVerification = !_showVerification,
                          ),
                          icon: Icon(
                            Icons.verified_rounded,
                            color: cs.primary,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      profile.role,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRect(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _showVerification
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shield_rounded,
                                  size: 18,
                                  color: cs.onPrimaryContainer,
                                ),
                                const Gap(8),
                                Flexible(
                                  child: Text(
                                    l10n.trafficRulesVerifiedInfo,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: cs.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              const Gap(22),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (profile.bioUri case final uri?)
                    _ProfileLinkButton(
                      label: 'Bio',
                      icon: const Icon(Icons.language_rounded, size: 19),
                      onPressed: () => _open(uri),
                    ),
                  _ProfileLinkButton(
                    label: 'Telegram',
                    icon: ClipOval(
                      child: Image.asset(
                        'assets/images/team/telegram.png',
                        width: 19,
                        height: 19,
                        cacheWidth: 40,
                        cacheHeight: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    onPressed: () => _open(profile.telegramUri),
                  ),
                  _ProfileLinkButton(
                    label: 'GitHub',
                    icon: const Icon(Icons.code_rounded, size: 19),
                    onPressed: () => _open(profile.githubUri),
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

class _ProfileLinkButton extends StatelessWidget {
  const _ProfileLinkButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [icon, const Gap(8), Text(label)],
      ),
    );
  }
}
