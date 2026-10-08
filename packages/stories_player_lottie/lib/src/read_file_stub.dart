import 'dart:typed_data';

/// Reads the file at [path]. Files are not available on the web.
Future<Uint8List> readFile(String path) =>
    throw UnsupportedError('StoryMedia.file is not supported on the web.');
