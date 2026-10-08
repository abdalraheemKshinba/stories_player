import 'dart:io';

import 'package:flutter/widgets.dart';

/// Returns an image provider for the file at [path].
ImageProvider fileImageProvider(String path) => FileImage(File(path));
