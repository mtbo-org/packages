// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';

import 'camera_controller.dart';
import 'camera_preview.dart';

/// Camera example home widget.
class CameraExampleHome extends StatefulWidget {
  /// Default Constructor
  const CameraExampleHome({super.key});

  @override
  State<CameraExampleHome> createState() {
    return _CameraExampleHomeState();
  }
}

class _CameraExampleHomeState extends State<CameraExampleHome>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback(
        (_) async => onNewCameraSelected().then((_) => startVideoRecording()));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCameraController(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(
                  color:
                      controller != null && controller!.value.isRecordingVideo
                          ? Colors.redAccent
                          : Colors.grey,
                  width: 3.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(),
                ),
              ),
            ),
          ),
          _captureControlRowWidget(),
        ],
      );

  Widget _cameraPreviewWidget() {
    debugPrint(switch (controller) {
      final CameraController _ => 'BUILD PREVIEW',
      _ => 'BUILD TEXT'
    });

    return switch (controller) {
      final CameraController cameraController =>
        CameraPreview(cameraController),
      _ => const Text(
          'NOT AVAILABLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24.0,
            fontWeight: FontWeight.w900,
          ),
        )
    };
  }

  /// Display the control bar with buttons to take pictures and record videos.
  Widget _captureControlRowWidget() {
    final CameraController? cameraController = controller;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.stop),
          color: Colors.red,
          onPressed: cameraController != null &&
                  cameraController.value.isInitialized &&
                  cameraController.value.isRecordingVideo
              ? onStopButtonPressed
              : null,
        ),
      ],
    );
  }

  Future<void> onNewCameraSelected() async {
    final CameraDescription cameraDescription = _cameras.first;

    return switch (controller) {
      final CameraController cameraController =>
        cameraController.setDescription(cameraDescription),
      _ => _initializeCameraController(cameraDescription)
    };
  }

  Future<void> _initializeCameraController(
      CameraDescription cameraDescription) async {
    final CameraController cameraController = CameraController(
      cameraDescription,
      mediaSettings: const MediaSettings(
        resolutionPreset: ResolutionPreset.low,
      ),
    );

    // If the controller is updated then update the UI.
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    try {
      await cameraController.initialize();
    } on CameraException catch (e) {
      switch (e.code) {
        case 'CameraAccessDenied':
          _printError('You have denied camera access.');
        case 'CameraAccessDeniedWithoutPrompt':
          // iOS only
          _printError('Please go to Settings app to enable camera access.');
        case 'CameraAccessRestricted':
          // iOS only
          _printError('Camera access is restricted.');
        case 'AudioAccessDenied':
          _printError('You have denied audio access.');
        case 'AudioAccessDeniedWithoutPrompt':
          // iOS only
          _printError('Please go to Settings app to enable audio access.');
        case 'AudioAccessRestricted':
          // iOS only
          _printError('Audio access is restricted.');
        case 'cameraPermission':
          // Android & web only
          _printError('Unknown permission error.');
        default:
          _showCameraException(e);
          break;
      }
    }

    controller = cameraController;

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> onStopButtonPressed() async {
    debugPrint('STOP 1');
    await stopVideoRecording().then((XFile? file) {
      debugPrint('STOP 2');
      if (mounted) {
        setState(() {});
      }
      if (file != null) {
        debugPrint('Video recorded to ${file.path}');
      }
    }, onError: (_) => null).then((_) {
      if (controller case final CameraController cameraController) {
        setState(() {
          controller = null;
        });

        debugPrint('STOP 3');
        final Future<void> res = cameraController.dispose();
        debugPrint('STOP 3.1');
        return res;
      }
    }, onError: (_) => null)
        //.then((_) => Future<void>.delayed(const Duration(milliseconds: 10)))
        .then((_) {
      debugPrint('STOP 4');
      return onNewCameraSelected();
    }, onError: (_) => null).then((_) {
      debugPrint('STOP 5');
      return startVideoRecording();
    }, onError: (_) => null).then((_) => unawaited(onStopButtonPressed()));
  }

  // Future<void> onStopButtonPressed() async {
  //   debugPrint('STOP 1');
  //   if (controller case final CameraController cameraController) {
  //     setState(() {
  //       controller = null;
  //     });
  //
  //     debugPrint('STOP 3');
  //     return cameraController
  //         .dispose()
  //         .then((_) {
  //           debugPrint('STOP 4');
  //           return onNewCameraSelected();
  //         })
  //         .then((_) => Future<void>.delayed(const Duration(seconds: 1)))
  //         .then((_) => unawaited(onStopButtonPressed()));
  //   }
  // }

  Future<void> onPausePreviewButtonPressed() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      _printError('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isPreviewPaused) {
      await cameraController.resumePreview();
    } else {
      await cameraController.pausePreview();
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> startVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      _printError('Error: select a camera first.');
      return;
    }

    if (cameraController.value.isRecordingVideo) {
      // A recording is already started, do nothing.
      return;
    }

    try {
      await cameraController.startVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return;
    }
  }

  Future<XFile?> stopVideoRecording() async {
    final CameraController? cameraController = controller;

    if (cameraController == null || !cameraController.value.isRecordingVideo) {
      return null;
    }

    try {
      return cameraController.stopVideoRecording();
    } on CameraException catch (e) {
      _showCameraException(e);
      return null;
    }
  }

  void _showCameraException(CameraException e) =>
      _printError('Error: ${e.code}\n${e.description}');
}

/// CameraApp is the Main Application.
class CameraApp extends StatelessWidget {
  /// Default Constructor
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: CameraExampleHome(),
      );
}

void _printError(String message) => debugPrint('ERROR: $message');

List<CameraDescription> _cameras = <CameraDescription>[];

Future<void> main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    _cameras = await CameraPlatform.instance.availableCameras();
  } on CameraException catch (e) {
    _printError('Error: ${e.code}\n${e.description}');
  }
  runApp(const CameraApp());
}
