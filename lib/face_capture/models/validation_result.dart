import 'package:flutter/material.dart';

class ValidationResult {
  final bool hasFace;
  final bool singleFace;
  final bool isCentered;
  final bool isGoodSize;
  final bool isFacingStraight;
  final bool isSharp;
  final bool isWellLit;
  final int faceCount;
  final double? blurScore;
  final double? brightnessScore;
  final double? faceRatio;
  final double? headAngleY;
  final double? headAngleZ;

  const ValidationResult({
    this.hasFace = false,
    this.singleFace = false,
    this.isCentered = false,
    this.isGoodSize = false,
    this.isFacingStraight = false,
    this.isSharp = false,
    this.isWellLit = false,
    this.faceCount = 0,
    this.blurScore,
    this.brightnessScore,
    this.faceRatio,
    this.headAngleY,
    this.headAngleZ,
  });

  bool get isReady =>
      singleFace &&
      isCentered &&
      isGoodSize &&
      isFacingStraight &&
      isSharp &&
      isWellLit;

  String get hint {
    if (!hasFace) return 'Face not detected\nPosition face in frame';

    if (!singleFace) return 'Multiple faces\nOnly one person visible';

    if (!isSharp) return 'Image blurry\nHold steady';

    if (!isWellLit) {
      final b = brightnessScore ?? 0;
      return b < 60 ? 'Too Dark\nMove to brighter area' : 'Too Bright\nAvoid direct sunlight';
    }

    if (!isGoodSize) {
      final r = faceRatio ?? 0;
      return r < 0.15 ? 'Face too small\nMove closer' : 'Move farther away';
    }

    if (!isCentered) return 'Center your face';

    if (!isFacingStraight) return 'Look straight';

    return 'Good! Hold steady...';
  }

  ValidationState get state {
    if (!hasFace) return ValidationState.noFace;

    if (isReady) return ValidationState.ready;

    if (singleFace && isCentered && isGoodSize) return ValidationState.partial;

    return ValidationState.bad;
  }

  int get qualityScore {
    if (!isReady) return 0;

    double score = 100.0;

    if (blurScore != null) {
      if (blurScore! < 100) score -= (100 - blurScore!) * 0.4;
    }

    if (brightnessScore != null) {
      if (brightnessScore! < 80) score -= (80 - brightnessScore!) * 0.5;
      if (brightnessScore! > 200) score -= (brightnessScore! - 200) * 0.5;
    }

    if (headAngleY != null) score -= headAngleY!.abs() * 0.5;
    if (headAngleZ != null) score -= headAngleZ!.abs() * 0.5;

    return score.clamp(0, 100).toInt();
  }
  String get qualityLabel {
    int score = qualityScore;
    if (score >= 90) return 'Excellent';
    if (score >= 70) return 'Acceptable';
    return 'Poor Quality';
  }

  Color get qualityColor {
    int score = qualityScore;
    if (score >= 90) return const Color(0xFF00E676); // Green
    if (score >= 70) return const Color(0xFFAEEA00); // Light Green
    return const Color(0xFFFF5252); // Red
  }
}

enum ValidationState { noFace, bad, partial, ready }
