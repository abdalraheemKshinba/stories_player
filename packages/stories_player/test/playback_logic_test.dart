// Unit tests for the pure logic the player is built from: where commands
// lead, how time is kept, and what the status is.

import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/src/playback/story_clock.dart';
import 'package:stories_player/src/playback/story_navigator.dart';
import 'package:stories_player/src/playback/story_session_pool.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

List<StoryGroup> _groups() => [
  for (final g in ['a', 'b', 'c'])
    StoryGroup(
      id: g,
      items: [for (var i = 0; i < 3; i++) FakeStoryItem(id: '$g$i')],
    ),
];

void main() {
  group('StoryNavigator', () {
    StoryNavigator at(int g, int i, {StoryGroupEndBehavior? end}) =>
        StoryNavigator(
          groups: _groups(),
          start: StoryPosition(g, i),
          groupEnd: end ?? StoryGroupEndBehavior.nextGroup,
        );

    test('next moves through a group, then to the next group', () {
      expect(at(0, 0).next(), const StoryStepItem(0, 1));
      expect(at(0, 2).next(), const StoryStepGroup(1));
    });

    test('next after the last item of the last group finishes everything', () {
      expect(at(2, 2).next(), const StoryStepEnd(finishedAll: true));
    });

    test('a group can end the session', () {
      expect(
        at(0, 2, end: StoryGroupEndBehavior.dismiss).next(),
        const StoryStepEnd(finishedAll: false),
      );
    });

    test('previous from a group start opens the previous group at its last '
        'item; from the very first item it restarts', () {
      final nav = at(1, 0);
      expect(nav.previous(), const StoryStepGroup(0));
      expect(nav.resumeItemOf(0), 2);
      expect(at(0, 0).previous(), const StoryStepItem(0, 0));
    });

    test('groups resume where the user left them', () {
      final nav = at(0, 0)..moveTo(1, 2);
      nav.moveTo(0, 1);
      expect(nav.resumeItemOf(1), 2);
    });

    test('a group never opened resumes at its first unseen item', () {
      final nav = StoryNavigator(
        groups: _groups(),
        start: StoryPosition.start,
        isSeen: (group, item) => item.id == 'b0',
      );
      expect(nav.resumeItemOf(1), 1);
    });

    test('jumps within the group are immediate; across groups they jump '
        'pages without animation', () {
      final nav = at(0, 0);
      expect(
        nav.goTo(const StoryPosition.item('a', 'a2')),
        const StoryStepItem(0, 2),
      );
      expect(
        nav.goTo(const StoryPosition.item('c', 'c1')),
        const StoryStepGroup(2, animate: false),
      );
      expect(nav.resumeItemOf(2), 1);
    });

    test('the upcoming item crosses into the next group, but not past the '
        'end', () {
      expect(at(0, 1).upcoming(), (group: 0, item: 2));
      expect(at(0, 2).upcoming(), (group: 1, item: 0));
      expect(at(2, 2).upcoming(), isNull);
    });

    test('new data keeps the user on their item when it still exists', () {
      final nav = at(1, 1);
      final moved = nav.reconcile([
        StoryGroup(
          id: 'new',
          items: const [FakeStoryItem(id: 'n')],
        ),
        ..._groups(),
      ]);
      expect(moved, (group: 2, item: 1, sameItem: true));
      expect(nav.item.id, 'b1');
      final gone = nav.reconcile([_groups().first]);
      expect(gone.sameItem, isFalse);
    });
  });

  group('StoryClock', () {
    const second = Duration(seconds: 1);

    test('counts time only while the item is ready', () {
      final clock = StoryClock();
      clock.tick(
        Duration.zero,
        duration: second,
        mediaPosition: null,
        counting: true,
      );
      expect(
        clock.tick(
          const Duration(milliseconds: 500),
          duration: second,
          mediaPosition: null,
          counting: true,
        ),
        closeTo(0.5, 0.001),
      );
      clock.tick(
        const Duration(milliseconds: 900),
        duration: second,
        mediaPosition: null,
        counting: false,
      );
      expect(clock.elapsed, const Duration(milliseconds: 500));
    });

    test('a pause is never counted as playing time', () {
      final clock = StoryClock();
      clock.tick(
        Duration.zero,
        duration: second,
        mediaPosition: null,
        counting: true,
      );
      clock.resume(); // the ticker stopped and restarted
      clock.tick(
        const Duration(seconds: 30),
        duration: second,
        mediaPosition: null,
        counting: true,
      );
      expect(clock.elapsed, Duration.zero);
    });

    test('follows the media position when the media keeps time', () {
      final clock = StoryClock();
      final progress = clock.tick(
        const Duration(seconds: 9),
        duration: const Duration(seconds: 4),
        mediaPosition: second,
        counting: true,
      );
      expect(progress, 0.25);
    });

    test('media ending before the item duration holds the last frame', () {
      final clock = StoryClock()..elapsed = const Duration(seconds: 4);
      expect(clock.onMediaCompleted(const Duration(seconds: 8)), isFalse);
      expect(clock.mediaEnded, isTrue);
      clock.tick(
        Duration.zero,
        duration: const Duration(seconds: 8),
        mediaPosition: null,
        counting: false,
      );
      final progress = clock.tick(
        const Duration(seconds: 2),
        duration: const Duration(seconds: 8),
        mediaPosition: const Duration(seconds: 4),
        counting: false,
      );
      expect(progress, 0.75, reason: 'counts on, ignoring the stopped media');
      expect(StoryClock().onMediaCompleted(null), isTrue);
    });

    test('status follows the session, the end, and holds', () {
      final clock = StoryClock();
      expect(
        storyPlaybackStatus(null, clock, held: false),
        StoryPlaybackStatus.loading,
      );
      expect(
        storyPlaybackStatus(StorySessionStatus.ready, clock, held: true),
        StoryPlaybackStatus.paused,
      );
      expect(
        storyPlaybackStatus(StorySessionStatus.buffering, clock, held: false),
        StoryPlaybackStatus.buffering,
      );
      clock.ended = true;
      expect(
        storyPlaybackStatus(StorySessionStatus.ready, clock, held: false),
        StoryPlaybackStatus.completed,
      );
      expect(storyIsPlayable(StorySessionStatus.ready, clock), isFalse);
    });
  });

  group('StorySessionPool', () {
    testWidgets('creates once, keeps what is asked, disposes the rest', (
      tester,
    ) async {
      var changes = 0;
      final pool = StorySessionPool(onChanged: () => changes++);
      final delegate = FakeStoryItemDelegate();
      StoryItemSession create(String id) => delegate.createSession(
        FakeStoryItem(id: id),
        StorySessionContext(
          store: FakeStoryMediaStore(),
          isMuted: true,
          preferLowQuality: false,
          imageDuration: const Duration(seconds: 5),
        ),
      );
      final a = pool.obtain('a', () => create('a'));
      expect(pool.obtain('a', () => create('again')), same(a));
      final b = pool.obtain('b', () => create('b'));
      await tester.pump();
      expect(changes, greaterThan(0), reason: 'sessions report changes');
      expect(pool.markShown(a), isTrue);
      expect(pool.markShown(a), isFalse, reason: 'shown before: rewind it');
      pool.keepOnly({'b'});
      expect(a.isDisposed, isTrue);
      expect(b.isDisposed, isFalse);
      pool.clear();
      expect(b.isDisposed, isTrue);
      expect(pool.keys, isEmpty);
    });
  });
}
