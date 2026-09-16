import 'pi_rpc_types.dart';

enum PiFileStatus {
  none,
  clean,
  modified,
  staged,
  added,
  deleted,
  renamed,
  untracked,
  ignored,
  conflict,
}

enum PiPreviewKind { text, binary, tooLarge, missing, symlink, unsupported }

class PiFileEntry {
  PiFileEntry.fromJson(Object? value) : this._(rpcObject(value));
  PiFileEntry._(Map<String, dynamic> json)
    : name = json['name'] as String,
      path = json['path'] as String,
      directory = json['directory'] as bool,
      symlink = json['symlink'] as bool,
      missing = json['missing'] as bool,
      status = PiFileStatus.values.byName(json['status'] as String),
      indexStatus = json['indexStatus'] as String,
      worktreeStatus = json['worktreeStatus'] as String;
  final String name, path, indexStatus, worktreeStatus;
  final bool directory, symlink, missing;
  final PiFileStatus status;
}

class PiDirectoryListing {
  PiDirectoryListing.fromJson(Object? value) : this._(rpcObject(value));
  PiDirectoryListing._(Map<String, dynamic> json)
    : workspace = json['workspace'] as String,
      path = json['path'] as String,
      branch = json['branch'] as String?,
      gitWarning = json['gitWarning'] as String?,
      hasMore = json['hasMore'] as bool,
      git = json['git'] as bool,
      entries = List.unmodifiable(
        (json['entries'] as List).map(PiFileEntry.fromJson),
      );
  final String workspace, path;
  final String? branch, gitWarning;
  final bool hasMore, git;
  final List<PiFileEntry> entries;
}

class PiGitCommit {
  PiGitCommit.fromJson(Object? value) : this._(rpcObject(value));
  PiGitCommit._(Map<String, dynamic> json)
    : hash = json['hash'] as String,
      author = json['author'] as String,
      subject = json['subject'] as String,
      date = DateTime.parse(json['date'] as String),
      parents = List.unmodifiable((json['parents'] as List).cast<String>()),
      refs = List.unmodifiable((json['refs'] as List).cast<String>());
  final String hash, author, subject;
  final DateTime date;
  final List<String> parents, refs;
  String get shortHash => hash.substring(0, hash.length < 8 ? hash.length : 8);
}

class PiGitGraph {
  PiGitGraph.fromJson(Object? value) : this._(rpcObject(value));
  PiGitGraph._(Map<String, dynamic> json)
    : workspace = json['workspace'] as String,
      root = json['root'] as String,
      branch = json['branch'] as String?,
      head = json['head'] as String?,
      hasMore = json['hasMore'] as bool,
      commits = List.unmodifiable(
        (json['commits'] as List).map(PiGitCommit.fromJson),
      );
  final String workspace, root;
  final String? branch, head;
  final bool hasMore;
  final List<PiGitCommit> commits;
}

class PiCommitFile {
  PiCommitFile.fromJson(Object? value) : this._(rpcObject(value));
  PiCommitFile._(Map<String, dynamic> json)
    : path = json['path'] as String,
      original = json['original'] as String?,
      status = json['status'] as String;
  final String path, status;
  final String? original;
}

class PiCommitDetails {
  PiCommitDetails.fromJson(Object? value) : this._(rpcObject(value));
  PiCommitDetails._(Map<String, dynamic> json)
    : workspace = json['workspace'] as String,
      hash = json['hash'] as String,
      author = json['author'] as String,
      message = json['message'] as String,
      date = DateTime.parse(json['date'] as String),
      parents = List.unmodifiable((json['parents'] as List).cast<String>()),
      files = List.unmodifiable(
        (json['files'] as List).map(PiCommitFile.fromJson),
      ),
      limited = json['limited'] as bool;
  final String workspace, hash, author, message;
  final DateTime date;
  final List<String> parents;
  final List<PiCommitFile> files;
  final bool limited;
}

class PiFilePreview {
  PiFilePreview.fromJson(Object? value) : this._(rpcObject(value));
  PiFilePreview._(Map<String, dynamic> json)
    : workspace = json['workspace'] as String,
      path = json['path'] as String,
      content = json['content'] as String?,
      kind = PiPreviewKind.values.byName(json['kind'] as String),
      stagedDiff = json['stagedDiff'] as String,
      workingDiff = json['workingDiff'] as String,
      commitDiff = json['commitDiff'] as String,
      diffLimited = json['diffLimited'] as bool;
  final String workspace, path, stagedDiff, workingDiff, commitDiff;
  final String? content;
  final PiPreviewKind kind;
  final bool diffLimited;
  bool get hasDiff =>
      stagedDiff.isNotEmpty ||
      workingDiff.isNotEmpty ||
      commitDiff.isNotEmpty ||
      diffLimited;
}

abstract interface class PiBrowserGateway {
  Stream<PiRpcEvent> get events;
  Future<PiDirectoryListing> listFiles(
    String workspace,
    String path, {
    bool force = false,
    int limit = 500,
  });
  Future<PiGitGraph> getGitGraph(
    String workspace, {
    bool force = false,
    int limit = 100,
  });
  Future<PiCommitDetails> getGitCommit(String workspace, String commit);
  Future<PiFilePreview> getFilePreview(
    String workspace,
    String path, {
    String? commit,
  });
}
