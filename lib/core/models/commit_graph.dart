import 'dart:math' as math;

/// Topologically ordered DAG input, independent of RPC and painting.
class CommitGraphNode {
  const CommitGraphNode(this.id, this.parents);
  final String id;
  final List<String> parents;
}

class CommitGraphEdge {
  const CommitGraphEdge(
    this.from,
    this.to,
    this.color, {
    this.fromNode = false,
  });
  final int from, to, color;
  final bool fromNode;
}

class CommitGraphRow {
  const CommitGraphRow({
    required this.column,
    required this.color,
    required this.incoming,
    required this.edges,
  });
  final int column, color;
  final bool incoming;
  final List<CommitGraphEdge> edges;
}

/// Each frontier contains unique pending parent IDs. Only actual parent edges
/// are drawn; disconnected roots, merges and unloaded parents stay distinct.
class CommitGraphLayout {
  CommitGraphLayout(Iterable<CommitGraphNode> nodes) {
    final lanes = <String>[];
    final colors = <String, int>{};
    var nextColor = 0;
    for (final node in nodes) {
      final incoming = lanes.contains(node.id);
      if (!incoming) lanes.add(node.id);
      final column = lanes.indexOf(node.id);
      final color = colors.putIfAbsent(node.id, () => nextColor++);
      final before = List<String>.of(lanes);
      lanes.removeAt(column);
      var insertion = math.min(column, lanes.length);
      for (final parent in node.parents.toSet()) {
        if (!lanes.contains(parent)) {
          lanes.insert(insertion++, parent);
          colors.putIfAbsent(
            parent,
            () => parent == node.parents.first ? color : nextColor++,
          );
        }
      }
      final edges = <CommitGraphEdge>[
        for (var i = 0; i < before.length; i++)
          if (before[i] != node.id)
            CommitGraphEdge(i, lanes.indexOf(before[i]), colors[before[i]]!),
        for (final parent in node.parents.toSet())
          CommitGraphEdge(
            column,
            lanes.indexOf(parent),
            colors[parent]!,
            fromNode: true,
          ),
      ];
      rows.add(
        CommitGraphRow(
          column: column,
          color: color,
          incoming: incoming,
          edges: List.unmodifiable(edges),
        ),
      );
      columns = math.max(columns, math.max(before.length, lanes.length));
    }
  }
  final rows = <CommitGraphRow>[];
  int columns = 1;
}
