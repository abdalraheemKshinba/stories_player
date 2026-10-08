import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../media/story_media_store.dart';
import '../model/story_item.dart';
import '../model/story_media.dart';
import 'story_audio.dart';

/// What a [StoryItemSession] is doing.
enum StorySessionStatus {
  /// Created; [StoryItemSession.prepare] has not been called.
  idle,

  /// Loading media.
  preparing,

  /// Ready to show. The player starts progress from here.
  ready,

  /// Out of data while playing; progress freezes.
  buffering,

  /// The media reached its own end before the item's duration.
  completed,

  /// Loading or playing failed. See [StoryItemSession.error].
  error,
}

/// Everything a session needs from the player.
@immutable
final class StorySessionContext {
  /// Creates a session context. Built by the player.
  const StorySessionContext({
    required this.store,
    required this.isMuted,
    required this.preferLowQuality,
    required this.imageDuration,
    this.audio,
    this.decodeWidth,
  });

  /// Where media is downloaded and cached.
  final StoryMediaStore store;

  /// Plays music tracks, if the app provided a backend.
  final StoryAudioBackend? audio;

  /// Whether sound starts off.
  final bool isMuted;

  /// Whether the network is slow and low-quality renditions are preferred.
  final bool preferLowQuality;

  /// The default duration of still images.
  final Duration imageDuration;

  /// The width, in physical pixels, to decode images at.
  final int? decodeWidth;
}

/// Shows one [StoryItem] while it is on screen, or prepares it just
/// before.
///
/// The player creates one session per item it shows or prepares, through
/// the item's [StoryItemDelegate], and disposes it when the item leaves the
/// prepared window. A session owns whatever the item needs to play: a
/// decoded image, a video player, a parsed animation.
///
/// The player drives a session through [prepare], [play], [pause] and
/// [dispose], and reads its [status]. Subclasses report progress in one of
/// two ways:
///
///  * **Timed** (the default): [position] returns `null` and the player
///    counts elapsed time itself while the session is [StorySessionStatus.ready].
///  * **Media clock**: [position] returns the media's own position, so
///    progress freezes automatically while a video buffers.
///
/// Implementations extend this class rather than implement it, so that
/// members added in future versions arrive with working defaults.
abstract base class StoryItemSession extends ChangeNotifier {
  /// Creates a session for [item].
  StoryItemSession(this.item, this.context);

  /// The item this session shows.
  final StoryItem item;

  /// What the player provided.
  final StorySessionContext context;

  StorySessionStatus _status = StorySessionStatus.idle;
  Object? _error;
  StackTrace? _stackTrace;
  Duration? _duration;
  bool _cacheHit = false;
  bool _isDisposed = false;
  Future<void>? _preparing;

  /// What the session is doing.
  StorySessionStatus get status => _status;

  /// The error that moved the session to [StorySessionStatus.error].
  Object? get error => _error;

  /// Where [error] happened, if known.
  StackTrace? get stackTrace => _stackTrace;

  /// The item's duration as the media reports it, once known.
  ///
  /// The player uses [StoryItem.duration] first, then this, then
  /// [StorySessionContext.imageDuration].
  Duration? get duration => _duration;

  /// Whether the media came from the device cache. Reported in
  /// [StoryItemShown.cacheHit].
  bool get cacheHit => _cacheHit;

  /// The media's own playback position, for sessions whose media keeps
  /// time. `null` means the player keeps time.
  Duration? get position => null;

  /// Whether [dispose] has been called.
  bool get isDisposed => _isDisposed;

  /// Loads the media. Safe to call more than once; later calls return the
  /// first call's future. Never throws: failures move the session to
  /// [StorySessionStatus.error].
  @nonVirtual
  Future<void> prepare() => _preparing ??= _prepare();

  Future<void> _prepare() async {
    setStatus(StorySessionStatus.preparing);
    try {
      await onPrepare();
      if (_status == StorySessionStatus.preparing) {
        setStatus(StorySessionStatus.ready);
      }
    } on Object catch (error, stackTrace) {
      reportError(error, stackTrace);
    }
  }

  /// Loads the media. Called once, by [prepare].
  ///
  /// Return when the first frame can be painted. Throw to report a
  /// failure. Check [isDisposed] after every `await`: the user may have
  /// moved on.
  @protected
  Future<void> onPrepare();

  /// Starts or resumes playback. Called only when [status] is ready.
  void play() {}

  /// Pauses playback.
  void pause() {}

  /// Turns sound on or off.
  void setMuted(bool muted) {}

  /// Moves playback to [position], for media that keeps time.
  void seekTo(Duration position) {}

  /// Prepares a session that was shown before to be shown again from the
  /// start, for example when the user taps back to it.
  ///
  /// The default seeks to zero and leaves the completed state. Sessions
  /// with their own extra state, such as a music track, override it and
  /// call `super.rewind()`.
  @mustCallSuper
  void rewind() {
    seekTo(Duration.zero);
    if (_status == StorySessionStatus.completed) {
      setStatus(StorySessionStatus.ready);
    }
  }

  /// Called every frame while the item plays, with the elapsed time and
  /// the progress from 0 to 1. Lets timed animations follow the progress
  /// bar.
  void onTick(Duration elapsed, double progress) {}

  /// Builds the item's content, filling the available space.
  Widget build(BuildContext context);

  /// Moves the session to [status] and notifies the player.
  @protected
  void setStatus(StorySessionStatus status) {
    if (_isDisposed || _status == status) return;
    _status = status;
    notifyListeners();
  }

  /// Records the media's own duration.
  @protected
  void setDuration(Duration duration) {
    if (_isDisposed || _duration == duration) return;
    _duration = duration;
    notifyListeners();
  }

  /// Records whether the media came from the cache.
  @protected
  set cacheHit(bool value) => _cacheHit = value;

  /// Moves the session to [StorySessionStatus.error].
  @protected
  void reportError(Object error, [StackTrace? stackTrace]) {
    if (_isDisposed) return;
    _error = error;
    _stackTrace = stackTrace;
    _status = StorySessionStatus.error;
    notifyListeners();
  }

  /// Releases everything the session holds. Subclasses release their media
  /// and call `super.dispose()`.
  @override
  @mustCallSuper
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  String toString() =>
      '${objectRuntimeType(this, 'StoryItemSession')}'
      '(${item.id}, ${_status.name})';
}

