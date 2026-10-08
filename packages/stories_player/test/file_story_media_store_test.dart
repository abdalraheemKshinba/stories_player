@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';

/// A local HTTP server that serves deterministic bytes and honours Range.
class _Server {
  late HttpServer _server;
  final Map<String, int> sizes = {};
  final List<String?> ranges = [];
  Duration chunkDelay = Duration.zero;

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Uri uri(String name) => Uri.parse('http://127.0.0.1:${_server.port}/$name');

  StoryMedia media(String name, int size, {StoryMediaKind? kind}) {
    sizes[name] = size;
    return StoryMedia.network(
      uri(name),
      bytes: size,
      kind: kind ?? StoryMediaKind.image,
    );
  }

  Future<void> _handle(HttpRequest request) async {
    final name = request.uri.pathSegments.last;
    final size = sizes[name];
    final response = request.response;
    if (size == null) {
      response.statusCode = 404;
      await response.close();
      return;
    }
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges.add(range);
    var start = 0;
    var end = size - 1;
    if (range != null) {
      final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(range)!;
      start = int.parse(match.group(1)!);
      if (match.group(2)!.isNotEmpty) end = int.parse(match.group(2)!);
      if (start >= size) {
        response.statusCode = 416;
        await response.close();
        return;
      }
      response
        ..statusCode = 206
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/$size',
        );
    }
    response.contentLength = end - start + 1;
    const chunk = 16 * 1024;
    try {
      for (var offset = start; offset <= end; offset += chunk) {
        final length = (end + 1 - offset).clamp(0, chunk);
        response.add(Uint8List(length)..fillRange(0, length, offset % 251));
        await response.flush();
        if (chunkDelay > Duration.zero) await Future<void>.delayed(chunkDelay);
      }
      await response.close();
    } on Object {
      // The client aborted.
    }
  }

  Future<void> close() => _server.close(force: true);
}

void main() {
  late Directory dir;
  late _Server server;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('stories_store_test');
    server = _Server();
    await server.start();
  });

  tearDown(() async {
    await server.close();
    await dir.delete(recursive: true);
  });

  FileStoryMediaStore store({int maxBytes = 1 << 20, Duration? maxAge}) =>
      FileStoryMediaStore(
        directory: dir.path,
        maxBytes: maxBytes,
        maxAge: maxAge ?? const Duration(days: 2),
      );

  test('downloads a file, keeps its extension, and finds it again', () async {
    final s = store();
    final media = server.media('clip.mp4', 100000, kind: StoryMediaKind.video);
    final path = await s.fetch(media);
    expect(path, isNotNull);
    expect(path, endsWith('.mp4'));
    expect(await File(path!).length(), 100000);
    expect(s.lookup(media), path);
    expect(await s.fetch(media), path);
    expect(server.ranges, hasLength(1));
    await s.dispose();
  });

  test(
    'stays under its byte limit by evicting the least recently used',
    () async {
      final s = store(maxBytes: 250000);
      final a = server.media('a.jpg', 100000);
      final b = server.media('b.jpg', 100000);
      final c = server.media('c.jpg', 100000);
      await s.fetch(a);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await s.fetch(b);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      s.lookup(a); // a is now more recent than b
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await s.fetch(c);
      final usage = await s.usage();
      expect(usage.bytes, lessThanOrEqualTo(250000));
      expect(s.lookup(b), isNull);
      expect(s.lookup(a), isNotNull);
      expect(s.lookup(c), isNotNull);
      await s.dispose();
    },
  );

  test('never evicts pinned media', () async {
    final s = store(maxBytes: 150000);
    final a = server.media('a.jpg', 100000);
    final b = server.media('b.jpg', 100000);
    await s.fetch(a);
    s.pin(a);
    await s.fetch(b);
    expect(s.lookup(a), isNotNull);
    s.unpin(a);
    await s.dispose();
  });

  test(
    'a prefix fetch keeps the bytes, and a full fetch resumes with Range',
    () async {
      final s = store();
      final media = server.media('v.mp4', 200000, kind: StoryMediaKind.video);
      expect(await s.fetch(media, maxBytes: 50000), isNull);
      expect((await s.usage()).bytes, greaterThanOrEqualTo(50000));
      final path = await s.fetch(media);
      expect(await File(path!).length(), 200000);
      expect(server.ranges.first, 'bytes=0-49999');
      expect(server.ranges.last, startsWith('bytes=5'));
      await s.dispose();
    },
  );

  test('cancelling completes with null and keeps partial bytes', () async {
    final s = store();
    server.chunkDelay = const Duration(milliseconds: 20);
    final media = server.media('slow.mp4', 400000, kind: StoryMediaKind.video);
    final token = StoryFetchToken();
    final future = s.fetch(media, token: token);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    token.cancel();
    expect(await future, isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final usage = await s.usage();
    expect(usage.bytes, greaterThan(0));
    expect(usage.bytes, lessThan(400000));
    expect(s.lookup(media), isNull);
    await s.dispose();
  });

  test('purges expired media', () async {
    final s = store();
    final media = server.media('old.jpg', 1000);
    await s.fetch(
      media,
      expiresAt: DateTime.now().add(const Duration(milliseconds: 50)),
    );
    expect(s.lookup(media), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await s.purgeExpired();
    expect(s.lookup(media), isNull);
    expect((await s.usage()).entries, 0);
    await s.dispose();
  });

  test('reports failures as StoryMediaException', () async {
    final s = store();
    final missing = StoryMedia.network(server.uri('missing.jpg'));
    await expectLater(s.fetch(missing), throwsA(isA<StoryMediaException>()));
    await s.dispose();
  });

  test('reopens from its index', () async {
    final first = store();
    final media = server.media('keep.jpg', 5000);
    final path = await first.fetch(media);
    await first.dispose();
    final second = store();
    await second.purgeExpired(); // opens the store
    expect(second.lookup(media), path);
    await second.dispose();
  });

  test('measures download speed', () async {
    final s = store();
    server.chunkDelay = const Duration(milliseconds: 2);
    await s.fetch(server.media('big.jpg', 600000));
    expect(s.estimatedBitsPerSecond, isNotNull);
    await s.dispose();
  });
}
