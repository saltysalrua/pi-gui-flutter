import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' as syntax;

import 'app_card.dart';
import 'app_copy_button.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/app_colors_extension.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_context_extensions.dart';

/// Bounded selectable code/output. Syntax parsing is cached and limited to small,
/// explicitly tagged blocks; unknown languages and large output stay plain text.
class AppCodeBlock extends StatefulWidget {
  const AppCodeBlock({
    super.key,
    required this.code,
    this.label,
    this.language,
    this.maxHeight = 320,
    this.framed = true,
    this.showHeader = true,
    this.previewLines,
    this.textColor,
  });
  final String code;
  final String? label, language;
  final double maxHeight;
  final bool framed, showHeader;
  final int? previewLines;
  final Color? textColor;
  static const previewLimit = 60000;
  @override
  State<AppCodeBlock> createState() => _AppCodeBlockState();
}

class _AppCodeBlockState extends State<AppCodeBlock> {
  String _text = '';
  List<syntax.Node>? _nodes;
  // Highlighted spans are rebuilt only when the parse or palette changes, not
  // on every parent rebuild (streaming rows, hover, tab switches).
  TextSpan? _span;
  Object? _spanColors;
  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(AppCodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.code != oldWidget.code ||
        widget.language != oldWidget.language ||
        widget.previewLines != oldWidget.previewLines) {
      _parse();
    }
  }

  void _parse() {
    _text = widget.code.length > AppCodeBlock.previewLimit
        ? widget.code.substring(0, AppCodeBlock.previewLimit)
        : widget.code;
    if (widget.previewLines case final count?) {
      _text = _text.split('\n').take(count).join('\n');
    }
    _nodes = null;
    _span = null;
    if (widget.language == null ||
        widget.language!.isEmpty ||
        _text.length > 12000) {
      return;
    }
    try {
      _nodes = syntax.highlight
          .parse(_text, language: widget.language!.toLowerCase())
          .nodes;
    } catch (_) {
      /* Unrecognized language: readable plain text is the fallback. */
    }
  }

  TextSpan _nodeSpan(AppColorsExtension colors, syntax.Node node) {
    final color = switch (node.className) {
      'keyword' || 'selector-tag' || 'built_in' => colors.primary,
      'string' || 'regexp' || 'symbol' => colors.success,
      'number' || 'literal' => colors.warning,
      'comment' || 'quote' => colors.textMuted,
      'title' || 'type' || 'attr' => colors.info,
      _ => null,
    };
    return TextSpan(
      text: node.value,
      style: TextStyle(color: color),
      children: node.children
          ?.map((child) => _nodeSpan(colors, child))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    if (_span == null || !identical(_spanColors, colors)) {
      _spanColors = colors;
      _span = TextSpan(
        text: _nodes == null ? _text : null,
        children: _nodes?.map((node) => _nodeSpan(colors, node)).toList(),
      );
    }
    final text = Text.rich(
      _span!,
      softWrap: false,
      overflow: widget.previewLines == null
          ? TextOverflow.visible
          : TextOverflow.clip,
      style: AppTheme.codeStyle(Theme.of(context))
          .copyWith(color: widget.textColor),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader)
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.label ?? context.l10n.chatCode,
                  style: context.textTheme.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppCopyButton(text: widget.code),
            ],
          ),
        if (widget.previewLines != null)
          ClipRect(child: text)
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: SingleChildScrollView(
              primary: false,
              child: SingleChildScrollView(
                primary: false,
                scrollDirection: Axis.horizontal,
                child: SelectionArea(child: text),
              ),
            ),
          ),
        if (widget.previewLines == null && _text.length < widget.code.length)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              context.l10n.chatPreviewLimited,
              style: context.textTheme.bodySmall,
            ),
          ),
      ],
    );
    return widget.framed
        ? AppCard(
            backgroundColor: context.colors.codeBackground,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: content,
          )
        : content;
  }
}
