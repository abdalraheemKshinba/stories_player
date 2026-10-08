import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';
import 'package:stories_player_video/stories_player_video.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Records every platform call, in order, and lets tests emit events.
class FakeVideoPlatform extends VideoPlayerPlatform {
  final List<String> log = [];
  final Map<int, StreamController<VideoEvent>> events = {};
  final Map<int, Duration> positions = {};
  final Set<int> disposed = {};
  bool? mixWithOthers;
  int _next = 0;

  /// Emits the initialized event automatically when a player is created.
  bool autoInitialize = true;

  int get lastId => _next - 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _next++;
    // Like the platforms' event channels: broadcast, and the player is
    // initialized once the controller listens.
    final auto = autoInitialize;
    events[id] = StreamController<VideoEvent>.broadcast(
      onListen: () {
        if (auto) initialize(id);
      },
    );
    positions[id] = Duration.zero;
    log.add('$id:create');
    return id;
  }

  void initialize(int id) => scheduleMicrotask(
    () => events[id]!.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 4),
        size: const Size(720, 1280),
      ),
    ),
  );

  void emit(int id, VideoEventType type) =>
      events[id]!.add(VideoEvent(eventType: type));

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events[playerId]!.stream;

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    log.add('$playerId:dispose');
  }

  @override
  Future<void> play(int playerId) async => log.add('$playerId:play');

  @override
  Future<void> pause(int playerId) async => log.add('$playerId:pause');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      log.add('$playerId:volume:${volume.toStringAsFixed(0)}');

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      log.add('$playerId:looping:$looping');

  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
    log.add('$playerId:seek:${position.inMilliseconds}');
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async =>
      this.mixWithOthers = mixWithOthers;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      Texture(textureId: options.playerId);

  List<String> callsFor(int id) => [
    for (final entry in log)
      if (entry.startsWith('$id:')) entry.substring('$id:'.length),
  ];
}

/// video_player releases a player over a few asynchronous steps, part of
/// which run on real time rather than the test clock.
Future<void> _letPlatformSettle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

StoryMedia _video(String name) => StoryMedia.network(
  Uri.parse('https://cdn.test/$name.mp4'),
  kind: StoryMediaKind.video,
);

StorySessionContext _context({bool muted = true}) => StorySessionContext(
  store: FakeStoryMediaStore(),
  isMuted: muted,
  preferLowQuality: false,
  imageDuration: const Duration(seconds: 5),
);

