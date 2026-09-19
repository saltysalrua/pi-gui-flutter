import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pi_gui/core/models/chat_timeline.dart';
import 'package:pi_gui/core/models/appearance_preferences.dart';
import 'package:pi_gui/core/models/diff_document.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_activity_label.dart';
import 'package:pi_gui/ui/atoms/app_code_block.dart';
import 'package:pi_gui/ui/atoms/app_diff_view.dart';
import 'package:pi_gui/ui/atoms/app_disclosure.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_image.dart';
import 'package:pi_gui/ui/core/chat_resource_scope.dart';
import 'package:pi_gui/ui/core/chat_tool_output_scope.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_theme.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/features/settings/controllers/appearance_controller.dart';

typedef ToolCardBuilder = Widget Function(
  BuildContext context,
  ChatToolCall call,
  VoidCallback? showChanges,
);

/// Public registration point: custom tools can replace a renderer without editing the timeline.
class ToolCardRegistry {
  ToolCardRegistry();
  final Map<String, ToolCardBuilder> builders = {};
  void register(String name, ToolCardBuilder builder) =>
      builders[name] = builder;
  void unregister(String name) => builders.remove(name);
  Widget build(
    BuildContext context,
    ChatToolCall call, {
    VoidCallback? showChanges,
  }) => (builders[call.name] ?? _defaultBuilder)(context, call, showChanges);

  static Widget _defaultBuilder(
    BuildContext context,
    ChatToolCall call,
    VoidCallback? showChanges,
  ) => _DefaultToolCard(
    key: ValueKey(call.id),
    call: call,
    showChanges: showChanges,
  );

  static Widget _buildDefault(
    BuildContext context,
    ChatToolCall call,
    VoidCallback? showChanges,
    DiffDocument? Function() document,
  ) {
    final l10n = context.l10n;
    final colors = context.colors;
    final display =
        AppearanceScope.maybeOf(context)?.preferences.toolDisplay ??
        ToolDisplayMode.compact;
    final args = call.arguments;
    final shell = call.name == 'bash' || call.name == 'powershell';
    final label = shell ? r'$' : call.name;
    final target = _target(call);
    final range = _readRange(call);
    final evicted = call.evicted;
    final written = evicted ? null : call.writtenContent;
    final stats = written == null
        ? ''
        : l10n.chatToolFileStats(
            _lineCount(written),
            _size(utf8.encode(written).length),
          );
    final title =
        '$label${target.isEmpty ? '' : ' $target'}$range${stats.isEmpty ? '' : ' ($stats)'}';
    final output = call.result?.text ?? '';
    final failed = call.phase == ToolPhase.failed;
    final preview =
        evicted ||
        switch (display) {
          // 收起：只留标题一行，不渲染任何预览。
          ToolDisplayMode.collapsed => false,
          // 展开：直接平铺完整详情（命令、输出、Diff、图片）。
          ToolDisplayMode.expanded => call.isFileChange || output.isNotEmpty,
          // 简略：既有默认样式（成功 read 一行、预览 6/3 行、Diff 8 行）。
          ToolDisplayMode.compact =>
            call.isFileChange ||
                output.isNotEmpty && (call.name != 'read' || failed),
        };
    final phase = switch (call.phase) {
      ToolPhase.preparing => l10n.chatToolPreparing,
      ToolPhase.running => l10n.chatToolRunning,
      ToolPhase.completed => l10n.chatToolDone,
      ToolPhase.failed => l10n.chatToolFailed,
      ToolPhase.interrupted => l10n.chatToolInterrupted,
    };
    final style = AppTheme.codeStyle(Theme.of(context));
    Widget details(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (evicted) ...[
          Text(
            l10n.chatOutputEvicted,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppActionButton.subtle(
              label: l10n.chatReloadOutput,
              leading: const Icon(Icons.refresh),
              onPressed: () =>
                  ChatToolOutputScope.maybeOf(context)?.reload(call.id),
            ),
          ),
        ] else if (shell && args['command'] is String) ...[
          AppCodeBlock(
            code: args['command'] as String,
            framed: false,
            showHeader: false,
          ),
          if (args['timeout'] is num)
            Text(
              l10n.chatToolTimeout(args['timeout'].toString()),
              style: context.textTheme.bodySmall,
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (call.isFileChange && !evicted)
          ToolChangeDetails(call: call, document: document())
        else if (output.isNotEmpty)
          AppCodeBlock(
            code: output,
            label: l10n.chatOutput,
            framed: false,
            textColor: failed ? colors.error : colors.textSecondary,
          )
        else if (!evicted &&
            call.result != null &&
            call.result!.content.every((b) => b.kind != PiContentKind.image))
          Text(l10n.chatNoOutput, style: context.textTheme.bodySmall),
        for (final block in call.result?.content ?? <PiContent>[])
          if (block.kind == PiContentKind.image && !evicted)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: AppImage(image: block.image),
            ),
        if (call.path != null || call.isFileChange && showChanges != null)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (call.isFileChange && showChanges != null)
                  AppIconButton.subtle(
                    icon: Icons.difference_outlined,
                    tooltip: l10n.chatViewDiff,
                    onPressed: showChanges,
                  ),
                if (call.path != null)
                  AppIconButton.subtle(
                    icon: Icons.open_in_new,
                    tooltip: l10n.chatOpenFile,
                    onPressed: () =>
                        ChatResourceScope.open(context, call.path!),
                  ),
              ],
            ),
          ),
      ],
    );
    return AppDisclosure(
      // 挡位参与存储键：切换挡位时重置每张卡片的局部展开记忆，避免收起挡位下残留旧展开状态。
      key: PageStorageKey('tool-${display.name}-${call.id}'),
      framed: false,
      title: title,
      titleContent: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            if (target.isNotEmpty)
              TextSpan(
                text: ' $target',
                style: TextStyle(
                  color: shell ? colors.textPrimary : colors.primary,
                ),
              ),
            if (range.isNotEmpty)
              TextSpan(
                text: range,
                style: TextStyle(color: colors.warning),
              ),
            if (stats.isNotEmpty)
              TextSpan(
                text: ' ($stats)',
                style: TextStyle(color: colors.textMuted),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
      trailing: switch (call.phase) {
        ToolPhase.completed => null,
        ToolPhase.preparing ||
        ToolPhase.running => AppActivityLabel(text: phase, active: true),
        _ => Tooltip(
          message: phase,
          child: Icon(
            failed ? Icons.error_outline : Icons.stop_circle_outlined,
            color: failed ? colors.error : colors.warning,
            size: 14,
          ),
        ),
      },
      previewBuilder: !preview
          ? null
          : display == ToolDisplayMode.expanded
          ? details
          : evicted
          ? (_) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Text(
                l10n.chatOutputEvicted,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            )
          : (_) => call.isFileChange
                ? ToolChangeDetails(
                    call: call,
                    previewLines: 8,
                    document: document(),
                  )
                : AppCodeBlock(
                    code: output,
                    framed: false,
                    showHeader: false,
                    previewLines: failed ? 3 : 6,
                    textColor: failed ? colors.error : colors.textSecondary,
                  ),
      previewHint:
          display == ToolDisplayMode.compact &&
              preview &&
              !evicted &&
              _previewTruncated(call, failed ? 3 : 6, document)
          ? l10n.chatShowMore
          : null,
      // Expanded rows pin their full output against the byte budget;
      // collapsing releases the pin again.
      onExpandedChanged: ChatToolOutputScope.maybeOf(context) == null
          ? null
          : (expanded) =>
                ChatToolOutputScope.maybeOf(context)!
                    .setPinned(call.id, expanded),
      builder: details,
    );
  }

  // Only a tool's useful identity is projected; arbitrary arguments are never dumped.
  static String _target(ChatToolCall call) {
    final args = call.arguments;
    final query = args['query'] ?? args['pattern'];
    if (query is String && query.isNotEmpty) {
      return [
        query,
        if (call.path != null) call.path!,
      ].join(' · ').replaceAll(RegExp(r'\s+'), ' ');
    }
    final value =
        call.path ??
        args['command'] ??
        args['url'] ??
        args['tool'] ??
        args['symbol'] ??
        args['operation'];
    return value is String ? value.replaceAll(RegExp(r'\s+'), ' ') : '';
  }

  static String _readRange(ChatToolCall call) {
    if (call.name != 'read') return '';
    final offset = call.arguments['offset'];
    final limit = call.arguments['limit'];
    final start = offset is int && offset > 0 ? offset : 1;
    if (limit is int && limit > 0) return ':$start-${start + limit - 1}';
    return offset is int && offset > 0 ? ':$start' : '';
  }

  static int _lineCount(String text) => text.isEmpty
      ? 0
      : '\n'.allMatches(text).length + (text.endsWith('\n') ? 0 : 1);

  static bool _previewTruncated(
    ChatToolCall call,
    int outputLines,
    DiffDocument? Function() document,
  ) {
    if (!call.isFileChange) {
      return _lineCount(call.result?.text ?? '') > outputLines;
    }
    return (document()?.displayLines.length ?? 0) > 8;
  }

  static String _size(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes / 1024).toStringAsFixed(1)} KiB';
}

