# stories_player

Fast, right-to-left-ready **stories** for Flutter: image, video, Lottie and
any-widget stories with the gestures people expect, a progress bar that never
lies, smart prefetching, and a media cache that respects the user's storage.

[![CI](https://github.com/abdalraheemKshinba/stories_player/actions/workflows/ci.yml/badge.svg)](https://github.com/abdalraheemKshinba/stories_player/actions/workflows/ci.yml)
[![pub](https://img.shields.io/pub/v/stories_player.svg)](https://pub.dev/packages/stories_player)
[![license](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

<p align="center">
  <img src="packages/stories_player/doc/screenshots/demo.gif" width="300" alt="Playing stories: tap to the next story, cube swipe to the next group, hold to pause">
</p>

> **Live demo:** coming soon.

## See it in action

Every clip is the [example app](packages/stories_player/example). Click a
clip for the full-quality video.

<table>
<tr><td align="center" width="33%"><a href="doc/media/tap_through.mp4"><img src="doc/media/tap_through.gif" width="240" alt="Tap through stories"></a><br><b>Tap through stories</b><br><sub>Lottie with music, a widget card, then a video</sub></td><td align="center" width="33%"><a href="doc/media/hold_to_pause.mp4"><img src="doc/media/hold_to_pause.gif" width="240" alt="Hold to pause"></a><br><b>Hold to pause</b><br><sub>The video stops and the overlays hide until you let go</sub></td><td align="center" width="33%"><a href="doc/media/swipe_down.mp4"><img src="doc/media/swipe_down.gif" width="240" alt="Drag down to close"></a><br><b>Drag down to close</b><br><sub>The app shows behind; a short drag springs back, a fling closes, even at an angle</sub></td></tr>
<tr><td align="center" width="33%"><a href="doc/media/swipe_groups.mp4"><img src="doc/media/swipe_groups.gif" width="240" alt="Swipe between groups"></a><br><b>Swipe between groups</b><br><sub>Right to left in Arabic, like everything else</sub></td><td align="center" width="33%"><a href="doc/media/cube_transition.mp4"><img src="doc/media/cube_transition.gif" width="240" alt="Cube transition"></a><br><b>Cube transition</b><br><sub>Optional; the default is a light slide</sub></td><td align="center" width="33%"><a href="doc/media/order_sheet.mp4"><img src="doc/media/order_sheet.gif" width="240" alt="Call to action"></a><br><b>Call to action</b><br><sub>The story pauses while your own sheet is open</sub></td></tr>
<tr><td align="center" width="33%"><a href="doc/media/error_retry.mp4"><img src="doc/media/error_retry.gif" width="240" alt="Error and retry"></a><br><b>Error and retry</b><br><sub>Automatic retry, visible progress, then Skip</sub></td><td align="center" width="33%"><a href="doc/media/seen_resume.mp4"><img src="doc/media/seen_resume.gif" width="240" alt="Resume where they left"></a><br><b>Resume where they left</b><br><sub>Opens at the first story not yet watched</sub></td><td align="center" width="33%"><a href="doc/media/rtl_tap_zones.mp4"><img src="doc/media/rtl_tap_zones.gif" width="240" alt="Right-to-left tap zones"></a><br><b>Right-to-left tap zones</b><br><sub>Arabic: the left side goes forward</sub></td></tr>
</table>

## Every kind of story

<table>
<tr><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/home.webp" width="190" alt="Story tray"><br><b>Story tray</b><br><sub>Your own tray; the player opens from any group</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/image_music.webp" width="190" alt="Image + music"><br><b>Image + music</b><br><sub>Segmented progress, caption, music that stops with its story</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/video.webp" width="190" alt="Video"><br><b>Video</b><br><sub>Progress follows the video, so it waits while buffering</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/bakery_video.webp" width="190" alt="Silent video"><br><b>Silent video</b><br><sub>No sound button when there is nothing to hear</sub></td></tr>
<tr><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/lottie_music.webp" width="190" alt="Lottie + music"><br><b>Lottie + music</b><br><sub>Parsed off the UI thread and cached</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/lottie_loop.webp" width="190" alt="Looping Lottie"><br><b>Looping Lottie</b><br><sub>Loops on the story clock</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/widget_story.webp" width="190" alt="Any widget"><br><b>Any widget</b><br><sub>Build the story yourself; it still gets progress and gestures</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/text_story.webp" width="190" alt="Text story"><br><b>Text story</b><br><sub>A plain widget story with a gradient</sub></td></tr>
</table>

## Every case handled

<table>
<tr><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/rtl_arabic.webp" width="190" alt="Right to left"><br><b>Right to left</b><br><sub>Progress, tap zones and swipes mirror; Arabic labels built in</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/custom_theme_cta.webp" width="190" alt="Theme + call to action"><br><b>Theme + call to action</b><br><sub>StoriesTheme and your own footer</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/tap_zones_ltr.webp" width="190" alt="Tap zones"><br><b>Tap zones</b><br><sub>Back on the left 30%, next on the rest</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/tap_zones_rtl.webp" width="190" alt="Tap zones, mirrored"><br><b>Tap zones, mirrored</b><br><sub>Next on the left in Arabic</sub></td></tr>
<tr><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/hold_to_pause.webp" width="190" alt="Hold to pause"><br><b>Hold to pause</b><br><sub>Overlays hide while held</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/swipe_down.webp" width="190" alt="Drag down"><br><b>Drag down</b><br><sub>The page behind shows through</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/cube_swipe.webp" width="190" alt="Cube swipe"><br><b>Cube swipe</b><br><sub>Between groups, following the finger</sub></td><td align="center" width="25%"><img src="packages/stories_player/doc/screenshots/error_retry.webp" width="190" alt="Can't load"><br><b>Can't load</b><br><sub>Readable over any background, with Retry</sub></td></tr>
</table>

Each behaviour is written down as a scenario in
[doc/scenarios.md](packages/stories_player/doc/scenarios.md), each tied to the
test that proves it.

## Quick start

```yaml
dependencies:
  stories_player: ^0.1.0
  stories_player_video: ^0.1.0   # only if you show videos
  stories_player_lottie: ^0.1.0  # only if you show Lottie
  stories_player_audio: ^0.1.0   # only if you play music
```

```dart
import 'package:stories_player/stories_player.dart';

final groups = [
  StoryGroup(
    id: 'market',
    label: 'Fresh Market',
    avatar: StoryMedia.network(Uri.parse('https://cdn.example.com/market.webp')),
    items: [
      ImageStoryItem(
        id: 'strawberries',
        image: StoryMedia.network(Uri.parse('https://cdn.example.com/s1.webp')),
        caption: 'Strawberries are in season.',
      ),
    ],
  ),
];

Navigator.of(context).push(
  MaterialPageRoute<void>(builder: (_) => StoriesPlayer(groups: groups)),
);
```

That is a complete player: progress bar, header, caption, gestures, caching
and prefetching included. The [stories_player README](packages/stories_player/README.md)
covers a real setup, controlling the player, caching, customizing and
performance on small phones.

## Packages

| package | what it adds | pub.dev |
|---|---|---|
| [`stories_player`](packages/stories_player) | the player, image and widget items, cache, prefetch, theme | [![pub](https://img.shields.io/pub/v/stories_player.svg)](https://pub.dev/packages/stories_player) |
| [`stories_player_video`](packages/stories_player_video) | video items, over `video_player` | [![pub](https://img.shields.io/pub/v/stories_player_video.svg)](https://pub.dev/packages/stories_player_video) |
| [`stories_player_lottie`](packages/stories_player_lottie) | Lottie items, over `lottie` | [![pub](https://img.shields.io/pub/v/stories_player_lottie.svg)](https://pub.dev/packages/stories_player_lottie) |
| [`stories_player_audio`](packages/stories_player_audio) | music behind stories, over `audioplayers` | [![pub](https://img.shields.io/pub/v/stories_player_audio.svg)](https://pub.dev/packages/stories_player_audio) |

Add only what you use: the core depends on nothing heavy.

## Repository

```
packages/
  stories_player/          the core package, its tests, and the example app
  stories_player_video/
  stories_player_lottie/
  stories_player_audio/
doc/media/                 the clips in the READMEs (GIF and MP4)
```

See [CONTRIBUTING.md](CONTRIBUTING.md) to build, test and release.

## License

BSD 3-Clause. See [LICENSE](LICENSE). Made by [Abdulraheem Kshinba](https://github.com/abdalraheemKshinba).
