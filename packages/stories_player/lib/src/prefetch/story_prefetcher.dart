import 'dart:async';

import 'package:meta/meta.dart';

import '../media/story_media_store.dart';
import '../model/story_group.dart';
import '../model/story_item.dart';
import '../model/story_media.dart';
import '../playback/story_item_session.dart';
import 'story_prefetch_policy.dart';

/// Finds the delegate that shows an item.
typedef StoryDelegateResolver = StoryItemDelegate? Function(StoryItem item);

/// Downloads the media the user is about to see, inside a sliding window
/// around the current item.
///
/// On every move, the prefetcher recomputes the window from its policy,
/// starts what is new, cancels what fell out, and pins the window so the
/// media store never evicts it. Pure logic over a [StoryMediaStore]; it
/// knows nothing about widgets.
@internal
final class StoryPrefetcher {
  /// Creates a prefetcher.
  StoryPrefetcher({
    required this.store,
    required this.policy,
    required this.signal,
    required this.delegateFor,
  });

  /// Where media is downloaded.
  final StoryMediaStore store;

  /// How much to download ahead.
  StoryPrefetchPolicy policy;

  /// How fast the network is.
  StoryNetworkSignal signal;

  /// Finds the delegate for an item.
  final StoryDelegateResolver delegateFor;

  final Map<String, _Pending> _pending = {};
  final Set<String> _done = {};
  final Map<String, StoryMedia> _pinned = {};
  bool _stressed = false;
  bool _disposed = false;
  _Window? _lastWindow;

  /// Media the prefetcher asked for.
  int requested = 0;

  /// Media that finished downloading.
  int completed = 0;

  /// Media cancelled before it finished.
  int cancelled = 0;

  /// Media that failed.
  int failed = 0;

  /// The quality the last window was computed for.
  StoryNetworkQuality get quality => signal.quality(store);

  /// Recomputes the window around group [groupIndex], item [itemIndex].
  ///
  /// [resumeItemOf] gives the item a group opens at, so the prefetcher
  /// fetches the item the user will actually see in the next group.
  void update({
    required List<StoryGroup> groups,
    required int groupIndex,
    required int itemIndex,
    required int Function(int groupIndex) resumeItemOf,
  }) {
    if (_disposed || groups.isEmpty) return;
    _lastWindow = _Window(groups, groupIndex, itemIndex, resumeItemOf);
    final tier = policy.tierFor(quality);
    final context = StoryPrefetchContext(
      preferLowQuality: tier.preferLowQuality,
      maxVideoBytes: tier.maxVideoBytes,
    );
    final wanted = <String, _Want>{};
    final pins = <String, StoryMedia>{};

    void want(
      StoryMedia? media,
      StoryFetchPriority priority, {
      int? maxBytes,
      DateTime? expiresAt,
    }) {
      if (media == null || !media.isNetwork) return;
      pins[media.cacheKey] = media;
      if (_stressed && priority.index > StoryFetchPriority.next.index) return;
      final existing = wanted[media.cacheKey];
      if (existing == null || priority.index < existing.priority.index) {
        wanted[media.cacheKey] = _Want(media, priority, maxBytes, expiresAt);
      }
    }

    void wantItem(StoryItem item, StoryFetchPriority priority) {
      if (policy.prefetchPosters) want(item.poster, priority);
      final delegate = delegateFor(item);
      if (delegate == null) return;
      for (final request in delegate.prefetch(item, context)) {
        want(
          request.media,
          priority,
          maxBytes: request.maxBytes,
          expiresAt: item.expiresAt,
        );
      }
    }

    void wantPoster(StoryItem item, StoryFetchPriority priority) {
      if (policy.prefetchPosters) want(item.poster, priority);
    }

    final group = groups[groupIndex];
    // The current item: pinned so nothing evicts it while it plays. Its
    // session fetches it at the highest priority.
    final current = group.items[itemIndex];
    for (final media in current.media) {
      pins[media.cacheKey] = media;
    }

    // Items ahead in this group.
    for (var k = 1; k <= tier.itemsAhead; k++) {
      final index = itemIndex + k;
      if (index >= group.items.length) break;
      wantItem(
        group.items[index],
        k == 1 ? StoryFetchPriority.next : StoryFetchPriority.ahead,
      );
    }
    if (tier.itemsAhead == 0 && itemIndex + 1 < group.items.length) {
      wantPoster(group.items[itemIndex + 1], StoryFetchPriority.next);
    }

    // The first item the user will see in the following groups.
    final atLastItem = itemIndex == group.items.length - 1;
    for (var j = 1; j <= 3; j++) {
      final g = groupIndex + j;
      if (g >= groups.length) break;
      final next = groups[g];
      final item = next.items[resumeItemOf(g).clamp(0, next.items.length - 1)];
      final priority = j == 1 && atLastItem
          ? StoryFetchPriority.next
          : StoryFetchPriority.ahead;
      if (j <= tier.groupsAhead) {
        wantItem(item, priority);
      } else if (j == 1) {
        wantPoster(item, priority);
      }
      if (policy.prefetchPosters) {
        want(next.avatar, StoryFetchPriority.background);
      }
    }

    // Cancel what fell out of the window.
    for (final key in _pending.keys.toList()) {
      if (!wanted.containsKey(key)) {
        _pending.remove(key)!.token.cancel();
        cancelled++;
      }
    }
    // Start what is new.
    final ordered = wanted.values.toList()
      ..sort((a, b) => a.priority.index - b.priority.index);
    for (final want in ordered) {
      final key = want.media.cacheKey;
      if (_pending.containsKey(key) || _done.contains(key)) continue;
      if (want.maxBytes == null && store.lookup(want.media) != null) {
        _done.add(key);
        continue;
      }
      _start(want);
    }
    _updatePins(pins);
  }

