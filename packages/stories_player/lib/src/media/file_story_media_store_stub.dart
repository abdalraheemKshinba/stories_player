import 'story_media_store.dart';

/// A disk cache for story media, bounded in bytes.
///
/// On the web there is no file system, so this store keeps nothing and
/// every load goes to the network, where the browser's HTTP cache applies.
/// See the documentation of the platforms with a file system for details.
final class FileStoryMediaStore extends StoryMediaStore {
  /// Creates a store. On the web it keeps nothing.
  FileStoryMediaStore({
    this.maxBytes = 100 * 1024 * 1024,
    this.maxAge = const Duration(days: 2),
    this.maxConcurrentDownloads = 2,
    String? directory,
  });

  /// The most bytes the store keeps on disk.
  final int maxBytes;

  /// How long unused media is kept.
  final Duration maxAge;

  /// How many downloads run at the same time.
  final int maxConcurrentDownloads;
}
