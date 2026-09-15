import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pi_gui/core/models/diff_document.dart';
import 'app_card.dart';
import 'app_copy_button.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_context_extensions.dart';

/// Read-only unified diff, or a neutral numbered after-view when no baseline
/// exists. Inline previews have no nested border, toolbar buttons or scrolling.
class AppDiffView extends StatefulWidget {
  const AppDiffView({
    super.key,
    required this.source,
    this.numbered = false,
    this.written = false,
    this.framed = true,
    this.previewLines,
    this.label,
    this.emptyLabel,
    this.maxHeight = 360,
  });
  final String source;
  final String? label, emptyLabel;
  final bool numbered, written, framed;
  final int? previewLines;
  final double maxHeight;
  @override
  State<AppDiffView> createState() => _AppDiffViewState();
}

class _AppDiffViewState extends State<AppDiffView> {
  late DiffDocument _document;
  late List<DiffLine> _lines;
  int _maxColumns = 0;
  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(AppDiffView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.numbered != widget.numbered ||
        oldWidget.written != widget.written) {
      _parse();
    }
  }

  void _parse() {
    _document = widget.written
        ? DiffDocument.written(widget.source)
        : DiffDocument(widget.source, numbered: widget.numbered);
    _lines = _document.displayLines;
    _maxColumns = 0;
    for (final line in _lines) {
      final columns = line.text.runes.fold<int>(
        0,
        (n, rune) =>
            n +
            (rune == 9
                ? 4
                : rune > 255
                ? 2
                : 1),
      );
      _maxColumns = math.max(_maxColumns, columns);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = AppTheme.codeStyle(Theme.of(context));
    final scale = MediaQuery.textScalerOf(context);
    final fontSize = scale.scale(style.fontSize!);
    final rowHeight = fontSize * (style.height ?? 1.4) + AppSpacing.xs;
    final digits = _lines
        .fold<int>(
          1,
          (n, line) =>
              math.max(n, math.max(line.oldLine ?? 0, line.newLine ?? 0)),
        )
        .toString()
        .length;
    final gutter = math.max(2, digits) * fontSize * 0.65 + AppSpacing.sm;
    final count = math.min(widget.previewLines ?? _lines.length, _lines.length);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              widget.label ??
                  (widget.written
                      ? context.l10n.chatWrittenContent
                      : context.l10n.chatDiff),
              style: context.textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
              ),
            ),
            if (!widget.written) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                '+${_document.added}',
                style: style.copyWith(color: colors.success),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '−${_document.removed}',
                style: style.copyWith(color: colors.error),
              ),
            ],
            const Spacer(),
            if (widget.previewLines == null) AppCopyButton(text: widget.source),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_lines.isEmpty)
          Text(
            widget.emptyLabel ??
                (widget.written
                    ? context.l10n.chatEmptyFile
                    : context.l10n.chatNoChanges),
            style: context.textTheme.bodySmall,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final width = math.max(
                constraints.maxWidth,
                // Conservative monospace width, including wide Unicode and tabs.
                _maxColumns * fontSize * 0.65 +
                    gutter * 2 +
                    AppSpacing.xxxl +
                    fontSize,
              );
              Widget rows(double rowWidth, {required bool preview}) => SizedBox(
                width: rowWidth,
                height: math.min(widget.maxHeight, count * rowHeight),
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: preview
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  itemExtent: rowHeight,
                  itemCount: count,
                  itemBuilder: (context, index) {
                    final line = _lines[index];
                    final color = switch (line.kind) {
                      DiffLineKind.added => colors.success,
                      DiffLineKind.removed => colors.error,
                      DiffLineKind.header => colors.info,
                      DiffLineKind.context => colors.textPrimary,
                    };
                    final prefix = switch (line.kind) {
                      DiffLineKind.added => '+',
                      DiffLineKind.removed => '−',
                      _ => ' ',
                    };
                    return ColoredBox(
                      color: color.withValues(
                        alpha:
                            line.kind == DiffLineKind.added ||
                                line.kind == DiffLineKind.removed
                            ? 0.08
                            : 0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xxs,
                        ),
                        child: Row(
                          children: [
                            if (!widget.written)
                              SizedBox(
                                width: gutter,
                                child: Text(
                                  line.oldLine?.toString() ?? '',
                                  textAlign: TextAlign.right,
                                  style: style.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: gutter,
                              child: Text(
                                line.newLine?.toString() ?? '',
                                textAlign: TextAlign.right,
                                style: style.copyWith(color: colors.textMuted),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            if (!widget.written) ...[
                              Text(prefix, style: style.copyWith(color: color)),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            Expanded(
                              child: Text(
                                line.text.replaceAll('\t', '    '),
                                softWrap: false,
                                overflow: TextOverflow.clip,
                                style: style.copyWith(
                                  color: line.kind == DiffLineKind.header
                                      ? colors.textMuted
                                      : colors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
              return widget.previewLines != null
                  ? rows(constraints.maxWidth, preview: true)
                  : SelectionArea(
                      child: SingleChildScrollView(
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        child: rows(width, preview: false),
                      ),
                    );
            },
          ),
      ],
    );
    return widget.framed
        ? AppCard(padding: const EdgeInsets.all(AppSpacing.sm), child: content)
        : content;
  }
}
