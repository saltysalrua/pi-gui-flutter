import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/rpc/pi_catalog_types.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_channel_hub.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/rpc/pi_workspace_transport.dart';
import 'package:pi_gui/core/rpc/pi_workspace_types.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/core/app_tabs_controller.dart';

import 'chat_controller.dart';
import 'image_attachment_controller.dart';
import 'model_picker_controller.dart';
import 'pi_extension_ui_bridge.dart';
import 'workspace_browser_controller.dart';
import 'workspace_tabs_controller.dart';

class WorkbenchSession {
  WorkbenchSession(this.id, this.workspace, this.client, VoidCallback changed) {
    chat = ChatController(client);
    models = ModelPickerController(client);
    extensions = PiExtensionUiBridge(
      client,
      input,
      slots: slots,
      foreground: false,
      onAttentionChanged: () {
        if (extensions.hasNotifications) unread = true;
        changed();
      },
    );
    Object? lastSummary;
    void summaryChanged() {
      final summary = (
        chat.title,
        chat.activity,
        chat.isSending,
        chat.isLoading,
        chat.sessionFile,
        chat.failure,
        models.isBusy,
      );
      if (summary == lastSummary) return;
      lastSummary = summary;
      changed();
    }

    chat.addListener(summaryChanged);
    models.addListener(summaryChanged);
    attachments.setWorkspace(workspace);
  }
  final String id, workspace;
  final PiRpcClient client;
  final input = TextEditingController();
  final attachments = ImageAttachmentController();
  final slots = SlotManager();
  late final ChatController chat;
  late final ModelPickerController models;
  late final PiExtensionUiBridge extensions;
  bool unread = false,
      hydrating = false,
      disposed = false,
      _hydrateAgain = false;
  String? historyPath;
  bool get busy =>
      chat.isRunning ||
      chat.isSending ||
      chat.isLoading ||
      models.isBusy ||
      extensions.needsAttention ||
      client.hasUnsettledConversationMutation;
  bool get hasDraft => input.text.isNotEmpty || attachments.hasAttachments;
  WorkspaceDocument get document => WorkspaceDocument.chat(id, workspace);
  Future<void> hydrate() async {
    if (disposed) return;
    if (hydrating) {
      _hydrateAgain = true;
      return;
    }
    hydrating = true;
    do {
      _hydrateAgain = false;
      await chat.refresh();
      if (!disposed) await models.refresh();
    } while (_hydrateAgain && !disposed);
    hydrating = false;
  }

  Future<void> dispose() async {
    disposed = true;
    extensions.dispose();
    chat.dispose();
    models.dispose();
    await client.close();
    input.dispose();
    attachments.dispose();
    slots.dispose();
  }
}

class WorkbenchTabs extends AppTabsController<WorkspaceDocument> {
  WorkbenchTabs() : super(home: const WorkspaceDocument.chat(), pinHome: false);
  ValueChanged<WorkspaceDocument>? onClose;
  @override
  void close(WorkspaceDocument tab) => onClose?.call(tab);
  void add(WorkspaceDocument document) {
    final placeholder =
        home.sessionId == null && home.kind == WorkspaceDocumentKind.chat
        ? home
        : null;
    open(document);
    if (placeholder != null) {
      replaceHome(document);
      super.close(placeholder);
    }
  }

  void remove(WorkspaceDocument document) {
    if (document == home) {
      final other = tabs.where((t) => t != document).firstOrNull;
      if (other == null) {
        const placeholder = WorkspaceDocument.chat();
        open(placeholder);
        replaceHome(placeholder);
      } else {
        replaceHome(other);
      }
    }
    super.close(document);
  }
}

