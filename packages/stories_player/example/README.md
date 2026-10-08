# stories_player example

Every feature of `stories_player` in one app: image, video, Lottie, music and
widget items; slide, cube and fade transitions; right-to-left Arabic; a custom
theme; tap-zone debugging; error recovery; and a live event log with
time-to-first-frame.

```sh
flutter run -d chrome
```

Assets:

* Photos: Unsplash via picsum.photos (Unsplash License).
* Food videos: made from those photos by `tool/make_videos.py`.
* Bee and butterfly videos: Flutter's `assets-for-api-docs`.
* Animations and music: original, generated for this example.

`tool/` also has an end-to-end sound check and the screenshot script, both
run against the web build in Chrome.
