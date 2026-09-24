import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/core/services/window_material_service.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_desktop_scaffold.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_document_tabs.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_split_panel.dart';
import 'package:pi_gui/ui/atoms/app_tab_workspace.dart';
import 'package:pi_gui/ui/core/chat_resource_scope.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/sidebar_layout_controller.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/core/window_material_scope.dart';

import '../controllers/workbench_controller.dart';
import '../controllers/workspace_tabs_controller.dart';
import '../widgets/home_chat_panel.dart';
import '../widgets/tool_card_registry.dart';
import '../widgets/workbench_sidebar.dart';
import '../widgets/workspace_browser_panel.dart';
import '../widgets/workspace_document_view.dart';
import '../widgets/worktree_create_dialog.dart';
import '../../settings/views/settings_view.dart';
import '../../settings/controllers/appearance_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WindowListener {
  final _workbench = WorkbenchController();
  final _toolCards = ToolCardRegistry();
  bool _closing = false;
  Future<void> _closeQueue = Future.value();
  Timer? _modelRefresh;

  /// Not a motion token: covers the plugin's file-watch debounce (250 ms)
  /// plus its re-registration before the model list is read again.
  static const _providerReloadDelay = Duration(milliseconds: 900);

  /// Provider profiles are live-reloaded by the plugin inside every running
  /// Pi (file watcher, ~250 ms debounce). Re-read each session's model list
  /// once that has happened; no Pi restart and no model change.
  void _refreshModelLists() {
    _modelRefresh?.cancel();
    _modelRefresh = Timer(_providerReloadDelay, () {
      for (final session in _workbench.sessions.values) {
        unawaited(session.models.refresh());
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _workbench.tabs.onClose = (doc) {
      _closeQueue = _closeQueue.then((_) => _closeDocument(doc));
    };
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true).catchError((Object _) {}));
    unawaited(_workbench.initialize());
    _workbench.startIdleSweep();
  }

  Future<bool> _confirm(String title, String message, {String? action}) async =>
      await showAppDialog<bool>(
        context,
        (context) => AppDialog(
          title: title,
          maxWidth: 420,
          actions: [
            AppActionButton.subtle(
              label: context.l10n.cancel,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            AppActionButton(
              label: action ?? context.l10n.confirm,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
          child: Text(message, style: context.textTheme.bodyMedium),
        ),
      ) ==
      true;

  Future<void> _closeDocument(WorkspaceDocument doc) async {
    if (!mounted) return;
    final session = _workbench.sessions[doc.sessionId];
    if (session == null) {
      if (doc.sessionId != null || doc.kind != WorkspaceDocumentKind.chat) {
        _workbench.tabs.remove(doc);
      }
      return;
    }
    final l10n = context.l10n;
    final busy = session.busy;
    if ((busy || session.hasDraft) &&
        !await _confirm(
          l10n.workbenchCloseSession,
          busy ? l10n.workbenchCloseRunning : l10n.workbenchCloseDraft,
          action: busy ? l10n.workbenchStopClose : l10n.close,
        )) {
      return;
    }
    await _workbench.closeSession(session.id, stop: busy);
  }

  Future<void> _addProject() async {
    try {
      final path = await getDirectoryPath(
        confirmButtonText: context.l10n.workbenchAddProject,
      );
      if (mounted && path != null) await _workbench.addProject(path);
    } catch (_) {
      if (mounted) {
        await _confirm(
          context.l10n.workbenchAddProject,
          context.l10n.workspacePathFailed,
        );
      }
    }
  }

  Future<void> _createWorktree(PiCatalogProject project) async {
    final draft = await showAppDialog<WorktreeDraft>(
      context,
      (_) => WorktreeCreateDialog(project: project),
    );
    if (!mounted || draft == null) return;
    unawaited(
      _workbench.createWorktree(
        project,
        draft.name,
        draft.branch,
        draft.baseRef,
      ),
    );
  }

  Future<void> _removeWorktree(
    PiCatalogProject project,
    PiCatalogWorktree worktree,
  ) async {
    if (await _confirm(
      context.l10n.worktreeRemove,
      '${context.l10n.worktreeRemoveConfirm}\n\n${worktree.path}',
    )) {
      await _workbench.removeWorktree(project, worktree);
    }
  }

  Future<void> _forgetProject(PiCatalogProject project) async {
    if (await _confirm(
      context.l10n.workbenchForgetProject,
      '${context.l10n.workbenchForgetHint}\n\n${project.path}',
    )) {
      await _workbench.forgetProject(project.path);
    }
  }

  @override
  void onWindowFocus() {
    _workbench.activeBrowser?.refreshIfOpen();
    // Returning to the app wakes a hibernated foreground session instead
    // of leaving a dead-looking editor behind.
    if (_workbench.activeSession?.hibernating == true) {
      unawaited(_workbench.wakeSession(_workbench.activeSession!.id));
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    if (_workbench.hasWorkspaceOperation) {
      await _confirm(
        context.l10n.windowClose,
        context.l10n.workbenchWaitBeforeClose,
      );
      _closing = false;
      return;
    }
    if (_workbench.sessions.values.any((s) => s.busy || s.hasDraft) &&
        !await _confirm(
          context.l10n.windowClose,
          context.l10n.workbenchCloseWindow,
          action: context.l10n.workbenchStopClose,
        )) {
      _closing = false;
      return;
    }
    // The close is now committed. Remove the window before waiting for the
    // owned process tree (taskkill on Windows); keep Flutter alive until both
    // backend cleanup and pending preference writes have finished.
    try {
      await windowManager.hide();
    } catch (_) {
      // A failed hide must not prevent the actual shutdown.
    }
    try {
      await Future.wait([
        _workbench.shutdown(),
        AppearanceController.instance.settled,
      ]);
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  void dispose() {
    _modelRefresh?.cancel();
    windowManager.removeListener(this);
    _workbench.dispose();
    super.dispose();
  }

  AppDocumentTab<WorkspaceDocument> _tab(WorkspaceDocument doc) {
    final l10n = context.l10n;
    if (doc.kind == WorkspaceDocumentKind.chat) {
      final session = _workbench.sessions[doc.sessionId];
      final title = session?.chat.title;
      return AppDocumentTab(
        id: doc,
        label: title == null || title.isEmpty ? l10n.newConversation : title,
        tooltip:
            '${title == null || title.isEmpty ? l10n.newConversation : title}\n${doc.workspace ?? ''}',
        icon: session?.extensions.needsAttention == true
            ? Icons.notifications_active_outlined
            : Icons.chat_bubble_outline,
        busy:
            session?.chat.isRunning == true &&
            session?.extensions.needsAttention != true,
        closable: session != null,
      );
    }
    final short = doc.commit?.substring(0, 7);
    return AppDocumentTab(
      id: doc,
      label: doc.path == null
          ? '${l10n.browserCommitDetails} · $short'
          : '${doc.path!.split('/').last}${short == null ? '' : ' · $short'}',
      tooltip: [
        doc.workspace!,
        if (doc.path != null) doc.path!,
        if (doc.commit != null) doc.commit!,
      ].join('\n'),
      icon: doc.path == null ? Icons.commit : Icons.description_outlined,
    );
  }

  Widget _document(BuildContext context, WorkspaceDocument doc) {
    final session = _workbench.sessions[doc.sessionId];
    if (doc.kind != WorkspaceDocumentKind.chat) {
      return ChatResourceScope(
        directory: doc.workspace,
        child: WorkspaceDocumentView(
          document: doc,
          tabs: _workbench.documentTabsFor(doc.workspace!),
          onOpenFile: (path, {commit}) =>
              _workbench.openFile(doc.workspace!, path, commit: commit),
        ),
      );
    }
    if (session == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.workbenchEmpty,
                style: context.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppActionButton.subtle(
                label: context.l10n.newConversation,
                leading: const Icon(Icons.add),
                onPressed:
                    _workbench.selectedWorkspace == null || _workbench.opening
                    ? null
                    : () =>
                          _workbench.openSession(_workbench.selectedWorkspace!),
              ),
            ],
          ),
        ),
      );
    }
    return SlotScope(
      manager: session.slots,
      child: ChatResourceScope(
        directory: session.workspace,
        child: HomeChatPanel(
          session: session,
          chat: session.chat,
          modelPicker: session.models,
          input: session.input,
          attachments: session.attachments,
          project: session.workspace.split(RegExp(r'[/\\]')).last,
          registry: _toolCards,
          browser: _workbench.browserFor(session.workspace),
          tabs: _workbench.documentTabsFor(session.workspace),
          conversationOnly: true,
          sharedDirectoryWarning: _workbench
              .sessionsFor(session.workspace)
              .any((s) => s.id != session.id && s.chat.isRunning),
          hibernating: session.hibernating,
          waking: session.waking,
          onWake: () => _workbench.wakeSession(session.id),
          contentBackground: Colors.transparent,
          panelBackground: Colors.transparent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preferences = AppearanceScope.of(context).preferences;
    final layout = SidebarLayoutController.instance;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge([_workbench, layout]),
        builder: (context, _) {
          final browser = _workbench.activeBrowser;
          final material =
              WindowMaterialScope.statusOf(context) ==
              WindowMaterialStatus.active;
          return AppDesktopScaffold(
            sidebarBackground: WindowMaterialScope.tint(
              context,
              colors.sidebarBackground,
              preferences.sidebarGlass,
            ),
            contentBackground: Colors.transparent,
            animate: material,
            sidebarWidth: layout.widthFor(constraints.maxWidth),
            onSidebarResize: (dx) =>
                layout.resizeBy(dx, viewportWidth: constraints.maxWidth),
            onSidebarReset: layout.reset,
            sidebar: WorkbenchSidebar(
              controller: _workbench,
              onAddProject: _addProject,
              onCreateWorktree: _createWorktree,
              onRemoveWorktree: _removeWorktree,
              onForgetProject: _forgetProject,
              onCloseSession: (s) => _workbench.tabs.close(s.document),
              onSettings: () => showSettings(
                context,
                control: _workbench.control,
                onProvidersChanged: _refreshModelLists,
              ),
              onQuota: () => showSettings(
                context,
                control: _workbench.control,
                onProvidersChanged: _refreshModelLists,
                initialPage: SettingsPage.quota,
              ),
            ),
            child: AppSplitPanel(
              isOpen: browser?.isOpen ?? false,
              onDismiss: () => browser?.toggle(),
              contentBackground: WindowMaterialScope.tint(
                context,
                colors.canvasBackground,
                preferences.canvasGlass,
              ),
              panelBackground: WindowMaterialScope.tint(
                context,
                colors.sidebarBackground,
                preferences.sidebarGlass,
              ),
              animateMaterial: material,
              panel: browser == null
                  ? const SizedBox.shrink()
                  : SlotScope(
                      manager:
                          _workbench.activeSession?.slots ??
                          SlotManager.instance,
                      child: WorkspaceBrowserPanel(
                        controller: browser,
                        onOpenFile: (path, {commit}) => _workbench.openFile(
                          browser.workspace!,
                          path,
                          commit: commit,
                        ),
                        onOpenCommit: (commit) =>
                            _workbench.openCommit(browser.workspace!, commit),
                      ),
                    ),
              child: AppTabWorkspace<WorkspaceDocument>(
                controller: _workbench.tabs,
                describeTab: _tab,
                builder: _document,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton.subtle(
                      icon: Icons.add,
                      tooltip: context.l10n.newConversation,
                      onPressed:
                          _workbench.selectedWorkspace == null ||
                              _workbench.opening
                          ? null
                          : () => _workbench.openSession(
                              _workbench.selectedWorkspace!,
                            ),
                    ),
                    AppIconButton.subtle(
                      icon: Icons.snippet_folder_outlined,
                      tooltip: context.l10n.browserTitle,
                      color: browser?.isOpen == true ? colors.primary : null,
                      onPressed: browser?.toggle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
