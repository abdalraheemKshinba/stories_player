import 'package:flutter/foundation.dart';

/// What a [StoryMedia] contains.
///
/// The kind lets the prefetcher budget bytes per media type and lets the
/// media store pick a file extension when the URL has none.
enum StoryMediaKind {
  /// A still image: JPEG, PNG, WebP, GIF.
  image,

  /// A video file, ideally a faststart MP4.
  video,

  /// A Lottie JSON animation.
  lottie,

  /// An audio track, such as the music behind an image item.
  audio,

  /// Anything else a custom item needs fetched.
  other,
}

/// Where a [StoryMedia] is loaded from.
enum StoryMediaSource {
  /// Downloaded over HTTP(S), cached by the [StoryMediaStore].
  network,

  /// Bundled with the app as a Flutter asset.
  asset,

  /// Already on the device's file system.
  file,
}

/// A reference to one piece of media a story item needs: an image, a video,
/// a Lottie file or an audio track.
///
/// Media is a value: two instances with the same source, location and kind
/// are equal. Network media is cached by its [uri], so republishing content
/// should use a new URL rather than new bytes behind the same URL.
///
/// {@tool snippet}
/// ```dart
/// final photo = StoryMedia.network(
///   Uri.parse('https://cdn.example.com/stories/1080/deal.webp'),
///   bytes: 184320,
///   width: 1080,
///   height: 1920,
/// );
/// final bundled = StoryMedia.asset('assets/stories/intro.webp');
/// ```
/// {@end-tool}
@immutable
final class StoryMedia {
  /// Media downloaded from [uri] and cached on the device.
  ///
  /// Set [bytes] when the size is known: the prefetcher then budgets data on
  /// slow networks without a `HEAD` request. [prefixBytes] is the number of
  /// bytes covering the first second of a video, so a prefetcher can fetch
  /// only the start of the file. [lowQuality] is an optional smaller
  /// rendition used on slow networks.
  const StoryMedia.network(
    Uri this.uri, {
    this.kind = StoryMediaKind.image,
    this.bytes,
    this.width,
    this.height,
    this.prefixBytes,
    this.lowQuality,
    this.headers = const <String, String>{},
    this.extension,
  }) : source = StoryMediaSource.network,
       assetName = null,
       package = null,
       filePath = null;

  /// Media bundled with the app under [assetName], optionally from [package].
  const StoryMedia.asset(
    String this.assetName, {
    this.package,
    this.kind = StoryMediaKind.image,
    this.width,
    this.height,
  }) : source = StoryMediaSource.asset,
       uri = null,
       filePath = null,
       bytes = null,
       prefixBytes = null,
       lowQuality = null,
       headers = const <String, String>{},
       extension = null;

  /// Media already on the device at [filePath]. Not available on the web.
  const StoryMedia.file(
    String this.filePath, {
    this.kind = StoryMediaKind.image,
    this.width,
    this.height,
  }) : source = StoryMediaSource.file,
       uri = null,
       assetName = null,
       package = null,
       bytes = null,
       prefixBytes = null,
       lowQuality = null,
       headers = const <String, String>{},
       extension = null;

  /// Where this media is loaded from.
  final StoryMediaSource source;

  /// The URL of network media; `null` for other sources.
  final Uri? uri;

  /// The asset key of bundled media; `null` for other sources.
  final String? assetName;

  /// The package that bundles [assetName], if not the app itself.
  final String? package;

  /// The path of on-device media; `null` for other sources.
  final String? filePath;

  /// What this media contains.
  final StoryMediaKind kind;

  /// The size of the file in bytes, if known.
  final int? bytes;

  /// The pixel width, if known. Lets the player reserve space and decode
  /// images at the size they are shown.
  final int? width;

  /// The pixel height, if known.
  final int? height;

  /// The bytes covering the first second of a video, if known.
  final int? prefixBytes;

  /// A smaller rendition of the same content for slow networks.
  final StoryMedia? lowQuality;

  /// HTTP headers sent with network requests for this media.
  final Map<String, String> headers;

  /// The file extension to store this media under, such as `mp4`.
  ///
  /// When `null`, the extension is taken from the URL path or derived from
  /// [kind]. Some platform players refuse to open a cached file that lacks
  /// the right extension.
  final String? extension;

  /// Whether this media is downloaded over the network.
  bool get isNetwork => source == StoryMediaSource.network;

  /// The key the media store caches this media under.
  ///
  /// Network media is keyed by URL; other sources are never cached.
  String get cacheKey => switch (source) {
    StoryMediaSource.network => uri.toString(),
    StoryMediaSource.asset => 'asset:${package ?? ''}/$assetName',
    StoryMediaSource.file => 'file:$filePath',
  };

  /// Returns the media to load for the given network quality.
  ///
  /// Returns [lowQuality] when [preferLowQuality] is true and a low
  /// rendition exists, and this media otherwise.
  StoryMedia resolve({required bool preferLowQuality}) =>
      preferLowQuality && lowQuality != null ? lowQuality! : this;

  @override
  bool operator ==(Object other) =>
      other is StoryMedia &&
      other.source == source &&
      other.kind == kind &&
      other.cacheKey == cacheKey;

  @override
  int get hashCode => Object.hash(source, kind, cacheKey);

  @override
  String toString() => 'StoryMedia.${source.name}(${kind.name}, $cacheKey)';
}
