import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../face_capture/models/upload_result.dart';
import '../face_capture/models/validation_result.dart';

class ImageProcessingService {

  /// Laplacian variance below this = blurry
  static const double kBlurThreshold = 80.0;

  /// Pixel luminance 0–255; sweet spot 60–210
  static const double kMinBrightness = 60.0;
  static const double kMaxBrightness = 210.0;

  /// Max dimension after compression
  static const int kMaxDimension = 1080;

  /// JPEG quality after compression
  static const int kJpegQuality = 85;


  Future<ValidationResult> analyseImage(
    String filePath, {
    ValidationResult? existing,
  }) async {
    final bytes = await File(filePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return existing ?? const ValidationResult();

    final blur = _laplacianVariance(image);
    final brightness = _averageLuminance(image);

    final isSharp = blur >= kBlurThreshold;
    final isWellLit =
        brightness >= kMinBrightness && brightness <= kMaxBrightness;

    if (existing == null) {
      return ValidationResult(
        isSharp: isSharp,
        isWellLit: isWellLit,
        blurScore: blur,
        brightnessScore: brightness,
      );
    }

    return ValidationResult(
      hasFace: existing.hasFace,
      singleFace: existing.singleFace,
      isCentered: existing.isCentered,
      isGoodSize: existing.isGoodSize,
      isFacingStraight: existing.isFacingStraight,
      faceCount: existing.faceCount,
      faceRatio: existing.faceRatio,
      headAngleY: existing.headAngleY,
      headAngleZ: existing.headAngleZ,
      isSharp: isSharp,
      isWellLit: isWellLit,
      blurScore: blur,
      brightnessScore: brightness,
    );
  }


  Future<ProcessedImage> compress(
    String sourcePath,
    ValidationResult validationResult,
  ) async {
    final sourceFile = File(sourcePath);
    final originalSize = await sourceFile.length();

    final dir = await getTemporaryDirectory();
    final outPath = p.join(
      dir.path,
      'face_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    // Read to get dimensions
    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Cannot decode image');

    final XFile? compressed = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      outPath,
      quality: kJpegQuality,
      minWidth: 0,
      minHeight: 0,
      // Resize to max dimension while preserving aspect ratio
      keepExif: false,
    );

    String finalPath = outPath;
    if (compressed != null) {
      final compressedBytes = await compressed.readAsBytes();
      final compressedImage = img.decodeImage(compressedBytes);

      if (compressedImage != null &&
          (compressedImage.width > kMaxDimension ||
              compressedImage.height > kMaxDimension)) {
        final resized = _resizeToMax(compressedImage);
        final reEncoded = img.encodeJpg(resized, quality: kJpegQuality);
        await File(outPath).writeAsBytes(reEncoded);
      }
      finalPath = compressed.path;
    } else {
      // Fallback: manual resize + encode
      final resized = _resizeToMax(decoded);
      final reEncoded = img.encodeJpg(resized, quality: kJpegQuality);
      await File(outPath).writeAsBytes(reEncoded);
    }

    final finalFile = File(finalPath);
    final compressedSize = await finalFile.length();
    final finalDecoded =
        img.decodeImage(await finalFile.readAsBytes()) ?? decoded;

    return ProcessedImage(
      filePath: finalPath,
      originalSizeBytes: originalSize,
      compressedSizeBytes: compressedSize,
      width: finalDecoded.width,
      height: finalDecoded.height,
      validationResult: validationResult,
    );
  }


  double _laplacianVariance(img.Image image) {
    final small = image.width > 400
        ? img.copyResize(image, width: 400)
        : image;
    final gray = img.grayscale(small);

    final w = gray.width;
    final h = gray.height;

    final List<double> laplacian = [];

    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        final center = _lum(gray, x, y);
        final top = _lum(gray, x, y - 1);
        final bottom = _lum(gray, x, y + 1);
        final left = _lum(gray, x - 1, y);
        final right = _lum(gray, x + 1, y);

        final response = top + bottom + left + right - 4.0 * center;
        laplacian.add(response.toDouble());
      }
    }

    return _variance(laplacian);
  }

  int _lum(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    return pixel.r.toInt();
  }

  double _variance(List<double> values) {
    if (values.isEmpty) return 0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    final sq = values.map((v) => math.pow(v - mean, 2)).reduce((a, b) => a + b);
    return sq / values.length;
  }


  double _averageLuminance(img.Image image) {
    final small = image.width > 400
        ? img.copyResize(image, width: 400)
        : image;

    double total = 0;
    int count = 0;

    for (int y = 0; y < small.height; y++) {
      for (int x = 0; x < small.width; x++) {
        final pixel = small.getPixel(x, y);
        // Perceived luminance (ITU-R BT.601)
        final lum =
            0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        total += lum;
        count++;
      }
    }

    return count > 0 ? total / count : 0;
  }


  img.Image _resizeToMax(img.Image source) {
    if (source.width <= kMaxDimension && source.height <= kMaxDimension) {
      return source;
    }
    if (source.width >= source.height) {
      return img.copyResize(source, width: kMaxDimension);
    } else {
      return img.copyResize(source, height: kMaxDimension);
    }
  }
}
