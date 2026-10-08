import 'package:meta/meta.dart';

import '../controller/stories_value.dart';
import 'story_item_session.dart';

/// Keeps time for the current item and decides when it ends.
///
/// Pure logic, fed by the player's ticker:
///
/// * Media that keeps time (video) is followed: [elapsed] is its position,
///   so progress freezes while it buffers.
/// * Otherwise elapsed time counts only while the item is ready.
/// * Media that ends before the item's set duration "holds its last frame":
///   the clock then counts the remaining time itself.
@internal
final class StoryClock {
  /// Time spent on the current item.
  Duration elapsed = Duration.zero;

  /// Whether the item reached its end.
  bool ended = false;

  /// Whether the media ended before the item's duration.
  bool mediaEnded = false;

  Duration? _lastTick;

  /// Starts a new item, at [start] when restoring one.
  void reset({Duration start = Duration.zero}) {
    elapsed = start;
    _lastTick = null;
    ended = false;
    mediaEnded = false;
  }

  /// Forgets the last tick, so a pause is not counted as playing time.
  void resume() => _lastTick = null;

  /// Advances to [now] and returns the progress, from 0 to 1.
  ///
  /// [mediaPosition] is the media's own position, if it keeps time.
  /// [counting] says whether the item is ready, so its own time runs.
  double tick(
    Duration now, {
    required Duration duration,
    required Duration? mediaPosition,
    required bool counting,
  }) {
    final dt = _lastTick == null ? Duration.zero : now - _lastTick!;
    _lastTick = now;
    final position = mediaEnded ? null : mediaPosition;
    if (position != null) {
      elapsed = position;
    } else if (counting || mediaEnded) {
      elapsed += dt;
    }
    if (duration <= Duration.zero) return 1;
    return (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
  }

  /// The media reached its own end. Returns whether the item ends now;
  /// when the item has a longer set duration, the last frame holds instead.
  bool onMediaCompleted(Duration? itemDuration) {
    if (itemDuration != null && elapsed < itemDuration) {
      mediaEnded = true;
      return false;
    }
    return true;
  }
}

/// Whether an item in [session] state can play.
@internal
bool storyIsPlayable(StorySessionStatus? session, StoryClock clock) =>
    session != null &&
    !clock.ended &&
    (session == StorySessionStatus.ready ||
        session == StorySessionStatus.buffering ||
        clock.mediaEnded);

/// What the current item is doing, as [StoriesValue.status] reports it.
///
/// [held] is whether a pause reason or a dismissal holds playback.
@internal
StoryPlaybackStatus storyPlaybackStatus(
  StorySessionStatus? session,
  StoryClock clock, {
  required bool held,
}) {
  if (session == null ||
      session == StorySessionStatus.idle ||
      session == StorySessionStatus.preparing) {
    return StoryPlaybackStatus.loading;
  }
  if (session == StorySessionStatus.error) return StoryPlaybackStatus.error;
  if (session == StorySessionStatus.buffering) {
    return StoryPlaybackStatus.buffering;
  }
  if (clock.ended) return StoryPlaybackStatus.completed;
  return held ? StoryPlaybackStatus.paused : StoryPlaybackStatus.playing;
}
