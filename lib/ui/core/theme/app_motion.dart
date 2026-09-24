import 'package:flutter/animation.dart';

/// 全局动效时长标尺 (基于 transitions.dev Motion Tokens)
abstract final class AppDurations {
  /// 40ms - 按项交错入场偏移行 (Stagger)
  static const Duration stagger = Duration(milliseconds: 40);

  /// 80ms - 微交互、抖动分段、tooltip 微延迟
  static const Duration micro = Duration(milliseconds: 80);

  /// 150ms - 弹窗/下拉收起、文字切换、轻量反馈
  static const Duration quick = Duration(milliseconds: 150);

  /// 250ms - 图标替换、下拉/弹窗展开、Tab滑动、页面滑动
  static const Duration fast = Duration(milliseconds: 250);

  /// 350ms - 抽屉面板收起、Toast 退出
  static const Duration medium = Duration(milliseconds: 350);

  /// 400ms - 抽屉面板展开、骨架屏揭示、输入清除
  static const Duration slow = Duration(milliseconds: 400);

  /// 500ms - 强调时刻、徽章弹出、文本渐显、成功对勾绘制
  static const Duration verySlow = Duration(milliseconds: 500);
}

/// 全局动效缓动曲线标尺 (基于 transitions.dev Motion Tokens)
abstract final class AppCurves {
  /// cubic-bezier(0.22, 1, 0.36, 1) - 现代高质感自然平滑减速 (模态/下拉/面板/尺寸变化)
  static const Curve smoothOut = Cubic(0.22, 1.0, 0.36, 1.0);

  /// 自然平滑过渡 (图标替换、原位切换)
  static const Curve inOut = Curves.easeInOut;

  /// 轻量平滑退出 (Tooltip 等)
  static const Curve easeOut = Curves.easeOut;

  /// 匀速线性运动 (微光流扫、循环加载)
  static const Curve linear = Curves.linear;

  /// cubic-bezier(0.34, 1.36, 0.64, 1) - 徽章弹入轻弹性
  static const Curve bounce = Cubic(0.34, 1.36, 0.64, 1.0);

  /// cubic-bezier(0.34, 3.85, 0.64, 1) - 强弹性自然复位
  static const Curve bounceStrong = Cubic(0.34, 3.85, 0.64, 1.0);
}

/// 动效缩放与位移标尺
abstract final class AppMotionScales {
  /// 0.96 - 模态弹窗进场初值
  static const double modal = 0.96;

  /// 0.97 - 下拉菜单展开初值
  static const double dropdown = 0.97;

  /// 0.98 - Tooltip 展开初值
  static const double tooltip = 0.98;

  /// 0.99 - 下拉关闭初值
  static const double tiny = 0.99;

  /// 0.97 - 按钮按下时的统一缩放
  static const double press = 0.97;
}
