import 'package:flutter/widgets.dart';

/// Default tool rows use this scope to keep their full output pinned against
/// the session's byte budget and to ask for a history re-read after an old
/// output was released. Outside a chat panel (or in a custom renderer) both
/// capabilities are simply absent.
class ChatToolOutputScope extends InheritedWidget {
  const ChatToolOutputScope({
    super.key,
    required this.reload,
    required this.setPinned,
    required super.child,
  });

  /// Re-reads history so a released output comes back complete. Never sends
  /// a prompt; the id is pinned against the next budget pass.
  final Future<void> Function(String toolCallId) reload;

  /// Expanded rows keep their full output; collapsing releases the pin.
  final void Function(String toolCallId, bool pinned) setPinned;

  static ChatToolOutputScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ChatToolOutputScope>();

  @override
  bool updateShouldNotify(ChatToolOutputScope oldWidget) =>
      reload != oldWidget.reload || setPinned != oldWidget.setPinned;
}
