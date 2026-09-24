import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/models/appearance_preferences.dart';
import 'app_colors_extension.dart';
import 'app_card_theme.dart';
import 'appearance_palette.dart';
import 'app_tokens.dart';

/// 全局视觉主题与排版规范
class AppTheme {
  static const String fontFamily = 'MiSans';

  /// Windows does not resolve the CSS-like 'monospace' family reliably.
  static TextStyle codeStyle(ThemeData theme) =>
      theme.textTheme.bodySmall!.copyWith(
        fontFamily: 'Consolas',
        fontFamilyFallback: const ['Cascadia Mono', 'Menlo', 'monospace'],
        color: theme.extension<AppColorsExtension>()!.textPrimary,
      );

  /// 亮色主题
  static ThemeData get lightTheme => build(Brightness.light);

  /// 暗色主题
  static ThemeData get darkTheme => build(Brightness.dark);

  static ThemeData build(
    Brightness brightness, {
    AppearancePreferences? preferences,
    Color? systemAccent,
  }) {
    final settings = preferences ?? AppearancePreferences();
    final colors = AppearancePalette.resolve(
      brightness,
      settings,
      systemAccent,
    );
    final textTheme = _buildTextTheme(colors).apply(
      fontSizeFactor:
          settings.baseFontSize / AppearancePreferences.defaultFontSize,
    );
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: brightness,
        ).copyWith(
          primary: colors.primary,
          secondary: colors.primaryLight,
          surface: colors.cardBackground,
          error: colors.error,
          onPrimary: AppearancePalette.onColor(colors.primary),
          onSurface: colors.textPrimary,
          onSurfaceVariant: colors.textSecondary,
          outline: colors.borderDefault,
          outlineVariant: colors.borderSubtle,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: colors.canvasBackground,
      // Desktop feedback is hover/pressed tint only (VSCode-like), no ripples.
      // Also skips InkSparkle's per-tap shader compilation and animation.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      extensions: [
        colors,
        AppCardTheme(
          opacity: settings.cardGlass.enabled ? settings.cardGlass.opacity : 1,
          blurSigma:
              settings.cardGlass.enabled && settings.cardGlass.opacity < 1
              ? AppGlass.cardBlurSigma
              : 0,
        ),
      ],
      colorScheme: scheme,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.25),
        selectionHandleColor: colors.primary,
      ),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: colors.textSecondary, size: 18),
      dividerTheme: DividerThemeData(
        color: colors.borderDefault,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: AppearancePalette.onColor(colors.textPrimary),
        ),
        waitDuration: AppDurations.verySlow,
      ),
    );
  }

  static TextTheme _buildTextTheme(AppColorsExtension colors) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: colors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        color: colors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: colors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: colors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: colors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: colors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        color: colors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.45,
      ),
      bodySmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      labelMedium: TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
      ),
      labelSmall: TextStyle(
        fontFamily: fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: colors.textMuted,
      ),
    );
  }
}

/// Bounded, owner-scoped theme cache. Preference saving, slot visibility and
/// glass tint changes must not regenerate M3 palettes or restart AnimatedTheme.
/// PiGuiApp creates this outside its listener builder (and renews on reload).
class AppThemeCache {
  final _entries = <Brightness, _ThemeEntry>{};

  ThemeData resolve(
    Brightness brightness, {
    required AppearancePreferences preferences,
    Color? systemAccent,
  }) {
    final p = preferences;
    final seed = switch (p.source) {
      PaletteSource.original => null,
      PaletteSource.system =>
        systemAccent?.toARGB32() ?? AppearancePreferences.defaultSeed,
      PaletteSource.custom => p.seed,
    };
    final overrides = brightness == Brightness.dark
        ? p.darkColors
        : p.lightColors;
    var entry = _entries[brightness];
    if (entry == null ||
        entry.seed != seed ||
        entry.fontSize != p.baseFontSize ||
        !mapEquals(entry.overrides, overrides)) {
      entry = _ThemeEntry(
        seed: seed,
        fontSize: p.baseFontSize,
        overrides: overrides,
        base: AppTheme.build(
          brightness,
          preferences: p.copyWith(
            cardGlass: AppearancePreferences.defaultCardGlass,
          ),
          systemAccent: systemAccent,
        ),
      );
      _entries[brightness] = entry;
    }
    final opacity = p.cardGlass.enabled ? p.cardGlass.opacity : 1.0;
    if (entry.opacity != opacity) {
      entry.opacity = opacity;
      entry.theme = entry.base.copyWith(
        extensions: [
          ...entry.base.extensions.values.where((e) => e is! AppCardTheme),
          AppCardTheme(
            opacity: opacity,
            blurSigma: opacity < 1 ? AppGlass.cardBlurSigma : 0,
          ),
        ],
      );
    }
    return entry.theme;
  }
}

class _ThemeEntry {
  _ThemeEntry({
    required this.seed,
    required this.fontSize,
    required this.overrides,
    required this.base,
  }) : theme = base;
  final int? seed;
  final double fontSize;
  final Map<AppearanceColor, int> overrides;
  final ThemeData base;
  double opacity = 1;
  ThemeData theme;
}
