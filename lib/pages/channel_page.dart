// lib/channel_page.dart

import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChannelPage extends StatefulWidget {
  const ChannelPage({super.key});

  @override
  State<ChannelPage> createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  static const platform = MethodChannel('com.example.overlay_test/helper');
  int _sum = 0;
  String _screenshotStatus = 'No screenshot yet.';
  bool _isCapturing = false;
  String? _lastScreenshotPath;

  // Handler for method calls coming from the native side
  // The service will call these to send back screenshot results
  Future<dynamic> _handleNativeMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'screenCaptureSuccess':
        final filePath = call.arguments as String?;
        setState(() {
          _screenshotStatus = 'Screenshot saved successfully!';
          _isCapturing = false;
          _lastScreenshotPath = filePath;
        });
        log('Screenshot success: $filePath');
        break;
      case 'screenCaptureError':
        final Map<dynamic, dynamic> errorMap = call.arguments;
        final code = errorMap['code'];
        final message = errorMap['message'];
        setState(() {
          _screenshotStatus = 'Error: $code - $message';
          _isCapturing = false;
        });
        log('Screenshot error: $code - $message');
        break;
      default:
        log('Unhandled method: ${call.method}');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    // Set the method call handler for incoming calls from native
    platform.setMethodCallHandler(_handleNativeMethodCall);
  }

  Future<void> _getSum() async {
    try {
      final result = await platform.invokeMethod<int>('handleSumMethod', <String, dynamic>{
        'a': 1,
        'b': 2
      });
      if (result != null) {
        setState(() {
          _sum = result;
        });
      }
    } on PlatformException catch(e) {
      log('Platform Exception for sum: ${e.message}');
      setState(() {
        _screenshotStatus = 'Failed to get sum: ${e.message}';
      });
    }
  }

  Future<void> _takeScreenshot() async {
    if (_isCapturing) {
      log('Screenshot already in progress.');
      return;
    }

    setState(() {
      _isCapturing = true;
      _screenshotStatus = 'Requesting screen capture permission...';
    });

    try {
      // Initiate the native flow. The actual screenshot path will come via a callback.
      await platform.invokeMethod('startScreenCapture');
      log('startScreenCapture method invoked on native side.');
      // The _screenshotStatus will be updated by _handleNativeMethodCall
    } on PlatformException catch (e) {
      log('Platform Exception initiating screenshot: ${e.code} - ${e.message}');
      setState(() {
        _screenshotStatus = 'Error initiating screenshot: ${e.message}';
        _isCapturing = false;
      });
    } catch (e) {
      log('Unexpected Error initiating screenshot: $e');
      setState(() {
        _screenshotStatus = 'An unexpected error occurred: $e';
        _isCapturing = false;
      });
    }
  }

  void _clearScreenshot() {
    setState(() {
      _lastScreenshotPath = null;
      _screenshotStatus = 'Screenshot cleared.';
    });
  }

  void _showFullScreenImage() {
    if (_lastScreenshotPath != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FullScreenImageViewer(imagePath: _lastScreenshotPath!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Native Screen Capture')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sum calculation section
            Text(
              '1 + 2 = $_sum',
              style: const TextStyle(fontSize: 24),
            ),
            ElevatedButton(
              onPressed: _getSum,
              child: const Text('Calculate Sum from Native'),
            ),
            
            const SizedBox(height: 40),
            
            // Screenshot section
            Text(
              'Screenshot Status:',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _screenshotStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _screenshotStatus.contains('Error') ? Colors.red : Colors.green
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Screenshot button
            ElevatedButton(
              onPressed: _isCapturing ? null : _takeScreenshot,
              child: _isCapturing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Take Full Screenshot'),
            ),
            
            const SizedBox(height: 20),
            
            // Image display section
            if (_lastScreenshotPath != null) ...[
              const Text(
                'Last Screenshot:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              
              // Screenshot preview
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: GestureDetector(
                    onTap: _showFullScreenImage,
                    child: Image.file(
                      File(_lastScreenshotPath!),
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error, color: Colors.red, size: 40),
                              const SizedBox(height: 8),
                              Text('Error loading image:\n${error.toString()}'),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showFullScreenImage,
                    icon: const Icon(Icons.fullscreen),
                    label: const Text('View Full Size'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _clearScreenshot,
                    icon: const Icon(Icons.clear),
                    label: const Text('Clear'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // File path info
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Path: $_lastScreenshotPath',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imagePath;

  const FullScreenImageViewer({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Screenshot', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // You can implement sharing functionality here if needed
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share functionality can be implemented here')),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          boundaryMargin: const EdgeInsets.all(20),
          minScale: 0.5,
          maxScale: 4,
          child: Image.file(
            File(imagePath),
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
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
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