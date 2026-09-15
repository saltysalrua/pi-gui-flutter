import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/services/chat_resources.dart';
import 'package:pi_gui/ui/features/home/controllers/image_attachment_controller.dart';

const pixel =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=';
ImageAttachment attachment(String name) => ImageAttachment(
  name: name,
  bytes: base64Decode(pixel),
  mimeType: 'image/png',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'file links resolve against workspace with Windows paths, escapes and line hints',
    () {
      Uri? resolve(String value) =>
          ChatResources.resolve(value, directory: r'D:\Code\project');
      for (final href in [
        './lib/a.dart#L12',
        r'lib\a.dart:12:3',
        'D:/Code/project/lib/a.dart:12',
        r'D:\Code\project\lib\a.dart',
        'D:%5CCode%5Cproject%5Clib%5Ca.dart',
        'file:///D:/Code/project/lib/a.dart#L12C3',
      ]) {
        expect(
          resolve(href).toString(),
          'file:///D:/Code/project/lib/a.dart',
          reason: href,
        );
      }
      expect(
        resolve('docs/%E4%B8%AD%20%E6%96%87.md')!.toFilePath(windows: true),
        r'D:\Code\project\docs\中 文.md',
      );
      expect(
        resolve('../other/file.md').toString(),
        'file:///D:/Code/other/file.md',
      );
      expect(ChatResources.resolve('a.md'), isNull);
      expect(
        ChatResources.resolve('a.md', directory: '/work/repo').toString(),
        'file:///work/repo/a.md',
      );
      expect(
        resolve('https://example.com/a?q=1#anchor').toString(),
        'https://example.com/a?q=1#anchor',
      );
    },
  );

  test(
    'unsafe schemes, SMB, device paths and executable associations are blocked',
    () {
      for (final href in [
        'javascript:alert(1)',
        'command:run',
        'data:text/html,hello',
        'vscode://file/a',
        '//server/share/image.png',
        r'\\server\share\a.png',
        'file://server/share/a',
        r'\\?\C:\a',
        'a%00.md',
        'https://name:password@example.com',
        'file:///D:/a.md?query',
        r'D:\a.md:stream',
        'file:///D:/NUL.png',
      ]) {
        expect(
          ChatResources.resolve(href, directory: 'D:/repo'),
          isNull,
          reason: href,
        );
      }
      for (final name in [
        'a.exe',
        'a.CMD',
        'a.lnk',
        'a.url',
        'a.js',
        'a.ps1',
      ]) {
        expect(
          ChatResources.canOpen(
            ChatResources.resolve(name, directory: 'D:/repo')!,
          ),
          false,
        );
      }
      expect(
        ChatResources.canOpen(
          ChatResources.resolve('a.md', directory: 'D:/repo')!,
        ),
        true,
      );
    },
  );

  test(
    'image bytes are validated, not trusted from an extension or MIME string',
    () async {
      final bytes = await ImageResources.decode(
        const PiImage(data: pixel, mimeType: 'image/png'),
      );
      expect(bytes, base64Decode(pixel));
      await expectLater(
        ImageResources.decode(
          const PiImage(data: 'not base64!', mimeType: 'image/png'),
        ),
        throwsFormatException,
      );
      await expectLater(
        ImageResources.decode(
          const PiImage(data: pixel, mimeType: 'image/jpeg'),
        ),
        throwsA(isA<ImageResourceException>()),
      );
      await expectLater(
        ImageResources.decode(
          PiImage(
            data: base64Encode(utf8.encode('<svg/>')),
            mimeType: 'image/svg+xml',
          ),
        ),
        throwsA(isA<ImageResourceException>()),
      );
    },
  );

  test(
    'attachment drafts isolate workspaces, ignore stale pickers and only clear accepted items',
    () async {
      var next = Completer<List<ImageAttachment>>();
      final drafts = ImageAttachmentController(pick: (_) => next.future);
      addTearDown(drafts.dispose);
      drafts.setWorkspace('first');
      final a = attachment('a.png');
      final b = attachment('b.png');
      final picking = drafts.choose('images');
      next.complete([a]);
      await picking;
      final sent = drafts.items;
      next = Completer<List<ImageAttachment>>();
      final adding = drafts.choose('images');
      next.complete([b]);
      await adding;
      drafts.accept(sent);
      expect(drafts.items, [b]);
      drafts.setWorkspace('second');
      expect(drafts.items, isEmpty);
      next = Completer<List<ImageAttachment>>();
      final stale = drafts.choose('images');
      drafts.setWorkspace('first');
      next.complete([a]);
      await stale;
      expect(drafts.items, [b]);
      next = Completer<List<ImageAttachment>>();
      final cancelled = drafts.choose('images');
      drafts.clear();
      next.complete([a]);
      await cancelled;
      expect(drafts.items, isEmpty);
      expect(drafts.isPicking, false);
    },
  );

  test(
    'picker failure and attachment limits leave the existing draft untouched',
    () async {
      var selected = [attachment('first.png')];
      final drafts = ImageAttachmentController(pick: (_) async => selected);
      addTearDown(drafts.dispose);
      await drafts.choose('images');
      final original = drafts.items;
      selected = List.generate(8, (i) => attachment('$i.png'));
      await drafts.choose('images');
      expect(drafts.failure, ImageFailure.tooMany);
      expect(drafts.items, original);
      selected = [];
      await drafts.choose('images');
      expect(drafts.items, original);
    },
  );
}
