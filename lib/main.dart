import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:opencv_dart/opencv_dart.dart';
import 'package:desktop_screenshot/desktop_screenshot.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

void main() {
  setLogLevel(LOG_LEVEL_VERBOSE);
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isRecording = false;
  String? errorMessage;
  VideoPlayerController? _videoPlayerController;
  String? videoPath;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Screen Recorder2'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_videoPlayerController != null &&
                  _videoPlayerController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoPlayerController!.value.aspectRatio,
                  child: VideoPlayer(_videoPlayerController!),
                ),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    errorMessage!,
                    style: TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: isRecording ? stopRecording : startRecording,
                child: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> startRecording() async {
    setState(() {
      errorMessage = null;
    });

    final screenshot = DesktopScreenshot();
    Uint8List? imgBytes;

    try {
      imgBytes = await screenshot.getScreenshot();
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to take screenshot: $e';
      });
      return;
    }

    if (imgBytes == null) {
      setState(() {
        errorMessage = 'Failed to take screenshot';
      });
      return;
    }

    final img = await imdecodeAsync(imgBytes, IMREAD_COLOR);
    final height = img.rows;
    final width = img.cols;

    final tempDir = await getTemporaryDirectory();
    final videoFilePath = '${tempDir.path}/video.mp4';

    final out = VideoWriter.open(videoFilePath, 'mp4v', 20.0, (width, height));

    if (!out.isOpened) {
      setState(() {
        errorMessage = 'Failed to open video writer';
      });
      return;
    }

    setState(() {
      isRecording = true;
      videoPath = videoFilePath;
    });

    Timer.periodic(Duration(milliseconds: 1000), (timer) async {
      if (!isRecording) {
        timer.cancel();
        out.release();
        print('Stopped recording');
        await showRecordedVideo();
        return;
      }

      try {
        imgBytes = await screenshot.getScreenshot();
      } catch (e) {
        setState(() {
          errorMessage = 'Failed to take screenshot: $e';
        });
        return;
      }

      if (imgBytes == null) {
        setState(() {
          errorMessage = 'Failed to take screenshot';
        });
        return;
      }

      final img = await imdecodeAsync(imgBytes!, IMREAD_COLOR);
      await out.writeAsync(img);
    });

    // Stop recording after a while for demo purposes (e.g., 10 seconds)
    await Future.delayed(Duration(seconds: 10));
    if (isRecording) {
      stopRecording();
    }
  }

  void stopRecording() {
    setState(() {
      isRecording = false;
    });
  }

  Future<void> showRecordedVideo() async {
    if (videoPath == null) return;

    _videoPlayerController = VideoPlayerController.file(File(videoPath!));
    await _videoPlayerController!.initialize();
    setState(() {});
    _videoPlayerController!.play();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    super.dispose();
  }
}
