import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pi_gui/core/services/chat_resources.dart';
import 'package:pi_gui/core/services/clipboard_attachments.dart';
import 'package:pi_gui/core/services/file_attachments.dart';
import 'package:pi_gui/ui/features/home/controllers/image_attachment_controller.dart';

class _GrowingFile extends XFile {
  _GrowingFile(super.path);
  @override
  Future<int> length() async => 0;
  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    for (var i = 0; i < 21; i++) {
      yield Uint8List(1024 * 1024);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const a = FileAttachment(name: 'notes.md', path: '/cache/notes.md', size: 3);
  const b = FileAttachment(name: 'next.pdf', path: '/cache/next.pdf', size: 4);

  test(
    'copies are immutable snapshots, duplicate names stay distinct; failed batch rolls back',
    () async {
      final root = await Directory.systemTemp.createTemp('pi-gui-files-test-');
      addTearDown(() => root.delete(recursive: true));
      final source = await File(
        p.join(root.path, '中文 notes.md'),
      ).writeAsString('before');
      final cache = Directory(p.join(root.path, 'cache'));
      final store = FileAttachmentStore(directory: () async => cache);
      final first = await store.import([
        XFile(source.path),
        XFile(source.path),
      ]);
      expect(first[0].path, isNot(first[1].path));
      expect(first[0].name, '中文 notes.md');
      await source.writeAsString('after');
      expect(await File(first[0].path).readAsString(), 'before');
      await expectLater(
        store.import([XFile(source.path), XFile(root.path)]),
        throwsA(isA<FileAttachmentException>()),
      );
      await expectLater(
        store.import([_GrowingFile(source.path)]),
        throwsA(isA<FileAttachmentException>()),
      );
      expect(
        await cache.list().length,
        1,
      ); // only the successful batch survives
      expect(await File(first[0].path).readAsString(), 'before');
    },
  );

  test(
    'file manifest round-trips newlines, quotes and marker-like names; invalid text is not hidden',
    () {
      const odd = FileAttachment(
        name: 'a " </attached_files>\n.txt',
        path: 'D:\\cache\\a.txt',
        size: 12,
      );
      for (final text in ['', 'check these', 'keep trailing\n']) {
        final wire = FileAttachmentPrompt.compose(text, [a, odd]);
        final decoded = FileAttachmentPrompt.parse(wire)!;
        expect(decoded.text, text);
        expect(decoded.files.map((f) => f.name), [a.name, odd.name]);
        expect(decoded.files[1].path, odd.path);
        expect(wire, contains(jsonEncode(odd.name)));
      }
      expect(FileAttachmentPrompt.compose('plain', []), 'plain');
      expect(
        FileAttachmentPrompt.parse(
          'plain <attached_files>not ours</attached_files>',
        ),
        isNull,
      );
      final wire = FileAttachmentPrompt.compose('hello', [a]);
      expect(FileAttachmentPrompt.parse('$wire\nnot a suffix'), isNull);
      expect(
        FileAttachmentPrompt.parse(wire.replaceFirst('"size":3', '"size":-1')),
        isNull,
      );
      expect(
        FileAttachmentPrompt.parse(
          wire.replaceFirst('"path":"/cache/notes.md"', '"path":"relative.md"'),
        ),
        isNull,
      );
    },
  );

  test(
    'mixed clipboard drafts are atomic, workspace-safe, and accept only the send snapshot',
    () async {
      final image = ImageAttachment(
        name: 'pixel.png',
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/png',
      );
      var next = Completer<AttachmentBatch?>();
      final controller = ImageAttachmentController(paste: (_) => next.future);
      addTearDown(controller.dispose);
      controller.setWorkspace('one');
      final adding = controller.paste('image');
      next.complete(AttachmentBatch(images: [image], files: [a]));
      expect(await adding, true);
      final sentImages = controller.items, sentFiles = controller.files;
      next = Completer<AttachmentBatch?>();
      final more = controller.paste('image');
      next.complete(const AttachmentBatch(files: [b]));
      await more;
      controller.accept(sentImages, files: sentFiles);
      expect(controller.items, isEmpty);
      expect(controller.files, [b]);
      next = Completer<AttachmentBatch?>();
      final stale = controller.paste('image');
      controller.setWorkspace('two');
      next.complete(const AttachmentBatch(files: [a]));
      await stale;
      expect(controller.hasAttachments, false);
      controller.setWorkspace('one');
      expect(controller.files, [b]);
      next = Completer<AttachmentBatch?>();
      final switchedSession = controller.paste('image');
      controller.clear();
      next.complete(
        null,
      ); // must NOT trigger default text paste into a new session
      expect(await switchedSession, true);
      expect(controller.hasAttachments, false);
    },
  );

  test(
    'text delegates; invalid images, busy paste and file limits preserve the draft',
    () async {
      AttachmentBatch? selected;
      final controller = ImageAttachmentController(
        paste: (_) async => selected,
      );
      addTearDown(controller.dispose);
      expect(await controller.paste('image'), false);
      selected = const AttachmentBatch(files: [a]);
      await controller.paste('image');
      selected = AttachmentBatch(files: List.filled(8, b));
      await controller.paste('image');
      expect(controller.files, [a]);
      expect(controller.fileFailure, FileAttachmentFailure.tooMany);
      selected = AttachmentBatch(
        files: List.filled(
          3,
          const FileAttachment(
            name: 'big.bin',
            path: '/cache/big.bin',
            size: 20 * 1024 * 1024,
          ),
        ),
      );
      await controller.paste('image');
      expect(controller.fileFailure, FileAttachmentFailure.tooLarge);
      expect(controller.files, [a]);
      final pending = Completer<AttachmentBatch?>();
      final busy = ImageAttachmentController(paste: (_) => pending.future);
      addTearDown(busy.dispose);
      final first = busy.paste('image');
      expect(await busy.paste('image'), true);
      pending.complete(null);
      expect(await first, false);
      final unavailable = ImageAttachmentController(
        paste: (_) async => throw const ClipboardReadException(),
      );
      addTearDown(unavailable.dispose);
      expect(await unavailable.paste('image'), false);
      expect(unavailable.pasteFailed, true);
    },
  );
}
