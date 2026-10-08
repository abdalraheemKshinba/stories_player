/// Fakes for testing code that uses `package:stories_player`.
///
/// ```dart
/// final delegate = FakeStoryItemDelegate();
/// await tester.pumpWidget(MaterialApp(
///   home: StoriesPlayer(
///     groups: [StoryGroup(id: 'g', items: [FakeStoryItem(id: 'a')])],
///     delegates: [delegate],
///   ),
/// ));
/// delegate.sessionFor('a').completePrepare();
/// ```
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'stories_player.dart';

/// An audio backend that records what it is doing, with commands that take
/// time like a real audio plugin, so tests can catch ordering bugs.
final class FakeStoryAudioBackend extends StoryAudioBackend {
  /// Creates a backend whose every command takes [latency].
  FakeStoryAudioBackend({this.latency = const Duration(milliseconds: 30)});

  /// How long each command takes.
  final Duration latency;

  /// The track loaded, or `null` after a stop.
  StoryMedia? current;

  /// Whether the loaded track is audible right now.
  bool isPlaying = false;

  /// Whether sound is off.
  bool isMuted = true;

  /// Every command, in the order it finished, such as `play:a.m4a`.
  final List<String> log = [];

  /// Times two commands ran at the same time. Always zero when calls are
  /// properly ordered.
  int overlaps = 0;

  int _running = 0;

  Future<void> _step(
    String entry,
    void Function() apply, {
    int steps = 1,
  }) async {
    _running++;
    if (_running > 1) overlaps++;
    await Future<void>.delayed(latency * steps);
    apply();
    log.add(entry);
    _running--;
  }

  @override
  Future<void> play(
    StoryMedia media, {
    required bool loop,
    required bool muted,
    String? localPath,
  }) => _step(
    'play:${media.cacheKey.split('/').last}',
    () {
      current = media;
      isMuted = muted;
      isPlaying = true;
    },
    // Starting a track is several plugin calls: stop, mode, volume, play.
    steps: 3,
  );

  @override
  Future<void> pause() => _step('pause', () => isPlaying = false);

  @override
  Future<void> resume() => _step('resume', () {
    if (current != null) isPlaying = true;
  });

  @override
  Future<void> stop() => _step('stop', () {
    current = null;
    isPlaying = false;
  });

  @override
  Future<void> setMuted(bool muted) =>
      _step('mute:$muted', () => isMuted = muted);
}

/// An item with no media, shown by [FakeStoryItemDelegate].
final class FakeStoryItem extends StoryItem {
  /// Creates a fake item lasting [duration].
  const FakeStoryItem({
    required super.id,
    super.duration = const Duration(seconds: 1),
    super.caption,
    super.semanticLabel,
    this.hasSound = false,
    this.media = const [],
  });

  /// Whether the item reports sound.
  final bool hasSound;

  @override
  final Iterable<StoryMedia> media;

  @override
  bool get hasAudio => hasSound;
}

/// Creates [FakeStoryItemSession]s and keeps them for inspection.
final class FakeStoryItemDelegate extends StoryItemDelegate {
  /// Creates a delegate. With [autoPrepare], sessions become ready as soon
  /// as they are prepared; otherwise call
  /// [FakeStoryItemSession.completePrepare].
  FakeStoryItemDelegate({this.autoPrepare = true, this.mediaClock = false});

  /// Whether sessions become ready on their own.
  final bool autoPrepare;

  /// Whether sessions report their own [FakeStoryItemSession.position].
  final bool mediaClock;

  /// Every session created, in order.
  final List<FakeStoryItemSession> sessions = [];

  /// The latest session created for the item with [itemId].
  FakeStoryItemSession sessionFor(String itemId) =>
      sessions.lastWhere((session) => session.item.id == itemId);

  @override
  bool canHandle(StoryItem item) => item is FakeStoryItem;

  @override
  StoryItemSession createSession(
    covariant FakeStoryItem item,
    StorySessionContext context,
  ) {
    final session = FakeStoryItemSession._(item, context, this);
    sessions.add(session);
    return session;
  }
}

/// A session whose loading, buffering and position a test controls.
final class FakeStoryItemSession extends StoryItemSession {
  FakeStoryItemSession._(super.item, super.context, this._delegate);

