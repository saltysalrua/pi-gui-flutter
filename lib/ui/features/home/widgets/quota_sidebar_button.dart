import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import 'package:pi_gui/ui/features/settings/controllers/quota_controller.dart';

/// Sidebar entry above the settings tile: click jumps to the settings
/// quota page; hovering shows a compact live quota summary card anchored
/// above the tile (tooltip-style, 80ms enter delay, non-interactive).
class QuotaSidebarButton extends StatefulWidget {
  const QuotaSidebarButton({super.key, required this.onOpenQuota});
  final VoidCallback onOpenQuota;

  @override
  State<QuotaSidebarButton> createState() => _QuotaSidebarButtonState();
}

class _QuotaSidebarButtonState extends State<QuotaSidebarButton> {
  final _anchorKey = GlobalKey();
  OverlayEntry? _hoverCard;
  Timer? _enterTimer;
  Timer? _exitTimer;

  QuotaController get controller => QuotaController.shared;

  @override
  void dispose() {
    _enterTimer?.cancel();
    _exitTimer?.cancel();
    _removeHoverCard();
    super.dispose();
  }

  void _showHoverCard() {
    if (_hoverCard != null || !mounted) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (context) =>
          _QuotaHoverCard(anchorKey: _anchorKey, controller: controller),
    );
    overlay.insert(entry);
    _hoverCard = entry;
  }

  void _removeHoverCard() {
    _hoverCard?.remove();
    _hoverCard = null;
  }

  void _onEnter(PointerEnterEvent event) {
    _exitTimer?.cancel();
    _exitTimer = null;
    // Lazy, stale-aware: first hover fetches; later hovers silently refresh.
    unawaited(controller.ensureFresh());
    if (_hoverCard != null) return;
    _enterTimer?.cancel();
    _enterTimer = Timer(AppDurations.micro, () {
      _enterTimer = null;
      if (mounted) _showHoverCard();
    });
  }

  void _onExit(PointerExitEvent event) {
    _enterTimer?.cancel();
    _enterTimer = null;
    if (_hoverCard == null) return;
    // Grace period so quickly grazing the tile does not flicker the card.
    _exitTimer?.cancel();
    _exitTimer = Timer(AppDurations.quick, () {
      _exitTimer = null;
      _removeHoverCard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      child: AppNavTile(
        key: _anchorKey,
        title: l.quotaPageTitle,
        leading: const Icon(Icons.data_usage_outlined),
        onTap: widget.onOpenQuota,
      ),
    );
  }
}

/// The brief hover card itself: email/plan line plus 5h/7d mini gauges,
/// or a one-line state message when the data is not ready.
class _QuotaHoverCard extends StatefulWidget {
  const _QuotaHoverCard({required this.anchorKey, required this.controller});
  final GlobalKey anchorKey;
  final QuotaController controller;

  @override
  State<_QuotaHoverCard> createState() => _QuotaHoverCardState();
}

class _QuotaHoverCardState extends State<_QuotaHoverCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final anchor = widget.anchorKey.currentContext?.findRenderObject();
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject();
    if (anchor is! RenderBox ||
        overlayBox is! RenderBox ||
        !anchor.attached ||
        !anchor.hasSize) {
      return const SizedBox.shrink();
    }
    return CustomSingleChildLayout(
      delegate: _HoverCardLayout(
        Rect.fromPoints(
          anchor.localToGlobal(Offset.zero, ancestor: overlayBox),
          anchor.localToGlobal(
            anchor.size.bottomRight(Offset.zero),
            ancestor: overlayBox,
          ),
        ),
      ),
      child: _HoverCardBody(controller: widget.controller),
    );
  }
}

class _HoverCardBody extends StatelessWidget {
  const _HoverCardBody({required this.controller});
  final QuotaController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final snapshot = controller.snapshot;
    return Material(
      type: MaterialType.transparency,
      child: AppCard(
        backgroundColor: colors.elevatedBackground,
        width: 240,
        shadows: AppShadows.dialog(
          Theme.of(context).colorScheme.shadow,
          brightness: Theme.of(context).brightness,
        ),
        child: switch (controller.status) {
          QuotaStatus.loading => Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: AppProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  l.quotaLoading,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          QuotaStatus.missing => _statusText(context, l.quotaMissingTitle),
          QuotaStatus.failed => _statusText(
            context,
            switch (controller.failure) {
              QuotaFailure.unauthorized => l.quotaUnauthorizedHint,
              QuotaFailure.network => l.quotaNetworkHint,
              _ => l.quotaParseHint,
            },
          ),
          QuotaStatus.ready => _buildSummary(context, snapshot!),
        },
      ),
    );
  }

  Widget _statusText(BuildContext context, String text) {
    final colors = context.colors;
    return Text(
      text,
      style: context.textTheme.bodySmall?.copyWith(color: colors.textSecondary),
    );
  }

  Widget _buildSummary(BuildContext context, CodexUsageSnapshot snapshot) {
    final l = context.l10n;
    final colors = context.colors;
    final identity = [
      if (snapshot.email.isNotEmpty) snapshot.email,
      if (snapshot.planType.isNotEmpty) snapshot.planType,
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (identity.isNotEmpty)
          Text(
            identity,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        if (identity.isNotEmpty) const SizedBox(height: AppSpacing.sm),
        _MiniGauge(
          label: l.quotaPrimaryWindow,
          percent: snapshot.primaryWindow.usedPercent,
        ),
        if (snapshot.secondaryWindow != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _MiniGauge(
            label: l.quotaSecondaryWindow,
            percent: snapshot.secondaryWindow!.usedPercent,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.quotaOpenDetails,
          style: context.textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
      ],
    );
  }
}

class _MiniGauge extends StatelessWidget {
  const _MiniGauge({required this.label, required this.percent});
  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final barColor = percent >= 90
        ? colors.error
        : percent >= 70
        ? colors.warning
        : colors.success;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: context.textTheme.bodySmall),
            Text(
              '$percent%',
              style: context.textTheme.bodySmall?.copyWith(
                color: barColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppDurations.slow,
            curve: AppCurves.smoothOut,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: colors.mutedBackground,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ),
      ],
    );
  }
}

/// Anchors the card above the tile, right-aligned to it, clamped inside
/// the overlay — same strategy as the model picker's _PopoverLayout.
class _HoverCardLayout extends SingleChildLayoutDelegate {
  _HoverCardLayout(this.anchor);
  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: math.min(240, math.max(0, constraints.maxWidth - 32)),
        maxHeight: math.min(220, math.max(0, constraints.maxHeight - 32)),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    (anchor.right - childSize.width).clamp(
      8.0,
      math.max(8.0, size.width - childSize.width - 8),
    ),
    (anchor.top - childSize.height - AppSpacing.sm).clamp(
      8.0,
      math.max(8.0, size.height - childSize.height - 8),
    ),
  );

  @override
  bool shouldRelayout(_HoverCardLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}
