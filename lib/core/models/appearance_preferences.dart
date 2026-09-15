/// GUI-only preferences. No Pi configuration or session data belongs here.
enum AppearanceMode { system, light, dark }

enum PaletteSource { original, system, custom }

enum AppearanceColor {
  primary,
  canvas,
  sidebar,
  composer,
  card,
  code,
  userMessage,
  elevated,
  textPrimary,
  textSecondary,
  textMuted,
  border,
  success,
  warning,
  error,
}

int? parseHexRgb(String value) {
  final hex = value.trim().replaceFirst(RegExp(r'^#'), '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return 0xff000000 | int.parse(hex, radix: 16);
}

String formatHexRgb(int color) =>
    '#${(color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// Tint opacity only; Windows owns the native blur radius. Missing fields keep
/// existing installations opaque. Each region retains its opacity when disabled.
class GlassPreferences {
  const GlassPreferences({this.enabled = false, this.opacity = 0.75});
  static const minOpacity = 0.2, maxOpacity = 1.0;
  final bool enabled;
  final double opacity;

  GlassPreferences copyWith({bool? enabled, double? opacity}) =>
      GlassPreferences(
        enabled: enabled ?? this.enabled,
        opacity: opacity ?? this.opacity,
      );

  factory GlassPreferences.fromJson(Object? raw, GlassPreferences fallback) {
    if (raw is! Map) return fallback;
    final opacity = raw['opacity'];
    return GlassPreferences(
      enabled: raw['enabled'] is bool
          ? raw['enabled'] as bool
          : fallback.enabled,
      opacity: opacity is num && opacity.isFinite
          ? opacity.toDouble().clamp(minOpacity, maxOpacity)
          : fallback.opacity,
    );
  }

  Map<String, dynamic> toJson() => {'enabled': enabled, 'opacity': opacity};
}

class AppearancePreferences {
  AppearancePreferences({
    this.mode = AppearanceMode.system,
    this.source = PaletteSource.original,
    this.seed = defaultSeed,
    this.baseFontSize = defaultFontSize,
    this.uiScale = 1,
    this.sidebarGlass = defaultSidebarGlass,
    this.canvasGlass = defaultCanvasGlass,
    Map<AppearanceColor, int> lightColors = const {},
    Map<AppearanceColor, int> darkColors = const {},
  }) : lightColors = Map.unmodifiable(lightColors),
       darkColors = Map.unmodifiable(darkColors);

  static const defaultSidebarGlass = GlassPreferences(opacity: 0.65);
  static const defaultCanvasGlass = GlassPreferences(opacity: 0.85);
  static const defaultSeed = 0xff0075de;
  static const defaultFontSize = 13.0;
  static const minFontSize = 12.0, maxFontSize = 18.0;
  static const minScale = 0.8, maxScale = 1.5;
  static const scaleOptions = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];
  final AppearanceMode mode;
  final PaletteSource source;
  final int seed;
  final double baseFontSize, uiScale;
  final GlassPreferences sidebarGlass, canvasGlass;
  bool get wantsGlass => sidebarGlass.enabled || canvasGlass.enabled;
  final Map<AppearanceColor, int> lightColors, darkColors;

  AppearancePreferences copyWith({
    AppearanceMode? mode,
    PaletteSource? source,
    int? seed,
    double? baseFontSize,
    double? uiScale,
    GlassPreferences? sidebarGlass,
    GlassPreferences? canvasGlass,
    Map<AppearanceColor, int>? lightColors,
    Map<AppearanceColor, int>? darkColors,
  }) => AppearancePreferences(
    mode: mode ?? this.mode,
    source: source ?? this.source,
    seed: seed ?? this.seed,
    baseFontSize: baseFontSize ?? this.baseFontSize,
    uiScale: uiScale ?? this.uiScale,
    sidebarGlass: sidebarGlass ?? this.sidebarGlass,
    canvasGlass: canvasGlass ?? this.canvasGlass,
    lightColors: lightColors ?? this.lightColors,
    darkColors: darkColors ?? this.darkColors,
  );

  AppearancePreferences withColor(
    AppearanceColor key,
    int? value, {
    required bool dark,
  }) {
    final colors = {...(dark ? darkColors : lightColors)};
    if (value == null) {
      colors.remove(key);
    } else {
      colors[key] = value | 0xff000000;
    }
    return copyWith(
      darkColors: dark ? colors : null,
      lightColors: dark ? null : colors,
    );
  }

  factory AppearancePreferences.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) throw const FormatException('appearance version');
    T choice<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    double number(Object? input, double fallback, double min, double max) =>
        input is num && input.isFinite
        ? input.toDouble().clamp(min, max)
        : fallback;
    Map<AppearanceColor, int> colors(Object? raw) => {
      if (raw is Map)
        for (final key in AppearanceColor.values)
          if (raw[key.name] case final String text) key: ?parseHexRgb(text),
    };
    return AppearancePreferences(
      mode: choice(AppearanceMode.values, json['mode'], AppearanceMode.system),
      source: choice(
        PaletteSource.values,
        json['source'],
        PaletteSource.original,
      ),
      seed: json['seed'] is String
          ? parseHexRgb(json['seed']) ?? defaultSeed
          : defaultSeed,
      baseFontSize: number(
        json['baseFontSize'],
        defaultFontSize,
        minFontSize,
        maxFontSize,
      ),
      uiScale: number(json['uiScale'], 1, minScale, maxScale),
      sidebarGlass: GlassPreferences.fromJson(
        json['sidebarGlass'],
        defaultSidebarGlass,
      ),
      canvasGlass: GlassPreferences.fromJson(
        json['canvasGlass'],
        defaultCanvasGlass,
      ),
      lightColors: colors(json['lightColors']),
      darkColors: colors(json['darkColors']),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': 1,
    'mode': mode.name,
    'source': source.name,
    'seed': formatHexRgb(seed),
    'baseFontSize': baseFontSize,
    'uiScale': uiScale,
    'sidebarGlass': sidebarGlass.toJson(),
    'canvasGlass': canvasGlass.toJson(),
    'lightColors': {
      for (final e in lightColors.entries) e.key.name: formatHexRgb(e.value),
    },
    'darkColors': {
      for (final e in darkColors.entries) e.key.name: formatHexRgb(e.value),
    },
  };
}
