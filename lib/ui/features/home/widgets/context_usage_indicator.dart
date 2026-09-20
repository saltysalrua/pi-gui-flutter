import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/context_usage_controller.dart';

/// Compact, read-only context meter. Unknown is an empty ring, never a spinner
/// or a claim that the conversation consumes zero tokens.
class ContextUsageIndicator extends StatefulWidget {
  const ContextUsageIndicator({super.key, this.gateway});
  final PiContextGateway? gateway;

  @override
  State<ContextUsageIndicator> createState() => _ContextUsageIndicatorState();
}

class _ContextUsageIndicatorState extends State<ContextUsageIndicator> {
  ContextUsageController? _controller;

  void _bind() {
    final gateway = widget.gateway;
    if (gateway == null) return;
    _controller = ContextUsageController(gateway)..addListener(_changed);
    unawaited(_controller!.refresh());
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(ContextUsageIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.gateway, widget.gateway)) {
      _controller?.dispose();
      _controller = null;
      _bind();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usage = _controller?.usage;
    final l10n = context.l10n;
    final colors = context.colors;
    final percent = usage?.percent;
    final tokens = usage?.tokens;
    final window = usage?.contextWindow;
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final tooltip = percent != null && tokens != null && window != null
        ? l10n.contextUsageDetails(
            NumberFormat('0.#', l10n.localeName).format(percent),
            number.format(tokens),
            number.format(window),
          )
        : window != null
        ? l10n.contextUsagePending(number.format(window))
        : l10n.contextUsageUnavailable;
    return Tooltip(
      message: tooltip,
      waitDuration: AppDurations.micro,
      child: SizedBox.square(
        dimension: 28,
        child: Center(
          child: SizedBox.square(
            dimension: 18,
            child: ExcludeSemantics(
              child: AppProgressIndicator(
                value: (percent ?? 0) / 100,
                color: percent != null && percent >= 90
                    ? colors.error
                    : percent != null && percent >= 75
                    ? colors.warning
                    : colors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