/// Project navigation and live conversation ownership. Switching UI selection
/// never issues switch_session, changes cwd, kills a process or replays a prompt.
class WorkbenchController extends ChangeNotifier {
  WorkbenchController({PiChannelHub? hub})
    : hub = hub ?? PiChannelHub(PiWorkspaceTransport.start) {
    control = PiRpcClient(transportFactory: () => this.hub.attach('control'));
    api = PiCatalogService(control);
    _events = control.events.listen((event) {
      if (event is PiAgentEvent && event.type == 'gui_catalog_changed' ||
          event is PiRpcConversationSettled) {
        unawaited(refresh());
      }
    });
    tabs.addListener(_selectionChanged);
  }
  final PiChannelHub hub;
  late final PiRpcClient control;
  late final PiCatalogService api;
  late final StreamSubscription<PiRpcEvent> _events;
  final tabs = WorkbenchTabs();
  final sessions = <String, WorkbenchSession>{};
  final history = <String, List<PiSessionSummary>>{};
  final loadingHistory = <String>{};
  final historyErrors = <String>{};
  final expandedProjects = <String>{}, expandedWorktrees = <String>{};
  // Catalog worktrees and Pi channels may spell the same Windows path with
  // different separators/casing. Share directory state, not raw-string keys.
  final _browsers = HashMap<String, WorkspaceBrowserController>(
    equals: p.equals,
    hashCode: p.hash,
  );
  final _documentTabs = HashMap<String, WorkspaceTabsController>(
    equals: p.equals,
    hashCode: p.hash,
  );
  final _sessionEvents = <String, StreamSubscription<PiRpcEvent>>{};
  PiCatalog? catalog;
  String? failure, catalogFailure, selectedWorkspace, _foreground;
  bool loading = false, opening = false, _disposed = false, _again = false;
  bool _expandedInitial = false, _searchingHistory = false;
  final _historyAgain = <String>{};
  int _sequence = 0;
  String operationId() =>
      'op-${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
  WorkbenchSession? get activeSession => sessions[tabs.selected.sessionId];
  bool get hasWorkspaceOperation =>
      control.hasUnsettledConversationMutation ||
      (control.isConnected &&
          (catalog?.jobs.any((job) => job.status == 'working') ?? false));
  WorkspaceBrowserController? get activeBrowser =>
      selectedWorkspace == null ? null : browserFor(selectedWorkspace!);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String errorCode(Object error) => error is PiRpcException
      ? error.outcomeUnknown
            ? 'OUTCOME_UNKNOWN'
            : error.message
      : 'WORKSPACE_FAILED';

  Future<void> initialize() async {
    await refresh();
  }

  Future<void> refresh() async {
    if (_disposed) return;
    if (loading) {
      _again = true;
      return;
    }
    loading = true;
    _notify();
    do {
      _again = false;
      try {
        final next = await api.catalog();
        if (_disposed) return;
        catalog = next;
        catalogFailure = null;
        for (final info in next.channels) {
          final session = sessions.putIfAbsent(
            info.id,
            () =>
                _makeSession(info.id, info.workspace)
                  ..historyPath = info.sessionFile,
          );
          if (!tabs.tabs.contains(session.document)) {
            tabs.add(session.document);
            unawaited(session.hydrate());
          } else if (info.status == 'ready' && !session.chat.isReady) {
            // Startup extensions can outlive the first read timeout. Read again
            // when Pi becomes ready, without opening/replaying another session.
            unawaited(session.hydrate());
          }
        }
        if (!_expandedInitial && next.projects.isNotEmpty) {
          expandedProjects.add(next.projects.first.path);
          _expandedInitial = true;
        }
        if (selectedWorkspace == null && next.projects.isNotEmpty) {
          selectedWorkspace = next.projects.first.worktrees.firstOrNull?.path;
        }
      } catch (error) {
        if (!_disposed) catalogFailure = errorCode(error);
      }
    } while (_again && !_disposed);
    loading = false;
    _notify();
  }

  WorkbenchSession _makeSession(String id, String workspace) {
    final client = PiRpcClient(transportFactory: () => hub.attach(id));
    final session = WorkbenchSession(id, workspace, client, _notify);
    _sessionEvents[id] = client.events.listen((event) {
      if (_disposed || session.disposed) return;
      if (event is PiChatEvent) {
        if (tabs.selected.sessionId != id &&
            const {'message_end', 'agent_settled'}.contains(event.type)) {
          session.unread = true;
        }
        if (event.type == 'agent_settled') {
          unawaited(loadHistory(workspace, force: true));
          browserFor(workspace).refreshIfOpen();
        }
        if (event.type == 'tool_execution_end') {
          browserFor(workspace).refreshIfOpen();
        }
      }
      if (event is PiRpcDisconnected ||
          event is PiChatEvent &&
              const {
                'message_end',
                'agent_settled',
                'agent_start',
              }.contains(event.type)) {
        _notify();
      }
    });
    return session;
  }

