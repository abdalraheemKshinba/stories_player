import 'dart:io';
import 'dart:typed_data';

/// Reads the file at [path].
Future<Uint8List> readFile(String path) => File(path).readAsBytes();
