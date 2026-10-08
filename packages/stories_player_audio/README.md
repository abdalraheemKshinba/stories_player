# stories_player_audio

Music for [stories_player](https://pub.dev/packages/stories_player) image and
Lottie items, played through `audioplayers`.

```dart
StoriesPlayer(
  groups: [
    StoryGroup(id: 'g', items: [
      ImageStoryItem(
        id: 'deal',
        image: StoryMedia.network(Uri.parse('https://cdn.example.com/deal.webp')),
        audio: StoryAudio(
          StoryMedia.network(
            Uri.parse('https://cdn.example.com/track.m4a'),
            kind: StoryMediaKind.audio,
          ),
        ),
      ),
    ]),
  ],
  audio: AudioplayersStoryAudio(),
)
```

Stories start muted; the header shows a mute button on items with music.
Tracks are cached with the rest of the story media.

See every feature in action in the
[stories_player README](https://pub.dev/packages/stories_player#see-it-in-action),
and the source in [abdalraheemKshinba/stories_player](https://github.com/abdalraheemKshinba/stories_player).
