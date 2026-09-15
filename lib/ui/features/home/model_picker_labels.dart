import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/l10n/app_localizations.dart';
import 'package:pi_gui/ui/features/home/controllers/model_picker_controller.dart';

String thinkingLevelLabel(AppLocalizations l10n, PiThinkingLevel level) =>
    switch (level) {
      PiThinkingLevel.off => l10n.thinkingNone,
      PiThinkingLevel.minimal => l10n.thinkingMinimal,
      PiThinkingLevel.low => l10n.thinkingLow,
      PiThinkingLevel.medium => l10n.thinkingMedium,
      PiThinkingLevel.high => l10n.thinkingHigh,
      PiThinkingLevel.xhigh => l10n.thinkingXHigh,
      PiThinkingLevel.max => l10n.thinkingMax,
    };

String modelPickerFailureLabel(
  AppLocalizations l10n,
  ModelPickerFailure failure,
) => switch (failure) {
  ModelPickerFailure.load => l10n.modelLoadFailed,
  ModelPickerFailure.changeModel => l10n.modelChangeFailed,
  ModelPickerFailure.changeThinking => l10n.modelThinkingFailed,
  ModelPickerFailure.disconnected => l10n.piDisconnected,
};
