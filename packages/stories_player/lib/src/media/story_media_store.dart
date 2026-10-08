import 'dart:async';

import 'package:flutter/foundation.dart';

import '../model/story_media.dart';
import 'default_store_stub.dart'
    if (dart.library.io) 'default_store_io.dart'
    as platform;

/// How urgently a download is needed. Lower values win.
///
/// A [visible] request pauses every less urgent download in progress, so
/// the item on screen always gets the bandwidth. Paused downloads keep
/// what they already fetched and resume later.
enum StoryFetchPriority {
  /// The media of the item on screen.
  visible,

  /// The item the user will see next.
  next,

  /// Items further ahead.
  ahead,

  /// Posters and avatars that are nice to have.
  background,
}

/// Cancels a [StoryMediaStore.fetch] request.
///
/// Cancelling a token does not throw from the fetch future; it completes
/// with `null`. Bytes already downloaded stay on disk.
final class StoryFetchToken {
  /// Creates an uncancelled token.
  StoryFetchToken();

  bool _isCancelled = false;
  final List<VoidCallback> _listeners = [];

  /// Whether [cancel] was called.
  bool get isCancelled => _isCancelled;

  /// Cancels the request. Calling it more than once is harmless.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List.of(_listeners)) {
      listener();
    }
    _listeners.clear();
  }

  /// Calls [listener] when the token is cancelled. For store
  /// implementations.
  void addListener(VoidCallback listener) {
    if (_isCancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  /// Stops calling [listener]. For store implementations.
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}

/// Thrown by [StoryMediaStore.fetch] when a download fails.
final class StoryMediaException implements Exception {
  /// Creates an exception for [media].
  const StoryMediaException(this.media, this.message, {this.statusCode});

  /// The media that failed.
  final StoryMedia media;

  /// What went wrong.
  final String message;

  /// The HTTP status code, if the server answered.
  final int? statusCode;

  @override
  String toString() =>
      'StoryMediaException(${media.cacheKey}: $message'
      '${statusCode == null ? '' : ', HTTP $statusCode'})';
}

/// How much space a [StoryMediaStore] uses.
@immutable
final class StoryMediaStoreUsage {
  /// Creates a usage report.
  const StoryMediaStoreUsage({required this.bytes, required this.entries});

  /// Bytes on disk, including partly downloaded files.
  final int bytes;

  /// Files on disk.
  final int entries;

  @override
  String toString() => 'StoryMediaStoreUsage($bytes bytes, $entries entries)';
}

/// Downloads story media and keeps it on the device within a size limit.
///
/// The player asks the store for the media of the item on screen and the
/// prefetcher asks it for media ahead. A store decides where the bytes
/// live and when they are deleted.
///
/// Implementations extend this class rather than implement it, so that
/// methods added in future versions arrive with working defaults.
///
/// See also:
///
///  * [FileStoryMediaStore], the default on Android, iOS and desktop: a
///    byte-bounded, least-recently-used disk cache with expiry.
///  * [NoopStoryMediaStore], the default on the web, where the browser's
///    HTTP cache does this job.
abstract base class StoryMediaStore {
  /// Constructor for subclasses.
  StoryMediaStore();

  static StoryMediaStore? _instance;

  /// The store used by players that are not given one.
  ///
  /// Created on first use: a [FileStoryMediaStore] with default limits on
  /// platforms with a file system, and a [NoopStoryMediaStore] on the web.
  /// Assign a different store at startup to change the default for every
  /// player.
  static StoryMediaStore get instance =>
      _instance ??= platform.createDefaultStore();

  static set instance(StoryMediaStore store) => _instance = store;

  /// Whether this store keeps files on the device.
  ///
  /// When false, players load network media straight from its URL.
  bool get supportsFiles => false;

  /// Returns the path of [media]'s complete file if it is already stored,
  /// without any I/O. Returns `null` otherwise.
  String? lookup(StoryMedia media) => null;

  /// Downloads [media] and returns the path of the complete file.
  ///
  /// When [maxBytes] is set, only the first [maxBytes] bytes are fetched
  /// and the future completes with `null`: a partial file is useful to a
  /// later full fetch, not to a player.
  ///
  /// Completes with `null` when [token] is cancelled or when the store
  /// keeps no files. Throws a [StoryMediaException] when the download
  /// fails.
  ///
  /// [expiresAt] tells the store when the media stops being needed.
  Future<String?> fetch(
    StoryMedia media, {
    StoryFetchPriority priority = StoryFetchPriority.visible,
    int? maxBytes,
    StoryFetchToken? token,
    DateTime? expiresAt,
  }) async => null;

  /// Protects [media] from eviction until a matching [unpin].
  ///
  /// Pins are counted: two pins need two unpins.
  void pin(StoryMedia media) {}

  /// Releases a [pin].
  void unpin(StoryMedia media) {}

  /// Deletes media whose `expiresAt` has passed or that has not been used
  /// for longer than the store's maximum age.
  Future<void> purgeExpired() async {}

  /// Deletes [media] from the device.
  Future<void> evict(StoryMedia media) async {}

  /// Deletes everything this store saved.
  Future<void> clear() async {}

  /// Reports how much space the store uses.
  Future<StoryMediaStoreUsage> usage() async =>
      const StoryMediaStoreUsage(bytes: 0, entries: 0);

  /// The measured download speed in bits per second, or `null` before the
  /// first download. Used by [StoryNetworkSignal.measured].
  double? get estimatedBitsPerSecond => null;

  /// Releases resources. The shared [instance] is never disposed.
  Future<void> dispose() async {}
}

/// A store that keeps nothing: every load goes to the network.
///
/// The default on the web, where the browser caches HTTP responses.
final class NoopStoryMediaStore extends StoryMediaStore {
  /// Creates a store that keeps nothing.
  NoopStoryMediaStore();
}
