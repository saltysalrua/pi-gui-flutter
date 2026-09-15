import 'package:flutter_test/flutter_test.dart';
import 'package:pi_gui/core/utils/terminal_text.dart';

void main() {
  test('terminal colors disappear without changing thinking or Markdown', () {
    const raw =
        '\x1b[38;2;138;190;183mThinking:\x1b[39m '
        '\x1b[38;2;128;128;128mDelete the quarantine folder.\x1b[39m';
    expect(
      stripTerminalControls(raw),
      'Thinking: Delete the quarantine folder.',
    );
    const markdown = '## 中文 😀\n\n- **保留正文**\r\n\t`[1;2m` 与 `\\x1b[31m`';
    expect(stripTerminalControls(markdown), markdown);
  });

  test(
    'OSC hyperlinks and other controls keep labels, never hidden payloads',
    () {
      expect(
        stripTerminalControls(
          '\x1b]8;;https://example.com\x07link\x1b]8;;\x1b\\',
        ),
        'link',
      );
      expect(stripTerminalControls('\x9b31m红\x9b0m\x9d0;title\x9c字'), '红字');
      expect(
        stripTerminalControls('a\x1bPpayload\x1b\\b\x1b(Bc\x07\x00'),
        'abc',
      );
      expect(stripTerminalControls('a\x1b[31中文'), 'a中文');
    },
  );

  test('split streaming controls never flash incomplete escapes', () {
    const sequences = [
      '\x1b[38;2;138;190;183m',
      '\x1b]8;;https://example.com\x1b\\',
      '\x1b]0;title\x07',
      '\x9b38:2::138:190:183m',
    ];
    for (final sequence in sequences) {
      for (var end = 1; end <= sequence.length; end++) {
        expect(stripTerminalControls('正文${sequence.substring(0, end)}'), '正文');
      }
      expect(stripTerminalControls('正文$sequence继续'), '正文继续');
    }
  });
}
