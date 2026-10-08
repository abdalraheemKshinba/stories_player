import 'package:flutter/foundation.dart';

import '../media/story_media_store.dart';

/// How fast the network is, as far as story media is concerned.
enum StoryNetworkQuality {
  /// Not measured yet. Treated as [slow], to protect users' data.
  unknown,

  /// A slow or metered connection: 2G, 3G, or the user's data saver.
  slow,

  /// A fast connection: Wi-Fi or LTE.
  fast,
}

/// Tells the prefetcher how fast the network is.
///
/// The default measures the speed of the player's own downloads, so the
/// package needs no connectivity plugin. Apps that already know more, such
/// as whether the user turned on a data saver, can supply their own:
///
/// {@tool snippet}
/// ```dart
/// final class AppNetworkSignal extends StoryNetworkSignal {
///   const AppNetworkSignal(this.settings);
///   final AppSettings settings;
///
///   @override
///   StoryNetworkQuality quality(StoryMediaStore store) => settings.dataSaver
///       ? StoryNetworkQuality.slow
///       : const StoryNetworkSignal.measured().quality(store);
/// }
/// ```
/// {@end-tool}
abstract base class StoryNetworkSignal {
  /// Constructor for subclasses.
  const StoryNetworkSignal();

  /// Measures the speed of story downloads: [StoryNetworkQuality.fast]
  /// above [fastBitsPerSecond], [StoryNetworkQuality.slow] below it.
  const factory StoryNetworkSignal.measured({double fastBitsPerSecond}) =
      _MeasuredNetworkSignal;

  /// Always reports [quality]. Useful for tests and for a data-saver mode.
  const factory StoryNetworkSignal.fixed(StoryNetworkQuality quality) =
      _FixedNetworkSignal;

  /// The current network quality.
  StoryNetworkQuality quality(StoryMediaStore store);
}

final class _MeasuredNetworkSignal extends StoryNetworkSignal {
  const _MeasuredNetworkSignal({this.fastBitsPerSecond = 1.5e6});

  final double fastBitsPerSecond;

  @override
  StoryNetworkQuality quality(StoryMediaStore store) {
    final measured = store.estimatedBitsPerSecond;
    if (measured == null) return StoryNetworkQuality.unknown;
    return measured >= fastBitsPerSecond
        ? StoryNetworkQuality.fast
        : StoryNetworkQuality.slow;
  }
}

final class _FixedNetworkSignal extends StoryNetworkSignal {
  const _FixedNetworkSignal(this._quality);

  final StoryNetworkQuality _quality;

  @override
  StoryNetworkQuality quality(StoryMediaStore store) => _quality;
}

/// How much to download ahead on one kind of network.
@immutable
final class StoryPrefetchTier {
  /// Creates a tier.
  const StoryPrefetchTier({
    required this.itemsAhead,
    required this.groupsAhead,
    required this.maxVideoBytes,
    this.preferLowQuality = false,
  }) : assert(
         itemsAhead >= 0 && groupsAhead >= 0,
         'Counts are never negative.',
       );

  /// Downloads nothing ahead.
  static const StoryPrefetchTier none = StoryPrefetchTier(
    itemsAhead: 0,
    groupsAhead: 0,
    maxVideoBytes: 0,
  );

  /// How many items after the current one, in the same group.
  final int itemsAhead;

  /// How many following groups get their first item downloaded.
  final int groupsAhead;

  /// The largest video downloaded whole ahead of time. Larger videos are
  /// left to the player's own buffering.
  final int maxVideoBytes;

  /// Whether to load low-quality renditions, when an item has them.
  final bool preferLowQuality;

  @override
  bool operator ==(Object other) =>
      other is StoryPrefetchTier &&
      other.itemsAhead == itemsAhead &&
      other.groupsAhead == groupsAhead &&
      other.maxVideoBytes == maxVideoBytes &&
      other.preferLowQuality == preferLowQuality;

