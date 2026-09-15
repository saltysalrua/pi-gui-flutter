import 'package:flutter/material.dart';
import 'package:pi_gui/core/services/chat_resources.dart';
import 'context_l10n.dart';

/// Resource paths are relative to Pi's current workspace, not the GUI process cwd.
class ChatResourceScope extends InheritedWidget {
  const ChatResourceScope({
    super.key,
    required this.directory,
    required super.child,
  });
  final String? directory;
  static String? directoryOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ChatResourceScope>()
      ?.directory;

  static Future<void> open(BuildContext context, String href) async {
    final uri = ChatResources.resolve(href, directory: directoryOf(context));
    final opened = uri != null && await ChatResources.open(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.chatOpenLinkFailed)));
    }
  }

  @override
  bool updateShouldNotify(ChatResourceScope oldWidget) =>
      directory != oldWidget.directory;
}
