import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_desktop_scaffold.dart';
import '../../../atoms/app_icon_button.dart';
import '../../../atoms/app_nav_tile.dart';
import '../../../atoms/app_select.dart';
import '../../../atoms/app_text_field.dart';
import '../../../core/app_desktop_page_route.dart';
import '../../../core/context_l10n.dart';
import '../../../core/sidebar_layout_controller.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../../../core/window_material_scope.dart';
import '../../../../core/rpc/pi_rpc_client.dart';
import '../../../../core/services/window_material_service.dart';
import '../controllers/appearance_controller.dart';
import '../controllers/packages_controller.dart';
import '../controllers/pi_update_controller.dart';
import 'appearance_settings_view.dart';
import 'packages_settings_view.dart';
import 'pi_settings_view.dart';

enum _SettingsPage { appearance, pi, plugins }

Future<void> showSettings(BuildContext context, {PiRpcClient? control}) =>
    Navigator.of(context).push<void>(
      AppDesktopPageRoute<void>(
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        builder: (_) => SettingsView(control: control),
      ),
    );

/// A normal maintained route: opening settings never disposes the RPC-owning
/// HomeView. The sidebar hosts one tile per settings page; compact widths
/// switch pages through an inline select instead.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key, this.control});
  final PiRpcClient? control;
  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String _query = '';
  _SettingsPage _page = _SettingsPage.appearance;
  PiUpdateController? _pi;
  PackagesController? _plugins;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    _pi?.dispose();
    _plugins?.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.fast,
      curve: AppCurves.smoothOut,
    );
  }

  void _select(_SettingsPage page, {bool clearSearch = false}) {
    if (clearSearch) {
      _search.clear();
      _query = '';
    }
    if (_page == page) {
      if (clearSearch) setState(() {});
      _scrollToTop();
      return;
    }
    // The Pi controller loads install info + changelog on first selection
    // and is kept alive until the settings route closes. The plugins
    // controller needs the shared control channel for package management.
    if (page == _SettingsPage.pi) _pi ??= PiUpdateController()..load();
    if (page == _SettingsPage.plugins) {
      final control = widget.control;
      if (control != null) {
        _plugins ??= PackagesController(control)..load();
      }
    }
    setState(() => _page = page);
    _scrollToTop();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final controller = AppearanceScope.of(context);
    final sidebarLayout = SidebarLayoutController.instance;
    final search = AppTextField(
      controller: _search,
      hintText: l.settingsSearch,
      isCompact: true,
      leading: const Icon(Icons.search),
      onChanged: (v) => setState(() => _query = v.trim()),
      trailing: _query.isEmpty
          ? null
          : AppIconButton.subtle(
              icon: Icons.close,
              tooltip: l.clearSearch,
              onPressed: () {
                _search.clear();
                setState(() => _query = '');
              },
            ),
    );
    Widget navTile(_SettingsPage page, String title, IconData icon) =>
        AppNavTile(
          title: title,
          leading: Icon(icon),
          isSelected: _page == page,
          onTap: () =>
              _select(page, clearSearch: page == _SettingsPage.appearance),
        );
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: sidebarLayout,
      builder: (context, _) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () =>
              Navigator.of(context).maybePop(),
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            final pageSwitcher = AppSelect<_SettingsPage>(
              value: _page,
              label: l.settings,
              options: [
                AppSelectOption(_SettingsPage.appearance, l.appearanceTitle),
                AppSelectOption(_SettingsPage.pi, l.piPageTitle),
                AppSelectOption(_SettingsPage.plugins, l.pluginsPageTitle),
              ],
              onChanged: (page) => _select(page),
            );
            final sidebar = SizedBox(
              width: sidebarLayout.widthFor(constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppActionButton.subtle(
                      label: l.settingsBack,
                      leading: const Icon(Icons.arrow_back_rounded),
                      isExpanded: true,
                      mainAxisAlignment: MainAxisAlignment.start,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    search,
                    const SizedBox(height: AppSpacing.xxl),
                    Text(l.settings, style: context.textTheme.labelSmall),
                    const SizedBox(height: AppSpacing.sm),
                    navTile(
                      _SettingsPage.appearance,
                      l.appearanceTitle,
                      Icons.palette_outlined,
                    ),
                    navTile(
                      _SettingsPage.pi,
                      l.piPageTitle,
                      Icons.terminal_rounded,
                    ),
                    navTile(
                      _SettingsPage.plugins,
                      l.pluginsPageTitle,
                      Icons.extension_rounded,
                    ),
                  ],
                ),
              ),
            );
            final content = switch (_page) {
              _SettingsPage.appearance => AppearanceSettingsContent(
                controller: controller,
                query: _query,
              ),
              _SettingsPage.pi => PiSettingsContent(
                controller: _pi ??= PiUpdateController()..load(),
                query: _query,
              ),
              _SettingsPage.plugins => () {
                final control = widget.control;
                if (control == null) {
                  return _PluginsUnavailable();
                }
                return PackagesSettingsContent(
                  controller: _plugins ??= PackagesController(control)..load(),
                  query: _query,
                );
              }(),
            };
            final page = Column(
              children: [
                if (compact)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        AppIconButton.subtle(
                          icon: Icons.arrow_back_rounded,
                          tooltip: l.settingsBack,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        pageSwitcher,
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: search),
                      ],
                    ),
                  ),
                Expanded(
                  child: Scrollbar(
                    controller: _scroll,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? AppSpacing.lg : AppSpacing.xxxl,
                        vertical: compact
                            ? AppSpacing.xxl
                            : AppSpacing.xxxl * 2,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 880),
                          child: AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : AppDurations.fast,
                            switchInCurve: AppCurves.inOut,
                            switchOutCurve: AppCurves.inOut,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: child,
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(_page),
                              child: content,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
            return AppDesktopScaffold(
              contentAnimation: ModalRoute.of(context)?.animation,
              sidebarBackground: WindowMaterialScope.tint(
                context,
                colors.sidebarBackground,
                controller.preferences.sidebarGlass,
              ),
              contentBackground: WindowMaterialScope.tint(
                context,
                colors.canvasBackground,
                controller.preferences.canvasGlass,
              ),
              animate:
                  WindowMaterialScope.statusOf(context) ==
                  WindowMaterialStatus.active,
              sidebar: compact ? null : sidebar,
              sidebarWidth: sidebarLayout.widthFor(constraints.maxWidth),
              onSidebarResize: (dx) => sidebarLayout.resizeBy(
                dx,
                viewportWidth: constraints.maxWidth,
              ),
              onSidebarReset: sidebarLayout.reset,
              child: page,
            );
          },
        ),
      ),
    );
  }
}

/// Shown when the plugins page is opened without a live control channel
/// (e.g. the home backend failed to start): no partial or fake state here.
class _PluginsUnavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.pluginsPageTitle, style: context.textTheme.displaySmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l.pluginsPageSubtitle,
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        AppCard(child: Text(l.pluginsNoChannel)),
      ],
    );
  }
}
