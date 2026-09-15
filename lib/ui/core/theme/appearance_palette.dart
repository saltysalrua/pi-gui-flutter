import 'package:flutter/material.dart';
import '../../../core/models/appearance_preferences.dart';
import 'app_colors_extension.dart';

/// Resolve generated M3 colors first, then apply explicit per-brightness overrides.
abstract final class AppearancePalette {
  static AppColorsExtension resolve(
    Brightness brightness,
    AppearancePreferences preferences,
    Color? systemAccent,
  ) {
    final dark = brightness == Brightness.dark;
    var colors = dark ? AppColorsExtension.dark : AppColorsExtension.light;
    if (preferences.source != PaletteSource.original) {
      final seed = preferences.source == PaletteSource.system
          ? systemAccent ?? Color(AppearancePreferences.defaultSeed)
          : Color(preferences.seed);
      final scheme = ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
      );
      colors = colors.copyWith(
        canvasBackground: scheme.surface,
        sidebarBackground: scheme.surfaceContainerLow,
        cardBackground: scheme.surfaceContainerLowest,
        composerBackground: scheme.surfaceContainerLowest,
        codeBackground: scheme.surfaceContainer,
        userMessageBackground: scheme.surfaceContainerHigh,
        elevatedBackground: scheme.surfaceContainerHigh,
        mutedBackground: scheme.surfaceContainerHighest,
        hoverBackground: scheme.onSurface.withValues(alpha: 0.06),
        borderSubtle: scheme.outlineVariant.withValues(alpha: 0.45),
        borderDefault: scheme.outlineVariant,
        borderHover: scheme.outline,
        borderFocus: scheme.primary,
        textPrimary: scheme.onSurface,
        textSecondary: scheme.onSurfaceVariant,
        textMuted: Color.lerp(scheme.onSurfaceVariant, scheme.surface, 0.2),
        primary: scheme.primary,
        primaryLight: Color.lerp(scheme.primary, scheme.onPrimary, 0.12),
        primaryDark: Color.lerp(
          scheme.primary,
          scheme.onPrimaryContainer,
          0.15,
        ),
        primaryTint: scheme.primaryContainer,
        accent: scheme.tertiary,
        info: scheme.primary,
        error: scheme.error,
      );
    }
    final overrides = dark ? preferences.darkColors : preferences.lightColors;
    Color? get(AppearanceColor key) =>
        overrides[key] == null ? null : Color(overrides[key]!);
    final primary = get(AppearanceColor.primary);
    final border = get(AppearanceColor.border);
    return colors.copyWith(
      primary: primary,
      primaryLight: primary == null
          ? null
          : Color.lerp(primary, colors.cardBackground, 0.16),
      primaryDark: primary == null
          ? null
          : Color.lerp(primary, colors.textPrimary, 0.16),
      primaryTint: primary == null
          ? null
          : Color.lerp(colors.canvasBackground, primary, 0.14),
      borderFocus: primary,
      info: primary,
      canvasBackground: get(AppearanceColor.canvas),
      sidebarBackground: get(AppearanceColor.sidebar),
      composerBackground: get(AppearanceColor.composer),
      cardBackground: get(AppearanceColor.card),
      codeBackground: get(AppearanceColor.code),
      userMessageBackground: get(AppearanceColor.userMessage),
      elevatedBackground: get(AppearanceColor.elevated),
      textPrimary: get(AppearanceColor.textPrimary),
      textSecondary: get(AppearanceColor.textSecondary),
      textMuted: get(AppearanceColor.textMuted),
      borderDefault: border,
      borderSubtle: border?.withValues(alpha: 0.5),
      borderHover: border == null
          ? null
          : Color.lerp(border, colors.textPrimary, 0.2),
      success: get(AppearanceColor.success),
      warning: get(AppearanceColor.warning),
      error: get(AppearanceColor.error),
    );
  }

  static Color value(AppColorsExtension colors, AppearanceColor key) =>
      switch (key) {
        AppearanceColor.primary => colors.primary,
        AppearanceColor.canvas => colors.canvasBackground,
        AppearanceColor.sidebar => colors.sidebarBackground,
        AppearanceColor.composer => colors.composerBackground,
        AppearanceColor.card => colors.cardBackground,
        AppearanceColor.code => colors.codeBackground,
        AppearanceColor.userMessage => colors.userMessageBackground,
        AppearanceColor.elevated => colors.elevatedBackground,
        AppearanceColor.textPrimary => colors.textPrimary,
        AppearanceColor.textSecondary => colors.textSecondary,
        AppearanceColor.textMuted => colors.textMuted,
        AppearanceColor.border => colors.borderDefault,
        AppearanceColor.success => colors.success,
        AppearanceColor.warning => colors.warning,
        AppearanceColor.error => colors.error,
      };

  static double contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + 0.05) / ((x < y ? x : y) + 0.05);
  }

  static Color onColor(Color color) =>
      contrast(color, AppColorsExtension.light.cardBackground) >=
          contrast(color, AppColorsExtension.light.textPrimary)
      ? AppColorsExtension.light.cardBackground
      : AppColorsExtension.light.textPrimary;
}
