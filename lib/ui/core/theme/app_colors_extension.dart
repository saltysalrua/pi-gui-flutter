import 'package:flutter/material.dart';

/// 应用语义色彩设计令牌 (ThemeExtension 体系)
///
/// 统一管理界面的背景层级、边框、文字、强调色及业务状态色彩，
/// 支持 Light (Notion Warm Paper) 与 Dark (Notion Minimal Dark) 的平滑过渡。
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  // --- 背景层级 ---
  final Color canvasBackground;
  final Color sidebarBackground;
  final Color cardBackground;
  final Color elevatedBackground;
  final Color mutedBackground;
  final Color hoverBackground;
  final Color composerBackground;
  final Color codeBackground;
  final Color userMessageBackground;

  // --- 边框层级 ---
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderHover;
  final Color borderFocus;

  // --- 文字层级 ---
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // --- 强调色族 ---
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color primaryTint;
  final Color accent;

  // --- 状态语义 ---
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Image viewing always uses a dark scrim, independent of the app brightness.
  final Color lightboxForeground;

  /// Neutral slider handle; not the foreground color of a primary button.
  final Color controlThumb;

  const AppColorsExtension({
    required this.canvasBackground,
    required this.sidebarBackground,
    required this.cardBackground,
    required this.elevatedBackground,
    required this.mutedBackground,
    required this.hoverBackground,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderHover,
    required this.borderFocus,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.primaryTint,
    required this.accent,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    this.lightboxForeground = const Color(0xFFF5F5F5),
    this.controlThumb = const Color(0xFFFFFFFF),
    Color? composerBackground,
    Color? codeBackground,
    Color? userMessageBackground,
  }) : composerBackground = composerBackground ?? cardBackground,
       codeBackground = codeBackground ?? mutedBackground,
       userMessageBackground = userMessageBackground ?? mutedBackground;

  /// 亮色调色板 (Notion 暖纸本工作台)
  static const AppColorsExtension light = AppColorsExtension(
    canvasBackground: Color(0xFFF9F9F8), // 亮色右侧主工作区暖白底色
    sidebarBackground: Color(0xFFF4F3F1), // 侧边栏微暖层次底色
    codeBackground: Color(0xFFF5F3F0),
    userMessageBackground: Color(0xFFF4F2EF),
    cardBackground: Color(0xFFFFFFFF), // 纯白悬浮卡片
    elevatedBackground: Color(0xFFFFFFFF),
    mutedBackground: Color(0xFFEFECE6),
    hoverBackground: Color(0x0C000000), // 微弱悬浮半透明底色
    borderSubtle: Color(0x0A000000),
    borderDefault: Color(0x14000000), // 0.08 alpha 细边框
    borderHover: Color(0x26000000),
    borderFocus: Color(0xFF0075DE),
    textPrimary: Color(0xFF191919),
    textSecondary: Color(0xFF5A5854),
    textMuted: Color(0xFF8A8884),
    primary: Color(0xFF0075DE), // 经典核心操作蓝
    primaryLight: Color(0xFF4CA6FF),
    primaryDark: Color(0xFF005AB0),
    primaryTint: Color(0xFFE6F2FE),
    accent: Color(0xFF0075DE),
    success: Color(0xFF0F9960),
    warning: Color(0xFFD9822B),
    error: Color(0xFFDB3737),
    info: Color(0xFF0075DE),
  );

  /// 暗色调色板 (Notion Minimal Dark 极简黑)
  static const AppColorsExtension dark = AppColorsExtension(
    canvasBackground: Color(0xFF191919), // 极简暗灰底色
    sidebarBackground: Color(0xFF141414), // 稍暗侧边栏底色
    codeBackground: Color(0xFF222222),
    userMessageBackground: Color(0xFF242424),
    cardBackground: Color(0xFF222222), // 悬浮卡片背景
    elevatedBackground: Color(0xFF2A2A2A),
    mutedBackground: Color(0xFF2E2E2E),
    hoverBackground: Color(0x14FFFFFF), // 悬浮白色半透明底色
    borderSubtle: Color(0x0FFFFFFF),
    borderDefault: Color(0x1AFFFFFF), // 微妙暗色描边
    borderHover: Color(0x33FFFFFF),
    borderFocus: Color(0xFF3395FF),
    textPrimary: Color(0xFFEBEBEB),
    textSecondary: Color(0xFFA1A1A1),
    textMuted: Color(0xFF707070),
    primary: Color(0xFF3395FF), // 暗色下更亮的高对比度蓝
    primaryLight: Color(0xFF66AEFF),
    primaryDark: Color(0xFF006DE0),
    primaryTint: Color(0xFF17304F),
    accent: Color(0xFF3395FF),
    success: Color(0xFF2ECC71),
    warning: Color(0xFFF39C12),
    error: Color(0xFFE74C3C),
    info: Color(0xFF3395FF),
  );

  @override
  AppColorsExtension copyWith({
    Color? canvasBackground,
    Color? sidebarBackground,
    Color? cardBackground,
    Color? elevatedBackground,
    Color? mutedBackground,
    Color? hoverBackground,
    Color? composerBackground,
    Color? codeBackground,
    Color? userMessageBackground,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderHover,
    Color? borderFocus,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? primaryTint,
    Color? accent,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? lightboxForeground,
    Color? controlThumb,
  }) {
    return AppColorsExtension(
      canvasBackground: canvasBackground ?? this.canvasBackground,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      cardBackground: cardBackground ?? this.cardBackground,
      elevatedBackground: elevatedBackground ?? this.elevatedBackground,
      mutedBackground: mutedBackground ?? this.mutedBackground,
      hoverBackground: hoverBackground ?? this.hoverBackground,
      composerBackground: composerBackground ?? this.composerBackground,
      codeBackground: codeBackground ?? this.codeBackground,
      userMessageBackground:
          userMessageBackground ?? this.userMessageBackground,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderHover: borderHover ?? this.borderHover,
      borderFocus: borderFocus ?? this.borderFocus,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryTint: primaryTint ?? this.primaryTint,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      lightboxForeground: lightboxForeground ?? this.lightboxForeground,
      controlThumb: controlThumb ?? this.controlThumb,
    );
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      canvasBackground: Color.lerp(
        canvasBackground,
        other.canvasBackground,
        t,
      )!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      elevatedBackground: Color.lerp(
        elevatedBackground,
        other.elevatedBackground,
        t,
      )!,
      mutedBackground: Color.lerp(mutedBackground, other.mutedBackground, t)!,
      hoverBackground: Color.lerp(hoverBackground, other.hoverBackground, t)!,
      composerBackground: Color.lerp(
        composerBackground,
        other.composerBackground,
        t,
      )!,
      codeBackground: Color.lerp(codeBackground, other.codeBackground, t)!,
      userMessageBackground: Color.lerp(
        userMessageBackground,
        other.userMessageBackground,
        t,
      )!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderHover: Color.lerp(borderHover, other.borderHover, t)!,
      borderFocus: Color.lerp(borderFocus, other.borderFocus, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      controlThumb: Color.lerp(controlThumb, other.controlThumb, t)!,
      lightboxForeground: Color.lerp(
        lightboxForeground,
        other.lightboxForeground,
        t,
      )!,
    );
  }
}
