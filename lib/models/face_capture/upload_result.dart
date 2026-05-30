import 'validation_result.dart';

class ProcessedImage {
  final String filePath;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final int width;
  final int height;
  final ValidationResult validationResult;

  const ProcessedImage({
    required this.filePath,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.width,
    required this.height,
    required this.validationResult,
  });

  double get compressionRatio =>
      (1 - compressedSizeBytes / originalSizeBytes) * 100;

  String get formattedOriginalSize => _formatBytes(originalSizeBytes);
  String get formattedCompressedSize => _formatBytes(compressedSizeBytes);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}
