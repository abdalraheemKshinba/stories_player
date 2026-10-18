## 0.1.1

* `StoriesTray`: shows story groups above your content, as circles (the
  Instagram look) or as Facebook-style cards with `StoriesTrayLayout.cards`.
  Cards are 112 × 200 dp with a snapshot of the story, a 36 dp avatar ring in
  the top corner and the name at the bottom. Both layouts mirror in
  right-to-left languages.
* `StoryCard` and `StoryCircle`, to build your own tray, and
  `StoriesTrayStyle` for sizes and colours.
* `StoryGroup.cover`: the snapshot a card shows. Without it, a card shows the
  poster or image of the first story not yet seen, where the player opens
  (`StoryCard.coverOf`).
* Rings turn grey once all of a group's stories were seen, using the same
  `isSeen` callback as the player.

## 0.1.0

First public release.

* `StoriesPlayer`: image and widget items, a segmented progress bar driven by
  the media's own clock, tap, hold, swipe and keyboard gestures, and full
  right-to-left mirroring.
* `StoriesController`, an immutable `StoriesValue`, and pause reasons that
  can never resume each other.
* `FileStoryMediaStore`: a byte-bounded, resumable media cache with expiry.
* Network-aware prefetching with `StoryPrefetchPolicy` presets and
  cancellation; the item on screen always gets the bandwidth.
* Resilience: a failed item is retried once on its own, after releasing
  other sessions' video decoders; a retry the user asks for shows progress at
  once, and a second failure offers Skip.
* A stall watchdog shows loading when a video's position stops moving.
* Ordered, single-owner audio: music never plays twice or after its story.
* Dragging down fades the backdrop and rounds the card, revealing the app
  behind a non-opaque route. A drag held at an angle still closes; only a
  mostly sideways drag changes group.
* Typed `StoryEvent`s, including time to first frame, stalls and a prefetch
  report.
* `StoriesThemeData`, `StoriesLabels` (English, Arabic, French), and slide,
  cube and fade group transitions.
* `package:stories_player/testing.dart` with fakes, including a slow audio
  backend for race tests.
