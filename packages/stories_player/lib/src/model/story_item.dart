import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'story_media.dart';

/// One screen of a story: an image, a video, an animation, or anything a
/// custom [StoryItemDelegate] can show.
///
/// [StoryItem] is a base class, not a sealed one: new item types can be
/// added by this package or by your app without breaking existing code.
/// Each item type is shown by the first delegate in
/// [StoriesPlayer.delegates] whose `canHandle` returns true.
///
/// Items are immutable and identified by [id], which must be unique within
/// its [StoryGroup].
///
/// See also:
///
///  * [ImageStoryItem], a photo with an optional music track.
///  * [WidgetStoryItem], any widget shown for a fixed duration.
///  * `VideoStoryItem` in `package:stories_player_video`.
///  * `LottieStoryItem` in `package:stories_player_lottie`.
@immutable
abstract base class StoryItem {
  /// Creates a story item. Subclasses add the media they show.
  const StoryItem({
    required this.id,
    this.duration,
    this.poster,
    this.placeholderColor,
    this.caption,
    this.semanticLabel,
    this.expiresAt,
  });

  /// Identifies this item within its group. Used in events and positions.
  final String id;

  /// How long the item stays on screen.
  ///
  /// When `null`, the media decides: a video's own length, a Lottie
  /// composition's length, or [StoriesPlaybackConfig.imageDuration] for
  /// still images.
  final Duration? duration;

  /// A still painted instantly, under the real media, while it loads.
  ///
  /// For a video, a real frame; for an animation, its first frame. Posters
  /// are always prefetched, whatever the network.
  final StoryMedia? poster;

  /// The colour painted on the very first frame, before even the poster.
  /// Usually the media's dominant colour.
  final Color? placeholderColor;

  /// Text shown at the bottom of the default footer.
  final String? caption;

  /// Read by screen readers instead of [caption].
  final String? semanticLabel;

  /// When this item stops being relevant. The media store deletes the
  /// item's cached media after this time.
  final DateTime? expiresAt;

  /// Every media this item may need, in the order it should be fetched.
  ///
  /// Used by the prefetcher and by the media store's expiry purge. Do not
  /// include the [poster]; it is fetched separately.
  Iterable<StoryMedia> get media;

  /// Whether this item can play sound, which shows the mute toggle.
  bool get hasAudio => false;

  /// Whether this item has expired at [now].
  bool isExpiredAt(DateTime now) =>
      expiresAt != null && !now.isBefore(expiresAt!);

  @override
  String toString() => '${objectRuntimeType(this, 'StoryItem')}($id)';
}

/// How long a slide with a music track stays on screen.
enum StoryAudioDuration {
  /// The item's own duration; the track is cut or looped to fit.
  item,

  /// The length of the track.
  track,

  /// Whichever of the two is shorter.
  shorter,
}

/// A music track played behind an image or animation item.
@immutable
final class StoryAudio {
  /// Creates a music track from [media].
  const StoryAudio(
    this.media, {
    this.loop = true,
    this.length,
    this.itemDuration = StoryAudioDuration.item,
  });

  /// The audio file.
  final StoryMedia media;

  /// Whether the track repeats until the item ends.
  final bool loop;

  /// The length of the track, if known. Needed by
  /// [StoryAudioDuration.track] and [StoryAudioDuration.shorter].
  final Duration? length;

  /// Whether the item or the track decides how long the item lasts.
  final StoryAudioDuration itemDuration;
}

/// A still image, optionally with a music track.
///
/// {@tool snippet}
/// ```dart
/// ImageStoryItem(
///   id: 'deal-1',
///   image: StoryMedia.network(Uri.parse('https://cdn.example.com/deal.webp')),
///   caption: '2-for-1 on all burgers this weekend',
///   duration: const Duration(seconds: 6),
/// )
/// ```
/// {@end-tool}
final class ImageStoryItem extends StoryItem {
  /// Creates an image item.
  const ImageStoryItem({
    required super.id,
    required this.image,
    this.audio,
    this.fit = BoxFit.cover,
    super.duration,
    super.poster,
    super.placeholderColor,
    super.caption,
    super.semanticLabel,
    super.expiresAt,
  });

  /// The image to show.
  final StoryMedia image;

  /// Music played while the image is shown.
  final StoryAudio? audio;

  /// How the image is inscribed into the screen.
  final BoxFit fit;

  @override
  Iterable<StoryMedia> get media => [image, if (audio != null) audio!.media];

  @override
  bool get hasAudio => audio != null;
}

/// Builds the content of a [WidgetStoryItem].
///
/// [progress] runs from 0 to 1 over the item's duration and can drive
/// animations that stay in sync with the progress bar.
typedef StoryWidgetBuilder =
    Widget Function(BuildContext context, Animation<double> progress);

/// Any widget, shown for a fixed duration: a text story, a promo card, a
/// poll the app renders itself.
///
/// {@tool snippet}
/// ```dart
/// WidgetStoryItem(
///   id: 'hello',
///   duration: const Duration(seconds: 4),
///   builder: (context, progress) => const ColoredBox(
///     color: Colors.indigo,
///     child: Center(child: Text('Hello!')),
///   ),
/// )
/// ```
/// {@end-tool}
final class WidgetStoryItem extends StoryItem {
  /// Creates an item that shows [builder]'s widget for [duration].
  const WidgetStoryItem({
    required super.id,
    required Duration super.duration,
    required this.builder,
    super.placeholderColor,
    super.caption,
    super.semanticLabel,
    super.expiresAt,
  });

  /// Builds the widget to show.
  final StoryWidgetBuilder builder;

  @override
  Iterable<StoryMedia> get media => const [];
}
