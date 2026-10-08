# stories_player_lottie

Lottie animation items for
[stories_player](https://pub.dev/packages/stories_player).

```dart
StoriesPlayer(
  groups: [
    StoryGroup(id: 'g', items: [
      LottieStoryItem(
        id: 'confetti',
        animation: StoryMedia.network(
          Uri.parse('https://cdn.example.com/confetti.json'),
          kind: StoryMediaKind.lottie,
        ),
        backgroundColor: const Color(0xFF2B1B4A),
      ),
    ]),
  ],
  delegates: const [LottieStoryDelegate()],
)
```

* The animation runs on the story's own clock: it pauses with the story and
  never drifts from the progress bar.
* Without a `duration`, the item lasts as long as the animation.
* Set `loop: true` to repeat it until the item ends, and `audio:` to add music
  (with `stories_player_audio`).
* Full-screen animations render without a raster cache by default, to keep
  memory low on small devices.

See every feature in action in the
[stories_player README](https://pub.dev/packages/stories_player#see-it-in-action),
and the source in [abdalraheemKshinba/stories_player](https://github.com/abdalraheemKshinba/stories_player).
