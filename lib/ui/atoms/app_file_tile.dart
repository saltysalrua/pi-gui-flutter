import 'package:flutter/material.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_card.dart';
import 'app_icon_button.dart';

/// Reusable local file tile; the caller owns data, file opening and removal.
class AppFileTile extends StatelessWidget {
  const AppFileTile({
    super.key,
    required this.name,
    required this.detail,
    this.tooltip,
    this.onOpen,
    this.onRemove,
  });
  final String name, detail;
  final String? tooltip;
  final VoidCallback? onOpen, onRemove;
  static const width = 172.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                hoverColor: context.colors.hoverBackground,
                focusColor: context.colors.primaryTint,
                onTap: onOpen,
                child: Tooltip(
                  message: tooltip ?? name,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file_outlined,
                          size: 28,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ),
              if (onRemove != null)
                AppIconButton.subtle(
                  icon: Icons.close,
                  tooltip: context.l10n.chatRemoveAttachment,
                  onPressed: onRemove,
                ),
            ],
          ),
        ],
      ),
    ),
  );
}