void main() {
  late FakeVideoPlatform platform;

  setUp(() {
    platform = FakeVideoPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  Future<StoryItemSession> prepared(
    WidgetTester tester, {
    bool muted = true,
    String name = 'a',
  }) async {
    final session = const VideoStoryDelegate().createSession(
      VideoStoryItem(id: name, video: _video(name)),
      _context(muted: muted),
    );
    unawaited(session.prepare());
    await tester.pump();
    await tester.pump();
    return session;
  }

  group('Sound', () {
    testWidgets('V1 a muted video is silenced before the platform can play '
        'it', (tester) async {
      final session = await prepared(tester);
      expect(session.status, StorySessionStatus.ready);
      final calls = platform.callsFor(platform.lastId);
      final firstVolume = calls.indexWhere((c) => c.startsWith('volume'));
      expect(firstVolume, isNonNegative);
      expect(calls[firstVolume], 'volume:0');
      expect(
        calls.where((c) => c.startsWith('volume')),
        everyElement('volume:0'),
      );
      final firstPlay = calls.indexOf('play');
      expect(firstPlay == -1 || firstPlay > firstVolume, isTrue);
      session.dispose();
    });

    testWidgets('V2 videos mix with the music the user is listening to', (
      tester,
    ) async {
      final session = await prepared(tester);
      expect(platform.mixWithOthers, isTrue);
      session.dispose();
    });

    testWidgets('V3 unmuting and muting set the volume', (tester) async {
      final session = await prepared(tester);
      session.setMuted(false);
      await tester.pump();
      expect(platform.callsFor(platform.lastId).last, 'volume:1');
      session.setMuted(true);
      await tester.pump();
      expect(platform.callsFor(platform.lastId).last, 'volume:0');
      session.dispose();
    });

    testWidgets('V4 pausing and disposing reach the platform', (tester) async {
      final session = await prepared(tester);
      final id = platform.lastId;
      session.play();
      await tester.pump();
      session.pause();
      await tester.pump();
      expect(platform.callsFor(id), containsAllInOrder(['play', 'pause']));
      session.dispose();
      await _letPlatformSettle(tester);
      expect(platform.disposed, contains(id));
    });

    testWidgets('V5 a video disposed while still loading never plays', (
      tester,
    ) async {
      platform.autoInitialize = false;
      final session = const VideoStoryDelegate().createSession(
        VideoStoryItem(id: 'slow', video: _video('slow')),
        _context(),
      );
      unawaited(session.prepare());
      await tester.pump();
      final id = platform.lastId;
      session.dispose();
      platform.initialize(id);
      await _letPlatformSettle(tester);
      expect(platform.callsFor(id), isNot(contains('play')));
      expect(platform.disposed, contains(id));
    });
  });

  group('Playback state', () {
    testWidgets('V6 progress reads the platform position', (tester) async {
      final session = await prepared(tester);
      platform.positions[platform.lastId] = const Duration(milliseconds: 1500);
      session.play();
      await tester.pump(const Duration(milliseconds: 600));
      expect(session.position, const Duration(milliseconds: 1500));
      expect(session.duration, const Duration(seconds: 4));
      session.dispose();
    });

    testWidgets('V7 buffering while playing freezes, and recovers', (
      tester,
    ) async {
      final session = await prepared(tester);
      session.play();
      platform.emit(platform.lastId, VideoEventType.bufferingStart);
      await tester.pump();
      expect(session.status, StorySessionStatus.buffering);
      platform.emit(platform.lastId, VideoEventType.bufferingEnd);
      await tester.pump();
      expect(session.status, StorySessionStatus.ready);
      session.dispose();
    });

    testWidgets('V8 the end of the video completes the session, and rewind '
        'replays it', (tester) async {
      final session = await prepared(tester);
      final id = platform.lastId;
      session.play();
      platform.positions[id] = const Duration(seconds: 4);
      platform.emit(id, VideoEventType.completed);
      await tester.pump();
      expect(session.status, StorySessionStatus.completed);
      session.rewind();
      await tester.pump();
      expect(session.status, StorySessionStatus.ready);
      expect(platform.callsFor(id), contains('seek:0'));
      session.dispose();
    });

    testWidgets('V9 a playback error is reported', (tester) async {
      final session = await prepared(tester);
      platform.events[platform.lastId]!.addError(
        PlatformException(code: 'decode', message: 'Unsupported codec'),
      );
      await tester.pump();
      expect(session.status, StorySessionStatus.error);
      session.dispose();
    });
  });

  group('In the player', () {
    testWidgets('V10 leaving a video story silences and releases it; only '
        'the current story plays', (tester) async {
      tester.view
        ..physicalSize = const Size(400, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StoriesController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: StoriesPlayer(
            groups: [
              StoryGroup(
                id: 'g',
                items: [
                  VideoStoryItem(id: 'v1', video: _video('v1')),
                  VideoStoryItem(id: 'v2', video: _video('v2')),
                  VideoStoryItem(id: 'v3', video: _video('v3')),
                ],
              ),
            ],
            controller: controller,
            delegates: const [VideoStoryDelegate()],
            mediaStore: FakeStoryMediaStore(),
            playback: const StoriesPlaybackConfig(initiallyMuted: false),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(controller.value.itemId, 'v1');
      // v1 plays; v2 is prepared ahead but never played.
      expect(platform.callsFor(0), contains('play'));
      expect(platform.callsFor(1), isNot(contains('play')));

      await tester.tapAt(const Offset(320, 450));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      await _letPlatformSettle(tester);
      expect(controller.value.itemId, 'v2');
      expect(platform.callsFor(0).last, anyOf('pause', 'dispose'));
      expect(platform.disposed, contains(0));
      expect(platform.callsFor(1), contains('play'));

      // Only one player has been told to play and not told to stop.
      final audible = <int>{};
      for (final entry in platform.log) {
        final id = int.parse(entry.split(':').first);
        final call = entry.split(':')[1];
        if (call == 'play') audible.add(id);
        if (call == 'pause' || call == 'dispose') audible.remove(id);
      }
      expect(audible, {1});
      await tester.pumpWidget(const SizedBox());
    });
  });
}
