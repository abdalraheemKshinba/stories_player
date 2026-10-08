import 'package:flutter/foundation.dart';

import 'pause_reason.dart';

/// What the current item is doing.
enum StoryPlaybackStatus {
  /// The item's media is loading; the poster is showing.
  loading,

  /// The item is on screen and its progress is moving.
  playing,

  /// Playback is held by at least one [PauseReason].
  paused,

  /// A streamed video ran out of data; progress is frozen until it resumes.
  buffering,

  /// The item failed to load. See [StoriesValue.error].
  error,

  /// The item finished and the player is not advancing on its own, for
  /// example because a screen reader is active.
  completed,
}

/// Why the player moved to another item.
enum StoryChangeReason {
  /// The player opened on this item.
  initial,

  /// The previous item's time ran out.
  timer,

  /// The user tapped a side of the screen.
  tap,

  /// The user swiped between groups.
  swipe,

  /// A keyboard shortcut.
  keyboard,

  /// A screen reader action.
  semantics,

  /// A call on [StoriesController].
  controller,
}

/// Why the player asked to be closed.
enum StoriesDismissReason {
  /// The last item of the last group finished.
  completed,

  /// The user tapped the close button.
  closeButton,

  /// The user dragged the player down.
  swipeDown,

  /// The user pressed Escape.
  keyboard,

  /// A screen reader's dismiss action.
  semantics,

  /// A call to [StoriesController.dismiss].
  controller,
}

/// An immutable snapshot of the player's state, held by
/// [StoriesController.value].
///
/// Progress inside the current item is not part of this value, because it
/// changes every frame; listen to [StoriesController.progress] for that.
@immutable
final class StoriesValue {
  /// Creates a snapshot. Most apps only read these.
  const StoriesValue({
    this.groupIndex = 0,
    this.itemIndex = 0,
    this.groupId,
    this.itemId,
    this.status = StoryPlaybackStatus.loading,
    this.pauseReasons = const <PauseReason>{},
    this.isMuted = true,
    this.itemDuration,
    this.error,
  });

  /// The value of a controller that is not attached to a player.
  static const StoriesValue detached = StoriesValue();

  /// The index of the current group.
  final int groupIndex;

  /// The index of the current item within its group.
  final int itemIndex;

  /// The id of the current group, once attached.
  final String? groupId;

  /// The id of the current item, once attached.
  final String? itemId;

  /// What the current item is doing.
  final StoryPlaybackStatus status;

  /// Everything currently holding playback. Empty while playing.
  final Set<PauseReason> pauseReasons;

  /// Whether sound is off.
  final bool isMuted;

  /// The current item's duration, once known.
  final Duration? itemDuration;

  /// The current item's load error, if [status] is
  /// [StoryPlaybackStatus.error].
  final Object? error;

  /// Whether the current item's progress is moving.
  bool get isPlaying => status == StoryPlaybackStatus.playing;

  /// Whether playback is held by a [PauseReason].
  bool get isPaused => pauseReasons.isNotEmpty;

  /// Whether the current item failed to load.
  bool get hasError => error != null;

  /// Returns a copy with the given fields replaced.
  StoriesValue copyWith({
    int? groupIndex,
    int? itemIndex,
    String? groupId,
    String? itemId,
    StoryPlaybackStatus? status,
    Set<PauseReason>? pauseReasons,
    bool? isMuted,
    Duration? itemDuration,
    Object? error = _unset,
  }) => StoriesValue(
    groupIndex: groupIndex ?? this.groupIndex,
    itemIndex: itemIndex ?? this.itemIndex,
    groupId: groupId ?? this.groupId,
    itemId: itemId ?? this.itemId,
    status: status ?? this.status,
    pauseReasons: pauseReasons ?? this.pauseReasons,
    isMuted: isMuted ?? this.isMuted,
    itemDuration: itemDuration ?? this.itemDuration,
    error: identical(error, _unset) ? this.error : error,
  );

  @override
  bool operator ==(Object other) =>
      other is StoriesValue &&
      other.groupIndex == groupIndex &&
      other.itemIndex == itemIndex &&
      other.groupId == groupId &&
      other.itemId == itemId &&
      other.status == status &&
      setEquals(other.pauseReasons, pauseReasons) &&
      other.isMuted == isMuted &&
      other.itemDuration == itemDuration &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    groupIndex,
    itemIndex,
    groupId,
    itemId,
    status,
    Object.hashAllUnordered(pauseReasons),
    isMuted,
    itemDuration,
    error,
  );

  @override
  String toString() =>
      'StoriesValue(group: $groupIndex, item: $itemIndex, ${status.name}'
      '${pauseReasons.isEmpty ? '' : ', paused by ${pauseReasons.map((r) => r.name).join('+')}'}'
      '${isMuted ? ', muted' : ''})';
}

const Object _unset = Object();
