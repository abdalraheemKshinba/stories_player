import 'package:flutter/foundation.dart';

import '../controller/stories_value.dart';

/// Something that happened in the player, for analytics and performance
/// monitoring.
///
/// Events arrive through [StoriesPlayer.onEvent] and
/// [StoriesController.events]. They are facts, named in the past tense, and
/// carry the position they happened at.
///
/// New event types may be added in minor versions, so a `switch` over
/// events should have a default case.
///
/// {@tool snippet}
/// ```dart
/// StoriesPlayer(
///   groups: groups,
///   onEvent: (event) {
///     if (event is StoryItemShown) {
///       analytics.timing('story_ttff', event.timeToFirstFrame);
///     }
///   },
/// )
/// ```
/// {@end-tool}
@immutable
abstract base class StoryEvent {
  /// Creates an event at the given position.
  StoryEvent({
    required this.groupId,
    required this.itemId,
    required this.groupIndex,
    required this.itemIndex,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// The group the event happened in.
  final String groupId;

  /// The item the event happened on.
  final String itemId;

  /// The index of [groupId].
  final int groupIndex;

  /// The index of [itemId] within its group.
  final int itemIndex;

  /// When the event happened.
  final DateTime timestamp;

  /// A short name for logs, such as `itemShown`.
  String get name;

  @override
  String toString() => '$name($groupId/$itemId)';
}

/// The player moved to a new item. Its media may still be loading.
final class StoryItemStarted extends StoryEvent {
  /// Creates the event.
  StoryItemStarted({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.reason,
  });

  /// Why the player moved here.
  final StoryChangeReason reason;

  @override
  String get name => 'itemStarted';
}

/// The item's media is on screen and its progress started.
final class StoryItemShown extends StoryEvent {
  /// Creates the event.
  StoryItemShown({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.timeToFirstFrame,
    required this.cacheHit,
  });

  /// Time from the item starting to its media being on screen. The key
  /// latency metric of a stories player.
  final Duration timeToFirstFrame;

  /// Whether the media came from the device cache.
  final bool cacheHit;

  @override
  String get name => 'itemShown';
}

/// The item counts as seen, under [StoriesPlaybackConfig.seenRule].
final class StoryItemSeen extends StoryEvent {
  /// Creates the event.
  StoryItemSeen({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
  });

  @override
  String get name => 'itemSeen';
}

/// The item played to its end.
final class StoryItemCompleted extends StoryEvent {
  /// Creates the event.
  StoryItemCompleted({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
  });

  @override
  String get name => 'itemCompleted';
}

/// The item's media failed to load or play.
final class StoryItemFailed extends StoryEvent {
  /// Creates the event.
  StoryItemFailed({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.error,
    this.stackTrace,
  });

  /// What went wrong.
  final Object error;

  /// Where it went wrong, if known.
  final StackTrace? stackTrace;

  @override
  String get name => 'itemFailed';
}

/// A streamed item ran out of data and has resumed.
final class StoryStalled extends StoryEvent {
  /// Creates the event.
  StoryStalled({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.stalledFor,
  });

  /// How long progress was frozen.
  final Duration stalledFor;

  @override
  String get name => 'stalled';
}

/// The player asked to be closed.
final class StoriesDismissed extends StoryEvent {
  /// Creates the event.
  StoriesDismissed({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.reason,
    required this.itemsShown,
  });

  /// Why.
  final StoriesDismissReason reason;

  /// How many items were shown in this session.
  final int itemsShown;

  @override
  String get name => 'dismissed';
}

/// What the prefetcher did during a player session. Sent once, when the
/// player is disposed.
final class StoryPrefetchReport extends StoryEvent {
  /// Creates the event.
  StoryPrefetchReport({
    required super.groupId,
    required super.itemId,
    required super.groupIndex,
    required super.itemIndex,
    required this.requested,
    required this.completed,
    required this.cancelled,
    required this.failed,
  });

  /// Media the prefetcher asked for.
  final int requested;

  /// Media that finished downloading ahead of time.
  final int completed;

  /// Media cancelled because the user moved away first.
  final int cancelled;

  /// Media that failed to download.
  final int failed;

  @override
  String get name => 'prefetchReport';
}
