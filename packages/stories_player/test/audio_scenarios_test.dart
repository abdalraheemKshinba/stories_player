// Sound scenarios: music must stop when its story is left, never mix with
// another story's sound, and survive taps faster than the audio plugin.
// Ids (A1, ...) match doc/scenarios.md.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

/// An item with a music track, played the way image and Lottie items play
/// theirs: through a [StoryAudioTrack].
final class _MusicItem extends StoryItem {
  _MusicItem(String id, {String? track})
    : audio = track == null
          ? null
          : StoryAudio(
              StoryMedia.asset('music/$track', kind: StoryMediaKind.audio),
            ),
      super(id: id, duration: const Duration(seconds: 5));

  final StoryAudio? audio;

  @override
  Iterable<StoryMedia> get media => [if (audio != null) audio!.media];

  @override
  bool get hasAudio => audio != null;
}

final class _MusicDelegate extends StoryItemDelegate {
  final List<_MusicSession> sessions = [];

  @override
  bool canHandle(StoryItem item) => item is _MusicItem;

  @override
  StoryItemSession createSession(StoryItem item, StorySessionContext context) {
    final session = _MusicSession(item as _MusicItem, context);
    sessions.add(session);
    return session;
  }
}

final class _MusicSession extends StoryItemSession {
  _MusicSession(_MusicItem super.item, super.context)
    : _track = item.audio == null
          ? null
          : StoryAudioTrack(
              audio: item.audio!,
              backend: context.audio,
              store: context.store,
              muted: context.isMuted,
            );

  final StoryAudioTrack? _track;

  @override
  Future<void> onPrepare() async {}

  @override
  void play() => _track?.play();

  @override
  void pause() => _track?.pause();

  @override
  void setMuted(bool muted) => _track?.setMuted(muted);

  @override
  void rewind() {
    _track?.rewind();
    super.rewind();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.black);

  @override
  void dispose() {
    _track?.dispose();
    super.dispose();
  }
}

class _Rig {
  _Rig(this.tester);

  final WidgetTester tester;
  final FakeStoryAudioBackend audio = FakeStoryAudioBackend();
  final StoriesController controller = StoriesController();
  final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();

  String? get playing =>
      audio.isPlaying ? audio.current!.cacheKey.split('/').last : null;

  Future<void> pump(List<StoryItem> items, {int maxPreparedItems = 2}) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: StoriesPlayer(
          groups: [StoryGroup(id: 'g', items: items)],
          controller: controller,
          delegates: [_MusicDelegate()],
          audio: audio,
          mediaStore: FakeStoryMediaStore(),
          playback: StoriesPlaybackConfig(maxPreparedItems: maxPreparedItems),
          onDismiss: (_) {},
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets every queued audio command finish.
  Future<void> settle() async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  }

  Future<void> tapNext() async {
    await tester.tapAt(const Offset(320, 450));
    await tester.pump(const Duration(milliseconds: 5));
  }

  Future<void> tapPrevious() async {
    await tester.tapAt(const Offset(40, 450));
    await tester.pump(const Duration(milliseconds: 5));
  }
}

/// Runs [body], then closes the player and lets its last audio commands
/// finish, so no audio timer outlives the test.
void _audioTest(
  String description,
  Future<void> Function(WidgetTester tester) body,
) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
  });
}

