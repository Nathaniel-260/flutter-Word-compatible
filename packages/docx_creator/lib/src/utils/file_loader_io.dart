import 'dart:io';
import 'dart:typed_data';

import 'file_loader.dart';

class FileLoaderImpl implements FileLoader {
  @override
  Future<Uint8List?> loadBytes(String path) async {
    final decodedPath = Uri.decodeFull(path);
    final file = File(decodedPath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<bool> exists(String path) async {
    final decodedPath = Uri.decodeFull(path);
    return await File(decodedPath).exists();
  }
}

FileLoader getFileLoader() => FileLoaderImpl();
