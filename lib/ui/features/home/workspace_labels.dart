import 'package:pi_gui/l10n/app_localizations.dart';

String workspaceFailureLabel(AppLocalizations l10n, String code) =>
    switch (code) {
      'WORKSPACE_BUSY' => l10n.workspaceBusy,
      'INVALID_PATH' || 'DIRECTORY_UNAVAILABLE' => l10n.workspacePathFailed,
      'INVALID_NAME' => l10n.workspaceNameInvalid,
      'PATH_EXISTS' => l10n.workspacePathExists,
      'CREATE_FAILED' => l10n.workspaceCreateFailed,
      'WORKSPACE_START_FAILED' ||
      'PI_RESTART_FAILED' => l10n.workspaceSwitchFailed,
      'OUTCOME_UNKNOWN' => l10n.workspaceUnknown,
      'SESSIONS_UNAVAILABLE' => l10n.sessionHistoryFailed,
      'WORKTREE_IN_USE' => l10n.worktreeInUse,
      'WORKTREE_LOCKED' => l10n.worktreeLockedBlocked,
      'WORKTREE_DIRTY' => l10n.worktreeDirtyBlocked,
      'WORKTREE_UNAVAILABLE' => l10n.worktreeUnavailable,
      'NOT_GIT' => l10n.worktreeNotGit,
      'NO_COMMIT' => l10n.worktreeNoCommit,
      'INVALID_BRANCH' => l10n.worktreeBranchInvalid,
      'BRANCH_EXISTS' => l10n.worktreeBranchExists,
      'INVALID_BASE' => l10n.worktreeBaseInvalid,
      'GIT_FAILED' || 'GIT_UNAVAILABLE' => l10n.worktreeGitFailed,
      _ => l10n.workspaceLoadFailed,
    };
