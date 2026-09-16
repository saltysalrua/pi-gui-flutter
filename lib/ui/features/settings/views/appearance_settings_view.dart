import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/models/appearance_preferences.dart';
import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_code_block.dart';
import '../../../atoms/app_color_picker.dart';
import '../../../atoms/app_dialog.dart';
import '../../../atoms/app_disclosure.dart';
import '../../../atoms/app_icon_button.dart';
import '../../../atoms/app_nav_tile.dart';
import '../../../atoms/app_desktop_scaffold.dart';
import '../../../../core/services/window_material_service.dart';
import '../../../core/window_material_scope.dart';
import '../../../atoms/app_select.dart';
import '../../../atoms/app_setting.dart';
import '../../../atoms/app_stepped_slider.dart';
import '../../../atoms/app_text_field.dart';
import '../../../core/app_desktop_page_route.dart';
import '../../../core/context_l10n.dart';
import '../../../core/sidebar_layout_controller.dart';
import '../../../core/theme/appearance_palette.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../appearance_labels.dart';
import '../controllers/appearance_controller.dart';

Future<void> showAppearanceSettings(BuildContext context) =>
    Navigator.of(context).push<void>(
      AppDesktopPageRoute<void>(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => const AppearanceSettingsView(),
      ),
    );

/// A normal maintained route: opening settings never disposes the RPC-owning HomeView.
class AppearanceSettingsView extends StatefulWidget {
  const AppearanceSettingsView({super.key});
  @override
  State<AppearanceSettingsView> createState() => _AppearanceSettingsViewState();
}

class _AppearanceSettingsViewState extends State<AppearanceSettingsView> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final controller = AppearanceScope.of(context);
    final sidebarLayout = SidebarLayoutController.instance;
    final search = AppTextField(
      controller: _search,
      hintText: l.settingsSearch,
      isCompact: true,
      leading: const Icon(Icons.search),
      onChanged: (v) => setState(() => _query = v.trim()),
      trailing: _query.isEmpty
          ? null
          : AppIconButton.subtle(
              icon: Icons.close,
              tooltip: l.clearSearch,
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
    );
    return ListenableBuilder(
      listenable: sidebarLayout,
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final sidebar = SizedBox(
              width: sidebarLayout.widthFor(constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppActionButton.subtle(
                      label: l.settingsBack,
                      leading: const Icon(Icons.arrow_back_rounded),
                      isExpanded: true,
                      mainAxisAlignment: MainAxisAlignment.start,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    search,
                    const SizedBox(height: AppSpacing.xxl),
                    Text(l.settings, style: context.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                    AppNavTile(
                      title: l.appearanceTitle,
                      leading: const Icon(Icons.palette_outlined),
                      isSelected: true,
                      onTap: () {
                        _search.clear();
                        setState(() => _query = '');
                        _scroll.animateTo(
                          0,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : AppDurations.fast,
                          curve: AppCurves.smoothOut,
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
            final page = Column(
              children: [
                if (compact)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        AppIconButton.subtle(
                          icon: Icons.arrow_back_rounded,
                          tooltip: l.settingsBack,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: search),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? AppSpacing.lg : AppSpacing.xxxl,
                        vertical: compact
                            ? AppSpacing.xxl
                            : AppSpacing.xxxl * 2,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: AppearanceSettingsContent(
                            controller: controller,
                            query: _query,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            return AppDesktopScaffold(
              contentAnimation: ModalRoute.of(context)?.animation,
              sidebarBackground: WindowMaterialScope.tint(
                context,
                colors.sidebarBackground,
                controller.preferences.sidebarGlass,
              ),
              contentBackground: WindowMaterialScope.tint(
                context,
                colors.canvasBackground,
                controller.preferences.canvasGlass,
              ),
              animate:
                  WindowMaterialScope.statusOf(context) ==
                  WindowMaterialStatus.active,
              sidebar: compact ? null : sidebar,
              sidebarWidth: sidebarLayout.widthFor(constraints.maxWidth),
              onSidebarResize: (dx) => sidebarLayout.resizeBy(
                dx,
                viewportWidth: constraints.maxWidth,
              ),
              onSidebarReset: sidebarLayout.reset,
              child: page,
            );
          },
        ),
      ),
    );
  }
}

class AppearanceSettingsContent extends StatefulWidget {
  const AppearanceSettingsContent({
    super.key,
    required this.controller,
    this.query = '',
  });
  final AppearanceController controller;
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
    listenable: widget.controller,
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
      return Column(
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
          const SizedBox(height: AppSpacing.xxxl),
          if (groups.isEmpty)
            Text(l.settingsNoResults, style: context.textTheme.bodyMedium),
          for (var i = 0; i < groups.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.xxxl),
            groups[i],
          ],
        ],
      );
    },
  );
}
