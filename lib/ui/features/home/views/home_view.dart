import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:pi_gui/core/rpc/pi_rpc_client.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/core/rpc/pi_workspace_transport.dart';
import 'package:pi_gui/ui/atoms/app_desktop_scaffold.dart';
import 'package:pi_gui/core/services/window_material_service.dart';
import 'package:pi_gui/ui/core/window_material_scope.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/chat_resource_scope.dart';
import 'package:pi_gui/ui/core/sidebar_layout_controller.dart';
import '../controllers/image_attachment_controller.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';
import '../controllers/chat_controller.dart';
import '../controllers/model_picker_controller.dart';
import '../controllers/pi_extension_ui_bridge.dart';
import '../controllers/workspace_controller.dart';
import '../widgets/home_chat_panel.dart';
import '../widgets/home_sidebar.dart';
import '../widgets/tool_card_registry.dart';
import '../widgets/workspace_dialog.dart';
import '../../settings/views/appearance_settings_view.dart';
import '../../settings/controllers/appearance_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> with WindowListener {
  final _pi = PiRpcClient(transportFactory: PiWorkspaceTransport.start);
  final _input = TextEditingController();
  final _attachments = ImageAttachmentController();
  late final ModelPickerController _modelPicker;
  late final PiExtensionUiBridge _extensionUi;
  late final ChatController _chat;
  late final WorkspaceController _workspace;
  late final StreamSubscription<PiRpcEvent> _events;
  final _drafts = <String, TextEditingValue>{};
  String? _draftWorkspace;
  final _toolCards = ToolCardRegistry();
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _modelPicker = ModelPickerController(_pi);
    _extensionUi = PiExtensionUiBridge(_pi, _input);
    _chat = ChatController(_pi);
    _workspace = WorkspaceController(_pi, _chat, _modelPicker);
    _workspace.addListener(_workspaceUpdated);
    _events = _pi.events.listen((event) {
      if (event is PiRpcWorkspaceChanged) {
        if (_draftWorkspace case final old?) _drafts[old] = _input.value;
        _draftWorkspace = event.path;
        _attachments.setWorkspace(event.path);
        _input.value = _drafts[event.path] ?? TextEditingValue.empty;
      }
    });
    windowManager.addListener(this);
    unawaited(windowManager.setPreventClose(true).catchError((Object _) {}));
    unawaited(_workspace.refresh());
  }

  void _workspaceUpdated() {
    _draftWorkspace ??= _workspace.snapshot?.current.path;
    if (_draftWorkspace case final path?) _attachments.setWorkspace(path);
  }

  Future<void> _chooseWorkspace([bool worktrees = false]) async {
    if (!_workspace.canSwitch) return;
    _workspace.dismissFailure();
    // Refresh the real Git list before presenting branches/worktrees.
    await _workspace.refresh(loadConversation: false);
    if (!mounted) return;
    await showAppDialog<void>(
      context,
      (_) => WorkspaceDialog(
        controller: _workspace,
        initialPage: worktrees
            ? WorkspaceDialogPage.worktrees
            : WorkspaceDialogPage.choose,
      ),
    );
  }

  Future<void> _changeSession([String? path]) async {
    if (!_workspace.canSwitch) return;
    if (await _chat.changeSession(path: path) && mounted) {
      _input.clear();
      _attachments.clear();
      unawaited(_workspace.refreshSessions());
      unawaited(_modelPicker.refresh());
    }
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    await _pi.close();
    await AppearanceController.instance.settled;
    await windowManager.destroy();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    unawaited(_events.cancel());
    _workspace.removeListener(_workspaceUpdated);
    _workspace.dispose();
    _chat.dispose();
    _extensionUi.dispose();
    _modelPicker.dispose();
    _input.dispose();
    _attachments.dispose();
    unawaited(_pi.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final preferences = AppearanceScope.of(context).preferences;
    final sidebarLayout = SidebarLayoutController.instance;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: Listenable.merge([
          _workspace,
          _chat,
          _modelPicker,
          sidebarLayout,
        ]),
        builder: (context, _) => AppDesktopScaffold(
          sidebarBackground: WindowMaterialScope.tint(
            context,
            colors.sidebarBackground,
            preferences.sidebarGlass,
          ),
          contentBackground: WindowMaterialScope.tint(
            context,
            colors.canvasBackground,
            preferences.canvasGlass,
          ),
          animate:
              WindowMaterialScope.statusOf(context) ==
              WindowMaterialStatus.active,
          sidebarWidth: sidebarLayout.widthFor(constraints.maxWidth),
          onSidebarResize: (dx) =>
              sidebarLayout.resizeBy(dx, viewportWidth: constraints.maxWidth),
          onSidebarReset: sidebarLayout.reset,
          sidebar: HomeSidebar(
            backgroundColor: Colors.transparent,
            width: sidebarLayout.widthFor(constraints.maxWidth),
            workspace: _workspace,
            selectedSessionId: _chat.sessionFile,
            onSessionSelected: _changeSession,
            onNewConversation: _changeSession,
            onChooseWorkspace: _chooseWorkspace,
            onChooseWorktree: () => _chooseWorkspace(true),
            onSettingsPressed: () => showAppearanceSettings(context),
          ),
          child: ChatResourceScope(
            directory: _workspace.snapshot?.current.path,
            child: HomeChatPanel(
              chat: _chat,
              modelPicker: _modelPicker,
              input: _input,
              attachments: _attachments,
              project:
                  _workspace.snapshot?.current.name ??
                  context.l10n.workspaceLoading,
              registry: _toolCards,
            ),
          ),
        ),
      ),
    );
  }
}
