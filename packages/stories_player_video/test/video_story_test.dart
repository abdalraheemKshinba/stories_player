import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';
import 'package:stories_player_video/stories_player_video.dart';

void main() {
  final video = StoryMedia.network(
    Uri.parse('https://cdn.test/v.mp4'),
    kind: StoryMediaKind.video,
    bytes: 900000,
  );

  test('the delegate handles only video items', () {
    const delegate = VideoStoryDelegate();
    expect(delegate.canHandle(VideoStoryItem(id: 'v', video: video)), isTrue);
    expect(delegate.canHandle(const FakeStoryItem(id: 'f')), isFalse);
  });

  test('videos report sound unless told otherwise', () {
    expect(VideoStoryItem(id: 'v', video: video).hasAudio, isTrue);
    expect(
      VideoStoryItem(id: 'v', video: video, hasSound: false).hasAudio,
      isFalse,
    );
  });

  test('a small video is prefetched, a large one is not', () {
    const delegate = VideoStoryDelegate();
    final item = VideoStoryItem(id: 'v', video: video);
    const roomy = StoryPrefetchContext(
      preferLowQuality: false,
      maxVideoBytes: 1000000,
    );
    const tight = StoryPrefetchContext(
      preferLowQuality: false,
      maxVideoBytes: 500000,
    );
    expect(delegate.prefetch(item, roomy).map((r) => r.media), [video]);
    expect(delegate.prefetch(item, tight), isEmpty);
  });

  test('slow networks fetch the low rendition', () {
    final low = StoryMedia.network(
      Uri.parse('https://cdn.test/v-480.mp4'),
      kind: StoryMediaKind.video,
      bytes: 300000,
    );
    final item = VideoStoryItem(
      id: 'v',
      video: StoryMedia.network(
        Uri.parse('https://cdn.test/v.mp4'),
        kind: StoryMediaKind.video,
        bytes: 2000000,
        lowQuality: low,
      ),
    );
    const slow = StoryPrefetchContext(
      preferLowQuality: true,
      maxVideoBytes: 1000000,
    );
    expect(const VideoStoryDelegate().prefetch(item, slow).single.media, low);
  });
}
