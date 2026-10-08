import 'package:flutter/foundation.dart';

/// When an item counts as seen and [StoriesPlayer.onItemSeen] fires.
enum StorySeenRule {
  /// As soon as the player moves to the item, before its media loads.
  onStart,

  /// When the item's media is on screen. The default, and what Telegram
  /// does: a story that never loaded was not seen.
  onFirstFrame,

  /// When the item plays to its end.
  onComplete,
}

/// What happens when a video ends before the item's set duration.
enum StoryMediaEndBehavior {
  /// The item ends with its media. The default: a frozen frame with a
  /// running progress bar looks like a stuck video.
  endItem,

  /// The last frame holds until the item's duration runs out.
  holdLastFrame,
}

/// What happens when the last item of a group ends.
enum StoryGroupEndBehavior {
  /// Continue with the next group; ask to dismiss after the last group.
  nextGroup,

  /// Ask to dismiss straight away.
  dismiss,
}

/// How the player plays items: durations, advancing, sound and seen state.
///
/// Group these settings into one object so an app can define its house
/// defaults once and adjust them with [copyWith].
@immutable
final class StoriesPlaybackConfig {
  /// Creates a playback configuration.
  const StoriesPlaybackConfig({
    this.imageDuration = const Duration(seconds: 5),
    this.autoAdvance = true,
    this.autoAdvanceWithScreenReader = false,
    this.groupEnd = StoryGroupEndBehavior.nextGroup,
    this.initiallyMuted = true,
    this.seenRule = StorySeenRule.onFirstFrame,
    this.loadingIndicatorDelay = const Duration(milliseconds: 300),
    this.skipFailedItemsAfter,
    this.maxPreparedItems = 2,
    this.mediaEnd = StoryMediaEndBehavior.endItem,
  }) : assert(maxPreparedItems >= 1, 'At least the current item is prepared.');

  /// How long an image stays when the item sets no duration.
  final Duration imageDuration;

  /// Whether the player moves on when an item ends.
  final bool autoAdvance;

  /// Whether to keep advancing while a screen reader is on.
  ///
  /// Off by default: screen reader users move with the semantic actions
  /// "next" and "previous" at their own pace.
  final bool autoAdvanceWithScreenReader;

  /// What happens after a group's last item.
  final StoryGroupEndBehavior groupEnd;

  /// Whether the player opens with sound off.
  final bool initiallyMuted;

  /// When an item counts as seen.
  final StorySeenRule seenRule;

  /// How long an item may load before the loading indicator shows, so fast
  /// loads never flash a spinner.
  final Duration loadingIndicatorDelay;

  /// When set, an item that fails to load is skipped after this delay.
  /// When `null`, the error stays on screen until the user retries or
  /// moves on.
  final Duration? skipFailedItemsAfter;

  /// How many items keep their media players alive: the current item plus
  /// the ones prepared ahead of it.
  ///
  /// Each prepared video holds a hardware decoder. Use 1 on low-end
  /// devices; the default of 2 prepares the next item so it starts
  /// instantly.
  final int maxPreparedItems;

  /// What happens when a video ends before the item's set duration.
  final StoryMediaEndBehavior mediaEnd;

  /// Returns a copy with the given fields replaced.
  StoriesPlaybackConfig copyWith({
    Duration? imageDuration,
    bool? autoAdvance,
    bool? autoAdvanceWithScreenReader,
    StoryGroupEndBehavior? groupEnd,
    bool? initiallyMuted,
    StorySeenRule? seenRule,
    Duration? loadingIndicatorDelay,
    Duration? skipFailedItemsAfter,
    int? maxPreparedItems,
    StoryMediaEndBehavior? mediaEnd,
  }) => StoriesPlaybackConfig(
    imageDuration: imageDuration ?? this.imageDuration,
    autoAdvance: autoAdvance ?? this.autoAdvance,
    autoAdvanceWithScreenReader:
        autoAdvanceWithScreenReader ?? this.autoAdvanceWithScreenReader,
    groupEnd: groupEnd ?? this.groupEnd,
    initiallyMuted: initiallyMuted ?? this.initiallyMuted,
    seenRule: seenRule ?? this.seenRule,
    loadingIndicatorDelay: loadingIndicatorDelay ?? this.loadingIndicatorDelay,
    skipFailedItemsAfter: skipFailedItemsAfter ?? this.skipFailedItemsAfter,
    maxPreparedItems: maxPreparedItems ?? this.maxPreparedItems,
    mediaEnd: mediaEnd ?? this.mediaEnd,
  );

