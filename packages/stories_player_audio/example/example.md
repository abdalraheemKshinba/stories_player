# Music behind stories

```dart
import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player_audio/stories_player_audio.dart';

void main() => runApp(
  MaterialApp(
    home: StoriesPlayer(
      groups: [
        StoryGroup(
          id: 'market',
          label: 'Fresh Market',
          items: [
            ImageStoryItem(
              id: 'strawberries',
              image: StoryMedia.network(
                Uri.parse('https://cdn.example.com/strawberries.webp'),
              ),
              audio: StoryAudio(
                StoryMedia.network(
                  Uri.parse('https://cdn.example.com/track.m4a'),
                  kind: StoryMediaKind.audio,
                ),
              ),
            ),
          ],
        ),
      ],
      audio: AudioplayersStoryAudio(),
    ),
  ),
);
```

Stories start muted; the header shows a mute button on items with music.
