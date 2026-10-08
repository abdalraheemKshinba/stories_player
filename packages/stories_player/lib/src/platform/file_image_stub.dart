import 'package:flutter/widgets.dart';

/// Returns an image provider for the file at [path]. Files are not
/// available on this platform.
ImageProvider fileImageProvider(String path) => throw UnsupportedError(
  'StoryMedia.file is not supported on the web. Use StoryMedia.network or '
  'StoryMedia.asset instead.',
);
