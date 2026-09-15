import 'package:flutter/widgets.dart';
import '../../l10n/app_localizations.dart';

/// 便捷扩展：[BuildContext] 快速获取强类型本地化文案
extension ContextL10n on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
