import 'package:flutter/foundation.dart';
import 'package:pi_gui/core/services/chat_resources.dart';
import 'package:pi_gui/core/services/clipboard_attachments.dart';
import 'package:pi_gui/core/services/file_attachments.dart';

/// Composer-only state. Image and file drafts share one async generation barrier.
class ImageAttachmentController extends ChangeNotifier {
  ImageAttachmentController({
    Future<List<ImageAttachment>> Function(String)? pick,
    Future<List<FileAttachment>> Function()? pickFiles,
    Future<AttachmentBatch?> Function(String)? paste,
  }) : _pick = pick ?? ImageResources.pick,
       _pickFilesOverride = pickFiles,
       _pasteOverride = paste;
  final Future<List<ImageAttachment>> Function(String) _pick;
  final Future<List<FileAttachment>> Function()? _pickFilesOverride;
  final Future<AttachmentBatch?> Function(String)? _pasteOverride;
  Future<List<FileAttachment>> _pickFiles() =>
      (_pickFilesOverride ?? FileAttachmentStore().pick)();
  Future<AttachmentBatch?> _paste(String label) =>
      (_pasteOverride ?? ClipboardAttachments(FileAttachmentStore()).read)(
        label,
      ).timeout(const Duration(seconds: 30));
  final _drafts = <String, List<ImageAttachment>>{};
  final _fileDrafts = <String, List<FileAttachment>>{};
  List<ImageAttachment> _items = [];
  List<FileAttachment> _files = [];
  List<ImageAttachment> get items => List.unmodifiable(_items);
  List<FileAttachment> get files => List.unmodifiable(_files);
  bool get hasAttachments => _items.isNotEmpty || _files.isNotEmpty;
  String? _workspace;
  int _generation = 0;
  bool _disposed = false;
  bool isPicking = false;
  ImageFailure? failure;
  FileAttachmentFailure? fileFailure;
  bool pasteFailed = false;

  void setWorkspace(String path) {
    if (_workspace == path) return;
    if (_workspace case final old?) {
      _drafts[old] = _items;
      _fileDrafts[old] = _files;
    }
    _workspace = path;
    _items = _drafts.remove(path) ?? [];
    _files = _fileDrafts.remove(path) ?? [];
    _invalidate();
  }

  void clear() {
    _items = [];
    _files = [];
    _invalidate();
  }

  void _clearFailure() {
    failure = null;
    fileFailure = null;
    pasteFailed = false;
  }

  void _invalidate() {
    _generation++;
    isPicking = false;
    _clearFailure();
    notifyListeners();
  }

  void remove(ImageAttachment attachment) {
    _items.remove(attachment);
    _clearFailure();
    notifyListeners();
  }

  void removeFile(FileAttachment attachment) {
    _files.remove(attachment);
    _clearFailure();
    notifyListeners();
  }

  // Keep cache copies: a timed-out or still-running send may already reference them.
  void accept(
    List<ImageAttachment> sent, {
    List<FileAttachment> files = const [],
  }) {
    _items.removeWhere(sent.contains);
    _files.removeWhere(files.contains);
    notifyListeners();
  }

  Future<void> choose(String label) async {
    await _load(() async => AttachmentBatch(images: await _pick(label)));
  }

  Future<void> chooseFiles() async {
    await _load(
      () async => AttachmentBatch(files: await _pickFiles()),
      filesOnly: true,
    );
  }

  /// false delegates to Flutter's original text paste action (caret/undo/IME intact).
  Future<bool> paste(String imageLabel) => _load(() => _paste(imageLabel));

  Future<bool> _load(
    Future<AttachmentBatch?> Function() load, {
    bool filesOnly = false,
  }) async {
    if (isPicking || _disposed) return true;
    final generation = _generation;
    isPicking = true;
    _clearFailure();
    notifyListeners();
    try {
      final selected = await load();
      if (_disposed || generation != _generation) return true;
      if (selected == null) return false;
      if (_items.length + selected.images.length >
          ImageResources.maxAttachments) {
        throw const ImageResourceException(ImageFailure.tooMany);
      }
      final total = [
        ..._items,
        ...selected.images,
      ].fold<int>(0, (sum, a) => sum + a.bytes.length);
      if (total > ImageResources.maxTotalBytes) {
        throw const ImageResourceException(ImageFailure.tooLarge);
      }
      if (_files.length + selected.files.length >
          FileAttachmentStore.maxFiles) {
        throw const FileAttachmentException(FileAttachmentFailure.tooMany);
      }
      final fileBytes = [
        ..._files,
        ...selected.files,
      ].fold<int>(0, (sum, a) => sum + a.size);
      if (fileBytes > FileAttachmentStore.maxTotalBytes) {
        throw const FileAttachmentException(FileAttachmentFailure.tooLarge);
      }
      _items.addAll(selected.images);
      _files.addAll(selected.files);
      return true;
    } catch (error) {
      if (!_disposed && generation == _generation) {
        if (error is ClipboardReadException) {
          pasteFailed = true;
          return false;
        } else if (error is FileAttachmentException) {
          fileFailure = error.failure;
        } else if (filesOnly) {
          fileFailure = FileAttachmentFailure.unreadable;
        } else {
          failure = error is ImageResourceException
              ? error.failure
              : ImageFailure.unreadable;
        }
      }
      return true;
    } finally {
      if (!_disposed && generation == _generation) {
        isPicking = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
