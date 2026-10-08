import 'dart:io';

import 'package:video_player/video_player.dart';

/// Creates a controller for the file at [path].
VideoPlayerController fileController(
  String path,
  VideoPlayerOptions? options,
) => VideoPlayerController.file(File(path), videoPlayerOptions: options);
