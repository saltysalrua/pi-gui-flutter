import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_rpc_types.dart';
import 'package:pi_gui/ui/features/home/controllers/model_picker_controller.dart';

const reasoning = PiModel(
  id: 'same-id',
  name: 'Same Model',
  provider: 'reasoning-provider',
  reasoning: true,
);
const plain = PiModel(
  id: 'same-id',
  name: 'Same Model',
  provider: 'plain-provider',
  reasoning: false,
);

class FakePi implements PiModelGateway {
  final bus = StreamController<PiRpcEvent>.broadcast();
  PiSessionState state = const PiSessionState(
    model: reasoning,
    thinkingLevel: PiThinkingLevel.high,
  );
  List<PiModel> models = [reasoning, plain];
  Completer<void>? writeGate, levelsGate;
  bool failWrite = false;
  bool failRead = false;
  bool failLevels = false;
  bool legacy = false;
  int stateReads = 0, levelsReads = 0;
  int writes = 0;
  int connections = 0;
  bool failConnect = false;
  @override
  Stream<PiRpcEvent> get events => bus.stream;
  @override
  Future<void> connect() async {
    connections++;
    if (failConnect) throw const PiRpcException('Pi unavailable');
  }

  @override
  Future<List<PiModel>> getAvailableModels() async => models;
  @override
  Future<PiSessionState> getState() async {
    stateReads++;
    if (failRead) throw const PiRpcException('Read failed');
    return state;
  }

  @override
  Future<List<PiThinkingLevel>> getAvailableThinkingLevels() async {
    levelsReads++;
    await levelsGate?.future;
    if (failLevels) throw const PiRpcException('Levels unavailable');
    if (legacy) {
      throw const PiRpcException(
        'Unknown command: get_available_thinking_levels',
        command: 'get_available_thinking_levels',
      );
    }
    return state.model?.reasoning == true
        ? [
            PiThinkingLevel.off,
            PiThinkingLevel.low,
            PiThinkingLevel.high,
            PiThinkingLevel.xhigh,
          ]
        : [PiThinkingLevel.off];
  }

  @override
  Future<PiModel> setModel(PiModel model) async {
    writes++;
    await writeGate?.future;
    if (failWrite) {
      throw const PiRpcException('No API key', command: 'set_model');
    }
    state = PiSessionState(
      model: model,
      thinkingLevel: model.reasoning
          ? PiThinkingLevel.high
          : PiThinkingLevel.off,
    );
    return model;
  }

  @override
  Future<void> setThinkingLevel(PiThinkingLevel level) async {
    writes++;
    await writeGate?.future;
    if (failWrite) {
      throw const PiRpcException('Write failed', command: 'set_thinking_level');
    }
    state = PiSessionState(model: state.model, thinkingLevel: level);
  }

  @override
  Future<void> close() => bus.close();
}

