import 'package:flutter/foundation.dart';

/// 会话简要信息实体
@immutable
class SessionSummary {
  final String id;
  final String title;
  final String projectName;
  final String relativeTime;
  final String? model;
  final DateTime updatedAt;

  const SessionSummary({
    required this.id,
    required this.title,
    required this.projectName,
    required this.relativeTime,
    this.model,
    required this.updatedAt,
  });

  SessionSummary copyWith({
    String? id,
    String? title,
    String? projectName,
    String? relativeTime,
    String? model,
    DateTime? updatedAt,
  }) {
    return SessionSummary(
      id: id ?? this.id,
      title: title ?? this.title,
      projectName: projectName ?? this.projectName,
      relativeTime: relativeTime ?? this.relativeTime,
      model: model ?? this.model,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// 项目及其会话分组
@immutable
class ProjectGroup {
  final String name;
  final String? path;
  final List<SessionSummary> sessions;
  final bool isExpanded;
  final int totalCount;

  const ProjectGroup({
    required this.name,
    this.path,
    required this.sessions,
    this.isExpanded = true,
    this.totalCount = 0,
  });

  ProjectGroup copyWith({
    String? name,
    String? path,
    List<SessionSummary>? sessions,
    bool? isExpanded,
    int? totalCount,
  }) {
    return ProjectGroup(
      name: name ?? this.name,
      path: path ?? this.path,
      sessions: sessions ?? this.sessions,
      isExpanded: isExpanded ?? this.isExpanded,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}
