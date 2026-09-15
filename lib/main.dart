import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'l10n/app_localizations.dart';
import 'ui/core/theme/app_theme.dart';
import 'ui/core/window_material_scope.dart';
import 'ui/features/home/views/home_view.dart';
import 'core/slots/slot_manager.dart';
import 'ui/atoms/slot_container.dart';
import 'ui/atoms/app_scale.dart';
import 'ui/core/theme/app_tokens.dart';
import 'ui/features/settings/controllers/appearance_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 桌面窗口配置 (Windows, macOS, Linux)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(920, 600),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
      title: 'Pi',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await AppearanceController.instance.initialize();
  runApp(const PiGuiApp());
}

/// Pi GUI 桌面客户端主应用
class PiGuiApp extends StatelessWidget {
  const PiGuiApp({super.key, this.appearance, this.home});
  final AppearanceController? appearance;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    final controller = appearance ?? AppearanceController.instance;
    return AppearanceScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => MaterialApp(
          title: 'Pi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(
            Brightness.light,
            preferences: controller.preferences,
            systemAccent: controller.systemAccent,
          ),
          darkTheme: AppTheme.build(
            Brightness.dark,
            preferences: controller.preferences,
            systemAccent: controller.systemAccent,
          ),
          themeMode: ThemeMode.values[controller.preferences.mode.index],
          themeAnimationDuration:
              WidgetsBinding
                  .instance
                  .platformDispatcher
                  .accessibilityFeatures
                  .disableAnimations
              ? Duration.zero
              : AppDurations.fast,
          themeAnimationCurve: AppCurves.smoothOut,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            // Extension prompts must remain above normal routes, including workspace dialogs.
            final content = Overlay.wrap(
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  const Positioned.fill(
                    child: SlotContainer(
                      slotId: ExtensibleSlotId.dialogOverlay,
                      material: true,
                    ),
                  ),
                  const Positioned(
                    top: 48,
                    right: 24,
                    width: 340,
                    child: SlotContainer(
                      slotId: ExtensibleSlotId.notificationToast,
                      material: true,
                    ),
                  ),
                ],
              ),
            );
            final material = WindowMaterialHost(
              enabled: controller.preferences.wantsGlass,
              dark: Theme.of(context).brightness == Brightness.dark,
              child: content,
            );
            // Windows 引擎的 accessibility bridge 在处理复杂动态节点增删时会报 AXTree 错误
            // (flutter/flutter#141151, #175041)。在 Windows 桌面端包裹 ExcludeSemantics 彻底消除该错误。
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
              return AppScale(
                scale: controller.preferences.uiScale,
                child: ExcludeSemantics(child: material),
              );
            }
            return AppScale(
              scale: controller.preferences.uiScale,
              child: material,
            );
          },
          home: home ?? const HomeView(),
        ),
      ),
    );
  }
}
