import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/devices/services/device_storage.dart';

class ImageService {
  /// Purpose: Provide the internal get image dir helper for this file.
  /// Inputs: None.
  /// Returns: `Future<Directory>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: Internal helper used within this file only.
  static Future<Directory> _getImageDir() async {
    final appDir = await DeviceStorage.getAppDir();
    final imgDir = Directory(p.join(appDir.path, 'images'));
    if (!await imgDir.exists()) {
      await imgDir.create(recursive: true);
    }
    return imgDir;
  }

  /// Purpose: Pick and save image from user-provided input.
  /// Inputs: None.
  /// Returns: `Future<String?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Pick an image file and copy it into app storage.
  /// Returns the relative path e.g. "images/xxx.png", or null if cancelled.
  static Future<String?> pickAndSaveImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final pickedPath = result.files.single.path;
    if (pickedPath == null) return null;

    final imgDir = await _getImageDir();
    final ext = p.extension(pickedPath);
    final newName = '${const Uuid().v4()}$ext';
    final dest = File(p.join(imgDir.path, newName));
    await File(pickedPath).copy(dest.path);
    return 'images/$newName';
  }

  /// Purpose: Resolve the requested value into the form required by the caller.
  /// Inputs: `relativePath`.
  /// Returns: `Future<File>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Resolve a relative imagePath to an absolute File.
  static Future<File> resolve(String relativePath) async {
    final appDir = await DeviceStorage.getAppDir();
    return File(p.join(appDir.path, relativePath));
  }

  /// Purpose: Delete the relevant data from the relevant storage or state.
  /// Inputs: `relativePath`.
  /// Returns: `Future<void>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Delete a previously saved image.
  static Future<void> delete(String relativePath) async {
    final file = await resolve(relativePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Purpose: Save image from url to the relevant storage or service layer.
  /// Inputs: `url`.
  /// Returns: `Future<String?>`.
  /// Side effects: Performs local file-system I/O.
  /// Notes: None.
  /// Download an image from a URL and save it into app storage.
  /// Returns the relative path e.g. "images/xxx.jpg", or null on failure.
  static Future<String?> saveImageFromUrl(String url) async {
    final resp = await http
        .get(Uri.parse(url), headers: {'User-Agent': 'MyDevice/0.1'})
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return null;

    final imgDir = await _getImageDir();
    var ext = p.extension(Uri.parse(url).path);
    if (ext.isEmpty || ext.length > 5) ext = '.jpg';
    final newName = '${const Uuid().v4()}$ext';
    final dest = File(p.join(imgDir.path, newName));
    await dest.writeAsBytes(resp.bodyBytes);
    return 'images/$newName';
  }
}