void main() {
  _audioTest('A1 leaving a story stops its music, even when the tap comes '
      'before the music finished starting', (tester) async {
    final rig = _Rig(tester);
    await rig.pump([_MusicItem('a', track: 'a.m4a'), _MusicItem('silent')]);
    await rig.tapNext(); // the play of a.m4a is still in flight
    await rig.settle();
    expect(rig.playing, isNull);
    expect(rig.audio.overlaps, 0);
  });

  _audioTest('A2 moving from one track to another plays only the new one', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([
      _MusicItem('a', track: 'a.m4a'),
      _MusicItem('b', track: 'b.m4a'),
    ]);
    await rig.settle();
    expect(rig.playing, 'a.m4a');
    await rig.tapNext();
    await rig.settle();
    expect(rig.playing, 'b.m4a');
    expect(rig.audio.log.last, 'play:b.m4a');
    expect(rig.audio.overlaps, 0);
  });

  _audioTest('A3 rapid taps through several tracks end on the last track '
      'only', (tester) async {
    final rig = _Rig(tester);
    await rig.pump([
      for (final id in ['a', 'b', 'c', 'd']) _MusicItem(id, track: '$id.m4a'),
    ]);
    for (var i = 0; i < 3; i++) {
      await rig.tapNext();
    }
    await rig.settle();
    expect(rig.controller.value.itemId, 'd');
    expect(rig.playing, 'd.m4a');
    expect(rig.audio.overlaps, 0);
  });

  _audioTest('A4 holding pauses the music and releasing resumes it', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([_MusicItem('a', track: 'a.m4a')]);
    await rig.settle();
    final gesture = await tester.startGesture(const Offset(200, 450));
    await rig.settle();
    expect(rig.playing, isNull);
    expect(rig.audio.current, isNotNull, reason: 'paused, not stopped');
    await gesture.up();
    await rig.settle();
    expect(rig.playing, 'a.m4a');
  });

  _audioTest('A5 unmuting applies now and carries to the next track', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([
      _MusicItem('a', track: 'a.m4a'),
      _MusicItem('b', track: 'b.m4a'),
    ]);
    await rig.settle();
    expect(rig.audio.isMuted, isTrue);
    rig.controller.setMuted(false);
    await rig.settle();
    expect(rig.audio.isMuted, isFalse);
    await rig.tapNext();
    await rig.settle();
    expect(rig.playing, 'b.m4a');
    expect(rig.audio.isMuted, isFalse);
  });

  _audioTest('A6 the app going to the background stops the music', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([_MusicItem('a', track: 'a.m4a')]);
    await rig.settle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await rig.settle();
    expect(rig.playing, isNull);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await rig.settle();
    expect(rig.playing, 'a.m4a');
  });

  _audioTest('A7 closing the player stops the music', (tester) async {
    final rig = _Rig(tester);
    await rig.pump([_MusicItem('a', track: 'a.m4a')]);
    await rig.settle();
    await tester.pumpWidget(const SizedBox());
    await rig.settle();
    expect(rig.playing, isNull);
  });

  _audioTest('A8 going back to a story kept warm restarts its track', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([
      _MusicItem('a', track: 'a.m4a'),
      _MusicItem('silent'),
    ], maxPreparedItems: 3);
    await rig.settle();
    await rig.tapNext();
    await rig.settle();
    expect(rig.playing, isNull);
    await rig.tapPrevious();
    await rig.settle();
    expect(rig.playing, 'a.m4a');
    // From the beginning (a new play), not a resume where it was left.
    expect(rig.audio.log.last, 'play:a.m4a');
  });

  _audioTest('A9 an old story released late never silences the new one', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([
      _MusicItem('a', track: 'a.m4a'),
      _MusicItem('b', track: 'b.m4a'),
      _MusicItem('c', track: 'c.m4a'),
    ], maxPreparedItems: 3);
    await rig.settle();
    await rig.tapNext(); // a is kept warm, b plays
    await rig.settle();
    expect(rig.playing, 'b.m4a');
    await rig.tapNext(); // a is released only now, while c starts
    await rig.settle();
    expect(rig.playing, 'c.m4a');
    expect(rig.audio.overlaps, 0);
  });

  _audioTest('A10 a route on top pauses the music', (tester) async {
    final rig = _Rig(tester);
    await rig.pump([_MusicItem('a', track: 'a.m4a')]);
    await rig.settle();
    unawaited(
      rig.navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Scaffold()),
      ),
    );
    await rig.settle();
    expect(rig.playing, isNull);
    rig.navigator.currentState!.pop();
    await rig.settle();
    expect(rig.playing, 'a.m4a');
  });

  _audioTest('A11 the mute button never makes two tracks audible', (
    tester,
  ) async {
    final rig = _Rig(tester);
    await rig.pump([
      _MusicItem('a', track: 'a.m4a'),
      _MusicItem('b', track: 'b.m4a'),
    ]);
    await rig.tapNext();
    rig.controller.setMuted(false);
    await rig.tapPrevious();
    await rig.settle();
    expect(rig.controller.value.itemId, 'a');
    expect(rig.playing, 'a.m4a');
    expect(rig.audio.overlaps, 0);
  });
}
