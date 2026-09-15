import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_icon_button.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';

class AppCopyButton extends StatefulWidget {
  const AppCopyButton({super.key, required this.text});
  final String text;
  @override
  State<AppCopyButton> createState() => _AppCopyButtonState();
}

class _AppCopyButtonState extends State<AppCopyButton> {
  bool _copied = false;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
      if (!mounted) return;
      _timer?.cancel();
      setState(() => _copied = true);
      _timer = Timer(AppDurations.verySlow * 3, () {
        if (mounted) setState(() => _copied = false);
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(context.l10n.chatCopyFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => AppIconButton.subtle(
    icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
    tooltip: _copied ? context.l10n.chatCopied : context.l10n.chatCopy,
    onPressed: widget.text.isEmpty ? null : _copy,
  );
}
