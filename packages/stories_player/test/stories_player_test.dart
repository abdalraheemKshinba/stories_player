import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

List<StoryGroup> _groups() => [
  StoryGroup(
    id: 'g1',
    label: 'First',
    items: const [
      FakeStoryItem(id: 'a'),
      FakeStoryItem(id: 'b'),
    ],
  ),
  StoryGroup(
    id: 'g2',
    label: 'Second',
    items: const [
      FakeStoryItem(id: 'c'),
      FakeStoryItem(id: 'd'),
    ],
  ),
];

class _Harness {
  _Harness(this.tester);

  final WidgetTester tester;
  final FakeStoryItemDelegate delegate = FakeStoryItemDelegate();
  final StoriesController controller = StoriesController();
  final List<String> changes = [];
  final List<StoriesDismissReason> dismissals = [];
  final List<String> seen = [];
  final List<StoryEvent> events = [];
  int completions = 0;

  String get current =>
      '${controller.value.groupId}/${controller.value.itemId}';

  Future<void> pump({
    List<StoryGroup>? groups,
    FakeStoryItemDelegate? delegate,
    TextDirection textDirection = TextDirection.ltr,
    StoryPosition initialPosition = StoryPosition.start,
    StorySeenTester? isSeen,
    StoriesPlaybackConfig playback = const StoriesPlaybackConfig(),
    MediaQueryData? mediaQuery,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget player = StoriesPlayer(
      groups: groups ?? _groups(),
      controller: controller,
      delegates: [delegate ?? this.delegate],
      mediaStore: FakeStoryMediaStore(),
      textDirection: textDirection,
      initialPosition: initialPosition,
      isSeen: isSeen,
      playback: playback,
      onItemChanged: (group, item, reason) =>
          changes.add('${group.id}/${item.id}:${reason.name}'),
      onItemSeen: (group, item) => seen.add(item.id),
      onDismiss: dismissals.add,
      onComplete: () => completions++,
      onEvent: events.add,
    );
    if (mediaQuery != null) {
      player = MediaQuery(data: mediaQuery, child: player);
    }
    await tester.pumpWidget(MaterialApp(home: player));
    await tester.pump();
  }

  /// Lets a group transition finish. The story clock pauses while pages
  /// move, so this does not advance items.
  Future<void> settle() async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Lets the current item play for [duration].
  Future<void> play(Duration duration) async {
    await tester.pump(duration);
    await tester.pump();
  }
}

void main() {
  testWidgets('opens on the first item and starts playing once ready', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    expect(h.current, 'g1/a');
    expect(h.controller.value.status, StoryPlaybackStatus.playing);
    expect(h.changes, ['g1/a:initial']);
    expect(h.delegate.sessionFor('a').isPlaying, isTrue);
  });

