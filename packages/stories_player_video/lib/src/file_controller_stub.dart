import 'package:video_player/video_player.dart';

/// Creates a controller for the file at [path]. Files are not available on
/// the web.
VideoPlayerController fileController(
  String path,
  VideoPlayerOptions? options,
) => throw UnsupportedError('StoryMedia.file is not supported on the web.');