  void _selectionChanged() {
    final doc = tabs.selected;
    selectedWorkspace = doc.workspace ?? selectedWorkspace;
    final id = doc.sessionId;
    if (_foreground != id) {
      sessions[_foreground]?.extensions.setForeground(false);
      _foreground = id;
      sessions[id]?.extensions.setForeground(true);
    }
    if (sessions[id] case final session?) {
      session.unread = false;
      expandedWorktrees.add(session.workspace);
      unawaited(loadHistory(session.workspace));
      for (final project in catalog?.projects ?? <PiCatalogProject>[]) {
        if (project.worktrees.any((w) => p.equals(w.path, session.workspace))) {
          expandedProjects.add(project.path);
        }
      }
    }
    _notify();
  }

  List<WorkbenchSession> sessionsFor(String workspace) =>
      sessions.values.where((s) => p.equals(s.workspace, workspace)).toList();
  WorkspaceBrowserController browserFor(String workspace) =>
      _browsers.putIfAbsent(workspace, () {
        final browser = WorkspaceBrowserController(control)
          ..setWorkspace(workspace);
        browser.addListener(_notify);
        return browser;
      });
  WorkspaceTabsController documentTabsFor(String workspace) =>
      _documentTabs.putIfAbsent(
        workspace,
        () => WorkspaceTabsController(browserFor(workspace)),
      );
  void openFile(String workspace, String path, {String? commit}) {
    browserFor(workspace).selectFile(path);
    tabs.add(WorkspaceDocument.file(workspace, path, commit: commit));
  }

  void openCommit(String workspace, String commit) =>
      tabs.add(WorkspaceDocument.commit(workspace, commit));

  Future<void> loadHistory(String workspace, {bool force = false}) async {
    if (_disposed) return;
    if (loadingHistory.contains(workspace)) {
      if (force) _historyAgain.add(workspace);
      return;
    }
    if (!force && history.containsKey(workspace)) return;
    loadingHistory.add(workspace);
    _notify();
    try {
      final list = await api.history(workspace, force: force);
      if (!_disposed) {
        history[workspace] = list;
        historyErrors.remove(workspace);
      }
    } catch (_) {
      if (!_disposed) historyErrors.add(workspace);
    } finally {
      loadingHistory.remove(workspace);
      if (_historyAgain.remove(workspace)) {
        unawaited(loadHistory(workspace, force: true));
      }
      _notify();
    }
  }

  Future<void> searchHistory() async {
    if (_searchingHistory || _disposed) return;
    _searchingHistory = true;
    try {
      final paths =
          catalog?.projects
              .expand((p) => p.worktrees)
              .where((w) => !w.unavailable)
              .map((w) => w.path)
              .toList() ??
          <String>[];
      for (var i = 0; i < paths.length && !_disposed; i += 2) {
        await Future.wait(
          paths.skip(i).take(2).map((path) => loadHistory(path)),
        );
      }
    } finally {
      _searchingHistory = false;
    }
  }

  void toggleProject(String path) {
    if (!expandedProjects.remove(path)) expandedProjects.add(path);
    _notify();
  }

  void toggleWorktree(String path) {
    if (!expandedWorktrees.remove(path)) {
      expandedWorktrees.add(path);
      unawaited(loadHistory(path));
    }
    _notify();
  }

  Future<void> selectWorktree(String path) async {
    expandedWorktrees.add(path);
    unawaited(loadHistory(path));
    final existing = sessionsFor(path).firstOrNull;
    if (existing != null) {
      tabs.activate(existing.document);
    } else {
      await openSession(path);
    }
  }

