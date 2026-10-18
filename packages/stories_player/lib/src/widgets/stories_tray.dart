import 'package:flutter/material.dart';

import '../media/story_media_image.dart';
import '../media/story_media_store.dart';
import '../model/story_group.dart';
import '../model/story_item.dart';
import '../model/story_media.dart';
import '../model/story_position.dart';

/// How a [StoriesTray] draws its groups.
enum StoriesTrayLayout {
  /// Round avatars with a ring and the name under them, as on Instagram.
  circles,

  /// Tall 9:16-style cards that show a snapshot of the story, with the
  /// avatar in the corner and the name at the bottom, as on Facebook.
  cards,
}

/// Sizes and colors of [StoryCircle], [StoryCard] and [StoriesTray].
///
/// Every color left null follows the app's [ColorScheme]. The defaults
/// follow the big apps: 64 dp circles, and 112 × 200 dp cards with a
/// 36 dp avatar.
@immutable
class StoriesTrayStyle {
  /// Creates a style. All sizes are in logical pixels.
  const StoriesTrayStyle({
    this.circleSize = 64,
    this.cardSize = const Size(112, 200),
    this.cardRadius = 12,
    this.cardAvatarSize = 36,
    this.ringWidth = 2.5,
    this.ringGap = 2,
    this.ringColors,
    this.seenRingColor,
    this.ringGapColor,
    this.labelStyle,
    this.cardLabelStyle,
    this.placeholderColor,
  });

  /// The diameter of a [StoryCircle]'s avatar, ring excluded.
  final double circleSize;

  /// The size of a [StoryCard].
  final Size cardSize;

  /// The corner radius of a [StoryCard].
  final double cardRadius;

  /// The diameter of the avatar in a [StoryCard]'s corner, ring excluded.
  final double cardAvatarSize;

  /// The width of the ring around an avatar.
  final double ringWidth;

  /// The space between the ring and the avatar.
  final double ringGap;

  /// The ring of a group with stories not yet seen. One color draws a solid
  /// ring, several a sweep gradient. Defaults to [ColorScheme.primary].
  final List<Color>? ringColors;

  /// The ring of a group whose stories were all seen. Defaults to
  /// [ColorScheme.outlineVariant].
  final Color? seenRingColor;

  /// Fills [ringGap]. Defaults to [ColorScheme.surface].
  final Color? ringGapColor;

  /// The name under a [StoryCircle]. Defaults to
  /// [TextTheme.labelMedium].
  final TextStyle? labelStyle;

  /// The name on a [StoryCard]. Defaults to white, 13 sp, semibold.
  final TextStyle? cardLabelStyle;

  /// Painted while an image loads, or when a card has no snapshot. Defaults
  /// to [ColorScheme.surfaceContainerHighest].
  final Color? placeholderColor;

  /// The full width of a [StoryCircle]'s ring.
  double get circleOuterSize => circleSize + 2 * (ringWidth + ringGap);

  /// The full width of a [StoryCard]'s avatar ring.
  double get cardAvatarOuterSize => cardAvatarSize + 2 * (ringWidth + ringGap);
}

/// Whether every story of [group] was seen, by the same rule the player
/// uses to resume. False when [isSeen] is null.
bool _allSeen(StoryGroup group, StorySeenTester? isSeen) =>
    isSeen != null && group.items.every((item) => isSeen(group, item));

/// A horizontal row of story groups, drawn as circles or as cards.
///
/// [isSeen] is the same callback the player takes, so a group's ring turns
/// grey once all its stories were seen, and a card shows the story the
/// player will open on.
///
/// {@tool snippet}
/// ```dart
/// StoriesTray(
///   groups: groups,
///   layout: StoriesTrayLayout.cards,
///   isSeen: (group, item) => seen.contains(item.id),
///   onTap: (group) => openPlayer(group.id),
/// )
/// ```
/// {@end-tool}
class StoriesTray extends StatelessWidget {
  /// Creates a tray of [groups].
  const StoriesTray({
    super.key,
    required this.groups,
    required this.onTap,
    this.layout = StoriesTrayLayout.circles,
    this.isSeen,
    this.leading,
    this.style = const StoriesTrayStyle(),
    this.padding = const EdgeInsetsDirectional.symmetric(horizontal: 16),
    this.spacing,
    this.store,
  });

  /// The groups, in order.
  final List<StoryGroup> groups;

  /// Called when a group is tapped.
  final ValueChanged<StoryGroup> onTap;

