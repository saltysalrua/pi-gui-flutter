import 'package:flutter/material.dart';

import 'app_action_button.dart';
import 'app_card.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

/// Lazy, persistent disclosure. Inline mode blends into the surrounding surface
/// and may keep a small preview visible without building the expanded content.
class AppDisclosure extends StatefulWidget {
  const AppDisclosure({
    super.key,
    required this.title,
    required this.builder,
    this.titleContent,
    this.leading,
    this.trailing,
    this.subtitle,
    this.initiallyExpanded = false,
    this.framed = true,
    this.previewBuilder,
    this.previewHint,
    this.onExpandedChanged,
  });
  final String title;
  final String? subtitle;
  final Widget? titleContent, leading, trailing;
  final WidgetBuilder builder;
  final WidgetBuilder? previewBuilder;
  final String? previewHint;
  final ValueChanged<bool>? onExpandedChanged;
  final bool initiallyExpanded, framed;
  @override
  State<AppDisclosure> createState() => _AppDisclosureState();
}

class _AppDisclosureState extends State<AppDisclosure> {
  late bool _expanded;
  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  void _restore() {
    if (widget.key != null) {
      _expanded =
          PageStorage.maybeOf(context)
                  ?.readState(context, identifier: (AppDisclosure, widget.key))
              as bool? ??
          _expanded;
    }
    // A remounted row (e.g. its tab was inactive) re-registers restored
    // expansion so owners that pin content stay consistent.
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _restore();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (widget.key != null) {
      // Never share ScrollPosition's implicit PageStorage path (a double).
      PageStorage.maybeOf(context)?.writeState(
        context,
        _expanded,
        identifier: (AppDisclosure, widget.key),
      );
    }
    widget.onExpandedChanged?.call(_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final chevron = AnimatedRotation(
      turns: _expanded ? 0.25 : 0,
      duration: reduceMotion ? Duration.zero : AppDurations.quick,
      curve: AppCurves.inOut,
      child: const Icon(Icons.chevron_right, size: 14),
    );
    final body = _expanded ? widget.builder : widget.previewBuilder;
    final bodyContent = body == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: widget.framed
                ? const EdgeInsets.all(AppSpacing.md)
                : const EdgeInsets.only(
                    left: AppSpacing.xxl,
                    right: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                  ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                body(context),
                if (!_expanded && widget.previewHint != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppActionButton.subtle(
                      label: widget.previewHint!,
                      labelStyle: context.textTheme.bodySmall?.copyWith(
                        color: context.colors.textMuted,
                      ),
                      height: 28,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      onPressed: _toggle,
                    ),
                  ),
              ],
            ),
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: Tooltip(
            message:
                '${widget.title.length > 1000 ? '${widget.title.substring(0, 1000)}…' : widget.title}\n${_expanded ? context.l10n.chatShowLess : context.l10n.chatShowMore}',
            child: AppActionButton.subtle(
              label: widget.title,
              labelContent: widget.titleContent,
              subtitle: widget.subtitle,
              leading: widget.framed ? widget.leading : chevron,
              trailing: widget.framed ? chevron : widget.trailing,
              isExpanded: true,
              expandLabel: widget.framed,
              mainAxisAlignment: MainAxisAlignment.start,
              height: 32,
              padding: EdgeInsets.symmetric(
                horizontal: widget.framed ? AppSpacing.md : AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              onPressed: _toggle,
            ),
          ),
        ),
        // Do not run AnimatedSize with a zero duration: the beta renderer may
        // synchronously re-dirty itself during layout when constraints change.
        if (reduceMotion)
          bodyContent
        else
          AnimatedSize(
            duration: AppDurations.fast,
            curve: AppCurves.smoothOut,
            alignment: Alignment.topCenter,
            child: bodyContent,
          ),
      ],
    );
    return widget.framed
        ? AppCard(padding: EdgeInsets.zero, child: content)
        : content;
  }
}
