import 'pi_rpc_client.dart';
import 'pi_rpc_types.dart';
import 'pi_workspace_types.dart';

class PiCatalogWorktree {
  PiCatalogWorktree.fromJson(Object? value) : this._(rpcObject(value));
  PiCatalogWorktree._(Map<String, dynamic> json)
    : path = json['path'] as String,
      name = json['name'] as String,
      branch = json['branch'] as String?,
      main = json['main'] == true,
      folder = json['folder'] == true,
      locked = json['locked'] == true,
      unavailable = json['prunable'] == true;
  final String path, name;
  final String? branch;
  final bool main, folder, locked, unavailable;
}

class PiCatalogProject {
  PiCatalogProject.fromJson(Object? value) : this._(rpcObject(value));
  PiCatalogProject._(Map<String, dynamic> json)
    : path = json['path'] as String,
      name = json['name'] as String,
      git = json['git'] == true,
      baseRef = json['baseRef'] as String? ?? 'HEAD',
      worktreeParent = json['worktreeParent'] as String?,
      hasHead = json['hasHead'] == true,
      branches = List.unmodifiable((json['branches'] as List).cast<String>()),
      worktrees = List.unmodifiable(
        (json['worktrees'] as List).map(PiCatalogWorktree.fromJson),
      );
  final String path, name;
  final bool git, hasHead;
  final String baseRef;
  final String? worktreeParent;
  final List<String> branches;
  final List<PiCatalogWorktree> worktrees;
}

class PiChannelInfo {
  PiChannelInfo.fromJson(Object? value) : this._(rpcObject(value));
  PiChannelInfo._(Map<String, dynamic> json)
    : id = json['id'] as String,
      workspace = json['workspace'] as String,
      sessionFile = json['sessionFile'] as String?,
      status = json['status'] as String;
  final String id, workspace, status;
  final String? sessionFile;
}

class PiWorkspaceJob {
  PiWorkspaceJob.fromJson(Object? value) : this._(rpcObject(value));
  PiWorkspaceJob._(Map<String, dynamic> json)
    : id = json['id'] as String,
      project = json['project'] as String,
      name = json['name'] as String,
      status = json['status'] as String,
      error = json['error'] as String?,
      path = json['path'] as String?;
  final String id, project, name, status;
  final String? error, path;
}

class PiCatalog {
  PiCatalog.fromJson(Object? value) : this._(rpcObject(value));
  PiCatalog._(Map<String, dynamic> json)
    : projects = List.unmodifiable(
        (json['projects'] as List).map(PiCatalogProject.fromJson),
      ),
      channels = List.unmodifiable(
        (json['channels'] as List).map(PiChannelInfo.fromJson),
      ),
      jobs = List.unmodifiable(
        (json['jobs'] as List).map(PiWorkspaceJob.fromJson),
      ),
      persistenceWarning = json['persistenceWarning'] == true;
  final List<PiCatalogProject> projects;
  final List<PiChannelInfo> channels;
  final List<PiWorkspaceJob> jobs;
  final bool persistenceWarning;
}

/// Strongly typed GUI management API; no raw JSON in widgets/controllers.
class PiCatalogService {
  PiCatalogService(this.client);
  final PiRpcClient client;
  Future<PiCatalog> catalog() async =>
      PiCatalog.fromJson(await client.requestGui('gui_get_catalog', {}));
  Future<String> addProject(String path) async =>
      rpcObject(
            await client.requestGui('gui_add_project', {'path': path}),
          )['path']
          as String;
  Future<void> forgetProject(String path) async {
    await client.requestGui('gui_forget_project', {'path': path});
  }

  Future<List<PiSessionSummary>> history(
    String workspace, {
    bool force = false,
  }) async => List.unmodifiable(
    (rpcObject(
              await client.requestGui('gui_workspace_history', {
                'workspace': workspace,
                'force': force,
              }),
            )['sessions']
            as List)
        .map(PiSessionSummary.fromJson),
  );
  Future<PiChannelInfo> open(
    String id,
    String workspace, {
    String? sessionPath,
  }) async => PiChannelInfo.fromJson(
    await client.requestGui('gui_open_channel', {
      'channelId': id,
      'workspace': workspace,
      'sessionPath': ?sessionPath,
    }),
  );
  Future<void> close(String id, {bool stop = false}) async {
    await client.requestGui('gui_close_channel', {
      'channelId': id,
      'stop': stop,
    });
  }

  Future<PiWorkspaceJob> createWorktree(
    String id,
    String project,
    String name,
    String branch,
    String baseRef,
  ) async => PiWorkspaceJob.fromJson(
    await client.requestGui('gui_add_worktree', {
      'operationId': id,
      'project': project,
      'name': name,
      'branch': branch,
      'baseRef': baseRef,
    }),
  );
  Future<PiWorkspaceJob> removeWorktree(
    String id,
    String project,
    String path,
  ) async => PiWorkspaceJob.fromJson(
    await client.requestGui('gui_delete_worktree', {
      'operationId': id,
      'project': project,
      'path': path,
    }),
  );
}