  /// Circles or cards.
  final StoriesTrayLayout layout;

  /// Whether a story was seen. When null, every group shows as unseen.
  final StorySeenTester? isSeen;

  /// Shown before the first group, such as an "Add story" button. Give it
  /// the height of the tray: [StoriesTrayStyle.cardSize] for cards.
  final Widget? leading;

  /// Sizes and colors.
  final StoriesTrayStyle style;

  /// Space around the row.
  final EdgeInsetsGeometry padding;

  /// Space between items. Defaults to 8 for cards and 12 for circles.
  final double? spacing;

  /// Where images are cached. Defaults to [StoryMediaStore.instance].
  final StoryMediaStore? store;

  @override
  Widget build(BuildContext context) {
    final cards = layout == StoriesTrayLayout.cards;
    final leading = this.leading;
    final offset = leading == null ? 0 : 1;
    final height = cards
        ? style.cardSize.height
        : _StoryCircleLabel.heightFor(context, style);
    return SizedBox(
      height: height + padding.vertical,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: groups.length + offset,
        separatorBuilder: (context, index) =>
            SizedBox(width: spacing ?? (cards ? 8 : 12)),
        itemBuilder: (context, index) {
          if (leading != null && index == 0) return leading;
          final group = groups[index - offset];
          final seen = _allSeen(group, isSeen);
          return cards
              ? StoryCard(
                  group: group,
                  seen: seen,
                  cover: StoryCard.coverOf(group, isSeen: isSeen),
                  onTap: () => onTap(group),
                  style: style,
                  store: store,
                )
              : StoryCircle(
                  group: group,
                  seen: seen,
                  onTap: () => onTap(group),
                  style: style,
                  store: store,
                );
        },
      ),
    );
  }
}

/// A group as a round avatar with a ring, and its name underneath.
class StoryCircle extends StatelessWidget {
  /// Creates a circle for [group].
  const StoryCircle({
    super.key,
    required this.group,
    this.seen = false,
    this.onTap,
    this.style = const StoriesTrayStyle(),
    this.store,
  });

  /// The group shown.
  final StoryGroup group;

  /// Whether all of the group's stories were seen; greys the ring.
  final bool seen;

  /// Called when tapped.
  final VoidCallback? onTap;

  /// Sizes and colors.
  final StoriesTrayStyle style;

  /// Where images are cached. Defaults to [StoryMediaStore.instance].
  final StoryMediaStore? store;

