/// Plain display text for terminal-formatted content. Never rewrite RPC data.
/// Incomplete escape sequences are hidden until the next accumulated update.
/// Printable text (including literal `\\x1b` examples), tabs and newlines survive.
String stripTerminalControls(String source) {
  final output = StringBuffer();
  var i = 0;
  while (i < source.length) {
    final code = source.codeUnitAt(i++);
    var control = code;
    if (code == 0x1b) {
      if (i == source.length) break;
      control = source.codeUnitAt(i++);
      if (control == 0x5b) {
        control = 0x9b; // CSI
      } else if (control == 0x5d) {
        control = 0x9d; // OSC
      } else if (const [0x50, 0x58, 0x5e, 0x5f].contains(control)) {
        control += 0x40; // DCS, SOS, PM, APC
      } else {
        // ESC intermediates followed by a final byte, e.g. charset selection.
        while (control >= 0x20 && control <= 0x2f && i < source.length) {
          control = source.codeUnitAt(i++);
        }
        continue;
      }
    }
    if (control == 0x9b) {
      while (i < source.length) {
        final next = source.codeUnitAt(i);
        if (next >= 0x40 && next <= 0x7e) {
          i++;
          break;
        }
        // Malformed CSI: stop without eating unrelated printable content.
        if (next < 0x20 || next > 0x3f) break;
        i++;
      }
      continue;
    }
    if (const [0x90, 0x98, 0x9d, 0x9e, 0x9f].contains(control)) {
      while (i < source.length) {
        final next = source.codeUnitAt(i++);
        if (next == 0x9c || control == 0x9d && next == 0x07) break;
        if (next == 0x1b && i < source.length && source.codeUnitAt(i) == 0x5c) {
          i++;
          break;
        }
      }
      continue;
    }
    if (code == 0x09 ||
        code == 0x0a ||
        code == 0x0d ||
        code >= 0x20 && !(code >= 0x7f && code <= 0x9f)) {
      output.writeCharCode(code);
    }
  }
  return output.toString();
}
