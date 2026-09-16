import 'package:flutter/foundation.dart';

import '../../../core/app_tabs_controller.dart';
import 'workspace_browser_controller.dart';

enum WorkspaceDocumentKind { chat, file, commit }

@immutable
class WorkspaceDocument {
  const WorkspaceDocument.chat([this.sessionId, this.workspace])
    : kind = WorkspaceDocumentKind.chat,
      path = null,
      commit = null;
  const WorkspaceDocument.file(this.workspace, this.path, {this.commit})
    : kind = WorkspaceDocumentKind.file,
      sessionId = null;
  const WorkspaceDocument.commit(this.workspace, this.commit)
    : kind = WorkspaceDocumentKind.commit,
      path = null,
      sessionId = null;
  final WorkspaceDocumentKind kind;
  final String? workspace, path, commit, sessionId;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceDocument &&
      kind == other.kind &&
      sessionId == other.sessionId &&
      workspace == other.workspace &&
      path == other.path &&
      commit == other.commit;
  @override
  int get hashCode => Object.hash(kind, sessionId, workspace, path, commit);
}

/// Workspace-bound document identities. Preview requests remain in the browser
/// controller, with its existing generation/late-response checks.
class WorkspaceTabsController extends AppTabsController<WorkspaceDocument> {
  WorkspaceTabsController(this.browser)
    : super(home: const WorkspaceDocument.chat()) {
    _workspace = browser.workspace;
    browser.addListener(_workspaceChanged);
  }
  final WorkspaceBrowserController browser;
  String? _workspace;

  void _workspaceChanged() {
    if (_workspace == browser.workspace) return;
    _workspace = browser.workspace;
    reset();
  }

  void openFile(String path, {String? commit}) {
    final workspace = browser.workspace;
    if (workspace == null) return;
    browser.selectFile(path);
    open(WorkspaceDocument.file(workspace, path, commit: commit));
  }

  void openCommit(String commit) {
    final workspace = browser.workspace;
    if (workspace == null) return;
    browser.selectCommit(commit);
    open(WorkspaceDocument.commit(workspace, commit));
  }

  void showChat() => activate(home);

  @override
  void dispose() {
    browser.removeListener(_workspaceChanged);
    super.dispose();
  }
}
