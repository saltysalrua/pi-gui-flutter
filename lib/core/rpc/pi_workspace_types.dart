import 'pi_rpc_types.dart';

class PiWorkspace {
  const PiWorkspace({required this.path, required this.name});
  factory PiWorkspace.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiWorkspace(
      path: json['path'] as String,
      name: json['name'] as String,
    );
  }
  final String path, name;
}

class PiSessionSummary {
  const PiSessionSummary({
    required this.path,
    required this.id,
    required this.cwd,
    required this.title,
    required this.modified,
    required this.messageCount,
  });
  factory PiSessionSummary.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiSessionSummary(
      path: json['path'] as String,
      id: json['id'] as String,
      cwd: json['cwd'] as String,
      title: json['title'] as String,
      modified: DateTime.parse(json['modified'] as String),
      messageCount: json['messageCount'] as int,
    );
  }
  final String path, id, cwd, title;
  final DateTime modified;
  final int messageCount;
}

class PiWorktree {
  const PiWorktree({
    required this.path,
    this.branch,
    this.detached = false,
    this.locked = false,
    this.prunable = false,
    this.bare = false,
  });
  factory PiWorktree.fromJson(Object? value) {
    final json = rpcObject(value);
    return PiWorktree(
      path: json['path'] as String,
      branch: json['branch'] as String?,
      detached: json['detached'] == true,
      locked: json['locked'] == true,
      prunable: json['prunable'] == true,
      bare: json['bare'] == true,
    );
  }
  final String path;
  final String? branch;
  final bool detached, locked, prunable, bare;
}

class PiGitWorkspace {
  PiGitWorkspace.fromJson(Object? value) : this._(rpcObject(value));
  PiGitWorkspace._(Map<String, dynamic> json)
    : root = json['root'] as String,
      branch = json['branch'] as String?,
      worktreeParent = json['worktreeParent'] as String,
      hasHead = json['hasHead'] as bool,
      dirty = json['dirty'] as bool,
      branches = List.unmodifiable((json['branches'] as List).cast<String>()),
      worktrees = List.unmodifiable(
        (json['worktrees'] as List).map(PiWorktree.fromJson),
      );
  final String root, worktreeParent;
  final String? branch;
  final bool hasHead, dirty;
  final List<String> branches;
  final List<PiWorktree> worktrees;
}

class PiWorkspaceSnapshot {
  PiWorkspaceSnapshot.fromJson(Object? value) : this._(rpcObject(value));
  PiWorkspaceSnapshot._(Map<String, dynamic> json)
    : current = PiWorkspace.fromJson(json['current']),
      recent = List.unmodifiable(
        (json['recent'] as List).map(PiWorkspace.fromJson),
      ),
      git = json['git'] == null ? null : PiGitWorkspace.fromJson(json['git']),
      gitWarning = json['gitWarning'] as String?,
      persistenceWarning = json['persistenceWarning'] == true;
  final PiWorkspace current;
  final List<PiWorkspace> recent;
  final PiGitWorkspace? git;
  final String? gitWarning;
  final bool persistenceWarning;
}

abstract interface class PiWorkspaceGateway {
  Stream<PiRpcEvent> get events;
  bool get hasUnsettledConversationMutation;
  Future<PiWorkspaceSnapshot> getWorkspace();
  Future<List<PiSessionSummary>> listSessions();
  Future<PiWorkspaceSnapshot> openWorkspace(String path);
  Future<String> createWorkspace(String parent, String name);
  Future<String> createWorktree(String branch, String baseRef);
  Future<void> removeWorktree(String path);
}
