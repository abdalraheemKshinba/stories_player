/// Lottie animation items for `package:stories_player`.
///
/// Add [LottieStoryDelegate] to [StoriesPlayer.delegates] and use
/// [LottieStoryItem] in your groups.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:lottie/lottie.dart';
import 'package:stories_player/stories_player.dart';

import 'src/lottie_composition_cache.dart';
import 'src/read_file_stub.dart'
    if (dart.library.io) 'src/read_file_io.dart'
    as platform;

export 'src/lottie_composition_cache.dart'
    show LottieCompositionCache, LottieImageResolver;

/// A Lottie animation, optionally with a music track.
///
/// The animation is driven by the story's own clock: it pauses when the
/// story pauses and never drifts from the progress bar. Without a
/// [duration], the item lasts as long as the animation.
///
/// {@tool snippet}
/// ```dart
/// LottieStoryItem(
///   id: 'confetti',
///   animation: StoryMedia.network(
///     Uri.parse('https://cdn.example.com/confetti.json'),
///     kind: StoryMediaKind.lottie,
///   ),
///   placeholderColor: const Color(0xFFFFE6D3),
/// )
/// ```
/// {@end-tool}
final class LottieStoryItem extends StoryItem {
  /// Creates an animation item.
  const LottieStoryItem({
    required super.id,
    required this.animation,
    this.audio,
    this.loop = false,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    super.duration,
    super.poster,
    super.placeholderColor,
    super.caption,
    super.semanticLabel,
    super.expiresAt,
  });

  /// The Lottie JSON file.
  final StoryMedia animation;

  /// Music played while the animation shows.
  final StoryAudio? audio;

  /// Whether the animation repeats until the item ends. When false, it
  /// plays once and holds its last frame.
  final bool loop;

  /// How the animation is inscribed into the screen.
  final BoxFit fit;

  /// Painted behind the animation.
  final Color? backgroundColor;

  @override
  Iterable<StoryMedia> get media => [
    animation,
    if (audio != null) audio!.media,
  ];

  @override
  bool get hasAudio => audio != null;
}

/// Shows [LottieStoryItem]s through `package:lottie`.
///
/// Built for smooth playback on small devices:
///
/// * **Parsed off the UI thread.** JSON is parsed on a background isolate,
///   so preparing the next story never drops a frame of the current one.
/// * **Parsed once.** Animations are kept in a [LottieCompositionCache], so
///   going back to a story is instant.
/// * **Repainted only on new frames.** With the default [frameRate], the
///   animation repaints at its own frame rate, not at every display frame.
/// * **No raster cache by default.** The raster cache keeps every frame as a
///   full-screen bitmap and is meant for small animations. Pass
///   [renderCache] to change it.
final class LottieStoryDelegate extends StoryItemDelegate {
  /// Creates the Lottie delegate.
  const LottieStoryDelegate({
    this.renderCache,
    this.frameRate = FrameRate.composition,
    this.cache,
  });

  /// How the Lottie widget caches frames. `null` caches nothing.
  final RenderCache? renderCache;

  /// How often the animation repaints. [FrameRate.composition] repaints only
  /// when the animation moves to its next frame.
  final FrameRate frameRate;

  /// Where parsed animations are kept. Defaults to
  /// [LottieCompositionCache.shared].
  final LottieCompositionCache? cache;

  @override
  bool canHandle(StoryItem item) => item is LottieStoryItem;

  @override
  StoryItemSession createSession(
    covariant LottieStoryItem item,
    StorySessionContext context,
  ) => _LottieStorySession(
    item,
    context,
    renderCache,
    frameRate,
    cache ?? LottieCompositionCache.shared,
  );
}

final class _LottieStorySession extends StoryItemSession {
  _LottieStorySession(
    LottieStoryItem super.item,
    super.context,
    this._renderCache,
    this._frameRate,
    this._compositions,
  ) : _audio = item.audio == null
          ? null
          : StoryAudioTrack(
              audio: item.audio!,
              backend: context.audio,
              store: context.store,
              muted: context.isMuted,
            );

