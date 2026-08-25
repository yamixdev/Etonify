import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

class SettingsBackupExportActions {
  const SettingsBackupExportActions({
    required this.store,
    required this.settingsState,
    required this.clientVersion,
    required this.loadSubscriptions,
  });

  static const _service = EtonifyBackupService();

  final AppSettingsStore store;
  final AppSettingsState settingsState;
  final String clientVersion;
  final Future<List<Subscription>> Function() loadSubscriptions;

  Future<void> exportSettings(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final content = _service.buildSettingsExport(
      store: store,
      state: settingsState,
      clientVersion: clientVersion,
    );
    final path = await FilePicker.saveFile(
      dialogTitle: l10n.backupExportSettings,
      fileName: 'etonify.etonify-settings.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
    if (path == null || !context.mounted) return;
    _showSaved(context);
  }

  Future<void> exportEncryptedProfile(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final password = await _askPassword(context);
    if (password == null || !context.mounted) return;
    final bytes = await _service.buildProfileExportBytesInBackground(
      subscriptions: await loadSubscriptions(),
      clientVersion: clientVersion,
      encryption: EtonifyProfileEncryption.encrypted,
      password: password,
    );
    final path = await FilePicker.saveFile(
      dialogTitle: l10n.backupExportProfileEncrypted,
      fileName: 'etonify-profile.etonify-profile',
      type: FileType.custom,
      allowedExtensions: const ['etonify-profile'],
      bytes: bytes,
    );
    if (path == null || !context.mounted) return;
    _showSaved(context);
  }

  Future<void> exportPlainProfile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).backupPlainWarningTitle),
        content: Text(
          AppLocalizations.of(dialogContext).backupPlainWarningMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(AppLocalizations.of(dialogContext).continueAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final bytes = await _service.buildProfileExportBytesInBackground(
      subscriptions: await loadSubscriptions(),
      clientVersion: clientVersion,
      encryption: EtonifyProfileEncryption.plain,
    );
    final path = await FilePicker.saveFile(
      dialogTitle: l10n.backupExportProfilePlain,
      fileName: 'etonify-profile-plain.etonify-profile',
      type: FileType.custom,
      allowedExtensions: const ['etonify-profile'],
      bytes: bytes,
    );
    if (path == null || !context.mounted) return;
    _showSaved(context);
  }

  Future<String?> _askPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocalizations.of(dialogContext).backupPasswordCreateTitle,
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(dialogContext).backupPasswordHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(AppLocalizations.of(dialogContext).continueAction),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = result?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  void _showSaved(BuildContext context) {
    if (!context.mounted) return;
    AppNotice.show(
      context,
      AppLocalizations.of(context).backupSaved,
      tone: AppNoticeTone.success,
    );
  }
}
