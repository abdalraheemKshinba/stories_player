import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/src/prefetch/story_prefetcher.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

StoryMedia _image(String name) =>
    StoryMedia.network(Uri.parse('https://cdn.test/$name.webp'), bytes: 100000);

StoryMedia _video(String name, int bytes) => StoryMedia.network(
  Uri.parse('https://cdn.test/$name.mp4'),
  kind: StoryMediaKind.video,
  bytes: bytes,
);

ImageStoryItem _item(String id) => ImageStoryItem(id: id, image: _image(id));

void main() {
  final groups = [
    for (var g = 0; g < 6; g++)
      StoryGroup(
        id: 'g$g',
        avatar: _image('avatar$g'),
        items: [for (var i = 0; i < 4; i++) _item('g$g-i$i')],
      ),
  ];

  StoryPrefetcher prefetcher(
    FakeStoryMediaStore store,
    StoryNetworkQuality quality, {
    StoryPrefetchPolicy policy = StoryPrefetchPolicy.balanced,
  }) => StoryPrefetcher(
    store: store,
    policy: policy,
    signal: StoryNetworkSignal.fixed(quality),
    delegateFor: (item) => const ImageStoryDelegate(),
  );

  Set<String> requested(FakeStoryMediaStore store) => {
    for (final fetch in store.fetches)
      if (!fetch.isCancelled) fetch.media.uri!.pathSegments.last,
  };

  test('fast network: two items ahead and three groups ahead', () {
    final store = FakeStoryMediaStore();
    prefetcher(store, StoryNetworkQuality.fast).update(
      groups: groups,
      groupIndex: 0,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    expect(requested(store), {
      'g0-i1.webp',
      'g0-i2.webp',
      'g1-i0.webp',
      'g2-i0.webp',
      'g3-i0.webp',
      'avatar1.webp',
      'avatar2.webp',
      'avatar3.webp',
    });
  });

  test('slow network: one item and one group ahead', () {
    final store = FakeStoryMediaStore();
    prefetcher(store, StoryNetworkQuality.slow).update(
      groups: groups,
      groupIndex: 0,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    expect(
      requested(store).where((name) => !name.startsWith('avatar')),
      unorderedEquals(['g0-i1.webp', 'g1-i0.webp']),
    );
  });

  test('the next item gets priority over later groups', () {
    final store = FakeStoryMediaStore();
    prefetcher(store, StoryNetworkQuality.fast).update(
      groups: groups,
      groupIndex: 0,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    final next = store.fetches.firstWhere(
      (f) => f.media.uri!.path.endsWith('g0-i1.webp'),
    );
    final later = store.fetches.firstWhere(
      (f) => f.media.uri!.path.endsWith('g3-i0.webp'),
    );
    expect(next.priority, StoryFetchPriority.next);
    expect(later.priority, StoryFetchPriority.ahead);
    expect(store.fetches.first, next);
  });

  test('moving on cancels what fell out of the window', () {
    final store = FakeStoryMediaStore();
    final p = prefetcher(store, StoryNetworkQuality.fast)
      ..update(
        groups: groups,
        groupIndex: 0,
        itemIndex: 0,
        resumeItemOf: (_) => 0,
      );
    p.update(
      groups: groups,
      groupIndex: 3,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    final g0 = store.fetches.firstWhere(
      (f) => f.media.uri!.path.endsWith('g0-i1.webp'),
    );
    expect(g0.isCancelled, isTrue);
    expect(p.cancelled, greaterThan(0));
    expect(requested(store), contains('g4-i0.webp'));
  });

  test('the window is pinned and released on dispose', () {
    final store = FakeStoryMediaStore();
    final p = prefetcher(store, StoryNetworkQuality.fast)
      ..update(
        groups: groups,
        groupIndex: 0,
        itemIndex: 0,
        resumeItemOf: (_) => 0,
      );
    expect(store.pins.keys, contains('https://cdn.test/g0-i0.webp'));
    expect(store.pins.keys, contains('https://cdn.test/g0-i1.webp'));
    p.dispose();
    expect(store.pins, isEmpty);
  });

  test('videos are prefetched only within the byte budget', () {
    final store = FakeStoryMediaStore();
    final videoGroups = [
      StoryGroup(
        id: 'v',
        items: [
          _item('first'),
          _VideoItem('small', _video('small', 800000)),
          _VideoItem('big', _video('big', 9000000)),
        ],
      ),
    ];
    StoryPrefetcher(
      store: store,
      policy: StoryPrefetchPolicy.balanced,
      signal: const StoryNetworkSignal.fixed(StoryNetworkQuality.fast),
      delegateFor: (item) => const _VideoDelegate(),
    ).update(
      groups: videoGroups,
      groupIndex: 0,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    expect(requested(store), contains('small.mp4'));
    expect(requested(store), isNot(contains('big.mp4')));
  });

  test('the none policy fetches nothing', () {
    final store = FakeStoryMediaStore();
    prefetcher(
      store,
      StoryNetworkQuality.fast,
      policy: StoryPrefetchPolicy.none,
    ).update(
      groups: groups,
      groupIndex: 0,
      itemIndex: 0,
      resumeItemOf: (_) => 0,
    );
    expect(store.fetches, isEmpty);
  });

  test('measured signal follows the store speed', () {
    final store = FakeStoryMediaStore();
    const signal = StoryNetworkSignal.measured();
    expect(signal.quality(store), StoryNetworkQuality.unknown);
    store.bitsPerSecond = 500000;
    expect(signal.quality(store), StoryNetworkQuality.slow);
    store.bitsPerSecond = 8e6;
    expect(signal.quality(store), StoryNetworkQuality.fast);
  });
}

final class _VideoItem extends StoryItem {
  const _VideoItem(String id, this.video) : super(id: id);

  final StoryMedia video;

  @override
  Iterable<StoryMedia> get media => [video];
}

final class _VideoDelegate extends StoryItemDelegate {
  const _VideoDelegate();

  @override
  bool canHandle(StoryItem item) => true;

  @override
  StoryItemSession createSession(StoryItem item, StorySessionContext context) =>
      throw UnimplementedError();
}
