import 'package:flutter/material.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

/// 通用文本输入原子：搜索与扩展输入复用，状态样式统一交给主题。
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.leading,
    this.trailing,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.isCompact = false,
    this.focusNode,
    this.minLines,
    this.borderless = false,
    this.onPaste,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged, onSubmitted;
  final Widget? leading, trailing;
  final bool autofocus, enabled;
  final int? maxLines, minLines;
  final FocusNode? focusNode;
  final bool isCompact, borderless;

  /// Return true when a non-text paste was handled; false preserves Flutter text editing.
  final Future<bool> Function()? onPaste;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: BorderSide(color: color),
    );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: maxLines == 1
          ? TextInputType.text
          : TextInputType.multiline,
      style:
          (borderless
                  ? context.textTheme.bodyLarge
                  : context.textTheme.bodyMedium)
              ?.copyWith(color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: context.textTheme.bodyMedium?.copyWith(
          color: colors.textMuted,
        ),
        prefixIcon: leading == null
            ? null
            : IconTheme(
                data: IconThemeData(
                  size: isCompact ? 16 : 20,
                  color: colors.textSecondary,
                ),
                child: leading!,
              ),
        suffixIcon: trailing,
        prefixIconConstraints: isCompact
            ? const BoxConstraints(minWidth: 32, minHeight: 32)
            : null,
        suffixIconConstraints: isCompact
            ? const BoxConstraints(minWidth: 28, minHeight: 28)
            : null,
        prefixIconColor: colors.textSecondary,
        suffixIconColor: colors.textSecondary,
        isDense: true,
        contentPadding: borderless
            ? const EdgeInsets.symmetric(vertical: AppSpacing.xs)
            : isCompact
            ? const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              )
            : const EdgeInsets.all(AppSpacing.md),
        border: borderless ? InputBorder.none : null,
        enabledBorder: borderless
            ? InputBorder.none
            : border(colors.borderDefault),
        focusedBorder: borderless
            ? InputBorder.none
            : border(colors.borderFocus),
        disabledBorder: borderless
            ? InputBorder.none
            : border(colors.mutedBackground),
        hoverColor: colors.hoverBackground,
        filled: !borderless,
        fillColor: enabled ? colors.cardBackground : colors.mutedBackground,
      ),
    );
    if (onPaste == null) return field;
    return Actions(
      actions: {
        PasteTextIntent: _AttachmentPasteAction(
          onPaste: onPaste!,
          controller: controller,
          focusNode: focusNode,
        ),
      },
      child: field,
    );
  }
}

class _AttachmentPasteAction extends Action<PasteTextIntent> {
  _AttachmentPasteAction({
    required this.onPaste,
    required this.controller,
    this.focusNode,
  });
  final Future<bool> Function() onPaste;
  final TextEditingController controller;
  final FocusNode? focusNode;

  @override
  Object? invoke(PasteTextIntent intent) {
    final delegate = callingAction;
    final before = controller.value;
    return onPaste().then((handled) {
      // Do not insert delayed clipboard text into a new session or changed selection.
      if (!handled &&
          controller.value == before &&
          focusNode?.hasFocus != false) {
        delegate?.invoke(intent);
      }
    });
  }
}
