import 'package:flutter/foundation.dart';

import 'story_group.dart';
import 'story_item.dart';

/// Decides whether an item has already been watched.
///
/// The player never stores seen state; the app does. This callback lets
/// [StoryPosition.group] and [StoryPosition.firstUnseen] resume at the first
/// item the user has not seen yet.
typedef StorySeenTester = bool Function(StoryGroup group, StoryItem item);

/// A place in a list of story groups, used to open the player and to jump.
///
/// Positions are resolved against the groups when they are used, so they
/// can refer to groups and items by id.
///
/// {@tool snippet}
/// ```dart
/// // Open the tapped group at its first unwatched item.
/// StoriesPlayer(
///   groups: groups,
///   initialPosition: StoryPosition.group('burger-barn'),
///   isSeen: (group, item) => watched.contains(item.id),
/// )
/// ```
/// {@end-tool}
@immutable
final class StoryPosition {
  /// The item at [groupIndex] and [itemIndex].
  const StoryPosition(this.groupIndex, this.itemIndex)
    : groupId = null,
      itemId = null,
      _kind = _PositionKind.indexed;

  /// The group with [groupId], at its first unseen item, or its first item
  /// if every item has been seen or no seen tester is given.
  const StoryPosition.group(String this.groupId)
    : itemId = null,
      groupIndex = null,
      itemIndex = null,
      _kind = _PositionKind.group;

  /// The item with [itemId] inside the group with [groupId].
  const StoryPosition.item(String this.groupId, String this.itemId)
    : groupIndex = null,
      itemIndex = null,
      _kind = _PositionKind.item;

  /// The first item, of any group, that has not been seen.
  static const StoryPosition firstUnseen = StoryPosition._firstUnseen();

  /// The first item of the first group.
  static const StoryPosition start = StoryPosition(0, 0);

  const StoryPosition._firstUnseen()
    : groupId = null,
      itemId = null,
      groupIndex = null,
      itemIndex = null,
      _kind = _PositionKind.firstUnseen;

  /// The group index, for index-based positions.
  final int? groupIndex;

  /// The item index, for index-based positions.
  final int? itemIndex;

  /// The group id, for id-based positions.
  final String? groupId;

  /// The item id, for item positions.
  final String? itemId;

  final _PositionKind _kind;

  /// Resolves this position against [groups] into concrete indexes.
  ///
  /// Unknown ids and out-of-range indexes resolve to the closest valid
  /// position, never to an error, because a deep link to an expired story
  /// should still open the player.
  ({int group, int item}) resolve(
    List<StoryGroup> groups, {
    StorySeenTester? isSeen,
  }) {
    assert(groups.isNotEmpty, 'Cannot resolve a position in no groups.');
    int firstUnseenIn(StoryGroup group) {
      if (isSeen == null) return 0;
      final index = group.items.indexWhere((item) => !isSeen(group, item));
      return index < 0 ? 0 : index;
    }

    switch (_kind) {
      case _PositionKind.indexed:
        final g = groupIndex!.clamp(0, groups.length - 1);
        return (
          group: g,
          item: itemIndex!.clamp(0, groups[g].items.length - 1),
        );
      case _PositionKind.group:
      case _PositionKind.item:
        final g = groups.indexWhere((group) => group.id == groupId);
        if (g < 0) return (group: 0, item: firstUnseenIn(groups.first));
        if (_kind == _PositionKind.item) {
          final i = groups[g].indexOfItem(itemId!);
          if (i >= 0) return (group: g, item: i);
        }
        return (group: g, item: firstUnseenIn(groups[g]));
      case _PositionKind.firstUnseen:
        if (isSeen != null) {
          for (var g = 0; g < groups.length; g++) {
            for (var i = 0; i < groups[g].items.length; i++) {
              if (!isSeen(groups[g], groups[g].items[i])) {
                return (group: g, item: i);
              }
            }
          }
        }
        return (group: 0, item: 0);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is StoryPosition &&
      other._kind == _kind &&
      other.groupIndex == groupIndex &&
      other.itemIndex == itemIndex &&
      other.groupId == groupId &&
      other.itemId == itemId;

  @override
  int get hashCode =>
      Object.hash(_kind, groupIndex, itemIndex, groupId, itemId);

  @override
  String toString() => switch (_kind) {
    _PositionKind.indexed => 'StoryPosition($groupIndex, $itemIndex)',
    _PositionKind.group => 'StoryPosition.group($groupId)',
    _PositionKind.item => 'StoryPosition.item($groupId, $itemId)',
    _PositionKind.firstUnseen => 'StoryPosition.firstUnseen',
  };
}

enum _PositionKind { indexed, group, item, firstUnseen }
