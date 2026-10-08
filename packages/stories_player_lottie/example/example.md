# Lottie stories

```dart
import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player_lottie/stories_player_lottie.dart';

void main() => runApp(
  MaterialApp(
    home: StoriesPlayer(
      groups: [
        StoryGroup(
          id: 'celebrate',
          label: 'Order delivered',
          items: const [
            LottieStoryItem(
              id: 'confetti',
              animation: StoryMedia.asset(
                'assets/confetti.json', // or a .lottie file
                kind: StoryMediaKind.lottie,
              ),
              backgroundColor: Color(0xFF2B1B4A),
            ),
          ],
        ),
      ],
      delegates: const [LottieStoryDelegate()],
    ),
  ),
);
```

A complete app with every feature is in the
[stories_player example](https://github.com/abdalraheemKshinba/stories_player/tree/main/packages/stories_player/example).
