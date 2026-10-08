// Feature scenarios. Each test is one row of doc/scenarios.md; keep the ids
// (P1, G3, ...) in sync with that file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

List<StoryGroup> _groups({int groups = 2, int items = 2}) => [
  for (var g = 0; g < groups; g++)
    StoryGroup(
      id: 'g$g',
      label: 'Group $g',
      items: [
        for (var i = 0; i < items; i++)
          FakeStoryItem(
            id: 'g$g-i$i',
            caption: 'Caption $g-$i',
            hasSound: true,
          ),
      ],
    ),
];

/// Pumps a player and records what it reports.
class _Rig {
  _Rig(this.tester);

  final WidgetTester tester;
  final StoriesController controller = StoriesController();
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
  late FakeStoryItemDelegate delegate;
  final List<String> changes = [];
  final List<String> seen = [];
  final List<StoriesDismissReason> dismissals = [];
  final List<StoryEvent> events = [];
  final List<String> swipeUps = [];
  int completions = 0;

  String get at => '${controller.value.itemId}';

  Future<void> pump({
    List<StoryGroup>? groups,
    FakeStoryItemDelegate? delegate,
    StoryItemDelegate? extraDelegate,
    StoriesPlaybackConfig playback = const StoriesPlaybackConfig(),
    StoriesGestureConfig gestures = const StoriesGestureConfig(),
    StoryPosition initialPosition = StoryPosition.start,
    StoriesLabels labels = StoriesLabels.english,
    TextDirection textDirection = TextDirection.ltr,
    StoryOverlayBuilder headerBuilder = StoriesPlayer.defaultHeaderBuilder,
    bool swipeUp = false,
    ThemeData? theme,
  }) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    this.delegate = delegate ?? FakeStoryItemDelegate();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: theme,
        home: StoriesPlayer(
          groups: groups ?? _groups(),
          controller: controller,
          delegates: [?extraDelegate, this.delegate],
          mediaStore: FakeStoryMediaStore(),
          initialPosition: initialPosition,
          playback: playback,
          gestures: gestures,
          labels: labels,
          textDirection: textDirection,
          headerBuilder: headerBuilder,
          onItemChanged: (group, item, reason) =>
              changes.add('${item.id}:${reason.name}'),
          onItemSeen: (group, item) => seen.add(item.id),
          onDismiss: dismissals.add,
          onComplete: () => completions++,
          onEvent: events.add,
          onSwipeUp: swipeUp ? (group, item) => swipeUps.add(item.id) : null,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> frames([int count = 25]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> tapNext() async {
    await tester.tapAt(const Offset(320, 450));
    await tester.pump();
  }

  Future<void> tapPrevious() async {
    await tester.tapAt(const Offset(40, 450));
    await tester.pump();
  }
}

/// Media that claims every tap for itself, like a web video element or a
/// native platform view.
final class _GreedyItem extends StoryItem {
  const _GreedyItem({required super.id})
    : super(duration: const Duration(seconds: 1));

  @override
  Iterable<StoryMedia> get media => const [];
}

final class _GreedyDelegate extends StoryItemDelegate {
  _GreedyDelegate();

  int mediaTaps = 0;

  @override
  bool canHandle(StoryItem item) => item is _GreedyItem;

  @override
  StoryItemSession createSession(StoryItem item, StorySessionContext context) =>
      _GreedySession(item, context, this);
}

final class _GreedySession extends StoryItemSession {
  _GreedySession(super.item, super.context, this._delegate);

  final _GreedyDelegate _delegate;

  @override
  Future<void> onPrepare() async {}

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _delegate.mediaTaps++,
    onLongPress: () {},
    child: const ColoredBox(color: Color(0xFF000000)),
  );
}

void main() {
  group('Playback', () {
    testWidgets('P1 the previous item stays warm and replays from the start '
        'when the budget allows it', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(
        playback: const StoriesPlaybackConfig(maxPreparedItems: 3),
      );
      final first = rig.delegate.sessionFor('g0-i0');
      await rig.tapNext();
      expect(first.isDisposed, isFalse);
      await rig.tapPrevious();
      expect(rig.at, 'g0-i0');
      expect(rig.delegate.sessionFor('g0-i0'), same(first));
      expect(first.seekedTo, Duration.zero);
    });

    testWidgets('P2 with a budget of one, nothing is prepared ahead', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(
        playback: const StoriesPlaybackConfig(maxPreparedItems: 1),
      );
      expect(rig.delegate.sessions.map((s) => s.item.id), ['g0-i0']);
    });

    testWidgets('P3 a group can end the session instead of moving on', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(
        playback: const StoriesPlaybackConfig(
          groupEnd: StoryGroupEndBehavior.dismiss,
        ),
      );
      await rig.tapNext();
      await rig.tapNext();
      expect(rig.dismissals, [StoriesDismissReason.completed]);
      expect(rig.at, 'g0-i1');
    });