  final RenderCache? _renderCache;
  final FrameRate _frameRate;
  final LottieCompositionCache _compositions;
  final StoryAudioTrack? _audio;
  final StoryProgressAnimation _progress = StoryProgressAnimation();
  final StoryFetchToken _token = StoryFetchToken();
  LottieComposition? _composition;

  LottieStoryItem get _item => item as LottieStoryItem;

  @override
  Future<void> onPrepare() async {
    if (_audio != null) unawaited(_audio.preload());
    final media = _item.animation;
    final store = context.store;
    cacheHit = !media.isNetwork || store.lookup(media) != null;
    final composition = await _compositions.get(
      media.cacheKey,
      images: _imageResolver(media),
      () async {
        switch (media.source) {
          case StoryMediaSource.network:
            var path = store.lookup(media);
            if (path == null && store.supportsFiles) {
              path = await store.fetch(
                media,
                token: _token,
                expiresAt: _item.expiresAt,
              );
            }
            if (path != null) return platform.readFile(path);
            if (_token.isCancelled) {
              // The user moved on; do not download it a second way.
              throw StoryMediaException(media, 'Cancelled');
            }
            final response = await http.get(media.uri!, headers: media.headers);
            if (response.statusCode != 200) {
              throw StoryMediaException(
                media,
                'Unexpected response',
                statusCode: response.statusCode,
              );
            }
            return response.bodyBytes;
          case StoryMediaSource.asset:
            final data = await rootBundle.load(
              media.package == null
                  ? media.assetName!
                  : 'packages/${media.package}/${media.assetName}',
            );
            return data.buffer.asUint8List(
              data.offsetInBytes,
              data.lengthInBytes,
            );
          case StoryMediaSource.file:
            return platform.readFile(media.filePath!);
        }
      },
    );
    if (isDisposed) return;
    _composition = composition;
    if (_item.duration == null) setDuration(composition.duration);
  }

  /// Resolves image files that a JSON animation keeps next to itself,
  /// relative to where the animation came from.
  LottieImageResolver _imageResolver(StoryMedia media) =>
      (LottieImageAsset image) {
        final relative = '${image.dirName}${image.fileName}';
        switch (media.source) {
          case StoryMediaSource.network:
            return NetworkImage(
              media.uri!.resolve(relative).toString(),
              headers: media.headers,
            );
          case StoryMediaSource.asset:
            final name = media.assetName!;
            final slash = name.lastIndexOf('/');
            final dir = slash < 0 ? '' : name.substring(0, slash + 1);
            return AssetImage('$dir$relative', package: media.package);
          case StoryMediaSource.file:
            return null;
        }
      };

  @override
  void onTick(Duration elapsed, double progress) {
    final composition = _composition;
    if (composition == null) return;
    final length = composition.duration.inMicroseconds;
    if (length <= 0) return;
    final t = elapsed.inMicroseconds / length;
    _progress.value = _item.loop ? t % 1.0 : t.clamp(0.0, 1.0);
  }

  @override
  void play() => _audio?.play();

  @override
  void pause() => _audio?.pause();

  @override
  void setMuted(bool muted) => _audio?.setMuted(muted);

  @override
  void rewind() {
    _audio?.rewind();
    _progress.value = 0;
    super.rewind();
  }

  @override
  Widget build(BuildContext context) {
    final composition = _composition;
    if (composition == null) return const SizedBox.expand();
    Widget child = Lottie(
      composition: composition,
      controller: _progress,
      fit: _item.fit,
      renderCache: _renderCache,
      frameRate: _frameRate,
      width: double.infinity,
      height: double.infinity,
    );
    final background = _item.backgroundColor;
    if (background != null) {
      child = ColoredBox(color: background, child: child);
    }
    return child;
  }

  @override
  void dispose() {
    _token.cancel();
    _audio?.dispose();
    _progress.dispose();
    super.dispose();
  }
}
