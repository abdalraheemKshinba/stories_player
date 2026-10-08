import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../controller/stories_controller.dart';
import '../media/story_media_image.dart';
import '../media/story_media_store.dart';
import '../model/story_group.dart';
import '../model/story_item.dart';
import '../theme/stories_labels.dart';
import '../theme/stories_theme.dart';

/// What the header, footer, progress and loading builders receive.
@immutable
final class StoryOverlayDetails {
  /// Creates details. Built by the player.
  const StoryOverlayDetails({
    required this.group,
    required this.item,
    required this.groupIndex,
    required this.itemIndex,
    required this.progress,
    required this.isCurrent,
    required this.isMuted,
    required this.labels,
    required this.store,
    required this.controller,
    required this.close,
    required this.toggleMuted,
  });

  /// The group on this page.
  final StoryGroup group;

  /// The item on this page.
  final StoryItem item;

  /// The index of [group].
  final int groupIndex;

  /// The index of [item] within [group].
  final int itemIndex;

  /// The item's progress from 0 to 1. Always 0 on pages that are not
  /// current, such as the neighbour revealed during a swipe.
  final ValueListenable<double> progress;

  /// Whether this page is the one playing.
  final bool isCurrent;

  /// Whether sound is off.
  final bool isMuted;

  /// The player's labels.
  final StoriesLabels labels;

  /// The player's media store, for showing avatars and other media.
  final StoryMediaStore store;

  /// The player's controller.
  final StoriesController controller;

  /// Asks to close the player, as the default close button does.
  final VoidCallback close;

  /// Turns sound on or off, as the default mute button does.
  final VoidCallback toggleMuted;
}

/// What the error builder receives.
@immutable
final class StoryErrorDetails {
  /// Creates details. Built by the player.
  const StoryErrorDetails({
    required this.overlay,
    required this.error,
    required this.retry,
    required this.skip,
    this.isRetrying = false,
    this.failures = 1,
  });

  /// The same details the other builders receive.
  final StoryOverlayDetails overlay;

  /// What went wrong.
  final Object error;

  /// Loads the item again.
  final VoidCallback retry;

  /// Moves on to the next item.
  final VoidCallback skip;

  /// Whether a retry the user asked for is loading. Show progress, and do
  /// not accept another tap.
  final bool isRetrying;

  /// How many times the item has failed in front of the user: 1 the first
  /// time, more after failed retries.
  final int failures;
}

/// Builds the header, footer, progress bar or loading indicator.
typedef StoryOverlayBuilder =
    Widget Function(BuildContext context, StoryOverlayDetails details);

/// Builds what a failed item shows.
typedef StoryErrorBuilder =
    Widget Function(BuildContext context, StoryErrorDetails details);

/// The segmented progress bar at the top of a story: one segment per item,
/// filled in reading order, right to left in right-to-left locales.
///
/// Repaints only itself as [progress] changes, never the media below it.
class StoryProgressBar extends StatelessWidget {
  /// Creates a progress bar for [count] items, at item [index].
  const StoryProgressBar({
    super.key,
    required this.count,
    required this.index,
    required this.progress,
    this.theme,
  });

  /// How many segments to draw.
  final int count;

  /// The segment being filled. Earlier segments are full.
  final int index;

  /// How full the current segment is, from 0 to 1.
  final ValueListenable<double> progress;

