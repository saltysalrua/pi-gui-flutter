// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Pi';

  @override
  String get newConversation => 'New Conversation';

  @override
  String get projects => 'Projects';

  @override
  String get settings => 'Settings';

  @override
  String get noSessions => 'No conversations yet';

  @override
  String get inputPlaceholder => 'Ask Pi anything, or assign a coding task...';

  @override
  String get selectModel => 'Select Model';

  @override
  String get sendMessage => 'Send';

  @override
  String get environmentLocal => 'Local RPC (Connected)';

  @override
  String get agentMain => 'Main Agent';

  @override
  String get windowMinimize => 'Minimize';

  @override
  String get windowMaximize => 'Maximize';

  @override
  String get windowRestore => 'Restore';

  @override
  String get windowClose => 'Close';

  @override
  String get currentWorkspace => 'Current Project';

  @override
  String get thinkingIntensity => 'Thinking Intensity';

  @override
  String get thinkingNone => 'Off';

  @override
  String get thinkingLow => 'Low';

  @override
  String get thinkingMedium => 'Medium';

  @override
  String get thinkingHigh => 'High';

  @override
  String get thinkingXHigh => 'X-High';

  @override
  String get thinkingMax => 'Max';

  @override
  String get defaultGroup => 'Default';

  @override
  String get recommendedModels => 'Recommended Models';

  @override
  String get reset => 'Reset';

  @override
  String get back => 'Back';

  @override
  String get thinkingMinimal => 'Minimal';

  @override
  String get modelSearchHint => 'Search models…';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get modelsLoading => 'Reading models from Pi…';

  @override
  String get modelsEmpty =>
      'Pi has no available models. Configure a provider in Pi, then refresh.';

  @override
  String get modelSearchEmpty => 'No matching models';

  @override
  String get modelLoadFailed =>
      'Could not read models. Check that Pi is installed and available on PATH, then retry.';

  @override
  String get modelChangeFailed =>
      'Pi could not confirm the model change. Refresh and try again.';

  @override
  String get modelThinkingFailed =>
      'Pi could not confirm the thinking level. Refresh and try again.';

  @override
  String get piDisconnected => 'Disconnected from Pi. Refresh to reconnect.';

  @override
  String get piNotConnected => 'Pi not connected';

  @override
  String get modelNoSelection => 'Select a model';

  @override
  String get modelRefresh => 'Refresh from Pi';

  @override
  String get modelUpdating => 'Waiting for Pi…';

  @override
  String get thinkingUnavailable =>
      'Pi did not return thinking levels. Update Pi and refresh.';

  @override
  String get thinkingNotSupported => 'This model does not support thinking.';

  @override
  String get modelPickerDismiss => 'Close model picker';

  @override
  String modelAndThinking(String model, String level) {
    return '$model · $level';
  }

  @override
  String availableModelCount(int count) {
    return 'Available models ($count)';
  }

  @override
  String get extensionUnsupported =>
      'This Pi extension UI request is not supported yet.';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get piExtensionInvalidRequest =>
      'A Pi extension sent a request that could not be displayed. Pi is still connected.';

  @override
  String get piReconnecting => 'Reconnecting to Pi…';

  @override
  String get chatYou => 'You';

  @override
  String chatAssistantNumber(int number) {
    return '#$number';
  }

  @override
  String get chatReady => 'Ready';

  @override
  String get chatWorking => 'Working…';

  @override
  String get chatRetrying => 'Pi is retrying after a temporary service error…';

  @override
  String get chatCompacting => 'Compacting context…';

  @override
  String get chatStopping => 'Stopping…';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatLoading => 'Loading conversation…';

  @override
  String get chatWelcome => 'Start with a question';

  @override
  String get chatWelcomeHint =>
      'Ask about code, investigate a problem, or let Pi edit this project.';

  @override
  String get chatInputHint => 'Enter to send · Shift+Enter for a new line';

  @override
  String get chatBusyHint =>
      'Draft your next message while Pi finishes this task.';

  @override
  String get chatThinking => 'Thinking';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatCopied => 'Copied';

  @override
  String get chatCopyFailed => 'Could not copy. Please try again.';

  @override
  String get chatCode => 'Code';

  @override
  String get chatOutput => 'Output';

  @override
  String get chatArguments => 'Arguments';

  @override
  String get chatPreviewLimited =>
      'Preview shortened. Copy to get the full content.';

  @override
  String get chatShowMore => 'Show more';

  @override
  String get chatShowLess => 'Show less';

  @override
  String get chatToolPreparing => 'Preparing';

  @override
  String get chatToolRunning => 'Running';

  @override
  String get chatToolDone => 'Completed';

  @override
  String get chatToolFailed => 'Failed';

  @override
  String get chatToolInterrupted => 'Interrupted';

  @override
  String get chatNoOutput => 'This tool returned no text output.';

  @override
  String get chatChanges => 'File changes';

  @override
  String get chatChangesEmpty => 'No file changes in this conversation yet.';

  @override
  String get chatChangesScope =>
      'Successful file-tool edits in this conversation, not a net Git diff. Changes made through shell commands are not tracked here.';

  @override
  String get chatSelectChange => 'Select a file to inspect its edits';

  @override
  String get chatViewDiff => 'View changes';

  @override
  String get chatDiff => 'Diff';

  @override
  String get chatNoChanges => 'Content unchanged';

  @override
  String get chatEmptyFile => 'Empty file';

  @override
  String get chatFileCreated => 'New file';

  @override
  String chatToolFileStats(int lines, String size) {
    return '$lines lines · $size';
  }

  @override
  String chatToolTimeout(String seconds) {
    return 'Timeout ${seconds}s';
  }

  @override
  String get chatWrittenContent => 'Written content';

  @override
  String get chatNoBaseline =>
      'Pi did not return the previous content. This is the content written, not a before/after diff.';

  @override
  String get chatDiffUnavailable => 'Pi did not return a diff for this edit.';

  @override
  String get chatLatest => 'Jump to latest';

  @override
  String get chatLoadFailed =>
      'Could not load the conversation. Check the Pi connection and refresh.';

  @override
  String get chatSendFailed =>
      'Pi did not accept this message. Your draft is kept. Check the model configuration and retry.';

  @override
  String get chatReplyFailed =>
      'The reply did not finish. Check the model service and quota, then send a message to continue.';

  @override
  String get chatUncertain =>
      'Pi has not confirmed the request. Sending is paused to avoid duplicate execution. Wait for confirmation or refresh the status.';

  @override
  String get chatStopFailed =>
      'Pi has not confirmed it stopped. Try stopping again shortly.';

  @override
  String get chatSessionCancelled =>
      'A Pi extension cancelled the session change. Your conversation is kept.';

  @override
  String get chatInvalidEvent =>
      'A Pi event could not be displayed. The conversation will continue. Refresh after the task to sync.';

  @override
  String get chatAborted => 'Reply stopped';

  @override
  String get chatLengthLimit =>
      'The model reached its output limit. Send a message to continue.';

  @override
  String get chatImageUnavailable =>
      'Could not display this image. It may be missing, damaged or too large.';

  @override
  String get chatUnsupportedContent =>
      'This content block is not supported yet';

  @override
  String get chatOpenLinkFailed =>
      'Could not open the link. Check that the file exists and has a default app. Executables, network shares and custom schemes are not supported.';

  @override
  String get chatRemoteImage => 'Image not loaded automatically';

  @override
  String get chatQueued => 'Queued messages';

  @override
  String get chatRefresh => 'Sync conversation';

  @override
  String get chatSessionHistoryHint =>
      'Pi conversations for this working directory, newest first.';

  @override
  String get chatRead => 'Read';

  @override
  String get chatEdit => 'Edit';

  @override
  String get chatWrite => 'Write';

  @override
  String get chatBash => 'Terminal';

  @override
  String chatFileCount(int count) {
    return 'File changes ($count)';
  }

  @override
  String chatEditCount(int count) {
    return '$count edits';
  }

  @override
  String chatEditNumber(int count) {
    return 'Edit $count';
  }

  @override
  String get workspaceChoose => 'Choose workspace';

  @override
  String get workspaceOpen => 'Open folder';

  @override
  String get workspaceCreate => 'New workspace';

  @override
  String get workspaceName => 'Folder name';

  @override
  String get workspaceParent => 'Choose parent folder';

  @override
  String get workspaceCreateHint =>
      'Create an empty folder here without initializing Git.';

  @override
  String get workspaceRecent => 'Recent workspaces';

  @override
  String get workspaceLoading => 'Loading workspace…';

  @override
  String get workspaceRefresh => 'Refresh workspace and history';

  @override
  String get workspaceBusy =>
      'Wait for the current operation to finish, or stop the running task.';

  @override
  String get workspaceLoadFailed =>
      'Could not load the workspace. Check Node.js and your npm installation of Pi, then refresh.';

  @override
  String get workspacePathFailed =>
      'This folder is unavailable. It may have moved or been deleted. Choose it again.';

  @override
  String get workspaceNameInvalid =>
      'Invalid name. Use a folder name without path separators.';

  @override
  String get workspacePathExists =>
      'The destination already exists. Choose another name or open it instead.';

  @override
  String get workspaceCreateFailed =>
      'Could not create the folder. Check write permissions at the destination.';

  @override
  String get workspaceSwitchFailed =>
      'Could not start Pi in that folder. Recovery of the previous workspace was attempted. Check the folder and Pi configuration.';

  @override
  String get workspaceUnknown =>
      'The backend has not confirmed the operation. Do not create or switch again; wait for confirmation and refresh.';

  @override
  String get workspaceCreatedKept =>
      'The folder was created and kept, but switching did not finish. Reopen it from recent workspaces:';

  @override
  String get workspacePersistenceFailed =>
      'Recent workspaces could not be saved. You may need to select this folder again next time.';

  @override
  String get sessionSearch => 'Search conversation history…';

  @override
  String get sessionNoMatch => 'No matching conversations';

  @override
  String get sessionHistoryFailed =>
      'Could not load conversation history. Refresh to retry.';

  @override
  String get sessionHistoryLoading => 'Loading conversation history…';

  @override
  String get worktreeManage => 'Choose worktree';

  @override
  String get worktreeCreate => 'New worktree';

  @override
  String get worktreeBranch => 'New branch name';

  @override
  String get worktreeBase => 'Start from (branch or full commit SHA)';

  @override
  String get worktreeHead => 'Current commit (HEAD)';

  @override
  String get worktreeDetached => 'Detached HEAD';

  @override
  String get worktreeLocked => 'Locked';

  @override
  String get worktreeUnavailable => 'Directory unavailable';

  @override
  String get worktreeNotGit =>
      'This folder is not a Git repository. Chat is still available.';

  @override
  String get worktreeNoCommit =>
      'This repository has no commits. Make an initial commit before creating a worktree.';

  @override
  String get worktreeDirty =>
      'This folder has uncommitted changes. They will not be copied into the new worktree.';

  @override
  String get worktreeCreateHint =>
      'Create a separate checkout and new branch from the selected commit. The source is unchanged; uncommitted and ignored files are not copied. Switch to the new folder after creation.';

  @override
  String get worktreeLocation => 'New checkouts will be stored in';

  @override
  String get worktreeGitFailed =>
      'Git failed. Check that Git is installed and the folder is writable, then refresh and retry.';

  @override
  String get worktreeBranchInvalid =>
      'Invalid branch name. Choose another name.';

  @override
  String get worktreeBranchExists =>
      'This branch exists. Use a new branch name for the new worktree.';

  @override
  String get worktreeBaseInvalid =>
      'The starting branch changed or is unavailable. Refresh and select it again.';

  @override
  String get workspaceOpenSelected => 'Open workspace';

  @override
  String sessionMessageCount(int count) {
    return '$count messages';
  }

  @override
  String get worktreeRemove => 'Remove worktree';

  @override
  String get worktreeRemoveConfirm =>
      'Remove only the working directory below. Keep the Git branch and Pi sessions. Uncommitted, untracked or ignored files block removal.';

  @override
  String get worktreeInUse =>
      'The main checkout and the current worktree cannot be removed. Switch to another directory first.';

  @override
  String get worktreeDirtyBlocked =>
      'This worktree contains uncommitted, untracked or ignored files. It was not removed. Save or clean them up first.';

  @override
  String get worktreeLockedBlocked =>
      'This worktree is locked and was not removed. Review and unlock it in Git first.';

  @override
  String get workspaceCreateOpen => 'Create and open';

  @override
  String get chatImage => 'Image';

  @override
  String get chatAddImages => 'Add images';

  @override
  String get chatRemoveImage => 'Remove image';

  @override
  String get chatPreviewImage => 'Click to enlarge image';

  @override
  String get chatImageLoading => 'Reading image…';

  @override
  String get chatOpenFile => 'Open with default app';

  @override
  String get chatLoadRemoteImage => 'Click to load remote image';

  @override
  String get chatImagePickFailed =>
      'Could not read the images. Check the files and select them again.';

  @override
  String get chatImageFormat => 'Choose PNG, JPEG, GIF or WebP images.';

  @override
  String get chatImageTooLarge =>
      'Images are too large. Limit: 10 MB each, 20 MB total and 40 megapixels.';

  @override
  String get chatImageTooMany => 'Add up to 8 images per message.';

  @override
  String get chatImageModel =>
      'This model does not support images. Switch models or remove the images.';

  @override
  String get chatAddAttachment => 'Add attachment';

  @override
  String get chatAddFiles => 'Add files';

  @override
  String get chatRemoveAttachment => 'Remove attachment';

  @override
  String get chatPasteImage => 'Pasted image';

  @override
  String get chatPasteFailed =>
      'Could not read clipboard attachments. Copy again or use the plus menu. Relaunch the window after updating the app.';

  @override
  String get chatFilePickFailed =>
      'Could not add the file. Check that it exists and is readable. Folders and network shares are not supported.';

  @override
  String get chatFileTooLarge =>
      'Files can be up to 20 MB each and 50 MB in total.';

  @override
  String get chatFileTooMany => 'You can attach up to 8 files per message.';

  @override
  String get chatFileAttachmentHint =>
      'Pi reads cached copies as needed. PDF and Office documents need suitable tools on the backend.';

  @override
  String chatAttachmentSize(String size) {
    return '$size MB';
  }

  @override
  String get chatLightboxClose => 'Close image (Esc)';

  @override
  String get chatLightboxHint =>
      'Scroll to zoom, drag to pan; double-click to zoom or reset.';

  @override
  String get settingsBack => 'Back to app';

  @override
  String get settingsSearch => 'Search settings…';

  @override
  String get settingsNoResults => 'No matching settings';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceSubtitle =>
      'Adjust colors, glass, text size and interface scale. Changes apply immediately and save automatically.';

  @override
  String get appearanceTheme => 'Theme and colors';

  @override
  String get appearanceMode => 'Appearance mode';

  @override
  String get appearanceModeHint =>
      'Follow the system, or always use light or dark mode.';

  @override
  String get appearanceSystem => 'System';

  @override
  String get appearanceLight => 'Light';

  @override
  String get appearanceDark => 'Dark';

  @override
  String get appearanceSource => 'Color source';

  @override
  String get appearanceSourceHint =>
      'Material 3 generates matching surfaces, text and accents from a seed color.';

  @override
  String get appearanceOriginal => 'Default palette';

  @override
  String get appearanceWindows => 'Windows accent';

  @override
  String get appearanceCustomSeed => 'Custom seed';

  @override
  String get appearanceSeed => 'Seed color';

  @override
  String get appearanceSeedHint =>
      'Generate a full palette rather than painting every surface the same color.';

  @override
  String get appearanceSystemHint =>
      'Reads the Windows accent and refreshes when you return to the app. Enable automatic accent selection in Windows to follow your wallpaper.';

  @override
  String get appearanceSystemUnavailable =>
      'System accent is unavailable; using the default seed. Relaunch after updating the app, or retry.';

  @override
  String get appearanceRefresh => 'Refresh';

  @override
  String get appearanceSizing => 'Text and interface size';

  @override
  String get appearanceFont => 'Base font size';

  @override
  String get appearanceFontHint =>
      'Changes text only, including headings and code. System text scaling is preserved. Default: 13.';

  @override
  String get appearanceScale => 'UI scale';

  @override
  String get appearanceScaleHint =>
      'Scales text, controls, icons and spacing together, on top of system display scaling. Default: 100%.';

  @override
  String get appearanceColors => 'Surface colors';

  @override
  String get appearanceColorsHint =>
      'Override colors for the current mode. Light and dark are saved separately. Changing the source keeps your overrides.';

  @override
  String get appearanceEditingLight => 'Editing light colors';

  @override
  String get appearanceEditingDark => 'Editing dark colors';

  @override
  String get appearanceAdvanced => 'Advanced colors';

  @override
  String get appearanceAdvancedHint => 'Text, borders and status colors';

  @override
  String get appearancePrimary => 'Accent';

  @override
  String get appearanceCanvas => 'Main background';

  @override
  String get appearanceSidebar => 'Title bar and sidebar';

  @override
  String get appearanceComposer => 'Composer';

  @override
  String get appearanceCard => 'Cards';

  @override
  String get appearanceCode => 'Code blocks';

  @override
  String get appearanceUserMessage => 'User messages';

  @override
  String get appearanceElevated => 'Popovers and menus';

  @override
  String get appearanceTextPrimary => 'Primary text';

  @override
  String get appearanceTextSecondary => 'Secondary text';

  @override
  String get appearanceTextMuted => 'Muted text';

  @override
  String get appearanceBorder => 'Borders';

  @override
  String get appearanceSuccess => 'Success / Diff additions';

  @override
  String get appearanceWarning => 'Warning';

  @override
  String get appearanceError => 'Error / Diff removals';

  @override
  String get appearanceAutomatic => 'Automatic';

  @override
  String get appearanceOverridden => 'Custom';

  @override
  String get appearanceResetColor => 'Reset to automatic';

  @override
  String get appearanceResetColors => 'Reset colors for this mode';

  @override
  String get appearanceResetColorsHint =>
      'Clear overrides for the current mode only. Keep text size, scale and the other mode.';

  @override
  String get appearanceResetAll => 'Restore default appearance';

  @override
  String get appearanceResetAllHint =>
      'Restore the default palette, base font size 13 and UI scale 100%. Turn off all glass, reset all tint opacities, and clear custom colors in both modes.';

  @override
  String get appearanceSaving => 'Saving…';

  @override
  String get appearanceSaveFailed =>
      'Changes are applied but could not be saved. Retry or check write access to the app data directory.';

  @override
  String get appearanceLoadFailed =>
      'Saved appearance could not be read. Using defaults for now. Relaunch to retry; editing will save new values.';

  @override
  String get appearanceRetry => 'Retry saving';

  @override
  String get appearancePreview => 'Preview';

  @override
  String get appearancePreviewText =>
      'Text, cards and code follow your appearance settings.';

  @override
  String get appearancePreviewCode => 'const greeting = \"Hello, Pi\";';

  @override
  String get appearanceChooseColor => 'Choose color';

  @override
  String get appearanceHex => ' #RRGGBB';

  @override
  String get appearanceHexInvalid =>
      'Enter a 6-digit hex color, such as #0075DE.';

  @override
  String get appearanceApply => 'Apply color';

  @override
  String get appearanceHue => 'Hue';

  @override
  String get appearanceSaturation => 'Saturation';

  @override
  String get appearanceValue => 'Value';

  @override
  String get appearanceContrastWarning =>
      'This color has low contrast with the current text or background and may be hard to read.';

  @override
  String appearancePercent(int value) {
    return '$value%';
  }

  @override
  String appearanceFontValue(int value) {
    return '$value';
  }

  @override
  String get appearanceGlass => 'Desktop glass';

  @override
  String get appearanceGlassHint =>
      'Separate settings for the title bar and sidebar, main area and cards. Windows blurs the desktop; cards blur in-app backgrounds while text stays clear. Shared by light and dark modes. Requires Windows 11 22H2 or newer.';

  @override
  String get appearanceGlassSidebar => 'Title bar and sidebar glass';

  @override
  String get appearanceGlassSidebarHint =>
      'Applies to the title bar, both sidebars and resize strips together.';

  @override
  String get appearanceGlassCanvas => 'Main area glass';

  @override
  String get appearanceGlassCanvasHint =>
      'Applies to the chat and settings backgrounds. The composer and other cards use the separate Card glass setting below.';

  @override
  String get appearanceGlassSidebarOpacity =>
      'Title bar and sidebar tint opacity';

  @override
  String get appearanceGlassCanvasOpacity => 'Main area tint opacity';

  @override
  String get appearanceGlassCards => 'Card glass';

  @override
  String get appearanceGlassCardsHint =>
      'Applies to tinted cards such as the composer, settings and dialogs. Transparent tool rows stay unchanged. Also enable Main area glass to reveal the desktop; blur is subtle on a flat background.';

  @override
  String get appearanceGlassCardsOpacity => 'Card glass tint opacity';

  @override
  String get appearanceGlassOpacityHint =>
      'Lower is more transparent; 100% is solid. Increase if text is hard to read. Change the tint under Surface colors.';

  @override
  String get appearanceGlassOn => 'On';

  @override
  String get appearanceGlassOff => 'Off';

  @override
  String get appearanceGlassSystemDisabled =>
      'Windows is not allowing transparency. Showing solid colors. Check Transparency effects, contrast themes and battery saver.';

  @override
  String get appearanceGlassUnsupported =>
      'This system does not support the material. Showing solid colors. Windows 11 22H2 or newer is required.';

  @override
  String get appearanceGlassUnavailable =>
      'Native glass is unavailable. Showing solid colors. Update and reopen the app to retry; hot reload cannot load native changes.';

  @override
  String get browserTitle => 'Files and Git';

  @override
  String get browserFiles => 'Files';

  @override
  String get browserGraph => 'Git graph';

  @override
  String get browserRefresh => 'Refresh files and Git';

  @override
  String get browserCollapse => 'Collapse all folders';

  @override
  String get browserLoading => 'Loading…';

  @override
  String get browserEmptyFolder => 'Empty folder';

  @override
  String get browserNoGit => 'This folder is not in a Git repository.';

  @override
  String get browserNoCommits => 'This repository has no commits yet.';

  @override
  String get browserGitMissing =>
      'Git was not found. Install Git and refresh. Files are still available.';

  @override
  String get browserReadFailed =>
      'Could not read this folder. Check access permissions and retry.';

  @override
  String get browserGitFailed =>
      'Could not read Git. Check the repository and refresh.';

  @override
  String get browserOldBackend =>
      'This window has an older backend. Available the next time you launch the updated app; your current chat is unaffected.';

  @override
  String get browserWorkspaceChanged =>
      'The workspace changed. Close this view and select again.';

  @override
  String get browserRetry => 'Retry';

  @override
  String get browserMore => 'Load more';

  @override
  String get browserLimit =>
      'Preview limit reached. Use an external tool for the remaining content.';

  @override
  String get browserContent => 'File contents';

  @override
  String get browserStaged => 'Staged changes';

  @override
  String get browserUnstaged => 'Unstaged changes';

  @override
  String get browserCommitDiff =>
      'Compared with the first parent (empty content for the initial commit)';

  @override
  String get browserBinary =>
      'Binary or non-UTF-8 file. Text preview is unavailable.';

  @override
  String get browserLargeFile =>
      'This file exceeds 256 KiB. Preview is unavailable.';

  @override
  String get browserMissingFile =>
      'This file was deleted. Inspect its changes in the Diff.';

  @override
  String get browserSymlink =>
      'Symbolic links are not followed, to keep browsing within this workspace.';

  @override
  String get browserUnsupported => 'This file type cannot be previewed.';

  @override
  String get browserCommitDetails => 'Commit details';

  @override
  String get browserCommitFilesEmpty =>
      'This commit has no file changes inside this workspace.';

  @override
  String get browserGraphScope =>
      'Local branches, remote-tracking branches and tags in this repository. No network fetch.';

  @override
  String get browserFileScope =>
      'Read-only workspace tree, including hidden and ignored files, excluding .git. Hover status marks for details.';

  @override
  String get browserClean => 'Committed · unchanged';

  @override
  String get browserModified => 'Modified';

  @override
  String get browserStatusStaged => 'Staged';

  @override
  String get browserAdded => 'Added';

  @override
  String get browserDeleted => 'Deleted';

  @override
  String get browserRenamed => 'Renamed';

  @override
  String get browserUntracked => 'Untracked';

  @override
  String get browserIgnored => 'Ignored';

  @override
  String get browserConflict => 'Conflicted';

  @override
  String get browserNoStatus => 'No Git status';

  @override
  String browserIndexStatus(String status) {
    return 'Index: $status';
  }

  @override
  String browserWorktreeStatus(String status) {
    return 'Working tree: $status';
  }

  @override
  String get browserUnchanged => 'Unchanged';

  @override
  String get tabsChat => 'Chat';

  @override
  String get tabsClose => 'Close tab (Ctrl+W)';

  @override
  String get tabsAll => 'All tabs';

  @override
  String get tabsSplit => 'Move to new group on the right';

  @override
  String get tabsMerge => 'Merge all tabs';

  @override
  String get tabsActions => 'Tab actions';

  @override
  String get tabsCloseOthers => 'Close other tabs';

  @override
  String get tabsReadOnly => 'Read-only';

  @override
  String get tabsRefresh => 'Reload this preview';

  @override
  String get workbenchSharedDirectory =>
      'Another session is running in this directory and may edit the same files. Create a worktree to isolate changes.';

  @override
  String get workbenchSearch => 'Search projects, worktrees and sessions…';

  @override
  String get workbenchAddProject => 'Add project';

  @override
  String get workbenchMain => 'Main';

  @override
  String get workbenchWaiting => 'Waiting for you';

  @override
  String get workbenchRunning => 'Running';

  @override
  String get workbenchUnread => 'Unread';

  @override
  String get workbenchHistory => 'History';

  @override
  String get workbenchCloseSession => 'Close session';

  @override
  String get workbenchStopClose => 'Stop and close';

  @override
  String get workbenchCloseRunning =>
      'This session is running or waiting for you. Stop and close ends its Pi process; saved history is kept.';

  @override
  String get workbenchCloseDraft =>
      'This session has unsent text or attachments. Closing discards the draft, but keeps saved history.';

  @override
  String get workbenchForgetProject => 'Remove project from list';

  @override
  String get workbenchForgetHint =>
      'Remove only the registration, not directories, branches or history. Close all sessions in this project first.';

  @override
  String get workbenchName => 'Worktree name';

  @override
  String get workbenchCreateHint =>
      'Creates a separate checkout and branch in the background. Uncommitted and ignored files are not copied; dependencies are not installed. Other sessions keep running.';

  @override
  String get workbenchCreateBackground => 'Create in background';

  @override
  String get workbenchCreating => 'Creating…';

  @override
  String get workbenchFailed => 'Operation failed';

  @override
  String get workbenchNoMatch => 'No matching projects or sessions';

  @override
  String get workbenchEmpty =>
      'Add a project or select a directory in the sidebar to start chatting.';

  @override
  String get workbenchOperationUnknown =>
      'Waiting for backend confirmation. Do not repeat the operation; refresh to check the result.';

  @override
  String get workbenchDisconnected =>
      'This session process exited. Other sessions are unaffected. Close this tab and reopen it from history; messages are never replayed automatically.';

  @override
  String workbenchSessionCount(int count) {
    return '$count sessions';
  }

  @override
  String get workbenchCloseWindow =>
      'Sessions are running or have unsent drafts. Closing this window stops all sessions and discards unsent drafts.';

  @override
  String get workbenchRemoveInUse =>
      'Close every session in this directory before removing the worktree. The main checkout cannot be removed.';

  @override
  String get workbenchWaitBeforeClose =>
      'A workspace operation is still in progress. Wait for creation or removal to finish before closing, to avoid leaving an incomplete Git checkout.';
}
