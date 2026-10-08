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
