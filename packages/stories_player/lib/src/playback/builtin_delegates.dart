import 'dart:async';

import 'package:flutter/widgets.dart';

import '../media/story_media_image.dart';
import '../media/story_media_store.dart';
import '../model/story_item.dart';
import 'story_audio.dart';
import 'story_item_session.dart';

/// Shows [ImageStoryItem]s. Always available; you never need to pass it.
final class ImageStoryDelegate extends StoryItemDelegate {
  /// Creates the image delegate.
  const ImageStoryDelegate();

  @override
  bool canHandle(StoryItem item) => item is ImageStoryItem;

  @override
  StoryItemSession createSession(
    covariant ImageStoryItem item,
    StorySessionContext context,
  ) => _ImageStorySession(item, context);
}

final class _ImageStorySession extends StoryItemSession {
  _ImageStorySession(ImageStoryItem super.item, super.context)
    : _audio = item.audio == null
          ? null
          : StoryAudioTrack(
              audio: item.audio!,
              backend: context.audio,
              store: context.store,
              muted: context.isMuted,
            );

  final StoryAudioTrack? _audio;
  final StoryFetchToken _token = StoryFetchToken();
  ImageProvider? _provider;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  ImageStoryItem get _item => item as ImageStoryItem;

  @override
  Duration? get duration {
    final audio = _item.audio;
    final length = audio?.length;
    if (audio == null || length == null || _item.duration != null) {
      return null;
    }
    return switch (audio.itemDuration) {
      StoryAudioDuration.item => null,
      StoryAudioDuration.track => length,
      StoryAudioDuration.shorter =>
        length < context.imageDuration ? length : context.imageDuration,
    };
  }

  @override
  Future<void> onPrepare() async {
    final store = context.store;
    final media = _item.image.resolve(
      preferLowQuality: context.preferLowQuality,
    );
    if (_audio != null) unawaited(_audio.preload());

    var path = store.lookup(media);
    cacheHit = path != null || !media.isNetwork;
    if (path == null && media.isNetwork && store.supportsFiles) {
      path = await store.fetch(
        media,
        token: _token,
        expiresAt: _item.expiresAt,
      );
      if (isDisposed) return;
    }
    final provider = _provider = storyImageProvider(
      media,
      localPath: path,
      decodeWidth: context.decodeWidth,
    );

    final completer = Completer<void>();
    final stream = _stream = provider.resolve(ImageConfiguration.empty);
    final listener = _listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!completer.isCompleted) completer.complete();
      },
      onError: (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );
    stream.addListener(listener);
    try {
      await completer.future;
    } on Object {
      // Flutter's image cache keeps a failed load and would hand the same
      // failure back to a retry; evict it so the retry fetches again.
      unawaited(provider.evict());
      rethrow;
    }
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
    super.rewind();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    if (provider == null) return const SizedBox.expand();
    return Image(
      image: provider,
      fit: _item.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
    );
  }

  @override
  void dispose() {
    _token.cancel();
    final listener = _listener;
    if (listener != null) _stream?.removeListener(listener);
    _audio?.dispose();
    super.dispose();
  }
}

/// Shows [WidgetStoryItem]s. Always available; you never need to pass it.
final class WidgetStoryDelegate extends StoryItemDelegate {
  /// Creates the widget delegate.
  const WidgetStoryDelegate();

  @override
  bool canHandle(StoryItem item) => item is WidgetStoryItem;

  @override
  StoryItemSession createSession(
    covariant WidgetStoryItem item,
    StorySessionContext context,
  ) => _WidgetStorySession(item, context);
}

final class _WidgetStorySession extends StoryItemSession {
  _WidgetStorySession(WidgetStoryItem super.item, super.context);

  final StoryProgressAnimation _progress = StoryProgressAnimation();

  @override
  Future<void> onPrepare() async {}

  @override
  void onTick(Duration elapsed, double progress) => _progress.value = progress;

  @override
  Widget build(BuildContext context) =>
      (item as WidgetStoryItem).builder(context, _progress);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }
}

/// An [Animation] whose value a session sets by hand, usually from
/// [StoryItemSession.onTick].
///
/// Lets widgets that take an [Animation], such as a Lottie player or a
/// transition, follow the story's own clock instead of running a second
/// clock that drifts from the progress bar.
final class StoryProgressAnimation extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  double _value = 0;

  @override
  double get value => _value;

  /// Sets the value and notifies listeners.
  set value(double value) {
    if (value == _value) return;
    final wasCompleted = _value >= 1;
    _value = value;
    notifyListeners();
    if (wasCompleted != (_value >= 1)) notifyStatusListeners(status);
  }

  @override
  AnimationStatus get status =>
      _value >= 1 ? AnimationStatus.completed : AnimationStatus.forward;

  @override
  void didRegisterListener() {}

  @override
  void didUnregisterListener() {}

  /// Removes every listener.
  void dispose() {
    clearListeners();
    clearStatusListeners();
  }
}
