import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';
import '../rpc/pi_chat_types.dart';

/// Local file / web links only. Never construct a shell command from model text.
abstract final class ChatResources {
  static final _drive = RegExp(r'^[a-zA-Z]:[/\\]');
  static final _lineSuffix = RegExp(r':\d+(?::\d+)?$');

  static Uri? resolve(String href, {String? directory}) {
    try {
      var value = href.trim();
      if (value.isEmpty || value.startsWith('#')) return null;
      final windows =
          _drive.hasMatch(value) ||
          RegExp(
            r'^[a-zA-Z]:(?:%5c|%2f)',
            caseSensitive: false,
          ).hasMatch(value);
      final uri = windows ? null : Uri.tryParse(value);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        return uri.host.isNotEmpty && uri.userInfo.isEmpty ? uri : null;
      }
      String path;
      if (uri?.scheme == 'file') {
        if (uri!.host.isNotEmpty || uri.hasQuery) return null;
        // Decode with the target path style, not the host OS (also testable on Linux).
        final isWindows = RegExp(r'^/[a-zA-Z]:/').hasMatch(uri.path);
        path = uri.removeFragment().toFilePath(windows: isWindows);
      } else {
        if (!windows && uri?.hasScheme == true) return null;
        // Standard Markdown file fragments are navigation hints, not part of a path.
        path = Uri.decodeComponent(value.split('#').first);
      }
      path = path.replaceAll(_lineSuffix, '');
      if (path.isEmpty || RegExp(r'[\x00-\x1f\x7f]').hasMatch(path)) {
        return null;
      }
      final normalized = path.replaceAll('\\', '/');
      // Do not let a link contact an SMB share or address a Windows device/ADS.
      if (normalized.startsWith('//')) return null;
      final pathContext = p.Context(
        style: _drive.hasMatch(path) || _drive.hasMatch(directory ?? '')
            ? p.Style.windows
            : p.Style.posix,
      );
      if (!pathContext.isAbsolute(path)) {
        if (directory == null || !pathContext.isAbsolute(directory)) {
          return null;
        }
        path = pathContext.join(directory, path);
      } else if (pathContext.style == p.Style.windows &&
          !_drive.hasMatch(path)) {
        if (directory == null) return null;
        path = pathContext.join(pathContext.rootPrefix(directory), path);
      }
      path = pathContext.normalize(path);
      if (pathContext.style == p.Style.windows) {
        if (path.substring(2).contains(':') || path.contains('?')) return null;
        final reserved = RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        );
        if (pathContext
            .split(path)
            .skip(1)
            .any(
              (part) =>
                  reserved.hasMatch(part) ||
                  part.endsWith('.') ||
                  part.endsWith(' '),
            )) {
          return null;
        }
      }
      return Uri.file(path, windows: pathContext.style == p.Style.windows);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  // Opening arbitrary executables via their OS association is not document viewing.
  static const _unsafeExtensions = {
    '.exe',
    '.com',
    '.bat',
    '.cmd',
    '.ps1',
    '.psm1',
    '.vbs',
    '.vbe',
    '.js',
    '.jse',
    '.wsf',
    '.wsh',
    '.hta',
    '.msi',
    '.msp',
    '.scr',
    '.pif',
    '.lnk',
    '.url',
    '.reg',
    '.cpl',
    '.app',
    '.command',
    '.sh',
    '.desktop',
    '.appref-ms',
    '.msc',
  };

  static bool canOpen(Uri uri) =>
      uri.scheme == 'http' ||
      uri.scheme == 'https' ||
      (uri.scheme == 'file' &&
          uri.host.isEmpty &&
          !_unsafeExtensions.contains(
            p.posix.extension(uri.path).toLowerCase(),
          ));

