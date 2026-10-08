import 'dart:async';

import 'package:flutter/widgets.dart';

import '../model/story_media.dart';
import '../platform/file_image_stub.dart'
    if (dart.library.io) '../platform/file_image_io.dart'
    as platform;
import 'story_media_store.dart';

/// Returns an [ImageProvider] for [media].
///
/// Network media loads from [localPath] when the media store has a file,
/// and from its URL otherwise. Set [decodeWidth] to decode the image at
/// the size it is shown, in physical pixels, which saves memory.
ImageProvider storyImageProvider(
  StoryMedia media, {
  String? localPath,
  int? decodeWidth,
}) {
  final ImageProvider provider = switch (media.source) {
    StoryMediaSource.network =>
      localPath != null
          ? platform.fileImageProvider(localPath)
          : NetworkImage(media.uri.toString(), headers: media.headers),
    StoryMediaSource.asset => AssetImage(
      media.assetName!,
      package: media.package,
    ),
    StoryMediaSource.file => platform.fileImageProvider(media.filePath!),
  };
  return ResizeImage.resizeIfNeeded(decodeWidth, null, provider);
}

/// Shows an image [StoryMedia] through a [StoryMediaStore], so it is
/// downloaded once and served from disk afterwards.
///
/// Use it for anything outside the player that shows story media, such as
/// the avatars of a stories tray: the player then finds them already
/// cached.
///
/// {@tool snippet}
/// ```dart
/// ClipOval(
///   child: StoryMediaImage(group.avatar!, width: 64, height: 64),
/// )
/// ```
/// {@end-tool}
class StoryMediaImage extends StatefulWidget {
  /// Shows [media].
  const StoryMediaImage(
    this.media, {
    super.key,
    this.store,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.color,
    this.priority = StoryFetchPriority.visible,
    this.semanticLabel,
  });

  /// The image to show.
  final StoryMedia media;

  /// Where the image is cached. Defaults to [StoryMediaStore.instance].
  final StoryMediaStore? store;

  /// How the image is inscribed into its box.
  final BoxFit fit;

  /// The width of the box, if fixed.
  final double? width;

  /// The height of the box, if fixed.
  final double? height;

  /// Painted while the image loads.
  final Color? color;

  /// How urgently to download the image.
  final StoryFetchPriority priority;

  /// Read by screen readers.
  final String? semanticLabel;

  @override
  State<StoryMediaImage> createState() => _StoryMediaImageState();
}

class _StoryMediaImageState extends State<StoryMediaImage> {
  StoryFetchToken? _token;
  String? _path;
  bool _waiting = false;

  StoryMediaStore get _store => widget.store ?? StoryMediaStore.instance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(StoryMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media != widget.media || oldWidget.store != widget.store) {
      _token?.cancel();
      _path = null;
      _load();
    }
  }

  void _load() {
    final media = widget.media;
    final store = _store;
    _waiting = false;
    if (!media.isNetwork || !store.supportsFiles) return;
    _path = store.lookup(media);
    if (_path != null) return;
    _waiting = true;
    final token = _token = StoryFetchToken();
    unawaited(
      store
          .fetch(media, priority: widget.priority, token: token)
          .then(
            (path) {
              if (!mounted || token.isCancelled) return;
              setState(() {
                _path = path;
                _waiting = false;
              });
            },
            onError: (Object _) {
              if (!mounted || token.isCancelled) return;
              // Fall back to loading from the URL.
              setState(() => _waiting = false);
            },
          ),
    );
  }

  @override
  void dispose() {
    _token?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = SizedBox(
      width: widget.width,
      height: widget.height,
      child: widget.color == null ? null : ColoredBox(color: widget.color!),
    );
    if (_waiting) return placeholder;
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final width = widget.width;
    return Image(
      image: storyImageProvider(
        widget.media,
        localPath: _path,
        decodeWidth: width == null || width.isInfinite
            ? null
            : (width * dpr).round(),
      ),
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      semanticLabel: widget.semanticLabel,
      excludeFromSemantics: widget.semanticLabel == null,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
          frame == null && !wasSynchronouslyLoaded ? placeholder : child,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