  /// Overrides the ambient [StoriesTheme].
  final StoriesThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final resolved = (theme ?? const StoriesThemeData()).merge(
      StoriesTheme.of(context),
    );
    return Padding(
      padding: resolved.progressPadding!,
      child: RepaintBoundary(
        child: SizedBox(
          height: resolved.progressHeight,
          width: double.infinity,
          child: CustomPaint(
            painter: _ProgressPainter(
              count: count,
              index: index,
              progress: progress,
              theme: resolved,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.count,
    required this.index,
    required this.progress,
    required this.theme,
    required this.textDirection,
  }) : super(repaint: progress);

  final int count;
  final int index;
  final ValueListenable<double> progress;
  final StoriesThemeData theme;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (count <= 0) return;
    final gap = theme.progressGap!;
    final segment = (size.width - gap * (count - 1)) / count;
    final radius = Radius.circular(theme.progressRadius!);
    final track = Paint()..color = theme.progressTrackColor!;
    final fill = Paint()..color = theme.progressFillColor!;
    final rtl = textDirection == TextDirection.rtl;
    for (var i = 0; i < count; i++) {
      final start = i * (segment + gap);
      final left = rtl ? size.width - start - segment : start;
      final rect = Rect.fromLTWH(left, 0, segment, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), track);
      final amount = i < index
          ? 1.0
          : i == index
          ? progress.value.clamp(0.0, 1.0)
          : 0.0;
      if (amount <= 0) continue;
      final filled = segment * amount;
      final fillRect = rtl
          ? Rect.fromLTWH(left + segment - filled, 0, filled, size.height)
          : Rect.fromLTWH(left, 0, filled, size.height);
      canvas.drawRRect(RRect.fromRectAndRadius(fillRect, radius), fill);
    }
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.count != count ||
      old.index != index ||
      old.progress != progress ||
      old.theme != theme ||
      old.textDirection != textDirection;
}

/// The default header: the group's avatar, label and subtitle, a mute
/// button when the item has sound, and a close button.
///
/// Use it inside your own header builder to add to it rather than
/// rebuild it.
class StoryHeader extends StatelessWidget {
  /// Creates the default header from [details].
  const StoryHeader({super.key, required this.details, this.trailing});

  /// What the player passed to the header builder.
  final StoryOverlayDetails details;

  /// Extra widgets shown before the mute and close buttons.
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = StoriesTheme.of(context);
    final group = details.group;
    final avatar = group.avatar;
    final size = theme.avatarSize!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 0),
      child: Row(
        children: [
          if (avatar != null) ...[
            ClipOval(
              child: StoryMediaImage(
                avatar,
                store: details.store,
                width: size,
                height: size,
                color: const Color(0x33FFFFFF),
                priority: StoryFetchPriority.background,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (group.label != null)
                    Text(
                      group.label!,
                      style: theme.titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (group.subtitle != null)
                    Text(
                      group.subtitle!,
                      style: theme.subtitleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          ...?trailing,
          if (details.item.hasAudio)
            IconButton(
              onPressed: details.toggleMuted,
              color: theme.iconColor,
              tooltip: details.isMuted
                  ? details.labels.unmute
                  : details.labels.mute,
              icon: Icon(
                details.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
              ),
            ),
          IconButton(
            onPressed: details.close,
            color: theme.iconColor,
            tooltip: details.labels.close,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// The default footer: the item's caption over a scrim, and optionally an
/// [action] under it, such as an order button.
///
/// One gradient sits behind both, so the action needs no box of its own.
///
/// {@tool snippet}
/// ```dart
/// StoriesPlayer(
///   groups: groups,
///   footerBuilder: (context, details) => StoryCaption(
///     details: details,
///     action: FilledButton(onPressed: order, child: const Text('Order now')),
///   ),
/// )
/// ```
/// {@end-tool}
class StoryCaption extends StatelessWidget {
  /// Creates the default footer from [details].
  const StoryCaption({super.key, required this.details, this.action});

  /// What the player passed to the footer builder.
  final StoryOverlayDetails details;

  /// Shown under the caption, full width.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final caption = details.item.caption;
    final hasCaption = caption != null && caption.isNotEmpty;
    final action = this.action;
    if (!hasCaption && action == null) return const SizedBox.shrink();
    final theme = StoriesTheme.of(context);
    // The gradient reaches the screen's bottom edge; the content stays above
    // the system navigation bar.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: theme.bottomScrim),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 56, 20, 24 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasCaption)
              Text(
                caption,
                style: theme.captionStyle,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            if (hasCaption && action != null) const SizedBox(height: 16),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// The default error view, over a dark overlay that keeps it readable on any
/// poster:
///
/// * A message and a **Retry** button.
/// * While retrying, the button shows progress and ignores taps, so the
///   user always sees that the tap did something.
/// * After a failed retry, the message says so and a **Skip** button joins
///   Retry.
class StoryErrorView extends StatelessWidget {
  /// Creates the default error view from [details].
  const StoryErrorView({super.key, required this.details});

  /// What the player passed to the error builder.
  final StoryErrorDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = StoriesTheme.of(context);
    final labels = details.overlay.labels;
    final color = theme.iconColor!;
    final retrying = details.isRetrying;
    final failedAgain = details.failures > 1;
    return ColoredBox(
      color: const Color(0xB3000000),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                retrying
                    ? Icons.sync_rounded
                    : failedAgain
                    ? Icons.cloud_off_rounded
                    : Icons.wifi_off_rounded,
                color: color,
                size: 44,
              ),
              const SizedBox(height: 14),
              Text(
                retrying
                    ? labels.retrying
                    : failedAgain
                    ? labels.stillFailing
                    : labels.loadFailed,
                style: theme.titleStyle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: retrying ? null : details.retry,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      disabledForegroundColor: color.withValues(alpha: 0.7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                      side: BorderSide(color: color.withValues(alpha: 0.7)),
                    ),
                    child: retrying
                        ? SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          )
                        : Text(labels.retry),
                  ),
                  if (failedAgain && !retrying)
                    TextButton(
                      onPressed: details.skip,
                      style: TextButton.styleFrom(
                        foregroundColor: color,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      child: Text(labels.skip),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
