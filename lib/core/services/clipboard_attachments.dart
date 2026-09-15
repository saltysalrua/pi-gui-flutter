import 'dart:async';
import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'chat_resources.dart';
import 'file_attachments.dart';

class AttachmentBatch {
  const AttachmentBatch({this.images = const [], this.files = const []});
  final List<ImageAttachment> images;
  final List<FileAttachment> files;
}

class ClipboardReadException implements Exception {
  const ClipboardReadException();
}

/// Read only in response to an explicit paste, never watch the user's clipboard.
class ClipboardAttachments {
  ClipboardAttachments(this.store);
  final FileAttachmentStore store;

  Future<AttachmentBatch?> read(String imageLabel) async {
    ClipboardReader reader;
    try {
      final clipboard = SystemClipboard.instance;
      if (clipboard == null) return null;
      reader = await clipboard.read();
    } catch (_) {
      // New native plugins require an app relaunch; text paste still works.
      throw const ClipboardReadException();
    }
    final images = <ImageAttachment>[];
    final files = <XFile>[];
    var imageBytes = 0;
    for (final item in reader.items) {
      // Explorer file copies win over a second synthesized image representation.
      final uri = await item.readValue(Formats.fileUri);
      if (uri != null) {
        if (uri.scheme != 'file' || uri.host.isNotEmpty) {
          throw const FileAttachmentException(FileAttachmentFailure.unreadable);
        }
        final file = XFile(uri.toFilePath());
        if (ImageResources.isImagePath(file.path)) {
          final image = await ImageResources.fromFile(file);
          images.add(image);
          imageBytes += image.bytes.length;
        } else {
          files.add(file);
        }
      } else {
        final formats = [Formats.png, Formats.jpeg, Formats.gif, Formats.webp];
        final format = formats.where(item.canProvide).firstOrNull;
        if (format == null) continue;
        final image = await _readImage(item, format, imageLabel);
        images.add(image);
        imageBytes += image.bytes.length;
      }
      if (images.length > ImageResources.maxAttachments) {
        throw const ImageResourceException(ImageFailure.tooMany);
      }
      if (imageBytes > ImageResources.maxTotalBytes) {
        throw const ImageResourceException(ImageFailure.tooLarge);
      }
      if (files.length > FileAttachmentStore.maxFiles) {
        throw const FileAttachmentException(FileAttachmentFailure.tooMany);
      }
    }
    if (images.isEmpty && files.isEmpty) return null;
    return AttachmentBatch(images: images, files: await store.import(files));
  }

  Future<ImageAttachment> _readImage(
    ClipboardDataReader reader,
    FileFormat format,
    String label,
  ) {
    final result = Completer<ImageAttachment>();
    final progress = reader.getFile(
      format,
      (file) async {
        try {
          final stream = file.getStream();
          final bytes = BytesBuilder(copy: false);
          await for (final chunk in stream) {
            if (bytes.length + chunk.length >
                ImageResources.maxAttachmentBytes) {
              throw const ImageResourceException(ImageFailure.tooLarge);
            }
            bytes.add(chunk);
          }
          final data = bytes.takeBytes();
          await ImageResources.validate(data);
          final mime = ImageResources.mimeType(data)!;
          result.complete(
            ImageAttachment(
              name: file.fileName ?? '$label.${mime.split('/').last}',
              bytes: data,
              mimeType: mime,
            ),
          );
        } catch (error, stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        }
      },
      onError: (error) {
        if (!result.isCompleted) result.completeError(error);
      },
    );
    if (progress == null && !result.isCompleted) {
      result.completeError(
        const ImageResourceException(ImageFailure.unreadable),
      );
    }
    return result.future;
  }
}