  @override
  int get hashCode =>
      Object.hash(itemsAhead, groupsAhead, maxVideoBytes, preferLowQuality);

  @override
  String toString() =>
      'StoryPrefetchTier(items: $itemsAhead, groups: $groupsAhead, '
      'video ≤ $maxVideoBytes B${preferLowQuality ? ', low quality' : ''})';
}

/// How much story media to download before the user reaches it.
///
/// Prefetching is what makes the next story start instantly, and what
/// costs the user data if they close the player early. A policy sets that
/// trade-off per network quality. Whatever the policy, the current item
/// always wins the bandwidth, anything the user moves away from is
/// cancelled, and posters are fetched because they are small.
///
/// | preset | fast: items / groups / video | slow: items / groups / video |
/// |---|---|---|
/// | [none] | 0 / 0 / – | 0 / 0 / – |
/// | [conservative] | 1 / 1 / 1 MB | 1 / 0 / – |
/// | [balanced] | 2 / 3 / 2.5 MB | 1 / 1 / 1 MB |
/// | [aggressive] | 3 / 3 / 5 MB | 2 / 2 / 2.5 MB |
///
/// Slow networks always prefer low-quality renditions.
@immutable
final class StoryPrefetchPolicy {
  /// Creates a policy with a tier for each network quality.
  const StoryPrefetchPolicy({
    required this.fast,
    required this.slow,
    this.prefetchPosters = true,
  });

  /// Downloads nothing ahead, not even posters. For a data-saver mode.
  static const StoryPrefetchPolicy none = StoryPrefetchPolicy(
    fast: StoryPrefetchTier.none,
    slow: StoryPrefetchTier.none,
    prefetchPosters: false,
  );

  /// The next item on a fast network; only the next image on a slow one.
  static const StoryPrefetchPolicy conservative = StoryPrefetchPolicy(
    fast: StoryPrefetchTier(itemsAhead: 1, groupsAhead: 1, maxVideoBytes: _mb),
    slow: StoryPrefetchTier(
      itemsAhead: 1,
      groupsAhead: 0,
      maxVideoBytes: 0,
      preferLowQuality: true,
    ),
  );

  /// The default: up to three groups ahead on a fast network, the next
  /// item and group on a slow one. Matches what large apps ship.
  static const StoryPrefetchPolicy balanced = StoryPrefetchPolicy(
    fast: StoryPrefetchTier(
      itemsAhead: 2,
      groupsAhead: 3,
      maxVideoBytes: 5 * _mb ~/ 2,
    ),
    slow: StoryPrefetchTier(
      itemsAhead: 1,
      groupsAhead: 1,
      maxVideoBytes: _mb,
      preferLowQuality: true,
    ),
  );

  /// Instant playback over data savings.
  static const StoryPrefetchPolicy aggressive = StoryPrefetchPolicy(
    fast: StoryPrefetchTier(
      itemsAhead: 3,
      groupsAhead: 3,
      maxVideoBytes: 5 * _mb,
    ),
    slow: StoryPrefetchTier(
      itemsAhead: 2,
      groupsAhead: 2,
      maxVideoBytes: 5 * _mb ~/ 2,
      preferLowQuality: true,
    ),
  );

  static const int _mb = 1024 * 1024;

  /// What to download on a fast network.
  final StoryPrefetchTier fast;

  /// What to download on a slow or unmeasured network.
  final StoryPrefetchTier slow;

  /// Whether posters and avatars are fetched ahead, whatever the network.
  final bool prefetchPosters;

  /// The tier for [quality].
  StoryPrefetchTier tierFor(StoryNetworkQuality quality) =>
      quality == StoryNetworkQuality.fast ? fast : slow;

  @override
  bool operator ==(Object other) =>
      other is StoryPrefetchPolicy &&
      other.fast == fast &&
      other.slow == slow &&
      other.prefetchPosters == prefetchPosters;

  @override
  int get hashCode => Object.hash(fast, slow, prefetchPosters);
}
