import 'package:meta/meta.dart';

import '../controller/stories_config.dart';
import '../model/story_group.dart';
import '../model/story_item.dart';
import '../model/story_position.dart';

/// Where a navigation command leads.
@internal
sealed class StoryStep {
  const StoryStep();
}

/// Show the item at [group], [item] now.
@internal
final class StoryStepItem extends StoryStep {
  /// Creates the step.
  const StoryStepItem(this.group, this.item);

  /// The group index.
  final int group;

  /// The item index.
  final int item;

  @override
  bool operator ==(Object other) =>
      other is StoryStepItem && other.group == group && other.item == item;

  @override
  int get hashCode => Object.hash(group, item);

  @override
  String toString() => 'StoryStepItem($group, $item)';
}

/// Move the pages to [group]; it opens at its resume item.
@internal
final class StoryStepGroup extends StoryStep {
  /// Creates the step.
  const StoryStepGroup(this.group, {this.animate});

  /// The group index.
  final int group;

  /// Whether to animate, or `null` for the player's default.
  final bool? animate;

  @override
  bool operator ==(Object other) =>
      other is StoryStepGroup &&
      other.group == group &&
      other.animate == animate;

  @override
  int get hashCode => Object.hash(group, animate);

  @override
  String toString() => 'StoryStepGroup($group)';
}

/// The stories are over: ask to close. [finishedAll] when the user reached
/// the end of the last group, which also completes the session.
@internal
final class StoryStepEnd extends StoryStep {
  /// Creates the step.
  const StoryStepEnd({required this.finishedAll});

  /// Whether every group was played to its end.
  final bool finishedAll;

  @override
  bool operator ==(Object other) =>
      other is StoryStepEnd && other.finishedAll == finishedAll;

  @override
  int get hashCode => finishedAll.hashCode;

  @override
  String toString() => 'StoryStepEnd(finishedAll: $finishedAll)';
}

/// The player's position among its groups, and where each command leads.
///
/// Pure logic: it decides where to go and remembers where each group was
/// left, and the player carries the step out.
@internal
final class StoryNavigator {
  /// Creates a navigator positioned at [start].
  StoryNavigator({
    required List<StoryGroup> groups,
    required StoryPosition start,
    this.isSeen,
    this.groupEnd = StoryGroupEndBehavior.nextGroup,
  }) : _groups = groups {
    final position = start.resolve(groups, isSeen: isSeen);
    moveTo(position.group, position.item);
  }

  /// Decides whether an item was watched, for resume positions.
  StorySeenTester? isSeen;

  /// What happens after a group's last item.
  StoryGroupEndBehavior groupEnd;

  List<StoryGroup> _groups;
  int _groupIndex = 0;
  int _itemIndex = 0;
  final Map<String, int> _resume = {};

  /// The groups.
  List<StoryGroup> get groups => _groups;

  /// The current group index.
  int get groupIndex => _groupIndex;

  /// The current item index.
  int get itemIndex => _itemIndex;

  /// The current group.
  StoryGroup get group => _groups[_groupIndex];

  /// The current item.
  StoryItem get item => group.items[_itemIndex];

  /// A key unique to the item at [group], [item].
  String keyOf(int group, int item) =>
      '${_groups[group].id}\u0000${_groups[group].items[item].id}';

  /// Moves to [group], [item] and remembers it as that group's resume item.
  void moveTo(int group, int item) {
    _groupIndex = group;
    _itemIndex = item;
    _resume[_groups[group].id] = item;
  }

  /// The item [group] opens at: where the user left it, or its first unseen
  /// item.
  int resumeItemOf(int group) =>
      _resume[_groups[group].id] ??
      StoryPosition.group(
        _groups[group].id,
      ).resolve(_groups, isSeen: isSeen).item;

  /// Where the next command leads.
  StoryStep next() {
    if (_itemIndex + 1 < group.items.length) {
      return StoryStepItem(_groupIndex, _itemIndex + 1);
    }
    if (groupEnd == StoryGroupEndBehavior.dismiss) {
      return const StoryStepEnd(finishedAll: false);
    }
    if (_groupIndex + 1 < _groups.length) {
      return StoryStepGroup(_groupIndex + 1);
    }
    return const StoryStepEnd(finishedAll: true);
  }

  /// Where the previous command leads. Going back from a group's first item
  /// opens the previous group at its last item; from the very first item,
  /// it restarts.
  StoryStep previous() {
    if (_itemIndex > 0) return StoryStepItem(_groupIndex, _itemIndex - 1);
    if (_groupIndex > 0) {
      final previous = _groups[_groupIndex - 1];
      _resume[previous.id] = previous.items.length - 1;
      return StoryStepGroup(_groupIndex - 1);
    }
    return StoryStepItem(_groupIndex, 0);
  }

  /// Where the next-group command leads.
  StoryStep nextGroup() => _groupIndex + 1 < _groups.length
      ? StoryStepGroup(_groupIndex + 1)
      : const StoryStepEnd(finishedAll: true);

  /// Where the previous-group command leads.
  StoryStep previousGroup() => _groupIndex > 0
      ? StoryStepGroup(_groupIndex - 1)
      : StoryStepItem(0, _itemIndex);

  /// Where a jump to [position] leads.
  StoryStep goTo(StoryPosition position) {
    final target = position.resolve(_groups, isSeen: isSeen);
    _resume[_groups[target.group].id] = target.item;
    return target.group == _groupIndex
        ? StoryStepItem(target.group, target.item)
        : StoryStepGroup(target.group, animate: false);
  }

  /// The item to prepare ahead: the next in this group, or the next group's
  /// resume item. `null` at the end.
  ({int group, int item})? upcoming() {
    if (_itemIndex + 1 < group.items.length) {
      return (group: _groupIndex, item: _itemIndex + 1);
    }
    if (groupEnd == StoryGroupEndBehavior.dismiss) return null;
    if (_groupIndex + 1 < _groups.length) {
      return (group: _groupIndex + 1, item: resumeItemOf(_groupIndex + 1));
    }
    return null;
  }

  /// The previous item in this group, if any.
  ({int group, int item})? previousInGroup() =>
      _itemIndex > 0 ? (group: _groupIndex, item: _itemIndex - 1) : null;

  /// Switches to [groups], keeping the user on the item they were watching
  /// when it still exists. Returns where the user now is, and whether it is
  /// the same item.
  ({int group, int item, bool sameItem}) reconcile(List<StoryGroup> groups) {
    final groupId = group.id;
    final itemId = item.id;
    _groups = groups;
    final position = StoryPosition.item(
      groupId,
      itemId,
    ).resolve(groups, isSeen: isSeen);
    final sameItem =
        groups[position.group].id == groupId &&
        groups[position.group].items[position.item].id == itemId;
    _resume.removeWhere((id, _) => !groups.any((group) => group.id == id));
    if (sameItem) {
      _groupIndex = position.group;
      _itemIndex = position.item;
    }
    return (group: position.group, item: position.item, sameItem: sameItem);
  }
}
