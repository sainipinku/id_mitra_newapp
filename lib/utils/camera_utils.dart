import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Helper utilities for camera setup and coordinate mapping.
class CameraUtils {
  /// Returns the front camera from [cameras], falling back to first available.
  static CameraDescription pickFrontCamera(List<CameraDescription> cameras) {
    return pickCameraByDirection(cameras, CameraLensDirection.front);
  }

  /// Picks a camera by [direction].
  static CameraDescription pickCameraByDirection(
    List<CameraDescription> cameras,
    CameraLensDirection direction,
  ) {
    return cameras.firstWhere(
      (c) => c.lensDirection == direction,
      orElse: () => cameras.first,
    );
  }

  /// Maps device orientation to ML Kit [InputImageRotation].
  static InputImageRotation rotationFromDeviceOrientation(
    CameraDescription camera,
  ) {
    // For front camera, mirror the rotation
    final sensorOrientation = camera.sensorOrientation;
    return _sensorToRotation(sensorOrientation);
  }

  static InputImageRotation rotationFromNativeOrientation(
    DeviceOrientation orientation,
    CameraDescription camera,
  ) {
    int rotationCompensation = 0;
    switch (orientation) {
      case DeviceOrientation.portraitUp:
        rotationCompensation = 0;
        break;
      case DeviceOrientation.landscapeLeft:
        rotationCompensation = 90;
        break;
      case DeviceOrientation.portraitDown:
        rotationCompensation = 180;
        break;
      case DeviceOrientation.landscapeRight:
        rotationCompensation = 270;
        break;
    }

    // Adjust for sensor orientation
    if (camera.lensDirection == CameraLensDirection.front) {
      rotationCompensation =
          (camera.sensorOrientation + rotationCompensation) % 360;
    } else {
      rotationCompensation =
          (camera.sensorOrientation - rotationCompensation + 360) % 360;
    }

    return _sensorToRotation(rotationCompensation);
  }

  static InputImageRotation _sensorToRotation(int degrees) {
    switch (degrees) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}