/// One lazy parse per mounted tool row, shared by its hint, preview and details.
/// No cache is attached to the timeline or shared across closed sessions.
class _DefaultToolCard extends StatefulWidget {
  const _DefaultToolCard({super.key, required this.call, this.showChanges});
  final ChatToolCall call;
  final VoidCallback? showChanges;

  @override
  State<_DefaultToolCard> createState() => _DefaultToolCardState();
}

class _DefaultToolCardState extends State<_DefaultToolCard> {
  final _diff = DiffDocumentMemo();

  @override
  void didUpdateWidget(_DefaultToolCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.call, widget.call)) _diff.clear();
  }

  DiffDocument? _document() {
    final call = widget.call;
    final patch = call.result?.patch ?? call.result?.diff;
    final source = patch ?? call.writtenContent;
    if (source == null) return null;
    return _diff.resolve(
      source,
      numbered: call.result?.patch == null,
      written: patch == null,
    );
  }

  @override
  Widget build(BuildContext context) => ToolCardRegistry._buildDefault(
    context,
    widget.call,
    widget.showChanges,
    _document,
  );
}

/// Inline previews and the changes panel show the same backend evidence.
class ToolChangeDetails extends StatelessWidget {
  const ToolChangeDetails({
    super.key,
    required this.call,
    this.previewLines,
    this.document,
  });
  final ChatToolCall call;
  final int? previewLines;
  final DiffDocument? document;
  @override
  Widget build(BuildContext context) {
    final result = call.result;
    final patch = result?.patch ?? result?.diff;
    final written = call.writtenContent;
    final created = result?.writeKind == PiWriteKind.created;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (patch != null)
          AppDiffView(
            source: patch,
            document: document,
            label: created ? context.l10n.chatFileCreated : null,
            emptyLabel: created ? context.l10n.chatEmptyFile : null,
            numbered: result?.patch == null,
            framed: false,
            previewLines: previewLines,
          )
        else if (written != null) ...[
          Text(
            context.l10n.chatNoBaseline,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppDiffView(
            source: written,
            document: document,
            written: true,
            framed: false,
            previewLines: previewLines,
          ),
        ] else
          Text(
            context.l10n.chatDiffUnavailable,
            style: context.textTheme.bodySmall,
          ),
      ],
    );
  }
}
