import 'dart:async';

import 'package:flutter/foundation.dart';

import '../media/story_media_store.dart';
import '../model/story_item.dart';
import '../model/story_media.dart';

/// Plays the music tracks of image and animation items.
///
/// The core package plays no audio itself, so apps that only show silent
/// stories pay nothing for an audio plugin. Add
/// `package:stories_player_audio` for a ready-made backend, or extend this
/// class over the audio plugin your app already uses.
///
/// The player uses one backend for the whole session and plays one track
/// at a time.
abstract base class StoryAudioBackend {
  /// Constructor for subclasses.
  StoryAudioBackend();

  /// Starts [media] from the beginning, replacing any track playing.
  ///
  /// [localPath] is the cached file, when the media store has one.
  Future<void> play(
    StoryMedia media, {
    required bool loop,
    required bool muted,
    String? localPath,
  });

  /// Pauses the current track.
  Future<void> pause();

  /// Resumes the current track.
  Future<void> resume();

  /// Stops the current track.
  Future<void> stop();

  /// Turns sound on or off without stopping the track.
  Future<void> setMuted(bool muted);

  /// Releases the backend. Called when the player is disposed, only for
  /// backends the player created.
  Future<void> dispose() async {}
}

/// Plays one item's [StoryAudio] through a [StoryAudioBackend].
///
/// A helper for session implementations. Several tracks share one backend,
/// and the user can move between items faster than an audio plugin
/// answers, so every call goes through one ordered queue per backend, and
/// the backend remembers which track owns it:
///
/// * Commands run one at a time, in the order they were made. A pause can
///   never overtake the play it follows, so a track can never start after
///   its item is gone.
/// * Only the owning track can pause, stop or mute the backend. A late
///   call from an item the user left does nothing, so it can never silence
///   the next item's music either.
/// * Starting a track takes ownership and replaces whatever was playing,
///   so two tracks never sound at once.
final class StoryAudioTrack {
  /// Creates a track helper.
  StoryAudioTrack({
    required this.audio,
    required this.backend,
    required this.store,
    required bool muted,
  }) : _muted = muted; // ignore: prefer_initializing_formals

  /// The track to play.
  final StoryAudio audio;

  /// What plays it. When `null`, the helper does nothing.
  final StoryAudioBackend? backend;

  /// Where the track is cached.
  final StoryMediaStore store;

  bool _muted;
  bool _started = false;
  bool _playing = false;
  bool _disposed = false;

  _AudioCoordinator? get _coordinator {
    final backend = this.backend;
    return backend == null ? null : _AudioCoordinator.of(backend);
  }

  /// Whether this track currently owns its backend.
  @visibleForTesting
  bool get ownsBackend => _coordinator?.owner == this;

  /// Downloads the track ahead of playing it.
  Future<void> preload() async {
    if (backend == null || !audio.media.isNetwork) return;
    try {
      await store.fetch(audio.media, priority: StoryFetchPriority.next);
    } on StoryMediaException {
      // Playback falls back to streaming the track.
    }
  }

  /// Starts the track, or resumes it if it was paused.
  void play() {
    final coordinator = _coordinator;
    if (coordinator == null || _playing || _disposed) return;
    _playing = true;
    if (_started && coordinator.owner == this) {
      coordinator.run(this, (backend) => backend.resume());
    } else {
      _started = true;
      final muted = _muted;
      coordinator.claim(
        this,
        (backend) => backend.play(
          audio.media,
          loop: audio.loop,
          muted: muted,
          localPath: store.lookup(audio.media),
        ),
      );
    }
  }

  /// Pauses the track.
  void pause() {
    if (!_playing) return;
    _playing = false;
    _coordinator?.run(this, (backend) => backend.pause());
  }

  /// Turns sound on or off.
  void setMuted(bool muted) {
    _muted = muted;
    if (_started) _coordinator?.run(this, (backend) => backend.setMuted(muted));
  }

  /// Makes the next [play] start the track from the beginning.
  void rewind() {
    if (_started) _coordinator?.release(this);
    _started = false;
    _playing = false;
  }

  /// Stops the track if it still owns the backend.
  void dispose() {
    _disposed = true;
    if (_started) _coordinator?.release(this);
    _started = false;
    _playing = false;
  }
}

/// Serialises one backend's calls and tracks which track owns it.
final class _AudioCoordinator {
  _AudioCoordinator(this._backend);

  static final Expando<_AudioCoordinator> _coordinators =
      Expando<_AudioCoordinator>('StoryAudioCoordinator');

  static _AudioCoordinator of(StoryAudioBackend backend) =>
      _coordinators[backend] ??= _AudioCoordinator(backend);

  final StoryAudioBackend _backend;
  Future<void> _tail = Future<void>.value();

  /// The track whose sound the backend is playing, or last played.
  StoryAudioTrack? owner;

  /// Makes [track] the owner and runs [command] after everything queued.
  void claim(
    StoryAudioTrack track,
    Future<void> Function(StoryAudioBackend backend) command,
  ) {
    owner = track;
    _enqueue(() => owner == track ? command(_backend) : Future<void>.value());
  }

  /// Runs [command] after everything queued, if [track] still owns the
  /// backend by then.
  void run(
    StoryAudioTrack track,
    Future<void> Function(StoryAudioBackend backend) command,
  ) {
    if (owner != track) return;
    _enqueue(() => owner == track ? command(_backend) : Future<void>.value());
  }

  /// Stops the backend if [track] owns it, and gives up ownership.
  void release(StoryAudioTrack track) {
    if (owner != track) return;
    owner = null;
    _enqueue(() => owner == null ? _backend.stop() : Future<void>.value());
  }

  void _enqueue(Future<void> Function() command) {
    _tail = _tail.then((_) => command()).catchError((Object error) {
      // An audio failure must never break playback of the story itself.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          library: 'stories_player',
          context: ErrorDescription('while controlling story audio'),
        ),
      );
    });
  }
}
