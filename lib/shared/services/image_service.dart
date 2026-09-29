import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../features/devices/services/device_storage.dart';
import '../utils/device_image_processing.dart';

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
  /// Notes: Pick an image file and copy it into app storage unchanged.
  /// Returns the relative path e.g. "images/xxx.png", or null if cancelled.
  /// The device editor goes through [pickImageFile] and the image editor
  /// instead; this stays for callers that want the file as-is.
  static Future<String?> pickAndSaveImage() async {
    final picked = await pickImageFile();
    if (picked == null) return null;
    return saveImageFile(picked);
  }

  /// Purpose: Let the user pick an image file without copying it.
  /// Inputs: None.
  /// Returns: The picked `File`, or null when cancelled.
  /// Side effects: Shows the platform file picker.
  /// Notes: The caller decides whether to edit it first ([loadEditableImage])
  /// or store it unchanged ([saveImageFile]).
  static Future<File?> pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    final pickedPath = result.files.single.path;
    if (pickedPath == null) return null;
    return File(pickedPath);
  }

  /// Purpose: Copy an image file into app storage unchanged.
  /// Inputs: `source` — the file to copy.
  /// Returns: The relative path, e.g. `images/<uuid>.jpg`.
  /// Side effects: Creates the images directory if needed; writes a file.
  /// Notes: Keeps the source extension.
  static Future<String> saveImageFile(File source) async {
    final imgDir = await _getImageDir();
    final newName = '${const Uuid().v4()}${p.extension(source.path)}';
    await source.copy(p.join(imgDir.path, newName));
    return 'images/$newName';
  }

  /// Purpose: Store encoded image bytes, such as the image editor's PNG.
  /// Inputs: `bytes`; `ext` including the dot, e.g. `.png`.
  /// Returns: The relative path, e.g. `images/<uuid>.png`.
  /// Side effects: Creates the images directory if needed; writes a file.
  /// Notes: Always a new flat file under `images/`, so backup and sync
  /// carry it like any other device image.
  static Future<String> saveImageBytes(Uint8List bytes, String ext) async {
    final imgDir = await _getImageDir();
    final newName = '${const Uuid().v4()}$ext';
    await File(p.join(imgDir.path, newName)).writeAsBytes(bytes, flush: true);
    return 'images/$newName';
  }

  /// Purpose: Decode an image file into pixels the image editor can process.
  /// Inputs: `file`; `maxSide` — the longest side kept after decoding.
  /// Returns: A request carrying straight RGBA pixels with default settings,
  /// or null when the file cannot be read or decoded.
  /// Side effects: Reads the file.
  /// Notes: See [decodeEditableImage].
  static Future<DeviceImageEditRequest?> loadEditableImage(
    File file, {
    int maxSide = 1024,
  }) async {
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (_) {
      return null;
    }
    return decodeEditableImage(bytes, maxSide: maxSide);
  }

  /// Purpose: Decode encoded image bytes into an editable RGBA request.
  /// Inputs: `bytes`; `maxSide` — the longest side kept after decoding.
  /// Returns: The request, or null when no decoder accepts the bytes.
  /// Side effects: None.
  /// Notes: Decodes with the platform codec first, so formats Flutter can
  /// show (and EXIF orientation) behave as they do on screen, and downscales
  /// while decoding so a 48 MP photo never becomes a full-size buffer. Falls
  /// back to `package:image` when the platform codec refuses the bytes.
  static Future<DeviceImageEditRequest?> decodeEditableImage(
    Uint8List bytes, {
    int maxSide = 1024,
  }) async {
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final wide = descriptor.width >= descriptor.height;
      final tooBig = math.max(descriptor.width, descriptor.height) > maxSide;
      final codec = await descriptor.instantiateCodec(
        targetWidth: tooBig && wide ? maxSide : null,
        targetHeight: tooBig && !wide ? maxSide : null,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      final request = data == null
          ? null
          : DeviceImageEditRequest(
              rgba: data.buffer.asUint8List(
                data.offsetInBytes,
                data.lengthInBytes,
              ),
              width: image.width,
              height: image.height,
            );
      image.dispose();
      codec.dispose();
      descriptor.dispose();
      buffer.dispose();
      if (request != null) return request;
    } catch (_) {
      // Fall through to the pure-Dart decoder.
    }
    try {
      var decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      decoded = img.bakeOrientation(decoded);
      if (math.max(decoded.width, decoded.height) > maxSide) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? maxSide : null,
          height: decoded.height > decoded.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
      }
      final rgba = decoded
          .convert(format: img.Format.uint8, numChannels: 4)
          .getBytes(order: img.ChannelOrder.rgba);
      return DeviceImageEditRequest(
        rgba: rgba,
        width: decoded.width,
        height: decoded.height,
      );
    } catch (_) {
      return null;
    }
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
