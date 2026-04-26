import 'dart:io';
import 'dart:typed_data';

import 'file_loader.dart';

class FileLoaderImpl implements FileLoader {
  @override
  Future<Uint8List?> loadBytes(String path) async {
    String decodedPath;
    try {
      decodedPath = Uri.decodeFull(path);
    } catch (e) {
      decodedPath = path;
    }
    final file = File(decodedPath);
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  @override
  Future<bool> exists(String path) async {
    String decodedPath;
    try {
      decodedPath = Uri.decodeFull(path);
    } catch (e) {
      decodedPath = path;
    }
    return await File(decodedPath).exists();
  }
}

FileLoader getFileLoader() => FileLoaderImpl();
