import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_chat_types.dart';
import 'package:pi_gui/core/services/chat_resources.dart';
import '../core/chat_resource_scope.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';
import 'app_action_button.dart';
import 'app_card.dart';
import 'app_image_lightbox.dart';
import 'app_icon_button.dart';

/// Shared image/attachment tile: bounded decode, loading/error states, keyboard preview.
/// Remote images require an explicit click; rebuilding a message never starts a request.
class AppImage extends StatefulWidget {
  const AppImage({
    super.key,
    this.image,
    this.bytes,
    this.source,
    this.label,
    this.compact = false,
    this.onRemove,
  });
  final PiImage? image;
  final Uint8List? bytes;
  final String? source, label;
  final bool compact;
  final VoidCallback? onRemove;
  static const compactWidth = 128.0;
  static const _thumbnailHeight = 72.0;
  static double compactHeight(BuildContext context) {
    final style = context.textTheme.bodySmall!;
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1.4);
    return _thumbnailHeight +
        AppSpacing.md +
        math.max(28, line + AppSpacing.sm);
  }

  @override
  State<AppImage> createState() => _AppImageState();
}

class _AppImageState extends State<AppImage> {
  Future<Uint8List>? _loaded;
  Uri? _uri;
  String? _directory;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final directory = ChatResourceScope.directoryOf(context);
    if (!_initialized || directory != _directory) {
      _directory = directory;
      _prepare();
    }
  }

  @override
  void didUpdateWidget(AppImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image?.data != widget.image?.data ||
        oldWidget.image?.mimeType != widget.image?.mimeType ||
        oldWidget.bytes != widget.bytes ||
        oldWidget.source != widget.source) {
      _prepare();
    }
  }

  void _prepare() {
    _initialized = true;
    _loaded = null;
    _uri = null;
    if (widget.bytes case final bytes?) {
      _loaded = Future.value(bytes);
    } else if (widget.image case final image?) {
      _loaded = ImageResources.decode(image);
    } else if (widget.source case final source?) {
      if (source.startsWith('data:')) {
        // Decode only whitelisted raster formats, never arbitrary data documents or SVG.
        final split = source.indexOf(';base64,');
        if (split > 5) {
          _loaded = ImageResources.decode(
            PiImage(
              mimeType: source.substring(5, split),
              data: source.substring(split + 8),
            ),
          );
        }
      } else {
        _uri = ChatResources.resolve(source, directory: _directory);
        if (_uri?.scheme == 'file') _loaded = ImageResources.load(_uri!);
      }
    }
  }

  Widget _error(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Text(
        context.l10n.chatImageUnavailable,
        style: context.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _picture(BuildContext context, Uint8List bytes) => Image.memory(
    bytes,
    fit: BoxFit.contain,
    cacheWidth: widget.compact ? 224 : 1024,
    semanticLabel: widget.label ?? context.l10n.chatImage,
    errorBuilder: (context, _, _) => _error(context),
    frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
      opacity: sync || frame != null ? 1 : 0,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppDurations.quick,
      child: child,
    ),
  );

  void _preview(Uint8List bytes) =>
      showAppImageLightbox(context, bytes, label: widget.label);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final remote = _uri?.scheme == 'https' || _uri?.scheme == 'http';
    final content = _loaded == null
        ? remote
              ? Center(
                  child: Tooltip(
                    message: _uri.toString(),
                    child: AppActionButton.subtle(
                      label: l10n.chatLoadRemoteImage,
                      leading: const Icon(Icons.download_outlined),
                      onPressed: () =>
                          setState(() => _loaded = ImageResources.load(_uri!)),
                    ),
                  ),
                )
              : _error(context)
        : FutureBuilder<Uint8List>(
            future: _loaded,
            builder: (context, snapshot) {
              if (snapshot.hasError) return _error(context);
              final bytes = snapshot.data;
              if (bytes == null) {
                return Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: AppProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: l10n.chatImageLoading,
                    ),
                  ),
                );
              }
              return Material(
                color: context.colors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.md),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _preview(bytes),
                  focusColor: context.colors.primaryTint,
                  hoverColor: context.colors.hoverBackground,
                  child: Tooltip(
                    message: l10n.chatPreviewImage,
                    child: SizedBox.expand(child: _picture(context, bytes)),
                  ),
                ),
              );
            },
          );
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: widget.compact ? AppImage.compactWidth : 560,
        ),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: widget.compact ? AppImage._thumbnailHeight : 260,
                child: content,
              ),
              if (widget.label != null || widget.onRemove != null)
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: widget.label ?? l10n.chatImage,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Text(
                            widget.label ?? l10n.chatImage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                    if (widget.onRemove != null)
                      AppIconButton.subtle(
                        icon: Icons.close,
                        tooltip: l10n.chatRemoveImage,
                        onPressed: widget.onRemove,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
