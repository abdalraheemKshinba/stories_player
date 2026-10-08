import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';
import 'package:stories_player_lottie/stories_player_lottie.dart';

Future<Uint8List> _example(String name) =>
    File('../stories_player/example/assets/lottie/$name.json').readAsBytes();

/// A one-layer animation whose only layer shows an image embedded as a
/// base64 data URI.
Uint8List _withEmbeddedImage() => utf8.encode(
  jsonEncode({
    'v': '5.7.4',
    'fr': 30,
    'ip': 0,
    'op': 30,
    'w': 100,
    'h': 100,
    'assets': [
      {
        'id': 'img_0',
        'w': 4,
        'h': 4,
        'u': '',
        'p':
            'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkp'
            'AAAAEElEQVR4nGP4HyUHRwzEcQBvwhdx9HHUcwAAAABJRU5ErkJggg==',
        'e': 1,
      },
    ],
    'layers': [
      {
        'ddd': 0,
        'ind': 1,
        'ty': 2,
        'nm': 'image',
        'refId': 'img_0',
        'sr': 1,
        'ks': {
          'o': {'a': 0, 'k': 100},
          'r': {'a': 0, 'k': 0},
          'p': {
            'a': 0,
            'k': [50, 50, 0],
          },
          'a': {
            'a': 0,
            'k': [2, 2, 0],
          },
          's': {
            'a': 0,
            'k': [100, 100, 100],
          },
        },
        'ao': 0,
        'ip': 0,
        'op': 30,
        'st': 0,
        'bm': 0,
      },
    ],
  }),
);

/// A dotLottie archive: a manifest plus the animation under `animations/`.
Uint8List _dotLottie(Uint8List json) {
  final archive = Archive()
    ..addFile(
      ArchiveFile.bytes(
        'manifest.json',
        utf8.encode('{"animations":[{"id":"a"}]}'),
      ),
    )
    ..addFile(ArchiveFile.bytes('animations/a.json', json));
  return ZipEncoder().encodeBytes(archive);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Files', () {
    for (final name in ['celebrate', 'preparing']) {
      test('the example animation "$name" parses off the UI thread and '
          'lasts 4 seconds', () async {
        final composition = await LottieCompositionCache.parse(
          await _example(name),
        );
        expect(composition.duration, const Duration(seconds: 4));
        expect(composition.layers, isNotEmpty);
      });
    }

    test('a dotLottie archive is unzipped and its animation found', () async {
      final bytes = _dotLottie(await _example('celebrate'));
      expect(LottieCompositionCache.isZip(bytes), isTrue);
      final composition = await LottieCompositionCache.parse(bytes);
      expect(composition.duration, const Duration(seconds: 4));
    });

    testWidgets('images embedded as data URIs are loaded', (tester) async {
      final composition = await tester.runAsync(
        () => LottieCompositionCache.parse(_withEmbeddedImage()),
      );
      final image = composition!.images['img_0']!;
      expect(image.loadedImage, isNotNull);
      expect(image.loadedImage!.width, 4);
    });

    test('plain JSON is not mistaken for a zip', () async {
      expect(LottieCompositionCache.isZip(await _example('preparing')), false);
    });
  });

  group('Cache', () {
    test('sessions asking at once share one load', () async {
      final cache = LottieCompositionCache();
      var loads = 0;
      Future<Uint8List> load() async {
        loads++;
        return _example('preparing');
      }

      final results = await Future.wait([
        cache.get('a', load),
        cache.get('a', load),
      ]);
      expect(loads, 1);
      expect(identical(results[0], results[1]), isTrue);
    });

    test('the least recently used animation is dropped first', () async {
      final cache = LottieCompositionCache(maxEntries: 2);
      final bytes = await _example('preparing');
      await cache.get('a', () async => bytes);
      await cache.get('b', () async => bytes);
      await cache.get('a', () async => bytes); // a is now the most recent
      await cache.get('c', () async => bytes);
      expect(cache.contains('a'), isTrue);
      expect(cache.contains('b'), isFalse);
      expect(cache.contains('c'), isTrue);
    });

    test('a failed load is not cached, so a retry loads again', () async {
      final cache = LottieCompositionCache();
      var loads = 0;
      await expectLater(
        cache.get('x', () async {
          loads++;
          throw const FormatException('offline');
        }),
        throwsFormatException,
      );
      await Future<void>.delayed(Duration.zero);
      expect(cache.contains('x'), isFalse);
      await cache.get('x', () async {
        loads++;
        return _example('preparing');
      });
      expect(loads, 2);
    });
  });

  group('Items', () {
    test('the delegate handles only Lottie items', () {
      const delegate = LottieStoryDelegate();
      const item = LottieStoryItem(
        id: 'l',
        animation: StoryMedia.asset('a.json', kind: StoryMediaKind.lottie),
      );
      expect(delegate.canHandle(item), isTrue);
      expect(delegate.canHandle(const FakeStoryItem(id: 'f')), isFalse);
      expect(item.hasAudio, isFalse);
      expect(item.media, [item.animation]);
    });

    test('items with music report sound and include the track', () {
      const music = StoryAudio(
        StoryMedia.asset('m.wav', kind: StoryMediaKind.audio),
      );
      const item = LottieStoryItem(
        id: 'l',
        animation: StoryMedia.asset('a.json', kind: StoryMediaKind.lottie),
        audio: music,
        backgroundColor: Color(0xFF000000),
      );
      expect(item.hasAudio, isTrue);
      expect(item.media, contains(music.media));
    });

    testWidgets('a session takes the animation length and follows the story '
        'clock, looping or holding the last frame', (tester) async {
      final dir = await tester.runAsync(
        () => Directory.systemTemp.createTemp('lottie_session'),
      );
      addTearDown(() => dir!.deleteSync(recursive: true));
      final bytes = await tester.runAsync(() => _example('preparing'));
      final file = File('${dir!.path}/preparing.json')
        ..writeAsBytesSync(bytes!);

      Future<StoryItemSession> prepared({required bool loop}) async {
        final session = LottieStoryDelegate(cache: LottieCompositionCache())
            .createSession(
              LottieStoryItem(
                id: loop ? 'loop' : 'once',
                animation: StoryMedia.file(
                  file.path,
                  kind: StoryMediaKind.lottie,
                ),
                loop: loop,
              ),
              StorySessionContext(
                store: FakeStoryMediaStore(),
                isMuted: true,
                preferLowQuality: false,
                imageDuration: const Duration(seconds: 5),
              ),
            );
        await tester.runAsync(session.prepare);
        return session;
      }

      Animation<double> progress() =>
          tester.widget<Lottie>(find.byType(Lottie)).controller!;
      Future<void> show(StoryItemSession session) => tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: session.build),
        ),
      );

      final once = await prepared(loop: false);
      expect(once.status, StorySessionStatus.ready);
      expect(once.duration, const Duration(seconds: 4));
      await show(once);
      once.onTick(const Duration(seconds: 2), 0.5);
      expect(progress().value, closeTo(0.5, 0.001));
      once.onTick(const Duration(seconds: 6), 1);
      expect(progress().value, 1, reason: 'holds the last frame');

      final loop = await prepared(loop: true);
      await show(loop);
      loop.onTick(const Duration(seconds: 5), 1);
      expect(progress().value, closeTo(0.25, 0.001), reason: 'wraps around');
      loop.rewind();
      expect(progress().value, 0);

      once.dispose();
      loop.dispose();
    });
  });
}
