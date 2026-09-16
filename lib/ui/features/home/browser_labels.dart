import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_browser_types.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

String browserError(BuildContext context, String code) => switch (code) {
  'UNKNOWN_COMMAND' => context.l10n.browserOldBackend,
  'WORKSPACE_CHANGED' => context.l10n.browserWorkspaceChanged,
  'GIT_UNAVAILABLE' => context.l10n.browserGitMissing,
  'NOT_GIT' => context.l10n.browserNoGit,
  'GIT_FAILED' || 'INVALID_COMMIT' => context.l10n.browserGitFailed,
  'REPOSITORY_TOO_LARGE' || 'DIFF_TOO_LARGE' => context.l10n.browserLimit,
  'SYMLINK_UNAVAILABLE' => context.l10n.browserSymlink,
  'DISCONNECTED' => context.l10n.piDisconnected,
  _ => context.l10n.browserReadFailed,
};
String fileStatusLabel(BuildContext context, PiFileStatus status) =>
    switch (status) {
      PiFileStatus.none => context.l10n.browserNoStatus,
      PiFileStatus.clean => context.l10n.browserClean,
      PiFileStatus.modified => context.l10n.browserModified,
      PiFileStatus.staged => context.l10n.browserStatusStaged,
      PiFileStatus.added => context.l10n.browserAdded,
      PiFileStatus.deleted => context.l10n.browserDeleted,
      PiFileStatus.renamed => context.l10n.browserRenamed,
      PiFileStatus.untracked => context.l10n.browserUntracked,
      PiFileStatus.ignored => context.l10n.browserIgnored,
      PiFileStatus.conflict => context.l10n.browserConflict,
    };
Color fileStatusColor(BuildContext context, PiFileStatus status) =>
    switch (status) {
      PiFileStatus.modified || PiFileStatus.renamed => context.colors.warning,
      PiFileStatus.staged ||
      PiFileStatus.added ||
      PiFileStatus.untracked => context.colors.success,
      PiFileStatus.deleted || PiFileStatus.conflict => context.colors.error,
      PiFileStatus.ignored || PiFileStatus.none => context.colors.textMuted,
      PiFileStatus.clean => context.colors.textSecondary,
    };
String gitCodeLabel(BuildContext context, String code) => code.trim().isEmpty
    ? context.l10n.browserUnchanged
    : fileStatusLabel(context, switch (code) {
        'M' || 'T' => PiFileStatus.modified,
        'A' || 'C' => PiFileStatus.added,
        'D' => PiFileStatus.deleted,
        'R' => PiFileStatus.renamed,
        'U' => PiFileStatus.conflict,
        '?' => PiFileStatus.untracked,
        '!' => PiFileStatus.ignored,
        _ => PiFileStatus.clean,
      });
String shortRef(String ref) =>
    ref.replaceFirst(RegExp(r'^refs/(heads|remotes|tags)/'), '');
