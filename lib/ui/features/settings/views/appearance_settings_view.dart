import 'package:flutter/material.dart';

import '../../../../core/models/appearance_preferences.dart';
import '../../../../core/services/window_material_service.dart';
import '../../../../core/slots/slot_manager.dart';
import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_code_block.dart';
import '../../../atoms/app_color_picker.dart';
import '../../../atoms/app_dialog.dart';
import '../../../atoms/app_disclosure.dart';
import '../../../atoms/app_icon_button.dart';
import '../../../atoms/app_select.dart';
import '../../../atoms/app_setting.dart';
import '../../../atoms/app_stepped_slider.dart';
import '../../../core/context_l10n.dart';
import '../../../core/theme/appearance_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../../../core/window_material_scope.dart';
import '../appearance_labels.dart';
import '../controllers/appearance_controller.dart';

/// The appearance settings page content, hosted by SettingsView.
class AppearanceSettingsContent extends StatefulWidget {
  const AppearanceSettingsContent({
    super.key,
    required this.controller,
    required this.scrollController,
    this.padding = EdgeInsets.zero,
    this.query = '',
  });
  final AppearanceController controller;
  final ScrollController scrollController;
  final EdgeInsetsGeometry padding;
  final String query;
  @override
  State<AppearanceSettingsContent> createState() =>
      _AppearanceSettingsContentState();
}

class _AppearanceSettingsContentState extends State<AppearanceSettingsContent> {
  double? _fontDraft;
  bool _matches(String text) =>
      text.toLowerCase().contains(widget.query.toLowerCase());

