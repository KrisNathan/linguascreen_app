import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show decodeImageFromList;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

/// An image in the one normal form the rest of the app uses.
///
/// Display and OCR both come from the same decoded pixels ([image]), so OCR
/// boxes line up with what is drawn no matter where the image came from.
class LoadedImage {
  LoadedImage(this.image);

  final ui.Image image;

  ui.Size get size => ui.Size(image.width.toDouble(), image.height.toDouble());

  /// Decodes [bytes] (any format Flutter can decode).
  static Future<LoadedImage> fromBytes(Uint8List bytes) async {
    return LoadedImage(await decodeImageFromList(bytes));
  }

  /// The pixels in the form ML Kit takes (raw RGBA, no file involved).
  Future<InputImage> toInputImage() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw StateError('Could not read the image pixels');

    return InputImage.fromBitmap(
      bitmap: data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      width: image.width,
      height: image.height,
    );
  }

  void dispose() => image.dispose();
}

/// Where an image comes from (gallery, camera, later: clipboard, share, ...).
/// Each origin only has to produce a [LoadedImage].
abstract class ImageOrigin {
  /// Null if the user cancelled.
  Future<LoadedImage?> pick();
}

/// Gallery or camera, through image_picker.
class PickerOrigin implements ImageOrigin {
  PickerOrigin(this.source);

  final ImageSource source;
  final ImagePicker _picker = ImagePicker();

  @override
  Future<LoadedImage?> pick() async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return null;
    return LoadedImage.fromBytes(await file.readAsBytes());
  }
}

/// An image file already on disk, e.g. a screenshot.
class FileOrigin implements ImageOrigin {
  FileOrigin(this.path);

  final String path;

  @override
  Future<LoadedImage?> pick() async =>
      LoadedImage.fromBytes(await File(path).readAsBytes());
}
