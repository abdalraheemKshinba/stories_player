# Video stories

```dart
import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player_video/stories_player_video.dart';

void main() => runApp(
  MaterialApp(
    home: StoriesPlayer(
      groups: [
        StoryGroup(
          id: 'kitchen',
          label: 'Our kitchen',
          items: [
            VideoStoryItem(
              id: 'grill',
              video: StoryMedia.network(
                Uri.parse('https://cdn.example.com/grill/720.mp4'),
                kind: StoryMediaKind.video,
                bytes: 2201600,
              ),
              poster: StoryMedia.network(
                Uri.parse('https://cdn.example.com/grill/poster.webp'),
              ),
            ),
          ],
        ),
      ],
      delegates: const [VideoStoryDelegate()],
    ),
  ),
);
```

A complete app with every feature is in the
[stories_player example](https://github.com/abdalraheemKshinba/stories_player/tree/main/packages/stories_player/example).
