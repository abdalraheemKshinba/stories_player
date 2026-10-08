import 'package:flutter/foundation.dart';

import 'story_item.dart';
import 'story_media.dart';

/// The stories of one source, played one after another: a person, a shop,
/// a campaign. Groups are what a stories tray shows as circles.
///
/// {@tool snippet}
/// ```dart
/// StoryGroup(
///   id: 'burger-barn',
///   label: 'Burger Barn',
///   avatar: StoryMedia.network(Uri.parse('https://cdn.example.com/a.webp')),
///   items: [
///     ImageStoryItem(id: 'deal', image: StoryMedia.asset('assets/deal.webp')),
///   ],
/// )
/// ```
/// {@end-tool}
@immutable
final class StoryGroup {
  /// Creates a group of [items]. [items] must not be empty, and item ids
  /// must be unique within the group.
  StoryGroup({
    required this.id,
    required List<StoryItem> items,
    this.label,
    this.subtitle,
    this.avatar,
    this.semanticLabel,
    this.expiresAt,
  }) : assert(items.isNotEmpty, 'StoryGroup "$id" has no items.'),
       assert(
         items.map((item) => item.id).toSet().length == items.length,
         'StoryGroup "$id" has duplicate item ids.',
       ),
       items = List.unmodifiable(items);

  /// Identifies this group among all groups passed to the player.
  final String id;

  /// The items, in play order.
  final List<StoryItem> items;

  /// The name shown in the default header, such as the shop's name.
  final String? label;

  /// Secondary text shown under [label], such as "2h ago".
  final String? subtitle;

  /// The image shown in the default header.
  final StoryMedia? avatar;

  /// Read by screen readers instead of [label].
  final String? semanticLabel;

  /// When the whole group stops being relevant. Its cached media is deleted
  /// after this time.
  final DateTime? expiresAt;

  /// Returns the index of the item with [itemId], or -1.
  int indexOfItem(String itemId) =>
      items.indexWhere((item) => item.id == itemId);

  @override
  String toString() => 'StoryGroup($id, ${items.length} items)';
}