  @override
  bool operator ==(Object other) =>
      other is StoriesPlaybackConfig &&
      other.imageDuration == imageDuration &&
      other.autoAdvance == autoAdvance &&
      other.autoAdvanceWithScreenReader == autoAdvanceWithScreenReader &&
      other.groupEnd == groupEnd &&
      other.initiallyMuted == initiallyMuted &&
      other.seenRule == seenRule &&
      other.loadingIndicatorDelay == loadingIndicatorDelay &&
      other.skipFailedItemsAfter == skipFailedItemsAfter &&
      other.maxPreparedItems == maxPreparedItems &&
      other.mediaEnd == mediaEnd;

  @override
  int get hashCode => Object.hash(
    imageDuration,
    autoAdvance,
    autoAdvanceWithScreenReader,
    groupEnd,
    initiallyMuted,
    seenRule,
    loadingIndicatorDelay,
    skipFailedItemsAfter,
    maxPreparedItems,
    mediaEnd,
  );
}

/// Which gestures the player responds to, and how.
///
/// Tap zones and swipe directions follow the ambient [TextDirection]: in a
/// right-to-left locale, tapping the right side goes back.
@immutable
final class StoriesGestureConfig {
  /// Creates a gesture configuration.
  const StoriesGestureConfig({
    this.previousZoneFraction = 0.3,
    this.holdToPause = true,
    this.holdDelay = const Duration(milliseconds: 200),
    this.hideOverlaysWhileHolding = true,
    this.swipeDownToDismiss = true,
    this.dismissDistanceFraction = 0.25,
    this.swipeBetweenGroups = true,
    this.keyboardShortcuts = true,
  }) : assert(
         previousZoneFraction > 0 && previousZoneFraction < 1,
         'previousZoneFraction must be between 0 and 1.',
       ),
       assert(
         dismissDistanceFraction > 0 && dismissDistanceFraction < 1,
         'dismissDistanceFraction must be between 0 and 1.',
       );

  /// The share of the width, on the leading side, where a tap goes back.
  /// The rest of the width goes forward.
  final double previousZoneFraction;

  /// Whether pressing and holding pauses.
  final bool holdToPause;

  /// How long a press lasts before it counts as a hold and not a tap.
  final Duration holdDelay;

  /// Whether the progress bar, header and footer hide while holding, so the
  /// user can look at the media.
  final bool hideOverlaysWhileHolding;

  /// Whether dragging down closes the player.
  final bool swipeDownToDismiss;

  /// How far, as a share of the height, a drag must go to close the player
  /// on release. A fast fling closes it from any distance.
  final double dismissDistanceFraction;

  /// Whether horizontal swipes move between groups.
  final bool swipeBetweenGroups;

  /// Whether arrow keys, Space and Escape control the player.
  final bool keyboardShortcuts;

  /// Returns a copy with the given fields replaced.
  StoriesGestureConfig copyWith({
    double? previousZoneFraction,
    bool? holdToPause,
    Duration? holdDelay,
    bool? hideOverlaysWhileHolding,
    bool? swipeDownToDismiss,
    double? dismissDistanceFraction,
    bool? swipeBetweenGroups,
    bool? keyboardShortcuts,
  }) => StoriesGestureConfig(
    previousZoneFraction: previousZoneFraction ?? this.previousZoneFraction,
    holdToPause: holdToPause ?? this.holdToPause,
    holdDelay: holdDelay ?? this.holdDelay,
    hideOverlaysWhileHolding:
        hideOverlaysWhileHolding ?? this.hideOverlaysWhileHolding,
    swipeDownToDismiss: swipeDownToDismiss ?? this.swipeDownToDismiss,
    dismissDistanceFraction:
        dismissDistanceFraction ?? this.dismissDistanceFraction,
    swipeBetweenGroups: swipeBetweenGroups ?? this.swipeBetweenGroups,
    keyboardShortcuts: keyboardShortcuts ?? this.keyboardShortcuts,
  );

  @override
  bool operator ==(Object other) =>
      other is StoriesGestureConfig &&
      other.previousZoneFraction == previousZoneFraction &&
      other.holdToPause == holdToPause &&
      other.holdDelay == holdDelay &&
      other.hideOverlaysWhileHolding == hideOverlaysWhileHolding &&
      other.swipeDownToDismiss == swipeDownToDismiss &&
      other.dismissDistanceFraction == dismissDistanceFraction &&
      other.swipeBetweenGroups == swipeBetweenGroups &&
      other.keyboardShortcuts == keyboardShortcuts;

  @override
  int get hashCode => Object.hash(
    previousZoneFraction,
    holdToPause,
    holdDelay,
    hideOverlaysWhileHolding,
    swipeDownToDismiss,
    dismissDistanceFraction,
    swipeBetweenGroups,
    keyboardShortcuts,
  );
}
