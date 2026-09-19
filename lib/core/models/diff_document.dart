/// A single retained parse owned by a mounted consumer, not a global history
/// cache. Replacing the input releases the previous document and its lines.
class DiffDocumentMemo {
  DiffDocument? _document;
  bool _numbered = false, _written = false;

  DiffDocument resolve(
    String source, {
    bool numbered = false,
    bool written = false,
  }) {
    if (_document?.source != source ||
        _numbered != numbered ||
        _written != written) {
      _numbered = numbered;
      _written = written;
      _document = written
          ? DiffDocument.written(source)
          : DiffDocument(source, numbered: numbered);
    }
    return _document!;
  }

  void clear() => _document = null;
}

enum DiffLineKind { context, added, removed, header }

class DiffLine {
  const DiffLine(this.text, this.kind, {this.oldLine, this.newLine});
  final String text;
  final DiffLineKind kind;
  final int? oldLine, newLine;
}

/// Parses Pi's standard patch, or its older numbered display diff. No file I/O.
class DiffDocument {
  DiffDocument(this.source, {bool numbered = false})
    : lines = _parse(source, numbered);

  /// A numbered after-view, not an invented diff against an empty file.
  DiffDocument.written(this.source) : lines = _written(source);
  final String source;
  final List<DiffLine> lines;

  /// File labels are already shown by the surrounding tool/file heading.
  late final List<DiffLine> displayLines = List.unmodifiable(
    lines.where(
      (line) =>
          !(line.kind == DiffLineKind.header &&
              (line.text.startsWith('--- ') ||
                  line.text.startsWith('+++ ') ||
                  line.text.startsWith('Index: ') ||
                  line.text.startsWith('==='))),
    ),
  );
  late final int added = lines
      .where((l) => l.kind == DiffLineKind.added)
      .length;
  late final int removed = lines
      .where((l) => l.kind == DiffLineKind.removed)
      .length;

  static List<DiffLine> _written(String source) {
    if (source.isEmpty) return const [];
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    if (lines.last.isEmpty) lines.removeLast();
    return List.unmodifiable([
      for (var i = 0; i < lines.length; i++)
        DiffLine(lines[i], DiffLineKind.context, newLine: i + 1),
    ]);
  }

  static List<DiffLine> _parse(String source, bool numbered) {
    final result = <DiffLine>[];
    final raw = source.replaceAll('\r\n', '\n').split('\n');
    if (raw.isNotEmpty && raw.last.isEmpty) raw.removeLast();
    var oldLine = 0, newLine = 0, inHunk = false;
    final hunk = RegExp(r'^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@');
    final display = RegExp(r'^([ +\-])\s*(\d+) (.*)$');
    for (final line in raw) {
      if (numbered) {
        final match = display.firstMatch(line);
        if (match == null) {
          result.add(DiffLine(line, DiffLineKind.header));
          continue;
        }
        final number = int.parse(match[2]!);
        final kind = match[1] == '+'
            ? DiffLineKind.added
            : match[1] == '-'
            ? DiffLineKind.removed
            : DiffLineKind.context;
        result.add(
          DiffLine(
            match[3]!,
            kind,
            oldLine: kind == DiffLineKind.added ? null : number,
            newLine:
                kind == DiffLineKind.removed || kind == DiffLineKind.context
                ? null
                : number,
          ),
        );
        continue;
      }
      final match = hunk.firstMatch(line);
      if (match != null) {
        oldLine = int.parse(match[1]!);
        newLine = int.parse(match[2]!);
        inHunk = true;
        result.add(DiffLine(line, DiffLineKind.header));
      } else if (inHunk && line.startsWith('+')) {
        result.add(
          DiffLine(line.substring(1), DiffLineKind.added, newLine: newLine++),
        );
      } else if (inHunk && line.startsWith('-')) {
        result.add(
          DiffLine(line.substring(1), DiffLineKind.removed, oldLine: oldLine++),
        );
      } else if (inHunk && line.startsWith(' ')) {
        result.add(
          DiffLine(
            line.substring(1),
            DiffLineKind.context,
            oldLine: oldLine++,
            newLine: newLine++,
          ),
        );
      } else {
        if (!line.startsWith('\\')) inHunk = false;
        result.add(DiffLine(line, DiffLineKind.header));
      }
    }
    return List.unmodifiable(result);
  }
}
