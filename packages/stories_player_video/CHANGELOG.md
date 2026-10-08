## 0.1.0

First public release.

* `VideoStoryItem` and `VideoStoryDelegate`, over `package:video_player`.
* Plays from the stories cache when the file is there, and streams it
  otherwise; prefers the `lowQuality` rendition on slow networks.
* Progress follows the video's position, so it freezes while buffering.
* Sets the volume before a video loads, so a muted story never makes a sound.
* Mixes with other audio by default.