  /// Holds back everything but the next item while the device struggles
  /// to render frames.
  void setStressed(bool stressed) {
    if (_stressed == stressed) return;
    _stressed = stressed;
    final window = _lastWindow;
    if (window != null) {
      update(
        groups: window.groups,
        groupIndex: window.groupIndex,
        itemIndex: window.itemIndex,
        resumeItemOf: window.resumeItemOf,
      );
    }
  }

  void _start(_Want want) {
    final key = want.media.cacheKey;
    final token = StoryFetchToken();
    _pending[key] = _Pending(token);
    requested++;
    unawaited(
      store
          .fetch(
            want.media,
            priority: want.priority,
            maxBytes: want.maxBytes,
            token: token,
            expiresAt: want.expiresAt,
          )
          .then(
            (_) {
              if (token.isCancelled) return;
              _pending.remove(key);
              _done.add(key);
              completed++;
            },
            onError: (Object _) {
              _pending.remove(key);
              failed++;
            },
          ),
    );
  }

  void _updatePins(Map<String, StoryMedia> pins) {
    for (final entry in _pinned.entries.toList()) {
      if (!pins.containsKey(entry.key)) {
        store.unpin(entry.value);
        _pinned.remove(entry.key);
      }
    }
    for (final entry in pins.entries) {
      if (!_pinned.containsKey(entry.key)) {
        store.pin(entry.value);
        _pinned[entry.key] = entry.value;
      }
    }
  }

  /// Cancels everything and releases every pin.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final pending in _pending.values) {
      pending.token.cancel();
      cancelled++;
    }
    _pending.clear();
    _updatePins(const {});
  }
}

final class _Want {
  _Want(this.media, this.priority, this.maxBytes, this.expiresAt);

  final StoryMedia media;
  final StoryFetchPriority priority;
  final int? maxBytes;
  final DateTime? expiresAt;
}

final class _Pending {
  _Pending(this.token);

  final StoryFetchToken token;
}

final class _Window {
  _Window(this.groups, this.groupIndex, this.itemIndex, this.resumeItemOf);

  final List<StoryGroup> groups;
  final int groupIndex;
  final int itemIndex;
  final int Function(int groupIndex) resumeItemOf;
}
