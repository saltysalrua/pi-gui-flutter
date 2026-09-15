import '../../../core/models/appearance_preferences.dart';
import '../../../l10n/app_localizations.dart';

String appearanceColorLabel(AppLocalizations l, AppearanceColor key) =>
    switch (key) {
      AppearanceColor.primary => l.appearancePrimary,
      AppearanceColor.canvas => l.appearanceCanvas,
      AppearanceColor.sidebar => l.appearanceSidebar,
      AppearanceColor.composer => l.appearanceComposer,
      AppearanceColor.card => l.appearanceCard,
      AppearanceColor.code => l.appearanceCode,
      AppearanceColor.userMessage => l.appearanceUserMessage,
      AppearanceColor.elevated => l.appearanceElevated,
      AppearanceColor.textPrimary => l.appearanceTextPrimary,
      AppearanceColor.textSecondary => l.appearanceTextSecondary,
      AppearanceColor.textMuted => l.appearanceTextMuted,
      AppearanceColor.border => l.appearanceBorder,
      AppearanceColor.success => l.appearanceSuccess,
      AppearanceColor.warning => l.appearanceWarning,
      AppearanceColor.error => l.appearanceError,
    };