    testWidgets('P4 going back from the very first item restarts it', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await rig.tapPrevious();
      expect(rig.at, 'g0-i0');
      expect(rig.changes.last, 'g0-i0:tap');
      expect(rig.controller.progress.value, lessThan(0.05));
    });

    testWidgets('P5 a failed item is skipped after the configured delay', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(
        delegate: FakeStoryItemDelegate(autoPrepare: false),
        playback: const StoriesPlaybackConfig(
          skipFailedItemsAfter: Duration(seconds: 2),
        ),
      );
      rig.delegate.sessionFor('g0-i0').failPrepare();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      rig.delegate.sessionFor('g0-i0').failPrepare(); // the automatic retry
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(rig.at, 'g0-i0');
      await tester.pump(const Duration(seconds: 2));
      expect(rig.at, 'g0-i1');
    });

    testWidgets('P6 seen can be counted at the start or at the end', (
      tester,
    ) async {
      final start = _Rig(tester);
      await start.pump(
        delegate: FakeStoryItemDelegate(autoPrepare: false),
        playback: const StoriesPlaybackConfig(seenRule: StorySeenRule.onStart),
      );
      expect(start.seen, ['g0-i0']);

      final end = _Rig(tester);
      await end.pump(
        playback: const StoriesPlaybackConfig(
          seenRule: StorySeenRule.onComplete,
        ),
      );
      expect(end.seen, isEmpty);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(end.seen, ['g0-i0']);
    });

    testWidgets('P7 the loading indicator waits before showing', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(delegate: FakeStoryItemDelegate(autoPrepare: false));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      rig.delegate.sessionFor('g0-i0').completePrepare();
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('P8 autoAdvance off holds the end of each item', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(playback: const StoriesPlaybackConfig(autoAdvance: false));
      await tester.pump(const Duration(seconds: 2));
      expect(rig.at, 'g0-i0');
      expect(rig.controller.value.status, StoryPlaybackStatus.completed);
      await rig.tapNext();
      expect(rig.at, 'g0-i1');
    });
  });

  group('Retry', () {
    /// Fails the first load and its silent automatic retry, so the error
    /// view is on screen.
    Future<_Rig> failed(WidgetTester tester) async {
      final rig = _Rig(tester);
      await rig.pump(delegate: FakeStoryItemDelegate(autoPrepare: false));
      rig.delegate.sessionFor('g0-i0').failPrepare('offline');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      rig.delegate.sessionFor('g0-i0').failPrepare('offline');
      await tester.pump();
      await tester.pump();
      expect(find.text("Couldn't load this story"), findsOneWidget);
      return rig;
    }

    testWidgets('R1 tapping Retry shows progress at once and ignores more '
        'taps', (tester) async {
      final rig = await failed(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Retrying…'), findsOneWidget);
      final retryButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );
      expect(retryButton.onPressed, isNull, reason: 'one retry at a time');
      expect(
        rig.delegate.sessions.where((s) => s.item.id == 'g0-i0'),
        hasLength(3),
      );
    });

    testWidgets('R2 a retry that fails at once still shows progress for a '
        'moment, then says it failed again and offers Skip', (tester) async {
      final rig = await failed(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      rig.delegate.sessionFor('g0-i0').failPrepare('offline');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Retrying…'), findsOneWidget, reason: 'not yet 0.8 s');
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text("Still couldn't load this story"), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(
        rig.delegate.sessions.where((s) => s.item.id == 'g0-i0'),
        hasLength(3),
        reason: 'a user retry is not retried silently again',
      );
    });

    testWidgets('R3 Skip moves past an item that keeps failing', (
      tester,
    ) async {
      final rig = await failed(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      rig.delegate.sessionFor('g0-i0').failPrepare('offline');
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(rig.at, 'g0-i1');
    });

    testWidgets('R4 a retry that works shows the story, with no error left', (
      tester,
    ) async {
      final rig = await failed(tester);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      rig.delegate.sessionFor('g0-i0').completePrepare();
      await tester.pump();
      await tester.pump();
      expect(find.byType(StoryErrorView), findsNothing);
      expect(rig.controller.value.status, StoryPlaybackStatus.playing);
      expect(
        rig.events.whereType<StoryItemFailed>(),
        hasLength(1),
        reason: 'only the failure the user saw is reported',
      );
    });
  });

  group('Gestures', () {
    testWidgets('G1 a tap on media that grabs input still moves to the next '
        'story (web video, platform views)', (tester) async {
      final rig = _Rig(tester);
      final greedy = _GreedyDelegate();
      await rig.pump(
        groups: [
          StoryGroup(
            id: 'v',
            items: const [
              _GreedyItem(id: 'video'),
              FakeStoryItem(id: 'after'),
            ],
          ),
        ],
        extraDelegate: greedy,
      );
      await rig.tapNext();
      expect(rig.at, 'after');
      expect(greedy.mediaTaps, 0);
    });

    testWidgets('G2 a long press on media that grabs input still pauses, and '
        'release resumes', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(
        groups: [
          StoryGroup(
            id: 'v',
            items: const [_GreedyItem(id: 'video')],
          ),
        ],
        extraDelegate: _GreedyDelegate(),
      );
      final gesture = await tester.startGesture(const Offset(200, 450));
      await tester.pump(const Duration(milliseconds: 400));
      expect(rig.controller.value.status, StoryPlaybackStatus.paused);
      final held = rig.controller.progress.value;
      await tester.pump(const Duration(seconds: 1));
      expect(rig.controller.progress.value, held);
      await gesture.up();
      await tester.pump();
      expect(rig.controller.value.status, StoryPlaybackStatus.playing);
      expect(rig.at, 'video');
    });

    testWidgets('G3 holding hides the overlays and releasing shows them', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      double opacity() => tester
          .widget<AnimatedOpacity>(find.byType(AnimatedOpacity).first)
          .opacity;
      expect(opacity(), 1);
      final gesture = await tester.startGesture(const Offset(200, 450));
      await tester.pump(const Duration(milliseconds: 300));
      expect(opacity(), 0);
      await gesture.up();
      await tester.pump();
      expect(opacity(), 1);
    });

    testWidgets('G4 swiping sideways changes group and pauses while the '
        'pages move', (tester) async {
      final rig = _Rig(tester);
      await rig.pump();
      final gesture = await tester.startGesture(const Offset(350, 400));
      await gesture.moveBy(const Offset(-60, 0));
      await tester.pump();
      expect(
        rig.controller.value.pauseReasons,
        contains(PauseReason.groupTransition),
      );
      await gesture.moveBy(const Offset(-200, 0));
      await gesture.up();
      await rig.frames(60);
      expect(rig.at, 'g1-i0');
      expect(rig.changes.last, 'g1-i0:swipe');
      expect(rig.controller.value.pauseReasons, isEmpty);
    });

    testWidgets('G5 sideways swipes can be turned off', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(
        gestures: const StoriesGestureConfig(swipeBetweenGroups: false),
      );
      await tester.dragFrom(const Offset(350, 400), const Offset(-300, 0));
      await rig.frames();
      expect(rig.at, 'g0-i0');
    });

    testWidgets('G6 swiping up reports the item', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(swipeUp: true);
      await tester.dragFrom(const Offset(200, 600), const Offset(0, -200));
      await rig.frames();
      expect(rig.swipeUps, ['g0-i0']);
      expect(rig.dismissals, isEmpty);
    });

    testWidgets('G7 the close button closes, it is not a tap forward', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      await tester.tap(find.byTooltip('Close'));
      await tester.pump();
      expect(rig.dismissals, [StoriesDismissReason.closeButton]);
      expect(rig.at, 'g0-i0');
    });

    testWidgets('G8 the mute button shows on items with sound and toggles', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      expect(rig.controller.value.isMuted, isTrue);
      await tester.tap(find.byTooltip('Unmute'));
      await tester.pump();
      expect(rig.controller.value.isMuted, isFalse);
      expect(find.byTooltip('Mute'), findsOneWidget);
      expect(rig.at, 'g0-i0');
    });

    testWidgets('G9 tap zones respect a custom previous-zone width', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(
        gestures: const StoriesGestureConfig(previousZoneFraction: 0.5),
        initialPosition: const StoryPosition(0, 1),
      );
      await tester.tapAt(const Offset(180, 450)); // 45 %: now "previous"
      await tester.pump();
      expect(rig.at, 'g0-i0');
    });
  });

  group('Lifecycle', () {
    testWidgets('L1 backgrounding releases the media and resuming restores '
        'the position', (tester) async {
      final rig = _Rig(tester);
      final delegate = FakeStoryItemDelegate(mediaClock: true);
      await rig.pump(delegate: delegate);
      final session = delegate.sessionFor('g0-i0')
        ..position = const Duration(milliseconds: 400);
      await tester.pump(const Duration(milliseconds: 16));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(session.isDisposed, isTrue);
      expect(rig.controller.value.status, StoryPlaybackStatus.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump();
      final restored = delegate.sessionFor('g0-i0');
      expect(restored, isNot(same(session)));
      expect(restored.seekedTo, const Duration(milliseconds: 400));
      expect(rig.controller.value.status, StoryPlaybackStatus.playing);
    });

    testWidgets('L2 an inactive app pauses without releasing', (tester) async {
      final rig = _Rig(tester);
      await rig.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        rig.controller.value.pauseReasons,
        contains(PauseReason.appInactive),
      );
      expect(rig.delegate.sessionFor('g0-i0').isDisposed, isFalse);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(rig.controller.value.status, StoryPlaybackStatus.playing);
    });

    testWidgets('L3 a route on top pauses, and coming back resumes', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      unawaited(
        rig.navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await rig.frames(30);
      expect(
        rig.controller.value.pauseReasons,
        contains(PauseReason.routeCovered),
      );
      rig.navigator.currentState!.pop();
      await rig.frames(30);
      expect(rig.controller.value.isPaused, isFalse);
    });
  });

  group('Controller', () {
    testWidgets('C1 jumps, group moves and dismiss', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(groups: _groups(groups: 3));
      rig.controller.jumpTo(const StoryPosition.item('g2', 'g2-i1'));
      await rig.frames();
      expect(rig.at, 'g2-i1');
      rig.controller.previousGroup();
      await rig.frames();
      expect(rig.controller.value.groupId, 'g1');
      rig.controller.nextGroup();
      await rig.frames();
      expect(rig.controller.value.groupId, 'g2');
      rig.controller.dismiss();
      await tester.pump();
      expect(rig.dismissals, [StoriesDismissReason.controller]);
    });

    testWidgets('C2 events arrive on the stream and the callback alike', (
      tester,
    ) async {
      final rig = _Rig(tester);
      final streamed = <String>[];
      final sub = rig.controller.events.listen((e) => streamed.add(e.name));
      addTearDown(sub.cancel);
      await rig.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pump();
      expect(
        rig.events.map((e) => e.name),
        containsAllInOrder([
          'itemStarted',
          'itemShown',
          'itemSeen',
          'itemCompleted',
          'itemStarted',
        ]),
      );
      expect(streamed, rig.events.map((e) => e.name).toList());
    });

    testWidgets('C3 custom builders reach the controller through the context', (
      tester,
    ) async {
      final rig = _Rig(tester);
      StoriesController? found;
      await rig.pump(
        headerBuilder: (context, details) {
          found = StoriesPlayer.of(context);
          return Text('Header ${details.itemIndex + 1}');
        },
      );
      expect(found, same(rig.controller));
      expect(find.text('Header 1'), findsOneWidget);
    });

    testWidgets('C4 the player reports a prefetch summary when it closes', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump();
      await tester.pumpWidget(const SizedBox());
      expect(rig.events.last, isA<StoryPrefetchReport>());
    });
  });

  group('Data', () {
    testWidgets('D1 new data keeps the user on the item they are watching', (
      tester,
    ) async {
      final rig = _Rig(tester);
      await rig.pump(initialPosition: const StoryPosition(1, 1));
      final session = rig.delegate.sessionFor('g1-i1');
      await rig.pump(
        groups: [
          StoryGroup(
            id: 'new',
            items: const [FakeStoryItem(id: 'n')],
          ),
          ..._groups(),
        ],
        delegate: rig.delegate,
        initialPosition: const StoryPosition(1, 1),
      );
      expect(rig.at, 'g1-i1');
      expect(rig.controller.value.groupIndex, 2);
      expect(rig.delegate.sessionFor('g1-i1'), same(session));
    });
  });

  group('Theme and language', () {
    testWidgets('T1 a theme extension reaches the player', (tester) async {
      final rig = _Rig(tester);
      await rig.pump(
        theme: ThemeData(
          extensions: const [
            StoriesThemeData(progressFillColor: Color(0xFFFFC23C)),
          ],
        ),
      );
      final context = tester.element(find.byType(StoryProgressBar));
      final theme = StoriesTheme.of(context);
      expect(theme.progressFillColor, const Color(0xFFFFC23C));
      expect(theme.progressHeight, StoriesThemeData.fallback.progressHeight);
    });

    testWidgets('T2 Arabic labels reach screen readers and buttons', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final rig = _Rig(tester);
      await rig.pump(
        labels: StoriesLabels.arabic,
        textDirection: TextDirection.rtl,
      );
      expect(find.bySemanticsLabel(RegExp('القصة 1 من 2')), findsOneWidget);
      expect(find.byTooltip('إغلاق'), findsOneWidget);
      handle.dispose();
    });
  });
}
