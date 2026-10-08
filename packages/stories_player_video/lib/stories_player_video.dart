/// Video items for `package:stories_player`.
///
/// Add [VideoStoryDelegate] to [StoriesPlayer.delegates] and use
/// [VideoStoryItem] in your groups.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:stories_player/stories_player.dart';
import 'package:video_player/video_player.dart';

import 'src/file_controller_stub.dart'
    if (dart.library.io) 'src/file_controller_io.dart'
    as platform;

/// A video, played to its own length unless [duration] is set.
///
/// Use a faststart MP4 (H.264 and AAC): it starts playing before it has
/// fully downloaded, and every Android and iOS device decodes it in
/// hardware. Give [video] its `bytes` so the prefetcher can download short
/// videos ahead on fast networks, and a `lowQuality` rendition for slow
/// ones.
///
/// {@tool snippet}
/// ```dart
/// VideoStoryItem(
///   id: 'grill',
///   video: StoryMedia.network(
///     Uri.parse('https://cdn.example.com/grill/720.mp4'),
///     kind: StoryMediaKind.video,
///     bytes: 2201600,
///     lowQuality: StoryMedia.network(
///       Uri.parse('https://cdn.example.com/grill/480.mp4'),
///       kind: StoryMediaKind.video,
///       bytes: 880000,
///     ),
///   ),
///   poster: StoryMedia.network(Uri.parse('https://cdn.example.com/grill.webp')),
/// )
/// ```
/// {@end-tool}
final class VideoStoryItem extends StoryItem {
  /// Creates a video item.
  const VideoStoryItem({
    required super.id,
    required this.video,
    this.hasSound = true,
    this.fit = BoxFit.cover,
    super.duration,
    super.poster,
    super.placeholderColor,
    super.caption,
    super.semanticLabel,
    super.expiresAt,
  });

  /// The video to play.
  final StoryMedia video;

  /// Whether the video has a sound track, which shows the mute button.
  final bool hasSound;

  /// How the video is inscribed into the screen.
  final BoxFit fit;

  @override
  Iterable<StoryMedia> get media => [video];

  @override
  bool get hasAudio => hasSound;
}

/// Shows [VideoStoryItem]s through `package:video_player`.
///
/// * Plays from the media store's file when the video is cached, and
///   streams it otherwise.
/// * Progress follows the video's own position, so it freezes while the
///   video buffers and never runs ahead of what the user sees.
/// * Prefers the low-quality rendition on slow networks.
/// * Prefetches whole videos only when they fit the prefetch policy's
///   video budget; larger ones rely on the next item's player buffering
///   ahead.
/// * Mixes with other audio by default, so a muted story never stops the
///   music the user is listening to.
final class VideoStoryDelegate extends StoryItemDelegate {
  /// Creates the video delegate.
  const VideoStoryDelegate({this.videoPlayerOptions});

  /// Options passed to every [VideoPlayerController].
  ///
  /// When null, videos mix with other audio (`mixWithOthers: true`), as
  /// muted autoplaying stories should.
  final VideoPlayerOptions? videoPlayerOptions;

  @override
  bool canHandle(StoryItem item) => item is VideoStoryItem;

  @override
  StoryItemSession createSession(
    covariant VideoStoryItem item,
    StorySessionContext context,
  ) => _VideoStorySession(item, context, videoPlayerOptions);
}

final class _VideoStorySession extends StoryItemSession {
  _VideoStorySession(
    VideoStoryItem super.item,
    super.context,
    VideoPlayerOptions? options,
  ) : _options = options ?? VideoPlayerOptions(mixWithOthers: true),
      _muted = context.isMuted;

  final VideoPlayerOptions? _options;
  VideoPlayerController? _controller;
  bool _muted;
  bool _wantsPlay = false;
  bool _ended = false;

  VideoStoryItem get _item => item as VideoStoryItem;

  @override
  Duration? get position {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    return controller.value.position;
  }

  @override
  Future<void> onPrepare() async {
    final media = _item.video.resolve(
      preferLowQuality: context.preferLowQuality,
    );
    final path = context.store.lookup(media);
    cacheHit = path != null || !media.isNetwork;
    final controller = _controller = switch (media.source) {
      StoryMediaSource.network =>
        path != null
            ? platform.fileController(path, _options)
            : VideoPlayerController.networkUrl(
                media.uri!,
                httpHeaders: media.headers,
                videoPlayerOptions: _options,
              ),
      StoryMediaSource.asset => VideoPlayerController.asset(
        media.assetName!,
        package: media.package,
        videoPlayerOptions: _options,
      ),
      StoryMediaSource.file => platform.fileController(
        media.filePath!,
        _options,
      ),
    };
    // Volume and looping before initialize, so the platform player never
    // makes a sound the user did not ask for, not even for a frame.
    await controller.setVolume(_muted ? 0 : 1);
    await controller.setLooping(false);
    await controller.initialize();
    if (isDisposed) return;
    await controller.setVolume(_muted ? 0 : 1);
    if (isDisposed) return;
    setDuration(controller.value.duration);
    controller.addListener(_onValue);
  }

  void _onValue() {
    final controller = _controller;
    if (controller == null || isDisposed) return;
    final value = controller.value;
    if (value.hasError) {
      reportError(value.errorDescription ?? 'Video playback failed');
      return;
    }
    if (status == StorySessionStatus.error) return;
    if (value.isCompleted && !_ended) {
      _ended = true;
      setStatus(StorySessionStatus.completed);
      return;
    }
    if (_wantsPlay && value.isBuffering && status == StorySessionStatus.ready) {
      setStatus(StorySessionStatus.buffering);
    } else if (!value.isBuffering && status == StorySessionStatus.buffering) {
      setStatus(StorySessionStatus.ready);
    }
  }

  @override
  void play() {
    _wantsPlay = true;
    unawaited(_controller?.play());
  }

  @override
  void pause() {
    _wantsPlay = false;
    unawaited(_controller?.pause());
  }

  @override
  void setMuted(bool muted) {
    _muted = muted;
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.setVolume(muted ? 0 : 1));
    }
  }

  @override
  void seekTo(Duration position) => unawaited(_controller?.seekTo(position));

  @override
  void rewind() {
    _ended = false;
    super.rewind();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    final size = controller.value.size;
    return ClipRect(
      child: FittedBox(
        fit: _item.fit,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onValue);
      // video_player waits for an initialize still in flight before it
      // releases the platform player.
      unawaited(controller.dispose());
    }
    super.dispose();
  }
}
