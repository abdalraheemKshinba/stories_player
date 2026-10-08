/// Music tracks for `package:stories_player`, played through
/// `package:audioplayers`.
///
/// Pass an [AudioplayersStoryAudio] to [StoriesPlayer.audio]:
///
/// ```dart
/// StoriesPlayer(groups: groups, audio: AudioplayersStoryAudio())
/// ```
library;

import 'package:audioplayers/audioplayers.dart';
import 'package:stories_player/stories_player.dart';

/// Plays story music tracks with one [AudioPlayer].
///
/// Cached tracks play from the media store's file; others stream from
/// their URL. Asset media is resolved by its full asset key, such as
/// `assets/music/track.m4a`.
final class AudioplayersStoryAudio extends StoryAudioBackend {
  /// Creates a backend. Pass [player] to share an existing player.
  AudioplayersStoryAudio({AudioPlayer? player})
    : _player = player ?? AudioPlayer(),
      _ownsPlayer = player == null {
    _player.audioCache = AudioCache(prefix: '');
  }

  final AudioPlayer _player;
  final bool _ownsPlayer;

  @override
  Future<void> play(
    StoryMedia media, {
    required bool loop,
    required bool muted,
    String? localPath,
  }) async {
    await _player.stop();
    await _player.setReleaseMode(loop ? ReleaseMode.loop : ReleaseMode.stop);
    await _player.setVolume(muted ? 0 : 1);
    final Source source = switch (media.source) {
      StoryMediaSource.network =>
        localPath != null
            ? DeviceFileSource(localPath)
            : UrlSource(media.uri.toString()),
      StoryMediaSource.asset => AssetSource(
        media.package == null
            ? media.assetName!
            : 'packages/${media.package}/${media.assetName}',
      ),
      StoryMediaSource.file => DeviceFileSource(media.filePath!),
    };
    await _player.play(source);
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> setMuted(bool muted) => _player.setVolume(muted ? 0 : 1);

  @override
  Future<void> dispose() async {
    if (_ownsPlayer) await _player.dispose();
  }
}