void main() {
  late FakePi pi;
  late ModelPickerController picker;
  setUp(() {
    pi = FakePi();
    picker = ModelPickerController(pi);
  });
  tearDown(() async {
    picker.dispose();
    await pi.close();
  });

  test('reads exact backend levels and searches provider/name/id without conflating identities', () async {
    await picker.refresh();
    expect(picker.thinkingLevels, [
      PiThinkingLevel.off,
      PiThinkingLevel.low,
      PiThinkingLevel.high,
      PiThinkingLevel.xhigh,
    ]);
    expect(picker.thinkingLevel, PiThinkingLevel.high);
    expect(picker.search('  SAME   plain-PROVIDER  '), [plain]);
    expect(picker.search('same-id'), [reasoning, plain]);
    expect(picker.search('missing'), isEmpty);
    expect(reasoning.sameIdentity(plain), isFalse);
    expect(await picker.selectThinkingLevel(PiThinkingLevel.minimal), isFalse);
    expect(pi.writes, 0);
    expect(await picker.selectThinkingLevel(PiThinkingLevel.xhigh), isTrue);
    expect(picker.thinkingLevel, PiThinkingLevel.xhigh);
  });

  test(
    'writes are serialized and model changes read back clamped thinking state',
    () async {
      await picker.refresh();
      pi.writeGate = Completer<void>();
      final change = picker.selectModel(plain);
      expect(picker.isBusy, isTrue);
      expect(picker.selectedModel, reasoning); // 不能乐观显示成功。
      expect(await picker.selectModel(reasoning), isFalse);
      expect(await picker.selectThinkingLevel(PiThinkingLevel.low), isFalse);
      pi.writeGate!.complete();
      expect(await change, isTrue);
      expect(pi.writes, 1);
      expect(picker.selectedModel, plain);
      expect(picker.thinkingLevels, [PiThinkingLevel.off]);
      expect(picker.thinkingLevel, PiThinkingLevel.off);
      expect(picker.canChangeThinking, isFalse);
    },
  );

  test('opening a ready picker does not read or pulse the busy lock', () async {
    await picker.ensureLoaded();
    var notifications = 0;
    picker.addListener(() => notifications++);
    for (var i = 0; i < 5; i++) {
      await picker.ensureLoaded();
    }
    expect(notifications, 0);
    expect(pi.connections, 1);
    expect(pi.stateReads, 1);
    expect(pi.levelsReads, 1);
    // 显式刷新仍读取，错误后再次打开仍能恢复。
    pi.failRead = true;
    await picker.refresh();
    expect(picker.isReady, isFalse);
    pi.failRead = false;
    await picker.ensureLoaded();
    expect(picker.isReady, isTrue);
    expect(pi.stateReads, 3);
  });

  test(
    'selection snapshot stays atomic while levels are pending or fail',
    () async {
      await picker.refresh();
      final confirmedState = picker.state;
      final confirmedLevels = picker.thinkingLevels;
      pi.levelsGate = Completer<void>();
      pi.failLevels = true;
      final change = picker.selectModel(plain);
      await Future<void>.delayed(Duration.zero);
      expect(pi.levelsReads, 2); // 新 state 已返回，但档位还未确认。
      expect(picker.state, same(confirmedState));
      expect(picker.thinkingLevels, same(confirmedLevels));
      expect(picker.isBusy, isTrue);
      pi.levelsGate!.complete();
      expect(await change, isFalse);
      expect(picker.state, same(confirmedState));
      expect(picker.thinkingLevels, same(confirmedLevels));
      expect(picker.canChangeModel, isFalse);
      pi.failLevels = false;
      await picker.ensureLoaded();
      expect(picker.selectedModel, plain);
      expect(picker.thinkingLevels, [PiThinkingLevel.off]);
    },
  );

  test(
    'rapid thinking commits stay serialized until readback completes',
    () async {
      await picker.refresh();
      pi.writeGate = Completer<void>();
      pi.levelsGate = Completer<void>();
      final change = picker.selectThinkingLevel(PiThinkingLevel.low);
      expect(picker.isBusy, isTrue);
      expect(picker.thinkingLevel, PiThinkingLevel.high);
      expect(await picker.selectThinkingLevel(PiThinkingLevel.xhigh), isFalse);
      pi.writeGate!.complete();
      await Future<void>.delayed(Duration.zero);
      expect(pi.levelsReads, 2);
      expect(picker.thinkingLevel, PiThinkingLevel.high);
      expect(picker.thinkingLevels.length, 4);
      expect(await picker.selectThinkingLevel(PiThinkingLevel.off), isFalse);
      pi.levelsGate!.complete();
      expect(await change, isTrue);
      expect(picker.thinkingLevel, PiThinkingLevel.low);
      expect(picker.canChangeThinking, isTrue);
      expect(pi.writes, 1);
    },
  );

  test(
    'failed write retains confirmed selection and refresh recovers',
    () async {
      await picker.refresh();
      pi.failWrite = true;
      expect(await picker.selectModel(plain), isFalse);
      expect(picker.selectedModel, reasoning);
      expect(picker.failure, ModelPickerFailure.changeModel);
      expect(picker.canChangeModel, isFalse);
      pi.failWrite = false;
      await picker.refresh();
      expect(picker.failure, isNull);
      expect(picker.canChangeModel, isTrue);
    },
  );

  test(
    'successful write followed by read failure requires authoritative refresh',
    () async {
      await picker.refresh();
      pi.failRead = true;
      expect(await picker.selectModel(plain), isFalse);
      expect(picker.canChangeModel, isFalse);
      pi.failRead = false;
      await picker.refresh();
      expect(picker.selectedModel, plain);
      expect(picker.thinkingLevel, PiThinkingLevel.off);
    },
  );

  test(
    'real disconnect reconnects with reads only and bounds repeated failures',
    () async {
      final recovering = ModelPickerController(
        pi,
        reconnectDelay: Duration.zero,
      );
      await recovering.refresh();
      pi.bus.add(const PiRpcDisconnected());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(recovering.isReady, isTrue);
      expect(recovering.failure, isNull);
      expect(pi.writes, 0);
      expect(pi.connections, 2);
      pi.failConnect = true;
      pi.bus.add(const PiRpcDisconnected());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(pi.connections, 5); // 初次连接 + 恢复一次 + 最多三次重试。
      expect(recovering.isReady, isFalse);
      recovering.dispose();
    },
  );

  test(
    'late selection acknowledgement schedules a read, never replays a write',
    () async {
      await picker.refresh();
      pi.state = const PiSessionState(
        model: plain,
        thinkingLevel: PiThinkingLevel.off,
      );
      pi.bus.add(const PiRpcSelectionSettled());
      await Future<void>.delayed(Duration.zero);
      expect(picker.selectedModel, plain);
      expect(picker.thinkingLevel, PiThinkingLevel.off);
      expect(pi.writes, 0);
    },
  );

  test(
    'late read repairs a catalog snapshot taken during the Pi startup window',
    () async {
      final windowed = ModelPickerController(pi, lateReadDelay: Duration.zero);
      await windowed.refresh();
      expect(windowed.models.length, 2);
      // 模拟 Pi 后台目录刷新结束后补齐模型。
      pi.models = [
        reasoning,
        plain,
        const PiModel(
          id: 'late-arrival',
          name: 'Late Arrival',
          provider: 'reasoning-provider',
          reasoning: true,
        ),
      ];
      var notifications = 0;
      windowed.addListener(() => notifications++);
      await pumpEventQueue();
      expect(windowed.models.length, 3);
      expect(notifications, 1);
      expect(windowed.isBusy, isFalse);
      expect(windowed.failure, isNull);
      expect(windowed.isReady, isTrue);
      // 每个进程周期只补读一次，后续读取不再触发额外通知。
      pi.models = [reasoning];
      await pumpEventQueue();
      expect(windowed.models.length, 3);
      expect(notifications, 1);
      windowed.dispose();
    },
  );

  test(
    'empty catalog, old Pi, and disconnection do not invent choices',
    () async {
      pi.models = [];
      pi.state = const PiSessionState(
        model: null,
        thinkingLevel: PiThinkingLevel.off,
      );
      await picker.refresh();
      expect(picker.models, isEmpty);
      expect(picker.selectedModel, isNull);
      expect(picker.canChangeThinking, isFalse);
      pi.models = [reasoning];
      pi.legacy = true;
      await picker.refresh();
      expect(picker.canChangeModel, isTrue);
      expect(picker.thinkingLevels, isEmpty);
      expect(picker.thinkingLevelsUnavailable, isTrue);
      pi.bus.add(const PiRpcDisconnected());
      await Future<void>.delayed(Duration.zero);
      expect(picker.failure, ModelPickerFailure.disconnected);
      expect(picker.canChangeModel, isFalse);
    },
  );
}
