## 0.1.0

First public release.

* `LottieStoryItem` and `LottieStoryDelegate`, over `package:lottie`.
* Parses JSON animations on a background isolate.
* `LottieCompositionCache`: shared loads and least-recently-used reuse.
* Loads images embedded in the JSON or stored next to it, and `.lottie`
  archives.
* Repaints at the animation's own frame rate, without a full-screen raster
  cache.