  Future<void> _resetAll() async {
    final l = context.l10n;
    final confirmed = await showAppDialog<bool>(
      context,
      (context) => AppDialog(
        title: l.appearanceResetAll,
        actions: [
          AppActionButton.subtle(
            label: l.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppActionButton(
            label: l.reset,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(
          l.appearanceResetAllHint,
          style: context.textTheme.bodyMedium,
        ),
      ),
    );
    if (confirmed == true && mounted) widget.controller.reset();
  }

  Future<void> _pick(AppearanceColor key) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;
    final value = await showAppColorPicker(
      context,
      title: appearanceColorLabel(context.l10n, key),
      initial: AppearancePalette.value(colors, key),
      contrastAgainst: switch (key) {
        AppearanceColor.canvas ||
        AppearanceColor.sidebar ||
        AppearanceColor.card ||
        AppearanceColor.composer ||
        AppearanceColor.code ||
        AppearanceColor.userMessage ||
        AppearanceColor.elevated => colors.textPrimary,
        AppearanceColor.textPrimary ||
        AppearanceColor.textSecondary ||
        AppearanceColor.textMuted => colors.canvasBackground,
        _ => null,
      },
    );
    if (value != null && mounted) {
      widget.controller.update(
        widget.controller.preferences.withColor(
          key,
          value.toARGB32(),
          dark: dark,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.controller.statusChanges,
    ]),
    builder: (context, _) {
      final controller = widget.controller;
      final p = controller.preferences;
      final l = context.l10n;
      final colors = context.colors;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final overrides = dark ? p.darkColors : p.lightColors;
      final groups = <Widget>[];
      void group(String title, String? description, List<AppSettingRow> rows) {
        final visible = rows
            .where(
              (r) => _matches(
                '$title ${description ?? ''} ${r.title} ${r.description ?? ''}',
              ),
            )
            .toList();
        if (visible.isNotEmpty) {
          groups.add(
            AppSettingsGroup(
              key: ValueKey(title),
              title: title,
              description: description,
              children: visible,
            ),
          );
        }
      }

      group(l.appearanceTheme, null, [
        AppSettingRow(
          title: l.appearanceMode,
          description: l.appearanceModeHint,
          control: AppSelect<AppearanceMode>(
            value: p.mode,
            label: l.appearanceMode,
            options: [
              AppSelectOption(AppearanceMode.system, l.appearanceSystem),
              AppSelectOption(AppearanceMode.light, l.appearanceLight),
              AppSelectOption(AppearanceMode.dark, l.appearanceDark),
            ],
            onChanged: (v) => controller.update(p.copyWith(mode: v)),
          ),
        ),
        AppSettingRow(
          title: l.appearanceSource,
          description: l.appearanceSourceHint,
          control: AppSelect<PaletteSource>(
            value: p.source,
            label: l.appearanceSource,
            options: [
              AppSelectOption(PaletteSource.original, l.appearanceOriginal),
              AppSelectOption(PaletteSource.system, l.appearanceWindows),
              AppSelectOption(PaletteSource.custom, l.appearanceCustomSeed),
            ],
            onChanged: (v) => controller.update(p.copyWith(source: v)),
          ),
        ),
        if (p.source == PaletteSource.custom)
          AppSettingRow(
            title: l.appearanceSeed,
            description: l.appearanceSeedHint,
            control: AppColorButton(
              color: Color(p.seed),
              onPressed: () async {
                final color = await showAppColorPicker(
                  context,
                  initial: Color(p.seed),
                  title: l.appearanceSeed,
                );
                if (color != null && mounted) {
                  controller.update(
                    controller.preferences.copyWith(seed: color.toARGB32()),
                  );
                }
              },
            ),
          ),
        if (p.source == PaletteSource.system)
          AppSettingRow(
            title: l.appearanceWindows,
            description: controller.systemAccent == null
                ? l.appearanceSystemUnavailable
                : l.appearanceSystemHint,
            control: AppActionButton.subtle(
              label: l.appearanceRefresh,
              leading: controller.systemAccent == null
                  ? const Icon(Icons.refresh)
                  : AppColorSwatch(color: controller.systemAccent!),
              isLoading: controller.systemColorBusy,
              onPressed: controller.refreshSystemColor,
            ),
          ),
      ]);
      group(l.appearanceSizing, null, [
        AppSettingRow(
          title: l.appearanceFont,
          description: l.appearanceFontHint,
          control: SizedBox(
            width: 210,
            child: Row(
              children: [
                Expanded(
                  child: AppSteppedSlider(
                    steps: 7,
                    value:
                        ((_fontDraft ?? p.baseFontSize) -
                                AppearancePreferences.minFontSize)
                            .round()
                            .clamp(0, 6),
                    height: 16,
                    thumbSize: 22,
                    semanticLabel: l.appearanceFont,
                    valueLabel: l.appearanceFontValue(
                      (_fontDraft ?? p.baseFontSize).round(),
                    ),
                    onChanged: (v) => setState(
                      () => _fontDraft = AppearancePreferences.minFontSize + v,
                    ),
                    onChangeEnd: (v) {
                      controller.update(
                        controller.preferences.copyWith(
                          baseFontSize: AppearancePreferences.minFontSize + v,
                        ),
                      );
                      setState(() => _fontDraft = null);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Text(
                  l.appearanceFontValue((_fontDraft ?? p.baseFontSize).round()),
                  style: context.textTheme.labelLarge,
                ),
              ],
            ),
          ),
        ),
        AppSettingRow(
          title: l.appearanceScale,
          description: l.appearanceScaleHint,
          control: AppSelect<double>(
            value: p.uiScale,
            label: l.appearanceScale,
            options: [
              for (final v in {
                ...AppearancePreferences.scaleOptions,
                p.uiScale,
              }.toList()..sort())
                AppSelectOption(v, l.appearancePercent((v * 100).round())),
            ],
            onChanged: (v) => controller.update(p.copyWith(uiScale: v)),
          ),
        ),
      ]);
      List<AppSelectOption<int>> frameOptions() => [
        for (final rate in AppearancePreferences.frameRateChoices)
          AppSelectOption(
            rate,
            rate == 0
                ? l.appearanceFrameRateDisplay
                : l.appearanceFrameRateValue(rate),
          ),
      ];
      group(l.appearancePerformance, null, [
        AppSettingRow(
          title: l.appearanceFrameRate,
          description: l.appearanceFrameRateHint,
          control: AppSelect<int>(
            value: p.frameRate,
            label: l.appearanceFrameRate,
            options: frameOptions(),
            onChanged: (v) => controller.update(p.copyWith(frameRate: v)),
          ),
        ),
        AppSettingRow(
          title: l.appearanceAnimationFrameRate,
          description: l.appearanceAnimationFrameRateHint,
          control: AppSelect<int>(
            value: p.animationFrameRate,
            label: l.appearanceAnimationFrameRate,
            options: frameOptions(),
            onChanged: (v) =>
                controller.update(p.copyWith(animationFrameRate: v)),
          ),
        ),
      ]);
      group(l.appearanceToolDisplay, l.appearanceToolDisplayHint, [
        AppSettingRow(
          title: l.appearanceToolDensity,
          description: switch (p.toolDisplay) {
            ToolDisplayMode.collapsed => l.appearanceToolCollapsedHint,
            ToolDisplayMode.compact => l.appearanceToolCompactHint,
            ToolDisplayMode.expanded => l.appearanceToolExpandedHint,
          },
          control: AppSelect<ToolDisplayMode>(
            value: p.toolDisplay,
            label: l.appearanceToolDisplay,
            options: [
              AppSelectOption(
                ToolDisplayMode.collapsed,
                l.appearanceToolCollapsed,
              ),
              AppSelectOption(ToolDisplayMode.compact, l.appearanceToolCompact),
              AppSelectOption(
                ToolDisplayMode.expanded,
                l.appearanceToolExpanded,
              ),
            ],
            onChanged: (v) => controller.update(p.copyWith(toolDisplay: v)),
          ),
        ),
      ]);
      group(l.appearanceHibernate, l.appearanceHibernateHint, [
        AppSettingRow(
          title: l.appearanceHibernate,
          description: switch (p.sessionIdleMinutes) {
            0 => l.hibernateNever,
            15 => l.hibernate15Minutes,
            _ => l.hibernate60Minutes,
          },
          control: AppSelect<int>(
            value: p.sessionIdleMinutes,
            label: l.appearanceHibernate,
            options: [
              for (final v in AppearancePreferences.idleMinuteChoices)
                AppSelectOption(v, switch (v) {
                  0 => l.hibernateNever,
                  15 => l.hibernate15Minutes,
                  _ => l.hibernate60Minutes,
                }),
            ],
            onChanged: (v) =>
                controller.update(p.copyWith(sessionIdleMinutes: v)),
          ),
        ),
      ]);
      AppSettingRow slotRow(ExtensibleSlotId slot, String title, String hint) =>
          AppSettingRow(
            title: title,
            description: hint,
            control: AppSelect<bool>(
              value: p.isSlotVisible(slot.name),
              label: title,
              options: [
                AppSelectOption(false, l.appearanceOff),
                AppSelectOption(true, l.appearanceOn),
              ],
              onChanged: (v) => controller.update(
                p.copyWith(slotVisibility: {...p.slotVisibility, slot.name: v}),
              ),
            ),
          );
      group(l.appearanceExtensionSlots, l.appearanceExtensionSlotsHint, [
        slotRow(
          ExtensibleSlotId.aboveEditor,
          l.appearanceSlotAboveEditor,
          l.appearanceSlotAboveEditorHint,
        ),
        slotRow(
          ExtensibleSlotId.belowEditor,
          l.appearanceSlotBelowEditor,
          l.appearanceSlotBelowEditorHint,
        ),
        slotRow(
          ExtensibleSlotId.statusBar,
          l.appearanceSlotStatusBar,
          l.appearanceSlotStatusBarHint,
        ),
        slotRow(
          ExtensibleSlotId.sidebarPanel,
          l.appearanceSlotSidebarPanel,
          l.appearanceSlotSidebarPanelHint,
        ),
        slotRow(
          ExtensibleSlotId.notificationToast,
          l.appearanceSlotNotificationToast,
          l.appearanceSlotNotificationToastHint,
        ),
      ]);
      final glassStatus = WindowMaterialScope.statusOf(context);
      final glassNotice = !p.wantsGlass
          ? null
          : switch (glassStatus) {
              WindowMaterialStatus.systemDisabled =>
                l.appearanceGlassSystemDisabled,
              WindowMaterialStatus.unsupported => l.appearanceGlassUnsupported,
              WindowMaterialStatus.unavailable => l.appearanceGlassUnavailable,
              _ => null,
            };
      List<AppSettingRow> glassRows({
        required String title,
        required String hint,
        required String opacityTitle,
        required GlassPreferences glass,
        required ValueChanged<GlassPreferences> onChanged,
      }) => [
        AppSettingRow(
          title: title,
          description: hint,
          control: AppSelect<bool>(
            value: glass.enabled,
            label: title,
            options: [
              AppSelectOption(false, l.appearanceGlassOff),
              AppSelectOption(true, l.appearanceGlassOn),
            ],
            onChanged: (enabled) => onChanged(glass.copyWith(enabled: enabled)),
          ),
        ),
        if (glass.enabled)
          AppSettingRow(
            title: opacityTitle,
            description: l.appearanceGlassOpacityHint,
            control: SizedBox(
              width: 210,
              child: Row(
                children: [
                  Expanded(
                    child: AppSteppedSlider(
                      steps: 17,
                      value:
                          ((glass.opacity - GlassPreferences.minOpacity) / 0.05)
                              .round()
                              .clamp(0, 16),
                      height: 16,
                      thumbSize: 22,
                      showTicks: false,
                      semanticLabel: opacityTitle,
                      valueLabel: l.appearancePercent(
                        (glass.opacity * 100).round(),
                      ),
                      onChanged: (value) => onChanged(
                        glass.copyWith(
                          opacity: GlassPreferences.minOpacity + value * 0.05,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    l.appearancePercent((glass.opacity * 100).round()),
                    style: context.textTheme.labelLarge,
                  ),
                ],
              ),
            ),
          ),
      ];
      group(
        l.appearanceGlass,
        [l.appearanceGlassHint, ?glassNotice].join('\n'),
        [
          ...glassRows(
            title: l.appearanceGlassSidebar,
            hint: l.appearanceGlassSidebarHint,
            opacityTitle: l.appearanceGlassSidebarOpacity,
            glass: p.sidebarGlass,
            onChanged: (value) => controller.update(
              controller.preferences.copyWith(sidebarGlass: value),
            ),
          ),
          ...glassRows(
            title: l.appearanceGlassCanvas,
            hint: l.appearanceGlassCanvasHint,
            opacityTitle: l.appearanceGlassCanvasOpacity,
            glass: p.canvasGlass,
            onChanged: (value) => controller.update(
              controller.preferences.copyWith(canvasGlass: value),
            ),
          ),
          // The shared card material never changes either desktop region.
          ...glassRows(
            title: l.appearanceGlassCards,
            hint: l.appearanceGlassCardsHint,
            opacityTitle: l.appearanceGlassCardsOpacity,
            glass: p.cardGlass,
            onChanged: (value) => controller.update(
              controller.preferences.copyWith(cardGlass: value),
            ),
          ),
        ],
      );
      AppSettingRow colorRow(AppearanceColor key) => AppSettingRow(
        title: appearanceColorLabel(l, key),
        description: overrides.containsKey(key)
            ? l.appearanceOverridden
            : l.appearanceAutomatic,
        control: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: AppColorButton(
                color: AppearancePalette.value(colors, key),
                onPressed: () => _pick(key),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppIconButton.subtle(
              icon: Icons.restart_alt_rounded,
              tooltip: l.appearanceResetColor,
              onPressed: overrides.containsKey(key)
                  ? () => controller.update(p.withColor(key, null, dark: dark))
                  : null,
            ),
          ],
        ),
      );
      group(
        l.appearanceColors,
        '${l.appearanceColorsHint}\n${dark ? l.appearanceEditingDark : l.appearanceEditingLight}',
        [for (final key in AppearanceColor.values.take(7)) colorRow(key)],
      );
      final advanced =
          [for (final key in AppearanceColor.values.skip(7)) colorRow(key)]
              .where(
                (r) => _matches(
                  '${l.appearanceAdvanced} ${r.title} ${r.description}',
                ),
              )
              .toList();
      if (advanced.isNotEmpty) {
        groups.add(
          AppDisclosure(
            key: ValueKey(widget.query.isNotEmpty),
            title: l.appearanceAdvanced,
            subtitle: l.appearanceAdvancedHint,
            initiallyExpanded: widget.query.isNotEmpty,
            leading: const Icon(Icons.tune_rounded),
            builder: (_) => Column(
              children: [
                for (var i = 0; i < advanced.length; i++) ...[
                  if (i > 0) const Divider(),
                  advanced[i],
                ],
              ],
            ),
          ),
        );
      }
      if (widget.query.isEmpty) {
        groups.add(
          AppSettingsGroup(
            title: l.appearancePreview,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.appearancePreviewText,
                      style: context.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCodeBlock(
                      code: l.appearancePreviewCode,
                      language: 'dart',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      backgroundColor: colors.composerBackground,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.inputPlaceholder,
                              style: context.textTheme.bodyLarge?.copyWith(
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppIconButton.primaryCircle(
                            icon: Icons.arrow_upward_rounded,
                            tooltip: l.sendMessage,
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
        groups.add(
          AppSettingRow(
            title: l.appearanceResetColors,
            description: l.appearanceResetColorsHint,
            control: AppActionButton.subtle(
              label: l.reset,
              onPressed: overrides.isEmpty
                  ? null
                  : () => controller.update(
                      p.copyWith(
                        lightColors: dark ? null : {},
                        darkColors: dark ? {} : null,
                      ),
                    ),
            ),
          ),
        );
      }
      final header = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: [
              Text(l.appearanceTitle, style: context.textTheme.displaySmall),
              AppActionButton.subtle(
                label: l.appearanceResetAll,
                leading: const Icon(Icons.restart_alt_rounded),
                onPressed: _resetAll,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.appearanceSubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          if (controller.loadFailed || controller.saveFailed) ...[
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.saveFailed
                        ? l.appearanceSaveFailed
                        : l.appearanceLoadFailed,
                    style: context.textTheme.bodySmall,
                  ),
                  if (controller.saveFailed)
                    AppActionButton.subtle(
                      label: l.appearanceRetry,
                      onPressed: controller.retrySave,
                    ),
                ],
              ),
            ),
          ],
          if (groups.isEmpty) ...[
            const SizedBox(height: AppSpacing.xxxl),
            Text(l.settingsNoResults, style: context.textTheme.bodyMedium),
          ],
        ],
      );
      final sections = [header, ...groups];
      // Mount/layout only visible sections, not every row and the code preview
      // below the fold on the very first route-animation frame.
      return Scrollbar(
        controller: widget.scrollController,
        child: ListView.builder(
          controller: widget.scrollController,
          padding: widget.padding,
          itemCount: sections.length,
          itemBuilder: (context, index) => Padding(
            padding: EdgeInsets.only(top: index == 0 ? 0 : AppSpacing.xxxl),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: sections[index],
              ),
            ),
          ),
        ),
      );
    },
  );
}