/// One media download the prefetcher may start for an item.
@immutable
final class StoryPrefetchRequest {
  /// Requests [media], or only its first [maxBytes] bytes.
  const StoryPrefetchRequest(this.media, {this.maxBytes});

  /// The media to fetch.
  final StoryMedia media;

  /// Fetch only this many bytes from the start, or the whole file if null.
  final int? maxBytes;
}

/// What the prefetcher knows when asking a delegate what to fetch.
@immutable
final class StoryPrefetchContext {
  /// Creates a prefetch context. Built by the prefetcher.
  const StoryPrefetchContext({
    required this.preferLowQuality,
    required this.maxVideoBytes,
  });

  /// Whether the network is slow and low renditions are preferred.
  final bool preferLowQuality;

  /// The largest video worth downloading whole ahead of time.
  final int maxVideoBytes;
}

/// Shows one kind of [StoryItem]: creates its sessions and says what to
/// prefetch for it.
///
/// The player asks its delegates in order and uses the first whose
/// [canHandle] returns true. Built-in delegates for [ImageStoryItem] and
/// [WidgetStoryItem] are always available after the ones you pass.
///
/// {@tool snippet}
/// A delegate for a custom item type:
///
/// ```dart
/// final class PollStoryItem extends StoryItem {
///   const PollStoryItem({required super.id, required this.question})
///     : super(duration: const Duration(seconds: 8));
///   final String question;
///   @override
///   Iterable<StoryMedia> get media => const [];
/// }
///
/// final class PollStoryDelegate extends StoryItemDelegate {
///   const PollStoryDelegate();
///   @override
///   bool canHandle(StoryItem item) => item is PollStoryItem;
///   @override
///   StoryItemSession createSession(
///     covariant PollStoryItem item,
///     StorySessionContext context,
///   ) => _PollSession(item, context);
/// }
/// ```
/// {@end-tool}
abstract base class StoryItemDelegate {
  /// Constructor for subclasses.
  const StoryItemDelegate();

  /// Whether this delegate shows [item].
  bool canHandle(StoryItem item);

  /// Creates a session that shows [item].
  StoryItemSession createSession(
    covariant StoryItem item,
    StorySessionContext context,
  );

  /// What to download ahead of time for [item].
  ///
  /// The default fetches every media of the item, except videos larger than
  /// [StoryPrefetchContext.maxVideoBytes] or of unknown size.
  Iterable<StoryPrefetchRequest> prefetch(
    covariant StoryItem item,
    StoryPrefetchContext context,
  ) => defaultPrefetch(item, context);

  /// The default prefetch rule, for delegates that extend it.
  static Iterable<StoryPrefetchRequest> defaultPrefetch(
    StoryItem item,
    StoryPrefetchContext context,
  ) sync* {
    for (final original in item.media) {
      final media = original.resolve(
        preferLowQuality: context.preferLowQuality,
      );
      if (!media.isNetwork) continue;
      if (media.kind == StoryMediaKind.video) {
        final bytes = media.bytes;
        if (bytes == null || bytes > context.maxVideoBytes) continue;
      }
      yield StoryPrefetchRequest(media);
    }
  }
}
