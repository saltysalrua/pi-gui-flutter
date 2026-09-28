import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/l10n/app_localizations.dart';

/// 菜单条目来源：GUI 内置映射、仅终端可用、Pi 返回的扩展/模板/技能命令。
enum SlashEntryKind { builtin, terminal, extension, prompt, skill }

class SlashMenuEntry {
  const SlashMenuEntry({
    required this.name,
    required this.description,
    required this.kind,
  });
  final String name, description;
  final SlashEntryKind kind;
}

/// GUI 有等价操作的内置命令；发送前拦截，绝不经 prompt 喂给模型。
enum SlashBuiltinAction {
  newSession,
  compact,
  rename,
  model,
  historyNavigate,
  historyFork,
  historyClone,
}

class SlashBuiltin {
  const SlashBuiltin(this.name, this.action);
  final String name;
  final SlashBuiltinAction action;
}

/// 与 docs/slash-commands.md（Pi 官方文档）中的 TUI 内置命令对齐。
const slashBuiltins = [
  SlashBuiltin('new', SlashBuiltinAction.newSession),
  SlashBuiltin('resume', SlashBuiltinAction.historyNavigate),
  SlashBuiltin('tree', SlashBuiltinAction.historyNavigate),
  SlashBuiltin('fork', SlashBuiltinAction.historyFork),
  SlashBuiltin('clone', SlashBuiltinAction.historyClone),
  SlashBuiltin('compact', SlashBuiltinAction.compact),
  SlashBuiltin('name', SlashBuiltinAction.rename),
  SlashBuiltin('model', SlashBuiltinAction.model),
];

/// 没有 GUI 等价物、也不该掉进模型的终端专用命令。
const terminalOnlySlashCommands = {
  'settings',
  'thinking',
  'scoped-models',
  'login',
  'logout',
  'llama',
  'session',
  'import',
  'copy',
  'export',
  'share',
  'bug',
  'trust',
  'reload',
  'hotkeys',
  'changelog',
  'quit',
};

SlashBuiltinAction? slashBuiltinActionFor(String name) {
  for (final builtin in slashBuiltins) {
    if (builtin.name == name) return builtin.action;
  }
  return null;
}

bool isTerminalOnlySlashCommand(String name) =>
    terminalOnlySlashCommands.contains(name);

/// 首个以 / 开头的空白分隔 token。光标必须仍在首个 token 内才会弹出菜单；
/// 解析发送内容时只要行首是 / 命令就返回。
class SlashToken {
  const SlashToken(this.name, this.args);
  final String name, args;
}

/// 提取行首斜杠命令名与参数；非命令文本返回 null。
SlashToken? parseSlashToken(String text) {
  if (!text.startsWith('/')) return null;
  final boundary = text.indexOf(RegExp(r'\s'));
  final name = boundary < 0 ? text.substring(1) : text.substring(1, boundary);
  if (name.isEmpty) return null;
  final args = boundary < 0 ? '' : text.substring(boundary).trim();
  return SlashToken(name, args);
}

/// 首个 token 即命令且光标落在 token 内时返回去 / 后的查询，否则 null。
/// 与 [parseSlashToken] 不同：单独一个 / 也返回空串，让菜单展示全量列表。
String? slashMenuQuery(String text, int cursor) {
  if (!text.startsWith('/')) return null;
  final boundary = text.indexOf(RegExp(r'\s'));
  final tokenLength = boundary < 0 ? text.length : boundary;
  if (cursor >= 0 && cursor > tokenLength) return null;
  return text.substring(1, tokenLength);
}

/// 内置命令在 GUI 里能干什么的说明；终端专用命令共用一条说明。
List<SlashMenuEntry> builtinSlashEntries(AppLocalizations l10n) => [
  for (final builtin in slashBuiltins)
    SlashMenuEntry(
      name: builtin.name,
      description: switch (builtin.action) {
        SlashBuiltinAction.newSession => l10n.slashDescNew,
        SlashBuiltinAction.historyNavigate =>
          builtin.name == 'resume' ? l10n.slashDescResume : l10n.slashDescTree,
        SlashBuiltinAction.historyFork => l10n.slashDescFork,
        SlashBuiltinAction.historyClone => l10n.slashDescClone,
        SlashBuiltinAction.compact => l10n.slashDescCompact,
        SlashBuiltinAction.rename => l10n.slashDescName,
        SlashBuiltinAction.model => l10n.slashDescModel,
      },
      kind: SlashEntryKind.builtin,
    ),
  for (final name in terminalOnlySlashCommands)
    SlashMenuEntry(
      name: name,
      description: l10n.slashDescTerminal,
      kind: SlashEntryKind.terminal,
    ),
];

/// 远端命令与内置命令合并；同名时远端（get_commands 实测存在）优先。
List<SlashMenuEntry> mergeSlashEntries(
  List<SlashMenuEntry> builtins,
  List<PiSlashCommand> remote,
) {
  final names = remote.map((command) => command.name).toSet();
  return [
    for (final command in remote)
      SlashMenuEntry(
        name: command.name,
        description: command.description ?? '',
        kind: switch (command.source) {
          'extension' => SlashEntryKind.extension,
          'prompt' => SlashEntryKind.prompt,
          'skill' => SlashEntryKind.skill,
          _ => SlashEntryKind.extension,
        },
      ),
    for (final entry in builtins)
      if (!names.contains(entry.name)) entry,
  ];
}

/// 按查询排序：完全匹配 > 前缀 > 名称包含 > 说明包含；空查询保持原序。
List<SlashMenuEntry> filterSlashEntries(
  List<SlashMenuEntry> entries,
  String query,
) {
  if (query.isEmpty) return entries;
  final ranked = <(int, SlashMenuEntry)>[];
  for (final entry in entries) {
    final name = entry.name;
    if (name == query) {
      ranked.add((-1, entry));
    } else if (name.startsWith(query)) {
      ranked.add((0, entry));
    } else if (name.contains(query)) {
      ranked.add((1, entry));
    } else if (entry.description.toLowerCase().contains(query.toLowerCase())) {
      ranked.add((2, entry));
    }
  }
  ranked.sort((a, b) {
    final byRank = a.$1.compareTo(b.$1);
    return byRank != 0 ? byRank : a.$2.name.compareTo(b.$2.name);
  });
  return [for (final (_, entry) in ranked) entry];
}

bool hasExactSlashEntry(List<SlashMenuEntry> entries, String name) =>
    entries.any((entry) => entry.name == name);
