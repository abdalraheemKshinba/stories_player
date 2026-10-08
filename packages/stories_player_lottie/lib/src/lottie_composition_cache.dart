import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lottie/lottie.dart';

/// Finds the image a Lottie file refers to by [LottieImageAsset.dirName] and
/// [LottieImageAsset.fileName], relative to where the file came from.
typedef LottieImageResolver = ImageProvider? Function(LottieImageAsset image);

/// Loads Lottie files the fast way and keeps the most recent ones, so a
/// story never parses its animation twice and parsing never drops a frame.
///
/// * **Plain JSON** (`.json`) is parsed on a background isolate (inline on
///   the web, which has none). Parsing a full-screen animation takes tens of
///   milliseconds, several frames on a low-end phone.
/// * **Images** are attached after parsing: images embedded as base64 data
///   URIs, and image files next to the JSON through a [LottieImageResolver].
/// * **dotLottie and zip** files (`.lottie`, `.zip`) go through
///   `package:lottie`'s own pipeline, which also loads their images and
///   fonts.
/// * **One load per file.** Sessions asking for the same file at the same
///   time share one load; a failed load is not cached, so a retry tries
///   again.
final class LottieCompositionCache {
  /// Creates a cache keeping up to [maxEntries] parsed animations.
  LottieCompositionCache({this.maxEntries = 8})
    : assert(maxEntries > 0, 'The cache must hold at least one entry.');

  /// The cache shared by delegates that are not given one.
  static final LottieCompositionCache shared = LottieCompositionCache();

  /// How many parsed animations are kept.
  final int maxEntries;

  final LinkedHashMap<String, Future<LottieComposition>> _entries =
      LinkedHashMap<String, Future<LottieComposition>>();

  /// How many animations are cached, or loading.
  int get length => _entries.length;

  /// Whether [key] is cached or loading.
  bool contains(String key) => _entries.containsKey(key);

  /// Returns the animation for [key], loading its bytes with [load] and
  /// parsing them the first time.
  Future<LottieComposition> get(
    String key,
    Future<Uint8List> Function() load, {
    LottieImageResolver? images,
  }) {
    final existing = _entries.remove(key);
    if (existing != null) {
      _entries[key] = existing; // the most recently used goes last
      return existing;
    }
    final future = load().then((bytes) => parse(bytes, images: images));
    _entries[key] = future;
    future.ignore();
    unawaited(
      future.then<void>(
        (_) {},
        onError: (Object _) {
          if (identical(_entries[key], future)) _entries.remove(key);
        },
      ),
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return future;
  }

  /// Forgets every cached animation.
  void clear() => _entries.clear();

  /// Parses Lottie [bytes] and attaches their images.
  static Future<LottieComposition> parse(
    Uint8List bytes, {
    LottieImageResolver? images,
  }) async {
    if (isZip(bytes)) {
      // dotLottie: package:lottie unzips it and loads its images and fonts.
      return MemoryLottie(bytes, imageProviderFactory: images).load();
    }
    final composition = await compute(_parseJson, bytes);
    await _attachImages(composition, images);
    return composition;
  }

  /// Whether [bytes] are a zip archive, such as a `.lottie` file.
  static bool isZip(List<int> bytes) =>
      bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B;

  static Future<void> _attachImages(
    LottieComposition composition,
    LottieImageResolver? images,
  ) async {
    for (final image in composition.images.values) {
      if (image.loadedImage != null) continue;
      final provider = image.fileName.startsWith('data:')
          ? MemoryImage(Uri.parse(image.fileName).data!.contentAsBytes())
          : images?.call(image);
      if (provider == null) continue;
      image.loadedImage = await _decode(provider, image, composition);
    }
  }

  static Future<ui.Image?> _decode(
    ImageProvider provider,
    LottieImageAsset image,
    LottieComposition composition,
  ) {
    final completer = Completer<ui.Image?>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        if (!completer.isCompleted) completer.complete(info.image);
      },
      onError: (Object error, _) {
        stream.removeListener(listener);
        composition.addWarning('Failed to load image ${image.id}: $error');
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    stream.addListener(listener);
    return completer.future;
  }
}

LottieComposition _parseJson(Uint8List bytes) =>
    LottieComposition.parseJsonBytes(bytes);
