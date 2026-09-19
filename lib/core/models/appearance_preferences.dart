/// GUI-only preferences. No Pi configuration or session data belongs here.
enum AppearanceMode { system, light, dark }

enum PaletteSource { original, system, custom }

/// 聊天时间线中 agent 工具卡片的默认展示密度。
enum ToolDisplayMode { collapsed, compact, expanded }

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

/// Tint opacity only; blur radii belong to Windows or the GUI's material tokens.
/// Missing fields keep existing installations opaque; disabling retains opacity.
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
    GlassPreferences this._cardGlass = defaultCardGlass,
    this.toolDisplay = ToolDisplayMode.compact,
    int this._sessionIdleMinutes = 0,
    int this._frameRate = defaultFrameRate,
    int this._animationFrameRate = defaultAnimationFrameRate,
    Map<String, bool> slotVisibility = const {},
    Map<AppearanceColor, int> lightColors = const {},
    Map<AppearanceColor, int> darkColors = const {},
  }) : lightColors = Map.unmodifiable(lightColors),
       darkColors = Map.unmodifiable(darkColors),
       slotVisibility = Map.unmodifiable(slotVisibility);

  static const defaultSidebarGlass = GlassPreferences(opacity: 0.65);
  static const defaultCanvasGlass = GlassPreferences(opacity: 0.85);
  static const defaultCardGlass = GlassPreferences(opacity: 0.75);
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
  // The long-lived preferences instance can predate this field after hot reload.
  // A nullable backing field keeps the active RPC-owning GUI safe to reload.
  final GlassPreferences? _cardGlass;
  GlassPreferences get cardGlass => _cardGlass ?? defaultCardGlass;

  /// 工具卡片展示挡位；`compact` 是一直以来的默认样式。
  final ToolDisplayMode toolDisplay;

  /// 闲置多少分钟后自动休眠后台 Pi 进程（0 = 从不）。默认关闭：扩展的
  /// 内存状态能否随休眠恢复尚未验证，休眠必须是用户主动选择的行为。
  /// 可空后背字段与 cardGlass 同理：长驻偏好实例可能早于本字段热重载。
  final int? _sessionIdleMinutes;
  int get sessionIdleMinutes => _sessionIdleMinutes ?? 0;
  static const idleMinuteChoices = [0, 15, 60];

  /// Independent GUI limits; zero follows the display. The decorative clock
  /// also respects the global ceiling. Nullable fields support live reloads.
  static const defaultFrameRate = 120, defaultAnimationFrameRate = 30;
  static const frameRateChoices = [30, 60, 120, 0];
  final int? _frameRate, _animationFrameRate;
  int get frameRate => _frameRate ?? defaultFrameRate;
  int get animationFrameRate =>
      _animationFrameRate ?? defaultAnimationFrameRate;

  /// Pi 扩展槽位开关，键为 [ExtensibleSlotId.name]，缺省视为开启。
  /// 只写入被关闭的键，旧配置文件里没有也能保持兼容。
  final Map<String, bool> slotVisibility;
  bool isSlotVisible(String slotName) => slotVisibility[slotName] ?? true;
  // Card-only glass also uses the native capability/system-policy gate. It
  // never makes the canvas or sidebar transparent on the user's behalf.
  bool get wantsGlass =>
      sidebarGlass.enabled || canvasGlass.enabled || cardGlass.enabled;
  final Map<AppearanceColor, int> lightColors, darkColors;

  AppearancePreferences copyWith({
    AppearanceMode? mode,
    PaletteSource? source,
    int? seed,
    double? baseFontSize,
    double? uiScale,
    GlassPreferences? sidebarGlass,
    GlassPreferences? canvasGlass,
    GlassPreferences? cardGlass,
    ToolDisplayMode? toolDisplay,
    int? sessionIdleMinutes,
    int? frameRate,
    int? animationFrameRate,
    Map<String, bool>? slotVisibility,
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
    cardGlass: cardGlass ?? this.cardGlass,
    toolDisplay: toolDisplay ?? this.toolDisplay,
    sessionIdleMinutes: sessionIdleMinutes ?? this.sessionIdleMinutes,
    frameRate: frameRate ?? this.frameRate,
    animationFrameRate: animationFrameRate ?? this.animationFrameRate,
    slotVisibility: slotVisibility ?? this.slotVisibility,
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
      cardGlass: GlassPreferences.fromJson(json['cardGlass'], defaultCardGlass),
      toolDisplay: choice(
        ToolDisplayMode.values,
        json['toolDisplay'],
        ToolDisplayMode.compact,
      ),
      sessionIdleMinutes:
          json['sessionIdleMinutes'] is num && json['sessionIdleMinutes'] >= 0
          ? (json['sessionIdleMinutes'] as num).round()
          : 0,
      frameRate:
          json['frameRate'] is int &&
              frameRateChoices.contains(json['frameRate'])
          ? json['frameRate'] as int
          : defaultFrameRate,
      animationFrameRate:
          json['animationFrameRate'] is int &&
              frameRateChoices.contains(json['animationFrameRate'])
          ? json['animationFrameRate'] as int
          : defaultAnimationFrameRate,
      slotVisibility: {
        if (json['slotVisibility'] case final Map raw)
          for (final entry in raw.entries)
            if (entry.value is bool) entry.key.toString(): entry.value as bool,
      },
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
    'cardGlass': cardGlass.toJson(),
    'toolDisplay': toolDisplay.name,
    'sessionIdleMinutes': sessionIdleMinutes,
    'frameRate': frameRate,
    'animationFrameRate': animationFrameRate,
    // 只保存关闭的槽位，避免文件随槽位枚举增长膨胀。
    'slotVisibility': {
      for (final entry in slotVisibility.entries)
        if (!entry.value) entry.key: false,
    },
    'lightColors': {
      for (final e in lightColors.entries) e.key.name: formatHexRgb(e.value),
    },
    'darkColors': {
      for (final e in darkColors.entries) e.key.name: formatHexRgb(e.value),
    },
  };
}
