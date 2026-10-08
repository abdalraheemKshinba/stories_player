# Feature scenarios

Every supported behaviour, written as a scenario and tied to the test that
proves it. A change that breaks a row fails CI.

| prefix | file |
|---|---|
| *(core)* | `test/stories_player_test.dart` |
| P, G, L, C, D, T | `test/scenarios_test.dart` |
| A | `test/audio_scenarios_test.dart` |
| S | `test/file_story_media_store_test.dart` |
| F | `test/story_prefetcher_test.dart` |
| V | `stories_player_video/test/video_session_test.dart` |
| Lottie | `stories_player_lottie/test/lottie_story_test.dart` |
| E | `example/tool/audio_e2e.mjs` (real Chrome, web build) |

## Playing

| id | given | when | then |
|---|---|---|---|
| core | an image item | it opens | progress starts only once the image is decoded |
| core | any item | its duration runs out | the next item starts (`timer`) |
| core | the last item of the last group | it ends | `onComplete`, then `onDismiss(completed)` |
| core | a video | it buffers | progress freezes; `StoryStalled` reports the stall |
| core | a video shorter than its item duration | it ends | its last frame holds until the time runs out |
| core | the OS "remove animations" setting | items play | they last their real duration |
| core | a screen reader | an item ends | the player waits instead of advancing |
| P1 | room for three prepared items | the user taps back | the previous item is still warm and replays from the start |
| P2 | room for one prepared item | an item plays | nothing is prepared ahead |
| P3 | `groupEnd: dismiss` | a group ends | the player asks to close |
| P4 | the very first item | the user taps back | it restarts |
| P5 | `skipFailedItemsAfter` | an item fails | it is skipped after the delay |
| P6 | a seen rule | items play | `onItemSeen` fires at start, first frame or end |
| P7 | a slow item | it loads | the spinner appears only after 300 ms |
| P8 | `autoAdvance: false` | an item ends | it holds until the user taps |
| core | an item that fails once (a busy video decoder, a network blip) | it fails | other sessions are released and it is retried once, silently: it shows as loading, and the app hears no new visit |

## Gestures

| id | given | when | then |
|---|---|---|---|
| core | LTR | the user taps the right / left side | next / previous item |
| core | RTL (Arabic) | the user taps the left / right side | next / previous item |
| core | the first item of a group | the user taps back | the previous group opens on its last item |
| core | any item | the user holds | playback pauses; the release is not a tap |
| core | a pause from the app (a sheet) | a finger lifts | the story stays paused |
| core | any item | the user drags down far enough / a little | the player asks to close / springs back |
| core | the player in a non-opaque route | the user drags down | the backdrop fades and the card rounds, revealing the app behind |
| core | several groups, a phone's small touch slop | the user drags down at an angle, up to about 45° | the player still closes; only a mostly sideways drag changes group |
| core | RTL | the user presses ← | next item |
| G1 | media that grabs input (web video, platform views) | the user taps | the story moves on; the media never sees the tap |
| G2 | the same media | the user holds | the story pauses, and resumes on release |
| G3 | any item | the user holds | the overlays hide, and return on release |
| G4 | several groups | the user swipes sideways | the next group opens; playback pauses while pages move |
| G5 | `swipeBetweenGroups: false` | the user swipes | nothing moves |
| G6 | `onSwipeUp` | the user swipes up | the item is reported, the player stays |
| G7 | the close button | the user taps it | the player asks to close; it is not a tap forward |
| G8 | an item with sound | the user taps the mute button | sound toggles; the story stays |
| G9 | a custom previous-zone width | the user taps inside it | previous item |

## Sound

| id | given | when | then |
|---|---|---|---|
| A1 | music still starting | the user moves to a silent story | the music never starts |
| A2 | music | the user moves to a story with other music | only the new track plays |
| A3 | four stories with music | the user taps through them quickly | only the last track plays |
| A4 | music | the user holds, then releases | it pauses, then resumes |
| A5 | sound turned on | the user moves on | the next track plays with sound on |
| A6 | music | the app goes to the background, then returns | it stops, then plays again |
| A7 | music | the player closes | it stops |
| A8 | a story kept warm | the user goes back to it | its track restarts from the beginning |
| A9 | an old story released late | a new track is playing | the new track is not silenced |
| A10 | music | a route covers the player | it pauses, and resumes on return |
| A11 | quick taps and a mute toggle | the user settles on a story | one track, never two |
| V1 | a muted video | it loads | its volume is 0 before the platform can play it |
| V2 | any video | it loads | it mixes with the user's own music |
| V3 | a video | the user toggles mute | the volume follows |
| V4 | a video | the story pauses or closes | the platform pauses and releases it |
| V5 | a video still loading | the user leaves | it never plays and is released |
| V10 | three video stories | the user taps forward | the previous video is silenced and released; one video is ever audible |
| E1–E5 | the web build in Chrome | music → video → hold → silent image → rapid taps → Lottie → promo | the audible media is exactly what the screen shows |

## Video and animation

| id | given | when | then |
|---|---|---|---|
| V6 | a video | it plays | progress reads the platform position |
| V7 | a video | it buffers, then recovers | the session reports buffering, then ready |
| V8 | a video | it ends, then is rewound | completed, then ready from 0 |
| V9 | a video | the platform reports an error | the session reports the error |
| Lottie | a JSON animation | it loads | it is parsed on a background isolate |
| Lottie | a `.lottie` archive | it loads | the animation inside is found |
| Lottie | images embedded as data URIs | it loads | the images are decoded and attached |
| Lottie | two sessions for one file | they load at once | the file is loaded once |
| Lottie | a full cache | a new animation loads | the least recently used one is dropped |
| Lottie | a failed load | the user retries | it loads again |
| Lottie | a session | the story clock ticks | the animation follows it, looping or holding its last frame |

## Lifecycle and control

| id | given | when | then |
|---|---|---|---|
| L1 | a video playing | the app goes to the background, then returns | the player is released, then restored at the same position |
| L2 | any item | the app is briefly inactive | it pauses without releasing |
| L3 | any item | a route covers the player | it pauses, and resumes on return |
| C1 | a controller | it jumps, changes group, dismisses | the player follows |
| C2 | a controller | events happen | the stream and the callback get the same events |
| C3 | a custom header | it builds | `StoriesPlayer.of(context)` finds the controller |
| C4 | the player | it closes | a prefetch summary is reported |
| D1 | the user watching an item | the app passes new data | the user stays on the same item and session |
| T1 | a theme extension | the player builds | it uses it, falling back for unset fields |
| T2 | Arabic labels | a screen reader reads | it hears Arabic |

## Media cache and prefetch

| id | given | when | then |
|---|---|---|---|
| S | a download | it completes | the file keeps its extension and is found again |
| S | a byte limit | more media arrives | the least recently used files go first |
| S | pinned media | the cache is full | it is never evicted |
| S | a prefix fetch | a full fetch follows | it resumes with HTTP `Range` |
| S | a download | it is cancelled | the fetch returns null; partial bytes stay |
| S | expired media | the store purges | it is deleted |
| S | the store | it reopens | it finds its files from its index |
| F | a fast network | an item plays | two items and three groups ahead are fetched |
| F | a slow network | an item plays | one item and one group ahead are fetched |
| F | the window | the user moves on | what fell out is cancelled; the window is pinned |
| F | a video over budget | the window is computed | it is not prefetched |
