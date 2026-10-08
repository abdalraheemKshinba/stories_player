# stories_player_video

Video items for [stories_player](https://pub.dev/packages/stories_player),
played through `video_player`.

```dart
StoriesPlayer(
  groups: [
    StoryGroup(id: 'g', items: [
      VideoStoryItem(
        id: 'grill',
        video: StoryMedia.network(
          Uri.parse('https://cdn.example.com/grill/720.mp4'),
          kind: StoryMediaKind.video,
          bytes: 2201600,
          lowQuality: StoryMedia.network(
            Uri.parse('https://cdn.example.com/grill/480.mp4'),
            kind: StoryMediaKind.video,
            bytes: 880000,
          ),
        ),
        poster: StoryMedia.network(Uri.parse('https://cdn.example.com/grill.webp')),
      ),
    ]),
  ],
  delegates: const [VideoStoryDelegate()],
)
```

* Plays from the stories cache when the file is there, and streams it
  otherwise.
* Progress follows the video's own position, so it freezes while buffering.
* A video shorter than its item's `duration` holds its last frame.
* Slow networks get the `lowQuality` rendition.
* Small videos are prefetched whole on fast networks. The next item's player
  is prepared ahead, so it starts instantly.

Use faststart MP4 (H.264 + AAC) for the quickest start.

See every feature in action in the
[stories_player README](https://pub.dev/packages/stories_player#see-it-in-action),
and the source in [abdalraheemKshinba/stories_player](https://github.com/abdalraheemKshinba/stories_player).