  static Future<bool> open(Uri uri) async {
    if (!canOpen(uri)) return false;
    try {
      if (uri.scheme == 'file' &&
          await FileSystemEntity.type(uri.toFilePath()) ==
              FileSystemEntityType.notFound) {
        return false;
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}

enum ImageFailure { unreadable, format, tooLarge, tooMany }

class ImageResourceException implements Exception {
  const ImageResourceException(this.failure);
  final ImageFailure failure;
}

class ImageAttachment {
  ImageAttachment({
    required this.name,
    required this.bytes,
    required String mimeType,
  }) : image = PiImage(data: base64Encode(bytes), mimeType: mimeType);
  final String name;
  final Uint8List bytes;
  final PiImage image;
}

/// User-selected attachments and display images. No LLM requests or Pi private-file access.
abstract final class ImageResources {
  static const maxAttachments = 8;
  static const maxAttachmentBytes = 10 * 1024 * 1024;
  static const maxTotalBytes = 20 * 1024 * 1024;
  static const maxDisplayBytes = 20 * 1024 * 1024;
  static const maxPixels = 40 * 1000 * 1000;

  static String? mimeType(Uint8List bytes) {
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(
          signature.length,
          (i) => bytes[i] == signature[i],
        ).every((v) => v);
    if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
    if (starts([255, 216, 255])) return 'image/jpeg';
    if (starts(ascii.encode('GIF87a')) || starts(ascii.encode('GIF89a'))) {
      return 'image/gif';
    }
    if (starts(ascii.encode('RIFF')) &&
        bytes.length >= 12 &&
        ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static Future<Uint8List> _bounded(Stream<List<int>> stream, int limit) async {
    final result = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (result.length + chunk.length > limit) {
        throw const ImageResourceException(ImageFailure.tooLarge);
      }
      result.add(chunk);
    }
    return result.takeBytes();
  }

  static Future<Uint8List> validate(
    Uint8List bytes, {
    String? expectedMime,
  }) async {
    final mime = mimeType(bytes);
    if (mime == null ||
        (expectedMime != null && mime != expectedMime.toLowerCase())) {
      throw const ImageResourceException(ImageFailure.format);
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        if (descriptor.width * descriptor.height > maxPixels) {
          throw const ImageResourceException(ImageFailure.tooLarge);
        }
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
    return bytes;
  }

  static bool isImagePath(String path) => const {
    '.png',
    '.jpg',
    '.jpeg',
    '.gif',
    '.webp',
  }.contains(p.extension(path).toLowerCase());

  static Future<ImageAttachment> fromFile(XFile file) async {
    if (await file.length() > maxAttachmentBytes) {
      throw const ImageResourceException(ImageFailure.tooLarge);
    }
    final bytes = await _bounded(file.openRead(), maxAttachmentBytes);
    await validate(bytes);
    return ImageAttachment(
      name: file.name,
      bytes: bytes,
      mimeType: mimeType(bytes)!,
    );
  }

  static Future<List<ImageAttachment>> pick(String label) async {
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(
          label: label,
          extensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
        ),
      ],
    );
    if (files.length > maxAttachments) {
      throw const ImageResourceException(ImageFailure.tooMany);
    }
    final attachments = <ImageAttachment>[];
    var total = 0;
    for (final file in files) {
      final attachment = await fromFile(file);
      total += attachment.bytes.length;
      if (total > maxTotalBytes) {
        throw const ImageResourceException(ImageFailure.tooLarge);
      }
      attachments.add(attachment);
    }
    return attachments;
  }

  static Future<Uint8List> decode(PiImage image) async {
    if (image.data.length > (maxDisplayBytes + 2) ~/ 3 * 4) {
      throw const ImageResourceException(ImageFailure.tooLarge);
    }
    final bytes = base64Decode(image.data);
    if (bytes.length > maxDisplayBytes) {
      throw const ImageResourceException(ImageFailure.tooLarge);
    }
    return validate(bytes, expectedMime: image.mimeType);
  }

  static Future<Uint8List> load(Uri uri) async {
    Uint8List bytes;
    if (uri.scheme == 'file' && uri.host.isEmpty) {
      final file = File.fromUri(uri);
      if (await file.length() > maxDisplayBytes) {
        throw const ImageResourceException(ImageFailure.tooLarge);
      }
      bytes = await _bounded(file.openRead(), maxDisplayBytes);
    } else if (uri.scheme == 'http' || uri.scheme == 'https') {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15);
      try {
        bytes = await (() async {
          final request = await client.getUrl(uri);
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw const ImageResourceException(ImageFailure.unreadable);
          }
          return _bounded(response, maxDisplayBytes);
        })().timeout(const Duration(seconds: 30));
      } finally {
        client.close(force: true);
      }
    } else {
      throw const ImageResourceException(ImageFailure.format);
    }
    return validate(bytes);
  }
}
