import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

void main() {
  final groups = [
    StoryGroup(
      id: 'g1',
      items: const [
        FakeStoryItem(id: 'a'),
        FakeStoryItem(id: 'b'),
      ],
    ),
    StoryGroup(
      id: 'g2',
      items: const [
        FakeStoryItem(id: 'c'),
        FakeStoryItem(id: 'd'),
      ],
    ),
  ];

  bool seenAB(StoryGroup group, StoryItem item) =>
      item.id == 'a' || item.id == 'b';

  test('indexes clamp into range', () {
    expect(const StoryPosition(5, 9).resolve(groups), (group: 1, item: 1));
  });

  test('a group opens at its first unseen item', () {
    expect(
      const StoryPosition.group(
        'g1',
      ).resolve(groups, isSeen: (group, item) => item.id == 'a'),
      (group: 0, item: 1),
    );
  });

  test('a fully seen group opens at its start', () {
    expect(const StoryPosition.group('g1').resolve(groups, isSeen: seenAB), (
      group: 0,
      item: 0,
    ));
  });

  test('firstUnseen skips seen groups', () {
    expect(StoryPosition.firstUnseen.resolve(groups, isSeen: seenAB), (
      group: 1,
      item: 0,
    ));
  });

  test('an unknown item falls back to the group, an unknown group to the '
      'start', () {
    expect(const StoryPosition.item('g2', 'zzz').resolve(groups), (
      group: 1,
      item: 0,
    ));
    expect(const StoryPosition.group('nope').resolve(groups), (
      group: 0,
      item: 0,
    ));
  });

  test('positions are values', () {
    expect(
      const StoryPosition.item('g', 'i'),
      const StoryPosition.item('g', 'i'),
    );
    expect(
      const StoryPosition.group('g'),
      isNot(const StoryPosition.item('g', 'i')),
    );
  });
}
