import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';
// import 'package:image_cropper/image_cropper.dart';
// import 'package:path_provider/path_provider.dart';

class EditorPage extends StatefulWidget {
  final String imagePath;

  const EditorPage({super.key, required this.imagePath});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  // Future<void> _cropAndSave() async {
  //   CroppedFile? croppedFile = await ImageCropper().cropImage(
  //     sourcePath: widget.imagePath,
  //     compressFormat: ImageCompressFormat.jpg,
  //     compressQuality: 100,
  //     uiSettings: [
  //       AndroidUiSettings(
  //         toolbarTitle: 'Select Content',
  //         toolbarColor: Colors.black,
  //         toolbarWidgetColor: Colors.white,
  //         initAspectRatio: CropAspectRatioPreset.square,
  //         lockAspectRatio: false,
  //         aspectRatioPresets: [
  //           CropAspectRatioPreset.original,
  //           CropAspectRatioPreset.square,
  //           CropAspectRatioPresetCustom(),
  //         ],
  //       ),
  //       IOSUiSettings(
  //         title: 'Select Content',
  //         aspectRatioPresets: [
  //           CropAspectRatioPreset.original,
  //           CropAspectRatioPreset.square,
  //           CropAspectRatioPresetCustom(), // IMPORTANT: iOS supports only one custom aspect ratio in preset list
  //         ],
  //       ),
  //       WebUiSettings(
  //         context: context,
  //         presentStyle: WebPresentStyle.dialog,
  //         size: const CropperSize(width: 520, height: 520),
  //       ),
  //     ],
  //   );

  //   if (croppedFile != null) {
  //     const String uploadUrl = 'http://localhost:3000/upload';
  //     String imagePath = croppedFile.path;

  //     try {
  //       var request = MultipartRequest('POST', Uri.parse(uploadUrl));
  //       request.files.add(await MultipartFile.fromPath('file', imagePath));

  //       StreamedResponse response = await request.send();
  //       final body = await response.stream.bytesToString();

  //       if (response.statusCode == 201) {
  //         // success
  //         log('Upload successful: $body');
  //       } else {
  //         // err
  //         log('Upload failed: $body');
  //       }
  //     } catch (e) {
  //       log('Error occured while trying to upload image: $e');
  //     }
  //   }
  // }

  @override
  void initState() {
    super.initState();

    // _cropAndSave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Captured Image',
          style: TextStyle(color: Colors.white),
        ),
        actions: [],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(widget.imagePath),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading image',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// class CropAspectRatioPresetCustom implements CropAspectRatioPresetData {
//   @override
//   (int, int)? get data => (2, 3);

//   @override
//   String get name => '2x3 (customized)';
// }
