import 'package:flutter/material.dart';
import 'package:pi_gui/core/slots/slot_manager.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/slot_container.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import '../controllers/chat_controller.dart';
import 'tool_card_registry.dart';

class ChatChangesPanel extends StatelessWidget {
  const ChatChangesPanel({super.key, required this.controller});
  final ChatController controller;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final changes = controller.changes;
    final selected = changes.containsKey(controller.selectedChangePath)
        ? controller.selectedChangePath
        : changes.keys.firstOrNull;
    final calls = changes[selected] ?? [];
    return ColoredBox(
      color: context.colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.difference_outlined,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.chatFileCount(changes.length),
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                AppIconButton.subtle(
                  icon: Icons.close,
                  tooltip: l10n.close,
                  onPressed: controller.showChanges,
                ),
              ],
            ),
          ),
          Divider(
            height: 1.0,
            thickness: 1.0,
            color: context.colors.borderDefault,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.chatChangesScope,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (changes.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  l10n.chatChangesEmpty,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            )
          else ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                primary: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                children: [
                  for (final entry in changes.entries)
                    Tooltip(
                      message: entry.key,
                      child: AppNavTile(
                        title: entry.key.replaceAll('\\', '/').split('/').last,
                        subtitle: l10n.chatEditCount(entry.value.length),
                        isSelected: selected == entry.key,
                        leading: const Icon(Icons.description_outlined),
                        onTap: () => controller.selectChange(entry.key),
                      ),
                    ),
                ],
              ),
            ),
            Divider(
              height: 1.0,
              thickness: 1.0,
              color: context.colors.borderDefault,
            ),
            if (selected != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: SelectableText(
                  selected,
                  style: context.textTheme.labelMedium?.copyWith(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  primary: false,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  key: PageStorageKey('changes-$selected'),
                  itemCount: calls.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.chatEditNumber(index + 1),
                          style: context.textTheme.labelSmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ToolChangeDetails(call: calls[index]),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
          const SlotContainer(slotId: ExtensibleSlotId.sidebarPanel),
        ],
      ),
    );
  }
}