  @override
  Widget build(BuildContext context) {
    final outer = style.circleOuterSize;
    final label = group.label;
    return Semantics(
      button: true,
      label: group.semanticLabel ?? label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: outer + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _StoryRing(
                style: style,
                seen: seen,
                avatarSize: style.circleSize,
                child: _Avatar(group: group, style: style, store: store),
              ),
              if (label != null) ...[
                const SizedBox(height: _StoryCircleLabel.gap),
                _StoryCircleLabel(label: label, seen: seen, style: style),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryCircleLabel extends StatelessWidget {
  const _StoryCircleLabel({
    required this.label,
    required this.seen,
    required this.style,
  });

  static const gap = 6.0;
  static const _lineHeight = 1.3;

  final String label;
  final bool seen;
  final StoriesTrayStyle style;

  static TextStyle _baseStyle(BuildContext context, StoriesTrayStyle style) =>
      (style.labelStyle ?? Theme.of(context).textTheme.labelMedium)!.copyWith(
        height: _lineHeight,
      );

  /// The height of a circle with its one-line label, at the current text
  /// scale, so the tray never clips the name.
  static double heightFor(BuildContext context, StoriesTrayStyle style) {
    final fontSize = _baseStyle(context, style).fontSize ?? 12;
    final text = MediaQuery.textScalerOf(context).scale(fontSize) * _lineHeight;
    return style.circleOuterSize + gap + text.ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = _baseStyle(context, style);
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: base.copyWith(
        fontWeight: seen ? FontWeight.w400 : FontWeight.w600,
        color: seen
            ? scheme.onSurfaceVariant
            : (base.color ?? scheme.onSurface),
      ),
    );
  }
}

/// A group as a tall card with a snapshot of its story, the avatar in the
/// top corner and the name at the bottom, as on Facebook.
///
/// The snapshot is [cover]; use [StoryCard.coverOf] to pick the one the
/// player will open on. Without one, the card shows the item's
/// placeholder color.
class StoryCard extends StatelessWidget {
  /// Creates a card for [group].
  const StoryCard({
    super.key,
    required this.group,
    this.cover,
    this.seen = false,
    this.onTap,
    this.style = const StoriesTrayStyle(),
    this.store,
  });

  /// The group shown.
  final StoryGroup group;

  /// The snapshot filling the card.
  final StoryMedia? cover;

  /// Whether all of the group's stories were seen; greys the avatar ring.
  final bool seen;

  /// Called when tapped.
  final VoidCallback? onTap;

  /// Sizes and colors.
  final StoriesTrayStyle style;

  /// Where images are cached. Defaults to [StoryMediaStore.instance].
  final StoryMediaStore? store;

  /// The snapshot for [group]'s card: [StoryGroup.cover] if set, otherwise
  /// the poster or image of the first story not yet seen, which is where
  /// the player opens. Falls back to the first item that has one.
  static StoryMedia? coverOf(StoryGroup group, {StorySeenTester? isSeen}) {
    final cover = group.cover;
    if (cover != null) return cover;
    final items = group.items;
    final unseen = isSeen == null
        ? 0
        : items.indexWhere((item) => !isSeen(group, item));
    final start = unseen < 0 ? 0 : unseen;
    for (var i = 0; i < items.length; i++) {
      final snapshot = _snapshotOf(items[(start + i) % items.length]);
      if (snapshot != null) return snapshot;
    }
    return null;
  }

  static StoryMedia? _snapshotOf(StoryItem item) =>
      item.poster ?? (item is ImageStoryItem ? item.image : null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = style.cardSize;
    final radius = BorderRadius.circular(style.cardRadius);
    final placeholder =
        group.items.first.placeholderColor ??
        style.placeholderColor ??
        scheme.surfaceContainerHighest;
    final cover = this.cover;
    final label = group.label;
    const inset = 8.0;
    return Semantics(
      button: true,
      label: group.semanticLabel ?? label,
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover == null)
                ColoredBox(color: placeholder)
              else
                StoryMediaImage(
                  cover,
                  store: store,
                  width: size.width,
                  height: size.height,
                  color: placeholder,
                  priority: StoryFetchPriority.background,
                ),
              // Keeps the white name readable over any snapshot.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, 0.22, 0.55, 1],
                    colors: [
                      Color(0x33000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x99000000),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                top: inset,
                start: inset,
                child: _StoryRing(
                  style: style,
                  seen: seen,
                  avatarSize: style.cardAvatarSize,
                  child: _Avatar(group: group, style: style, store: store),
                ),
              ),
              if (label != null)
                PositionedDirectional(
                  start: inset,
                  end: inset,
                  bottom: inset,
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        style.cardLabelStyle ??
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Color(0x66000000), blurRadius: 4),
                          ],
                        ),
                  ),
                ),
              Material(
                type: MaterialType.transparency,
                child: InkWell(onTap: onTap, borderRadius: radius),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The ring around an avatar: colored while there are stories to see, grey
/// once they were all seen.
class _StoryRing extends StatelessWidget {
  const _StoryRing({
    required this.style,
    required this.seen,
    required this.avatarSize,
    required this.child,
  });

  final StoriesTrayStyle style;
  final bool seen;
  final double avatarSize;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = style.ringColors ?? [scheme.primary];
    return Container(
      padding: EdgeInsets.all(style.ringWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: seen
            ? style.seenRingColor ?? scheme.outlineVariant
            : colors.length == 1
            ? colors.single
            : null,
        gradient: seen || colors.length == 1
            ? null
            : SweepGradient(colors: [...colors, colors.first]),
      ),
      child: Container(
        padding: EdgeInsets.all(style.ringGap),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: style.ringGapColor ?? scheme.surface,
        ),
        child: SizedBox.square(dimension: avatarSize, child: child),
      ),
    );
  }
}

/// The group's avatar, or its initial when it has none.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.group, required this.style, this.store});

  final StoryGroup group;
  final StoriesTrayStyle style;
  final StoryMediaStore? store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final avatar = group.avatar;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.shortestSide;
        if (avatar != null) {
          return ClipOval(
            child: StoryMediaImage(
              avatar,
              store: store,
              width: size,
              height: size,
              color: style.placeholderColor ?? scheme.surfaceContainerHighest,
              priority: StoryFetchPriority.background,
            ),
          );
        }
        final label = group.label?.trim() ?? '';
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: scheme.primaryContainer,
          ),
          child: Center(
            child: Text(
              label.isEmpty ? '' : label.characters.first.toUpperCase(),
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}
