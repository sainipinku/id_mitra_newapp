import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';

import '../face_capture/models/validation_result.dart';


class FaceValidationService {
  late final FaceDetector _detector;
  bool _isProcessing = false;


  static const double kMinFaceRatio = 0.20;
  static const double kMaxFaceRatio = 0.70;


  static const double kCentreMargin = 0.25;


  static const double kMaxHeadAngleY = 15.0;
  static const double kMaxHeadAngleZ = 15.0;


  FaceValidationService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableLandmarks: false,
        enableTracking: false,
        performanceMode: FaceDetectorMode.fast,
        minFaceSize: 0.15,
      ),
    );
  }


  bool get isReady => !_isProcessing;

  Future<ValidationResult> validateFrame(
    CameraImage frame,
    InputImageRotation rotation,
  ) async {
    if (_isProcessing) return const ValidationResult();
    _isProcessing = true;

    try {
      final inputImage = _buildInputImage(frame, rotation);
      final faces = await _detector.processImage(inputImage);
      return _evaluate(faces, frame.width, frame.height);
    } catch (_) {
      return const ValidationResult();
    } finally {
      _isProcessing = false;
    }
  }

  Future<ValidationResult> validateFile(String filePath) async {
    final inputImage = InputImage.fromFilePath(filePath);
    // Use accurate mode for the final captured image
    final accurateDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.10,
      ),
    );
    try {
      final faces = await accurateDetector.processImage(inputImage);
      // We don't know pixel dimensions here, so skip size/centre checks
      return ValidationResult(
        hasFace: faces.isNotEmpty,
        singleFace: faces.length == 1,
        faceCount: faces.length,
        isCentered: true,
        isGoodSize: true,
        isFacingStraight: faces.length == 1
            ? _isAngleOk(
                faces.first.headEulerAngleY,
                faces.first.headEulerAngleZ,
              )
            : false,
        // blur + brightness filled in by ImageProcessingService
        isSharp: true,
        isWellLit: true,
        headAngleY: faces.isNotEmpty ? faces.first.headEulerAngleY : null,
        headAngleZ: faces.isNotEmpty ? faces.first.headEulerAngleZ : null,
      );
    } finally {
      accurateDetector.close();
    }
  }

  ValidationResult _evaluate(
    List<Face> faces,
    int imageWidth,
    int imageHeight,
  ) {
    if (faces.isEmpty) {
      return const ValidationResult(hasFace: false, faceCount: 0);
    }

    final face = faces.first;
    final rect = face.boundingBox;

    final faceRatio = rect.width / imageWidth;
    final isGoodSize =
        faceRatio >= kMinFaceRatio && faceRatio <= kMaxFaceRatio;

    final faceCentreX = (rect.left + rect.width / 2) / imageWidth;
    final faceCentreY = (rect.top + rect.height / 2) / imageHeight;
    final isCentered =
        (faceCentreX - 0.5).abs() < kCentreMargin &&
        (faceCentreY - 0.5).abs() < kCentreMargin;

    final isStraight =
        _isAngleOk(face.headEulerAngleY, face.headEulerAngleZ);

    return ValidationResult(
      hasFace: true,
      singleFace: faces.length == 1,
      faceCount: faces.length,
      isCentered: isCentered,
      isGoodSize: isGoodSize,
      isFacingStraight: isStraight,
      isSharp: true,
      isWellLit: true,
      faceRatio: faceRatio,
      headAngleY: face.headEulerAngleY,
      headAngleZ: face.headEulerAngleZ,
    );
  }

  bool _isAngleOk(double? angleY, double? angleZ) {
    if (angleY == null || angleZ == null) return true;
    return angleY.abs() < kMaxHeadAngleY && angleZ.abs() < kMaxHeadAngleZ;
  }

  InputImage _buildInputImage(CameraImage frame, InputImageRotation rotation) {
    return InputImage.fromBytes(
      bytes: _toNv21(frame),
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: frame.width,
      ),
    );
  }


  Uint8List _toNv21(CameraImage frame) {
    final int width = frame.width;
    final int height = frame.height;

    if (frame.planes.length == 1) {
      final plane = frame.planes[0];
      if (plane.bytesPerRow == width) return plane.bytes;
      final out = Uint8List(width * height + width * (height ~/ 2));
      int dst = 0;
      final totalRows = height + height ~/ 2;
      for (int row = 0; row < totalRows; row++) {
        out.setRange(dst, dst + width, plane.bytes, row * plane.bytesPerRow);
        dst += width;
      }
      return out;
    }

    final out = Uint8List(width * height + width * (height ~/ 2));
    int dst = 0;

    final yPlane = frame.planes[0];
    for (int row = 0; row < height; row++) {
      out.setRange(dst, dst + width, yPlane.bytes, row * yPlane.bytesPerRow);
      dst += width;
    }

    if (frame.planes.length == 2) {
      // NV21 semi-planar: VU interleaved in plane[1]
      final uvPlane = frame.planes[1];
      final uvHeight = height ~/ 2;
      for (int row = 0; row < uvHeight; row++) {
        out.setRange(dst, dst + width, uvPlane.bytes, row * uvPlane.bytesPerRow);
        dst += width;
      }
    } else {
      final uPlane = frame.planes[1];
      final vPlane = frame.planes[2];
      final int uvHeight = height ~/ 2;
      final int uvWidth = width ~/ 2;
      final int pixelStride = uPlane.bytesPerPixel ?? 1;

      if (pixelStride == 2) {
        // Semi-planar NV21 reported as 3 planes: V plane points to VU buffer start
        for (int row = 0; row < uvHeight; row++) {
          out.setRange(dst, dst + width, vPlane.bytes, row * vPlane.bytesPerRow);
          dst += width;
        }
      } else {
        // Fully planar (I420/YUV420): manually interleave V then U for NV21
        for (int row = 0; row < uvHeight; row++) {
          final vRow = row * vPlane.bytesPerRow;
          final uRow = row * uPlane.bytesPerRow;
          for (int col = 0; col < uvWidth; col++) {
            out[dst++] = vPlane.bytes[vRow + col];
            out[dst++] = uPlane.bytes[uRow + col];
          }
        }
      }
    }

    return out;
  }

  void dispose() => _detector.close();
}
