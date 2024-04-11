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
  bool _active = true;

  CameraController? controller;

  final StreamController<bool> recordingController = StreamController<bool>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async => restartCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _active = false;
      unawaited(_disposeController());
    } else if (state == AppLifecycleState.resumed) {
      _active = true;
      unawaited(restartCamera());
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
        if (controller?.value.isRecordingVideo ?? false) {
          recordingController.add(true);
        } else {
          recordingController.add(false);
        }

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

  Future<void> restartCamera() async {
    if (!_active) {
      return;
    }

    debugPrint('LOOP 1');
    await onNewCameraSelected()
        .then(
          (_) {
            debugPrint('LOOP 2');
            return startVideoRecording();
          },
          onError: (_) => null,
        )
        .then((_) =>
            // wait minmax(1, 10) seconds.
            Future.any(<Future<void>>[
              Future.wait(<Future<void>>[
                _waitRecording(),
                Future<void>.delayed(const Duration(seconds: 1)),
              ]),
              Future<void>.delayed(const Duration(seconds: 10)),
            ]))
        .then(
          (_) {
            debugPrint('LOOP 3');
            return stopVideoRecording();
          },
          onError: (_) => null,
        )
        .then(
          (XFile? file) {
            debugPrint('LOOP 4');
            if (mounted) {
              setState(() {});
            }
            if (file != null) {
              debugPrint('Video recorded to ${file.path}');
            }
          },
          onError: (_) => null,
        )
        .then(
          (_) {
            return _disposeController();
          },
          onError: (_) => null,
        )
        //.then((_) => Future<void>.delayed(const Duration(milliseconds: 10)))
        .then((_) => unawaited(restartCamera()));
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

  Future<void> _disposeController() async {
    if (controller case final CameraController cameraController) {
      if (!cameraController.value.isInitialized) {
        return;
      }

      setState(() {
        controller = null;
      });

      return cameraController.dispose();
    }
  }

  Future<void> _waitRecording() async {
    await for (final bool value in recordingController.stream) {
      if (value) {
        return;
      }
    }
  }
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
