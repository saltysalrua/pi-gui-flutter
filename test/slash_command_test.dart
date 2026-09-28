import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/chat_controller.dart';
import 'package:pi_gui/ui/features/home/controllers/slash_command_controller.dart';
import 'package:pi_gui/ui/features/home/slash_commands.dart';

import 'chat_rpc_test.dart' show FakeChatGateway;

class FakeCommandGateway implements PiCommandGateway {
  final stream = StreamController<PiRpcEvent>.broadcast(sync: true);
  int reads = 0;
  List<PiSlashCommand> commands = const [];
  Object? error;

  @override
  Stream<PiRpcEvent> get events => stream.stream;

  @override
  Future<List<PiSlashCommand>> getCommands() async {
    reads++;
    if (error != null) throw error!;
    return commands;
  }
}

PiSlashCommand command(String name, {String source = 'extension'}) =>
    PiSlashCommand(name: name, source: source, description: 'd-$name');

void main() {
  test('PiSlashCommand parses sourceInfo and skips malformed entries', () {
    final parsed = PiSlashCommand.fromJson({
      'name': 'fix-tests',
      'description': 'Fix failing tests',
      'source': 'prompt',
      'sourceInfo': {'path': '/prompts/fix-tests.md'},
    });
    expect(parsed.name, 'fix-tests');
    expect(parsed.source, 'prompt');
    expect(parsed.path, '/prompts/fix-tests.md');

    final legacy = piSlashCommands({
      'commands': [
        {'name': 'old', 'source': 'extension', 'path': '/old.mjs'},
        {'name': ''},
        'not-a-map',
      ],
    });
    expect(legacy, hasLength(1));
    expect(legacy.single.name, 'old');
    expect(legacy.single.path, '/old.mjs');
  });

  test('parseSlashToken and slashMenuQuery respect cursor position', () {
    expect(parseSlashToken('hello'), isNull);
    expect(parseSlashToken('/'), isNull);
    final token = parseSlashToken('/compact keep tests');
    expect(token!.name, 'compact');
    expect(token.args, 'keep tests');
    expect(parseSlashToken('/reload ')!.args, isEmpty);

    expect(slashMenuQuery('/comp', 5), 'comp');
    // 单独一个 / 也弹出菜单，展示全量列表。
    expect(slashMenuQuery('/', 1), '');
    // Cursor beyond the first token (typing args) closes the menu.
    expect(slashMenuQuery('/compact now', 12), isNull);
    expect(slashMenuQuery('plain text', 3), isNull);
  });

  test('mergeSlashEntries prefers remote commands over built-in names', () {
    final merged = mergeSlashEntries(
      [
        const SlashMenuEntry(
          name: 'name',
          description: '',
          kind: SlashEntryKind.builtin,
        ),
        const SlashMenuEntry(
          name: 'new',
          description: '',
          kind: SlashEntryKind.builtin,
        ),
      ],
      [command('name')],
    );
    expect(merged, hasLength(2));
    expect(merged.first.kind, SlashEntryKind.extension);
    expect(
      merged.where((e) => e.kind == SlashEntryKind.builtin).single.name,
      'new',
    );
  });

  test('filterSlashEntries ranks exact, prefix, contains and description', () {
    final entries = [
      const SlashMenuEntry(
        name: 'reload',
        description: '',
        kind: SlashEntryKind.terminal,
      ),
      const SlashMenuEntry(
        name: 'fix-tests',
        description: 'reload fixtures',
        kind: SlashEntryKind.prompt,
      ),
      const SlashMenuEntry(
        name: 'compact',
        description: '',
        kind: SlashEntryKind.builtin,
      ),
      const SlashMenuEntry(
        name: 'tree-sitter',
        description: 'rule files',
        kind: SlashEntryKind.skill,
      ),
    ];
    final filtered = filterSlashEntries(entries, 're');
    expect(
      filtered.map((e) => e.name).toList(),
      orderedEquals(['reload', 'tree-sitter', 'fix-tests']),
    );
    expect(filterSlashEntries(entries, 'compact').first.name, 'compact');
    // Empty query preserves discovery order.
    expect(filterSlashEntries(entries, '').map((e) => e.name).toList(), [
      'reload',
      'fix-tests',
      'compact',
      'tree-sitter',
    ]);
    expect(filterSlashEntries(entries, 'zzz'), isEmpty);
  });

  test('built-in lookup and terminal-only classification', () {
    expect(slashBuiltinActionFor('compact'), SlashBuiltinAction.compact);
    expect(slashBuiltinActionFor('quit'), isNull);
    expect(isTerminalOnlySlashCommand('quit'), isTrue);
    expect(isTerminalOnlySlashCommand('compact'), isFalse);
  });

  test('SlashCommandController loads lazily and refetches after staleness', () async {
    final pi = FakeCommandGateway();
    final controller = SlashCommandController(pi);
    addTearDown(controller.dispose);
    addTearDown(pi.stream.close);

    await controller.ensureLoaded();
    expect(pi.reads, 1);
    expect(controller.isReady, isTrue);
    expect(controller.commands, isEmpty);

    // Fresh cache: no extra read.
    await controller.ensureLoaded();
    expect(pi.reads, 1);

    pi.commands = [command('fix-tests', source: 'prompt')];
    // An agent_settled event marks the cache stale.
    pi.stream.add(const PiAgentEvent('agent_settled', {}));
    await controller.ensureLoaded();
    expect(pi.reads, 2);
    expect(controller.commands.single.name, 'fix-tests');

    // A disconnect is also staleness; a failed read keeps the old list usable.
    pi.stream.add(const PiRpcDisconnected());
    pi.error = const PiRpcException('Pi exited');
    await controller.ensureLoaded();
    expect(pi.reads, 3);
    expect(controller.failure, SlashCommandFailure.load);
    expect(controller.commands.single.name, 'fix-tests');
  });

  test(
    'ChatController.compact dispatches the RPC and guards busy sessions',
    () async {
      final pi = FakeChatGateway();
      final chat = ChatController(pi);
      addTearDown(chat.dispose);
      addTearDown(pi.stream.close);

      await chat.refresh();
      expect(chat.isReady, isTrue);
      expect(await chat.compact('keep tests'), isTrue);
      expect(pi.commands, contains('compact:keep tests'));

      pi.commands.clear();
      pi.stream.add(PiChatEvent('agent_start', {}));
      expect(chat.isRunning, isTrue);
      expect(await chat.compact(null), isFalse);
      expect(pi.commands.where((c) => c.startsWith('compact:')), isEmpty);
    },
  );

  test('ChatController.rename updates the projected name only', () async {
    final pi = FakeChatGateway();
    final chat = ChatController(pi);
    addTearDown(chat.dispose);
    addTearDown(pi.stream.close);

    await chat.refresh();
    expect(await chat.rename('probe-name'), isTrue);
    expect(pi.commands, contains('set_session_name:probe-name'));
    expect(chat.state?.sessionName, 'probe-name');
    expect(chat.title, 'probe-name');

    pi.error = const PiRpcException('unknown command');
    expect(await chat.rename('again'), isFalse);
    expect(chat.failure, ChatFailure.rename);
  });
}