  final FakeStoryItemDelegate _delegate;
  final Completer<void> _prepared = Completer<void>();
  Duration? _position;

  /// Whether the player told the session to play.
  bool isPlaying = false;

  /// How many times [play] was called.
  int playCount = 0;

  /// The last value passed to [setMuted].
  bool? muted;

  /// The last value passed to [seekTo].
  Duration? seekedTo;

  @override
  Duration? get position => _delegate.mediaClock ? _position : null;

  /// Sets the media position, for a delegate created with `mediaClock`.
  set position(Duration? value) => _position = value;

  @override
  Future<void> onPrepare() {
    if (_delegate.autoPrepare && !_prepared.isCompleted) _prepared.complete();
    return _prepared.future;
  }

  /// Makes the session ready.
  void completePrepare() {
    if (!_prepared.isCompleted) _prepared.complete();
  }

  /// Makes the session fail to load.
  void failPrepare([Object error = 'fake failure']) {
    if (!_prepared.isCompleted) _prepared.completeError(error);
  }

  /// Simulates a stream running out of data.
  void startBuffering() => setStatus(StorySessionStatus.buffering);

  /// Simulates the stream recovering.
  void stopBuffering() => setStatus(StorySessionStatus.ready);

  /// Simulates the media ending on its own.
  void finish() => setStatus(StorySessionStatus.completed);

  @override
  void play() {
    isPlaying = true;
    playCount++;
  }

  @override
  void pause() => isPlaying = false;

  @override
  void setMuted(bool muted) => this.muted = muted;

  @override
  void seekTo(Duration position) => seekedTo = position;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: const Color(0xFF223344), child: Text(item.id));
}

/// A media store that records requests and completes them on command.
final class FakeStoryMediaStore extends StoryMediaStore {
  /// Creates a fake store. With [completeImmediately], every fetch
  /// succeeds at once.
  FakeStoryMediaStore({this.completeImmediately = false});

  /// Whether fetches succeed at once.
  final bool completeImmediately;

  /// Every fetch, in order.
  final List<FakeStoryFetch> fetches = [];

  /// Pin counts by cache key.
  final Map<String, int> pins = {};

  /// The bits per second reported to network signals.
  double? bitsPerSecond;

  @override
  bool get supportsFiles => true;

  @override
  double? get estimatedBitsPerSecond => bitsPerSecond;

  @override
  Future<String?> fetch(
    StoryMedia media, {
    StoryFetchPriority priority = StoryFetchPriority.visible,
    int? maxBytes,
    StoryFetchToken? token,
    DateTime? expiresAt,
  }) {
    final fetch = FakeStoryFetch._(media, priority, maxBytes, token);
    fetches.add(fetch);
    token?.addListener(() => fetch.complete(null));
    if (completeImmediately) fetch.complete('/fake/${media.cacheKey}');
    return fetch._completer.future;
  }

  @override
  void pin(StoryMedia media) =>
      pins.update(media.cacheKey, (count) => count + 1, ifAbsent: () => 1);

  @override
  void unpin(StoryMedia media) {
    final count = (pins[media.cacheKey] ?? 0) - 1;
    if (count <= 0) {
      pins.remove(media.cacheKey);
    } else {
      pins[media.cacheKey] = count;
    }
  }
}

/// One request made to a [FakeStoryMediaStore].
final class FakeStoryFetch {
  FakeStoryFetch._(this.media, this.priority, this.maxBytes, this.token);

  /// The media requested.
  final StoryMedia media;

  /// How urgently.
  final StoryFetchPriority priority;

  /// The byte limit, if any.
  final int? maxBytes;

  /// The cancellation token, if any.
  final StoryFetchToken? token;

  final Completer<String?> _completer = Completer<String?>();

  /// Whether the request was cancelled.
  bool get isCancelled => token?.isCancelled ?? false;

  /// Completes the request with [path].
  void complete(String? path) {
    if (!_completer.isCompleted) _completer.complete(path);
  }

  /// Fails the request.
  void fail(Object error) {
    if (!_completer.isCompleted) _completer.completeError(error);
  }
}