  testWidgets('advances when the item duration runs out', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    await h.play(const Duration(milliseconds: 500));
    expect(h.current, 'g1/a');
    expect(h.controller.progress.value, closeTo(0.5, 0.05));
    await h.play(const Duration(milliseconds: 600));
    expect(h.current, 'g1/b');
    expect(h.changes.last, 'g1/b:timer');
  });

  testWidgets('crosses into the next group, then completes and dismisses', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    for (var i = 0; i < 3; i++) {
      await h.play(const Duration(milliseconds: 1100));
      await h.settle();
    }
    expect(h.current, 'g2/d');
    await h.play(const Duration(milliseconds: 1100));
    expect(h.completions, 1);
    expect(h.dismissals, [StoriesDismissReason.completed]);
  });

  group('tap zones', () {
    testWidgets('LTR: right goes forward, left goes back', (tester) async {
      final h = _Harness(tester);
      await h.pump();
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(h.current, 'g1/b');
      await tester.tapAt(const Offset(40, 400));
      await tester.pump();
      expect(h.current, 'g1/a');
      expect(h.changes.last, 'g1/a:tap');
    });

    testWidgets('RTL: left goes forward, right goes back', (tester) async {
      final h = _Harness(tester);
      await h.pump(textDirection: TextDirection.rtl);
      await tester.tapAt(const Offset(100, 400));
      await tester.pump();
      expect(h.current, 'g1/b');
      await tester.tapAt(const Offset(380, 400));
      await tester.pump();
      expect(h.current, 'g1/a');
    });

    testWidgets('back from a group start opens the previous group at its '
        'last item', (tester) async {
      final h = _Harness(tester);
      await h.pump(initialPosition: const StoryPosition(1, 0));
      expect(h.current, 'g2/c');
      await tester.tapAt(const Offset(40, 400));
      await h.settle();
      expect(h.current, 'g1/b');
    });
  });

  testWidgets('holding pauses, and the release is not a tap', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    final gesture = await tester.startGesture(const Offset(300, 400));
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.controller.value.pauseReasons, contains(PauseReason.pointerDown));
    final before = h.controller.progress.value;
    await tester.pump(const Duration(seconds: 2));
    expect(h.controller.progress.value, before);
    await gesture.up();
    await tester.pump();
    expect(h.current, 'g1/a');
    expect(h.controller.value.isPaused, isFalse);
  });

  testWidgets('a pause from the app survives a finger lifting', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    const sheet = PauseReason('sheet');
    h.controller.pause(sheet);
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pump(const Duration(seconds: 2));
    expect(h.controller.value.status, StoryPlaybackStatus.paused);
    expect(h.current, 'g1/a');
    h.controller.play(sheet);
    await tester.pump();
    expect(h.controller.value.status, StoryPlaybackStatus.playing);
  });

  testWidgets('progress follows the media clock and freezes while '
      'buffering', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(mediaClock: true);
    await h.pump(delegate: delegate);
    final session = delegate.sessionFor('a')
      ..position = const Duration(milliseconds: 250);
    await tester.pump(const Duration(milliseconds: 16));
    expect(h.controller.progress.value, closeTo(0.25, 0.01));
    session.startBuffering();
    await tester.pump(const Duration(seconds: 3));
    expect(h.controller.value.status, StoryPlaybackStatus.buffering);
    expect(h.current, 'g1/a');
    session.stopBuffering();
    await tester.pump();
    expect(h.events.whereType<StoryStalled>(), hasLength(1));
  });

  testWidgets('by default, an item ends when its media ends, even before its '
      'set duration', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(mediaClock: true);
    await h.pump(delegate: delegate);
    delegate.sessionFor('a').position = const Duration(milliseconds: 400);
    await tester.pump(const Duration(milliseconds: 16));
    delegate.sessionFor('a').finish();
    await tester.pump();
    await tester.pump();
    expect(h.current, 'g1/b');
  });

  testWidgets('a video whose position stops moving shows the loading '
      'indicator, and reports the stall when it moves again', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(mediaClock: true);
    await h.pump(delegate: delegate);
    final session = delegate.sessionFor('a')
      ..position = const Duration(milliseconds: 300);
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(h.current, 'g1/a', reason: 'progress froze with the video');
    session.position = const Duration(milliseconds: 350);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the caption gradient reaches the bottom edge and its text '
      'stays above the system bar', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.reset);
    final controller = StoriesController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: StoriesPlayer(
          groups: [
            StoryGroup(
              id: 'g',
              items: const [FakeStoryItem(id: 'a', caption: 'Hello')],
            ),
          ],
          controller: controller,
          delegates: [FakeStoryItemDelegate()],
          mediaStore: FakeStoryMediaStore(),
        ),
      ),
    );
    await tester.pump();
    final caption = tester.getRect(find.byType(StoryCaption));
    expect(caption.bottom, 800, reason: 'the gradient reaches the edge');
    final text = tester.getRect(find.text('Hello'));
    expect(text.bottom, lessThanOrEqualTo(800 - 48 - 24));
  });

  testWidgets('with holdLastFrame, media that ends early holds its last '
      'frame until the item duration runs out', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(mediaClock: true);
    await h.pump(
      delegate: delegate,
      playback: const StoriesPlaybackConfig(
        mediaEnd: StoryMediaEndBehavior.holdLastFrame,
      ),
    );
    final session = delegate.sessionFor('a')
      ..position = const Duration(milliseconds: 400);
    await tester.pump(const Duration(milliseconds: 16));
    session.finish();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.current, 'g1/a');
    expect(h.controller.value.status, StoryPlaybackStatus.playing);
    expect(h.controller.progress.value, closeTo(0.7, 0.05));
    await h.play(const Duration(milliseconds: 400));
    expect(h.current, 'g1/b');
  });

  testWidgets('progress waits for the media to load', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(autoPrepare: false);
    await h.pump(delegate: delegate);
    expect(h.controller.value.status, StoryPlaybackStatus.loading);
    await tester.pump(const Duration(seconds: 5));
    expect(h.current, 'g1/a');
    expect(h.controller.progress.value, 0);
    delegate.sessionFor('a').completePrepare();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(h.controller.progress.value, closeTo(0.5, 0.05));
    final shown = h.events.whereType<StoryItemShown>().single;
    expect(shown.timeToFirstFrame, greaterThan(const Duration(seconds: 4)));
  });

  testWidgets('reduced motion does not speed up items', (tester) async {
    final h = _Harness(tester);
    await h.pump(
      mediaQuery: const MediaQueryData(
        size: Size(400, 800),
        disableAnimations: true,
      ),
    );
    await h.play(const Duration(milliseconds: 500));
    expect(h.current, 'g1/a');
    expect(h.controller.progress.value, closeTo(0.5, 0.05));
  });

  testWidgets('with a screen reader on, items do not auto-advance', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump(
      mediaQuery: const MediaQueryData(
        size: Size(400, 800),
        accessibleNavigation: true,
      ),
    );
    await h.play(const Duration(seconds: 3));
    expect(h.current, 'g1/a');
    expect(h.controller.value.status, StoryPlaybackStatus.completed);
  });

  testWidgets('exposes semantics with the position and actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final h = _Harness(tester);
    await h.pump();
    expect(
      find.bySemanticsLabel(RegExp('Story 1 of 2, First')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('dragging down far enough asks to dismiss', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    await tester.dragFrom(const Offset(200, 200), const Offset(0, 300));
    await tester.pump();
    expect(h.dismissals, [StoriesDismissReason.swipeDown]);
  });

  group('a tilted drag', () {
    // A phone's touch slop, smaller than the test default, as on Android.
    const phone = MediaQueryData(
      size: Size(400, 800),
      gestureSettings: DeviceGestureSettings(touchSlop: 8),
    );

    // Moves like a finger: a report every pixel or two, in a straight line.
    Future<void> swipe(WidgetTester tester, Offset by) async {
      final gesture = await tester.startGesture(const Offset(200, 200));
      const steps = 160;
      for (var i = 0; i < steps; i++) {
        await gesture.moveBy(by / steps.toDouble());
        await tester.pump(const Duration(milliseconds: 2));
      }
      await gesture.up();
      await tester.pump();
    }

    for (final dx in [60.0, -60.0, 140.0, -140.0, 200.0, -260.0]) {
      testWidgets('down and sideways by $dx still dismisses', (tester) async {
        final h = _Harness(tester);
        await h.pump(mediaQuery: phone);
        await swipe(tester, Offset(dx, 300));
        await h.settle();
        expect(h.dismissals, [StoriesDismissReason.swipeDown]);
        expect(h.current, 'g1/a');
      });
    }

    testWidgets('mostly sideways still swipes to the next group', (
      tester,
    ) async {
      final h = _Harness(tester);
      await h.pump(mediaQuery: phone);
      await swipe(tester, const Offset(-300, 90));
      await h.settle();
      expect(h.dismissals, isEmpty);
      expect(h.current, 'g2/c');
    });
  });

  testWidgets('a short drag down springs back', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    await tester.dragFrom(const Offset(200, 200), const Offset(0, 60));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(h.dismissals, isEmpty);
    expect(h.controller.value.isPaused, isFalse);
  });

  testWidgets('keyboard arrows follow the text direction', (tester) async {
    final h = _Harness(tester);
    await h.pump(textDirection: TextDirection.rtl);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(h.current, 'g1/b');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(h.current, 'g1/a');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(h.dismissals, [StoriesDismissReason.keyboard]);
  });

  testWidgets('a failed item shows retry, and retry loads it again', (
    tester,
  ) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(autoPrepare: false);
    await h.pump(delegate: delegate);
    // The first failure is retried once on its own; the second shows.
    delegate.sessionFor('a').failPrepare('offline');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    delegate.sessionFor('a').failPrepare('offline');
    await tester.pump();
    await tester.pump();
    expect(h.controller.value.status, StoryPlaybackStatus.error);
    expect(find.text('Retry'), findsOneWidget);
    expect(h.events.whereType<StoryItemFailed>().single.error, 'offline');
    await tester.tap(find.text('Retry'));
    await tester.pump();
    final retried = delegate.sessionFor('a');
    expect(delegate.sessions.where((s) => s.item.id == 'a'), hasLength(3));
    retried.completePrepare();
    await tester.pump();
    await tester.pump();
    expect(h.controller.value.status, StoryPlaybackStatus.playing);
  });

  testWidgets('an item that fails once is retried on its own, after other '
      'sessions are released, and recovers without an error', (tester) async {
    final h = _Harness(tester);
    final delegate = FakeStoryItemDelegate(autoPrepare: false);
    await h.pump(delegate: delegate);
    delegate.sessionFor('a').failPrepare('decoder busy');
    await tester.pump();
    expect(h.controller.value.status, isNot(StoryPlaybackStatus.error));
    await tester.pump(const Duration(milliseconds: 400));
    final second = delegate.sessionFor('a');
    expect(delegate.sessions.where((s) => s.item.id == 'a'), hasLength(2));
    second.completePrepare();
    await tester.pump();
    await tester.pump();
    expect(h.controller.value.status, StoryPlaybackStatus.playing);
    expect(h.events.whereType<StoryItemFailed>(), isEmpty);
    expect(h.changes, ['g1/a:initial'], reason: 'a retry is not a new visit');
  });

  testWidgets('opens a group at its first unseen item and reports seen '
      'items once', (tester) async {
    final h = _Harness(tester);
    await h.pump(
      initialPosition: const StoryPosition.group('g2'),
      isSeen: (group, item) => item.id == 'c',
    );
    expect(h.current, 'g2/d');
    expect(h.seen, ['d']);
    await tester.pump(const Duration(milliseconds: 100));
    expect(h.seen, ['d']);
  });

  testWidgets('prepares the next item ahead and disposes items left behind', (
    tester,
  ) async {
    final h = _Harness(tester);
    await h.pump();
    expect(h.delegate.sessions.map((s) => s.item.id), ['a', 'b']);
    await tester.tapAt(const Offset(300, 400));
    await tester.pump();
    final a = h.delegate.sessions.first;
    expect(a.isDisposed, isTrue);
    expect(h.delegate.sessions.map((s) => s.item.id), ['a', 'b', 'c']);
  });

  testWidgets(
    'a controller cannot drive two players',
    experimentalLeakTesting:
        // The second player fails in initState on purpose, so Flutter never
        // disposes its State; nothing else may leak.
        LeakTesting.settings.withIgnored(
          classes: ['StatefulElement', '_StoriesPlayerState'],
        ),
    (tester) async {
      final controller = StoriesController();
      addTearDown(controller.dispose);
      tester.view
        ..physicalSize = const Size(800, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: StoriesPlayer(
                    groups: _groups(),
                    controller: controller,
                    delegates: [FakeStoryItemDelegate()],
                    mediaStore: FakeStoryMediaStore(),
                  ),
                ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    },
  );

  testWidgets('mute applies to sessions and the state', (tester) async {
    final h = _Harness(tester);
    await h.pump();
    expect(h.controller.value.isMuted, isTrue);
    h.controller.setMuted(false);
    await tester.pump();
    expect(h.controller.value.isMuted, isFalse);
    expect(h.delegate.sessionFor('a').muted, isFalse);
  });
}
