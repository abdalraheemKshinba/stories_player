# stories_player

A fast, right-to-left-ready **stories player** for Flutter. Image, video,
Lottie and any-widget stories, with the gestures people expect, a progress bar
that never lies, smart prefetching, and a media cache that respects the
user's storage.

<p align="center">
  <img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/demo.gif" width="300" alt="Playing stories: tap to the next story, cube swipe to the next group, hold to pause">
</p>

## See it in action

Recorded from the [example](https://github.com/abdalraheemKshinba/stories_player/tree/main/packages/stories_player/example) app). Click a clip for the video.

<table>
<tr><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/tap_through.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/tap_through.gif" width="220" alt="Tap through stories"></a><br><b>Tap through stories</b><br><sub>Lottie with music, a widget card, then a video</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/hold_to_pause.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/hold_to_pause.gif" width="220" alt="Hold to pause"></a><br><b>Hold to pause</b><br><sub>Press and hold pauses the video and hides the overlays</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/swipe_down.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/swipe_down.gif" width="220" alt="Drag down to close"></a><br><b>Drag down to close</b><br><sub>The app shows behind; a short drag springs back, a fling closes, even at an angle</sub></td></tr>
<tr><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/swipe_groups.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/swipe_groups.gif" width="220" alt="Swipe between groups"></a><br><b>Swipe between groups</b><br><sub>Right to left in Arabic, as everything else</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/cube_transition.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/cube_transition.gif" width="220" alt="Cube transition"></a><br><b>Cube transition</b><br><sub>Optional; the default is a light slide</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/order_sheet.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/order_sheet.gif" width="220" alt="Call to action"></a><br><b>Call to action</b><br><sub>The story pauses while your own sheet is open</sub></td></tr>
<tr><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/error_retry.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/error_retry.gif" width="220" alt="Error and retry"></a><br><b>Error and retry</b><br><sub>Automatic retry, visible progress, then Skip</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/seen_resume.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/seen_resume.gif" width="220" alt="Resume where they left"></a><br><b>Resume where they left</b><br><sub>Opens at the first story not yet watched</sub></td><td align="center" width="33%"><a href="https://github.com/abdalraheemKshinba/stories_player/blob/main/doc/media/rtl_tap_zones.mp4"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/doc/media/rtl_tap_zones.gif" width="220" alt="Right-to-left tap zones"></a><br><b>Right-to-left tap zones</b><br><sub>Arabic: the left side goes forward</sub></td></tr>
</table>

> **Live demo:** coming soon.

## Why another stories package

Most stories packages get the look right and the hard parts wrong. This one
was built from an audit of every Flutter stories package and their issue
trackers, Telegram's open-source client, and how Instagram and Facebook load
media. It fixes what users keep reporting:

| | stories_player |
|---|---|
| **Progress tells the truth** | Video progress follows the player, so it freezes while buffering. Images start counting only once decoded. The OS "remove animations" setting does not speed stories up. |
| **Pausing never breaks** | Every pause has a reason: a finger, a sheet, the app in the background. Playback resumes only when all reasons are gone. |
| **Right to left, for real** | In Arabic or Hebrew, tap zones, progress, swipes and the cube all mirror. |
| **Accessible** | Screen-reader labels and actions, no auto-advance while TalkBack or VoiceOver is on, reduced-motion support. |
| **Storage stays small** | A disk cache bounded in **bytes**, with expiry and least-recently-used eviction. Nothing on screen is ever evicted. |
| **Prefetch with a budget** | Up to 3 groups ahead on fast networks, less on slow ones. Anything the user skips is cancelled; the story on screen always gets the bandwidth. |
| **Measurable** | Typed events report time to first frame, stalls and prefetch results. |
| **Light** | The core package depends on nothing heavy. Video, Lottie and music are separate packages. |

## Features

<table>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/image_music.webp" width="200"><br><b>Image + music</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/video.webp" width="200"><br><b>Food video</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/lottie_music.webp" width="200"><br><b>Lottie</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/widget_story.webp" width="200"><br><b>Any widget</b></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/rtl_arabic.webp" width="200"><br><b>Right to left</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/cube_swipe.webp" width="200"><br><b>Cube transition</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/custom_theme_cta.webp" width="200"><br><b>Theme + call to action</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/error_retry.webp" width="200"><br><b>Error and retry</b></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/home.webp" width="200"><br><b>Story tray</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/lottie_loop.webp" width="200"><br><b>Looping Lottie</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/bakery_video.webp" width="200"><br><b>Silent video</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/text_story.webp" width="200"><br><b>Text story</b></td>
</tr>
<tr>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/hold_to_pause.webp" width="200"><br><b>Hold to pause</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/swipe_down.webp" width="200"><br><b>Swipe down to close</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/tap_zones_ltr.webp" width="200"><br><b>Tap zones</b></td>
<td align="center"><img src="https://raw.githubusercontent.com/abdalraheemKshinba/stories_player/main/packages/stories_player/doc/screenshots/tap_zones_rtl.webp" width="200"><br><b>Tap zones, mirrored</b></td>
</tr>
</table>

## Packages

| package | adds | depends on |
|---|---|---|
| `stories_player` | the player, image and widget items, cache, prefetch | `path_provider` |
| `stories_player_video` | `VideoStoryItem` | `video_player` |
| `stories_player_lottie` | `LottieStoryItem` | `lottie` |
| `stories_player_audio` | music behind image and Lottie items | `audioplayers` |

Add only what you use.

## Quick start

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
and prefetching included.

## A real setup

```dart
StoriesPlayer(
  groups: groups,
  // Open the tapped group at its first unwatched item.
  initialPosition: StoryPosition.group(tappedGroupId),
  isSeen: (group, item) => seenIds.contains(item.id),
  onItemSeen: (group, item) => seenIds.add(item.id),

  // Video, Lottie and music come from their own packages.
  delegates: const [VideoStoryDelegate(), LottieStoryDelegate()],
  audio: AudioplayersStoryAudio(),

  // Arabic: labels for screen readers; layout mirrors automatically.
  labels: StoriesLabels.arabic,

  // Analytics and performance.
  onEvent: (event) {
    if (event is StoryItemShown) {
      analytics.timing('story_first_frame', event.timeToFirstFrame);
    }
  },
  onDismiss: (reason) => Navigator.of(context).pop(),
)
```

## Item types

```dart
ImageStoryItem(id: 'a', image: media, audio: StoryAudio(track));
VideoStoryItem(id: 'b', video: video, poster: firstFrame);   // stories_player_video
LottieStoryItem(id: 'c', animation: json, loop: true);       // stories_player_lottie
WidgetStoryItem(
  id: 'd',
  duration: const Duration(seconds: 5),
  builder: (context, progress) => MyPromoCard(progress: progress),
);
```

Every item can carry a `poster` and a `placeholderColor`, painted on the very
first frame while the media loads. Your own item types plug in through a
`StoryItemDelegate`.

## Controlling the player

```dart
final controller = StoriesController();

StoriesPlayer(groups: groups, controller: controller);

controller.next();
controller.jumpTo(const StoryPosition.item('market', 'grapes'));
controller.setMuted(false);

// Pause while your own sheet is open. A finger lifting off the screen
// can never resume it: only the same reason can.
const sheet = PauseReason('orderSheet');
controller.pause(sheet);
await showModalBottomSheet(...);
controller.play(sheet);
```

`controller.value` is an immutable `StoriesValue` (position, status, pause
reasons, mute). `controller.progress` updates every frame without rebuilding
anything else.

## Caching and data use

```dart
StoryMediaStore.instance = FileStoryMediaStore(
  maxBytes: 80 * 1024 * 1024,      // a hard ceiling, enforced on every write
  maxAge: const Duration(days: 2), // unused media is deleted after this
);
```

* Media past an item's `expiresAt` is deleted.
* Downloads resume from where they stopped, with HTTP `Range`.
* Give `StoryMedia` its `bytes` and a `lowQuality` rendition: slow networks
  use the small one, and the prefetcher budgets data without extra requests.

Prefetching follows a policy: `StoryPrefetchPolicy.balanced` by default, or
`none`, `conservative` and `aggressive`. The network speed is measured from
the player's own downloads. Plug in a `StoryNetworkSignal` to honour your
app's data-saver setting.

## Customizing

* **Theme:** `StoriesThemeData`, as a `ThemeExtension` or a `StoriesTheme`
  widget: progress colours, sizes, text styles, scrims.
* **Builders:** `headerBuilder`, `footerBuilder`, `progressBuilder`,
  `loadingBuilder` and `errorBuilder`. Reuse the defaults inside your own:
  `StoryHeader`, `StoryCaption`, `StoryProgressBar`.
* **Behaviour:** `StoriesPlaybackConfig` (durations, seen rule, end of group,
  muted start) and `StoriesGestureConfig` (tap zones, hold, swipes, keyboard).
* **Transitions:** `StoryGroupTransition.slide` (default), `cube`, `fade` or
  `none`, or your own.

## Behaviour

| gesture | result |
|---|---|
| tap the trailing 70 % | next item (next group after the last) |
| tap the leading 30 % | previous item (previous group's last item) |
| press | pauses immediately |
| hold | stays paused and hides the overlays |
| drag down | follows the finger, closes past 25 % or on a fling |
| swipe sideways | next or previous group |
| ← → Space Esc | keyboard navigation, pause, close |

"Leading" means left in left-to-right languages and right in right-to-left
ones.

## Smooth on small phones

What the player does so video, sound and animation stay smooth on a 2 GB
phone on 3G:

**Video**
* The next item is prepared ahead while the current one plays, so a tap
  forward starts instantly. With `maxPreparedItems: 3`, the previous item
  stays warm too, for an instant tap back.
* Each video's volume is set before it loads, so a story never makes a sound
  it should not, not even for a frame.
* Videos mix with the user's own music: a muted story never stops their
  playlist.
* Players the user has moved past are released at once, and every player is
  released when the app goes to the background, freeing decoders and memory.
* Progress follows the video's own clock. A video shorter than its story
  holds its last frame.
* Slow networks get the `lowQuality` rendition. Posters paint on the first
  frame, and the next poster is decoded ahead.

**Sound**
* One ordered queue per audio backend: a pause can never overtake the play
  it follows, so music can never start after its story is gone.
* Only the story that owns the speaker can pause, stop or mute it, so two
  tracks never play at once, and a late call never silences the next story.

**Animation**
* Lottie JSON is parsed on a background isolate: preparing the next story
  never drops a frame of the current one.
* Parsed animations are cached (least recently used first), so going back
  is instant, and two loads of one file are shared.
* Animations repaint at their own frame rate, not at every display frame,
  without a full-screen raster cache.
* Images embedded in the JSON, image files next to it, and `.lottie`
  archives all load.

**Everywhere**
* Media never takes input, so web video elements and native views can never
  swallow the taps and holds meant for the story.
* The progress bar repaints alone; the media is behind a repaint boundary.
* Prefetching backs off while the device is dropping frames.

Every behaviour is written down as a scenario in
[doc/scenarios.md](https://github.com/abdalraheemKshinba/stories_player/blob/main/packages/stories_player/doc/scenarios.md), each tied to the test that proves it.

## Testing your integration

`package:stories_player/testing.dart` ships fakes: `FakeStoryItem`,
`FakeStoryItemDelegate` (control loading, buffering and position) and
`FakeStoryMediaStore`.

## Example

The [example](https://github.com/abdalraheemKshinba/stories_player/tree/main/packages/stories_player/example) app shows every feature, with a live event log. Run it
with `flutter run -d chrome`.
