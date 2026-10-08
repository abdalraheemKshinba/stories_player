# Contributing

Thanks for helping. Issues and pull requests are welcome.

## Setup

Flutter 3.44 or later. Each package resolves the local core through its
`pubspec_overrides.yaml`, so changes to the core are picked up at once.

```sh
cd packages/stories_player && flutter pub get
```

## Before you open a pull request

Run, in each package you changed:

```sh
dart format .
flutter analyze --fatal-infos --fatal-warnings
flutter test
```

- **Behaviour changes** come with a test, and a row in
  `packages/stories_player/doc/scenarios.md`.
- **Golden images** (`flutter test --tags golden`) are made on macOS;
  regenerate them with `--update-goldens` only for intended visual changes.
- **Every widget test tracks leaks**: dispose what you create.
- **Public API** needs doc comments; the core keeps 160/160 pub points.
- **Changelog**: add your change under `## NEXT` in the package's
  `CHANGELOG.md`.

## Releasing

1. Move `## NEXT` to the new version in `CHANGELOG.md` and bump `pubspec.yaml`.
2. Release the core first, then the adapters if they changed.
3. Push a tag: `stories_player-v0.1.1`, `stories_player_video-v0.1.1`, …
   The `publish` workflow publishes that package to pub.dev.

Breaking changes go through a deprecation first, with a `dart fix` entry in
`lib/fix_data.yaml`.
