import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:meow_client/core/widgets/app_notice.dart';
import 'package:meow_client/data/backup/etonify_backup_service.dart';
import 'package:meow_client/data/local/app_settings_store.dart';
import 'package:meow_client/l10n/generated/app_localizations.dart';
import 'package:meow_client/models/subscription.dart';

class SettingsBackupImportActions {
  const SettingsBackupImportActions({
    required this.store,
    required this.settingsState,
    required this.clientVersion,
    required this.onImportSettings,
    required this.onImportSubscriptions,
  });

  static const _service = EtonifyBackupService();

  final AppSettingsStore store;
  final AppSettingsState settingsState;
  final String clientVersion;
  final Future<void> Function(AppSettingsState state) onImportSettings;
  final Future<void> Function(List<Subscription> subscriptions)
  onImportSubscriptions;

  Future<void> importFile(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return;
    final file = picked.files.first;
    if (file.size > EtonifyBackupService.maxImportBytes) {
      throw const EtonifyBackupException('Backup file is too large.');
    }
    final path = file.path;
    final bytes =
        file.bytes ?? (path == null ? null : await File(path).readAsBytes());
    if (!context.mounted) return;
    if (bytes == null) {
      throw const EtonifyBackupException('Could not read selected file.');
    }
    final decodedHead = utf8.decode(
      bytes.take(256).toList(growable: false),
      allowMalformed: true,
    );
    if (decodedHead.contains(EtonifyBackupService.settingsMagic)) {
      await _importSettings(context, bytes);
      return;
    }
    if (decodedHead.contains(EtonifyBackupService.profileMagic)) {
      await _importProfile(context, bytes);
      return;
    }
    throw const EtonifyBackupException('This is not an Etonify backup file.');
  }

  Future<void> _importSettings(BuildContext context, List<int> bytes) async {
    final parsed = _service.parseSettingsExport(
      bytes: bytes,
      currentClientVersion: clientVersion,
    );
    if (!await _confirmCompatibility(context, parsed.warning) ||
        !context.mounted) {
      return;
    }
    final state = store.mergeSafeImportMap(settingsState, parsed.settings);
    await onImportSettings(state);
    if (!context.mounted) return;
    _showImported(context);
  }

  Future<void> _importProfile(BuildContext context, List<int> bytes) async {
    String? password;
    if (_service.detectProfileEncryption(bytes) ==
        EtonifyProfileEncryption.encrypted) {
      password = await _askPassword(context);
      if (password == null || !context.mounted) return;
    }
    EtonifyProfileImportResult parsed;
    try {
      parsed = await _service.parseProfileExportInBackground(
        bytes: bytes,
        currentClientVersion: clientVersion,
        password: password,
      );
    } on EtonifyBackupException catch (error) {
      if (password != null ||
          !error.message.toLowerCase().contains('password')) {
        rethrow;
      }
      if (!context.mounted) return;
      final retryPassword = await _askPassword(context);
      if (retryPassword == null) return;
      parsed = await _service.parseProfileExportInBackground(
        bytes: bytes,
        currentClientVersion: clientVersion,
        password: retryPassword,
      );
    }
    if (!context.mounted) return;
    if (parsed.encryption == EtonifyProfileEncryption.plain) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            AppLocalizations.of(dialogContext).backupPlainImportTitle,
          ),
          content: Text(
            AppLocalizations.of(dialogContext).backupPlainImportMessage,
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
    }
    if (!await _confirmCompatibility(context, parsed.warning) ||
        !context.mounted) {
      return;
    }
    await onImportSubscriptions(parsed.subscriptions);
    if (!context.mounted) return;
    _showImported(context);
  }

  Future<bool> _confirmCompatibility(
    BuildContext context,
    EtonifyImportWarning warning,
  ) async {
    if (warning.compatibility == ExportCompatibilityStatus.compatible) {
      return true;
    }
    if (warning.compatibility == ExportCompatibilityStatus.unsupported) {
      AppNotice.show(
        context,
        AppLocalizations.of(context).backupUnsupportedVersion,
      );
      return false;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).backupNewerVersionTitle),
        content: Text(
          AppLocalizations.of(
            dialogContext,
          ).backupNewerVersionMessage(warning.createdByVersion),
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
    return confirmed == true;
  }

  Future<String?> _askPassword(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          AppLocalizations.of(dialogContext).backupPasswordEnterTitle,
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

  void _showImported(BuildContext context) {
    if (!context.mounted) return;
    AppNotice.show(
      context,
      AppLocalizations.of(context).backupImported,
      tone: AppNoticeTone.success,
    );
  }
}
