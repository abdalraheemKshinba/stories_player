# Example tools

Scripts that drive the example's **web build** in Chrome, at phone size.

```sh
# 1. Build and serve the example
cd ..
flutter build web --release --no-web-resources-cdn
(cd build/web && python3 -m http.server 8765) &

# 2. Run the tools
cd tool
PUPPETEER_SKIP_DOWNLOAD=1 npm install
npm run audio          # end-to-end sound check: never two sounds at once
npm run screenshots    # README screenshots, taken with real taps and swipes
```

Both use your installed Chrome
(`/Applications/Google Chrome.app` on macOS; edit `executablePath` elsewhere).

`audio_e2e.mjs` records every `<audio>` and `<video>` element the page plays
and checks, after each tap, hold and rapid double tap, which ones are
actually audible.

`make_videos.py` renders the example's food videos from its photos, with
Pillow and ffmpeg:

```sh
python3 -m venv venv && ./venv/bin/pip install imageio-ffmpeg pillow
./venv/bin/python make_videos.py \
  ../assets/videos ../assets/images ../assets/audio/sunny_loop.wav
```

Output follows the package's media rules: H.264 Main, `yuv420p`, faststart
MP4, AAC, 9:16, under 2.5 MB, with first-frame posters.