  Future<void> openSession(String workspace, {String? sessionPath}) async {
    if (_disposed || opening) return;
    final existing = sessionPath == null
        ? null
        : sessions.values
              .where(
                (s) =>
                    s.chat.sessionFile == sessionPath ||
                    s.historyPath == sessionPath,
              )
              .firstOrNull;
    if (existing != null) {
      tabs.activate(existing.document);
      return;
    }
    opening = true;
    failure = null;
    _notify();
    final id = operationId();
    // Subscribe before the child is launched so startup questions are not lost.
    final provisional = _makeSession(id, workspace)..historyPath = sessionPath;
    sessions[id] = provisional; // Catalog events may arrive before the open acknowledgement.
    try {
      await provisional.client.connect();
      final info = await api.open(id, workspace, sessionPath: sessionPath);
      if (_disposed) {
        await provisional.dispose();
        return;
      }
      if (info.id == id) {
        sessions[id] = provisional;
        tabs.add(provisional.document);
        unawaited(provisional.hydrate());
      } else {
        sessions.remove(id);
        await _sessionEvents.remove(id)?.cancel();
        await provisional.dispose();
        await refresh();
        if (sessions[info.id] case final live?) tabs.activate(live.document);
      }
      expandedWorktrees.add(workspace);
      unawaited(loadHistory(workspace));
    } catch (error) {
      failure = errorCode(error);
      // An uncertain write might have opened a child: catalog reconciliation
      // adopts it, rather than retrying and creating a second conversation.
      if (error is! PiRpcException || !error.outcomeUnknown) {
        sessions.remove(id);
        await _sessionEvents.remove(id)?.cancel();
        await provisional.dispose();
      }
      // Keep the same client subscribed on an unknown outcome. A late catalog
      // acknowledgement must not attach a second listener to its channel.
      unawaited(refresh());
    } finally {
      opening = false;
      _notify();
    }
  }

  Future<bool> closeSession(String id, {bool stop = false}) async {
    final session = sessions[id];
    if (session == null) return true;
    try {
      await api.close(id, stop: stop);
      if (_disposed) return true;
      if (_foreground == id) {
        session.extensions.setForeground(false);
        _foreground = null;
      }
      sessions.remove(id);
      tabs.remove(session.document);
      await _sessionEvents.remove(id)?.cancel();
      // Let the current frame unmount its editor before disposing controllers.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(session.dispose()),
      );
      unawaited(loadHistory(session.workspace, force: true));
      return true;
    } catch (error) {
      failure = errorCode(error);
      _notify();
      return false;
    }
  }

  void dismissFailure() {
    failure = null;
    _notify();
  }

  Future<void> addProject(String path) async {
    failure = null;
    try {
      final workspace = await api.addProject(path);
      await refresh();
      await selectWorktree(workspace);
    } catch (error) {
      failure = errorCode(error);
      _notify();
    }
  }

  Future<void> forgetProject(String path) async {
    failure = null;
    try {
      await api.forgetProject(path);
      await refresh();
    } catch (error) {
      failure = errorCode(error);
      _notify();
    }
  }

  Future<bool> createWorktree(
    PiCatalogProject project,
    String name,
    String branch,
    String baseRef,
  ) async {
    failure = null;
    try {
      await api.createWorktree(
        operationId(),
        project.path,
        name,
        branch,
        baseRef,
      );
      await refresh();
      return true;
    } catch (error) {
      failure = errorCode(error);
      _notify();
      return false;
    }
  }

  Future<void> removeWorktree(
    PiCatalogProject project,
    PiCatalogWorktree worktree,
  ) async {
    failure = null;
    try {
      await api.removeWorktree(operationId(), project.path, worktree.path);
      await refresh();
    } catch (error) {
      failure = errorCode(error);
      _notify();
    }
  }

  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    await _events.cancel();
    for (final event in _sessionEvents.values) {
      await event.cancel();
    }
    for (final session in sessions.values) {
      await session.dispose();
    }
    await control.close();
    await hub.close();
  }

  @override
  void dispose() {
    unawaited(shutdown());
    tabs.removeListener(_selectionChanged);
    tabs.dispose();
    for (final tabs in _documentTabs.values) {
      tabs.dispose();
    }
    for (final browser in _browsers.values) {
      browser.dispose();
    }
    super.dispose();
  }
}
