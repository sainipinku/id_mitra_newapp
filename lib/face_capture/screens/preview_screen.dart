import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/face_capture/models/upload_result.dart';


class PreviewScreen extends StatefulWidget {
  final ProcessedImage processedImage;
  final String? uploadUrl;

  const PreviewScreen({
    super.key,
    required this.processedImage,
    this.uploadUrl,
  });

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool _isUploading = false;
  double _uploadProgress = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  Future<void> _usePhoto() async {
    if (widget.uploadUrl == null) {
      Navigator.pop(context, widget.processedImage);
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.3;
    });

    try {
      debugPrint("Uploading from PreviewScreen to: ${widget.uploadUrl}");
      
      final response = await ApiManager().multiRequestRoute(
        widget.processedImage.filePath,
        widget.uploadUrl!,
      );

      if (!mounted) return;

      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        final jsonData = jsonDecode(response.body);
        
        setState(() => _uploadProgress = 1.0);

        if (mounted) {
          Navigator.pop(context, jsonData['data'] ?? {});
        }
      } else {
        setState(() => _isUploading = false);
        _showErrorSnack('Upload failed. Server returned ${response?.statusCode ?? "error"}');
      }
    } catch (e) {
      debugPrint("PreviewScreen upload error: $e");
      if (mounted) {
        setState(() => _isUploading = false);
        _showErrorSnack('Upload error: $e');
      }
    }
  }

  void _retake() => Navigator.pop(context, false);

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF5252),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = widget.processedImage;
    final qualityScore = img.validationResult.qualityScore;
    final isLowQuality = qualityScore < 70;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildImagePreview(img, qualityScore)),
              _buildStatsBar(img),
              _buildValidationBadges(img),
              _buildActionButtons(isLowQuality),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          GestureDetector(
            onTap: _isUploading ? null : _retake,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh, color: Colors.white70, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Retake',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const Expanded(
            child: Text(
              'Review Photo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 80), // balance
        ],
      ),
    );
  }

  Widget _buildImagePreview(ProcessedImage img, int qualityScore) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(img.filePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                    color: Color(0xFF1C1C1E),
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Colors.white24, size: 48),
                    ),
                  ),
                ),
                // Subtle vignette
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.2,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.35),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Quality Score Overlay
          Positioned(
            bottom: 20,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quality Score',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$qualityScore',
                      style: TextStyle(
                        color: img.validationResult.qualityColor,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      '/100',
                      style: TextStyle(color: Colors.white38, fontSize: 16),
                    ),
                  ],
                ),
                Text(
                  img.validationResult.qualityLabel,
                  style: TextStyle(
                    color: img.validationResult.qualityColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar(ProcessedImage img) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          _StatTile(
            label: 'Original',
            value: img.formattedOriginalSize,
            icon: Icons.photo_size_select_actual_outlined,
            color: Colors.white54,
          ),
          const _Arrow(),
          _StatTile(
            label: 'Upload size',
            value: img.formattedCompressedSize,
            icon: Icons.upload_outlined,
            color: const Color(0xFF00E676),
          ),
          const Spacer(),
          _StatTile(
            label: 'Saved',
            value: '${img.compressionRatio.toStringAsFixed(0)}%',
            icon: Icons.compress,
            color: const Color(0xFF64B5F6),
          ),
        ],
      ),
    );
  }

  Widget _buildValidationBadges(ProcessedImage img) {
    final v = img.validationResult;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Row(
        children: [
          _Badge(label: 'Face', ok: v.singleFace),
          const SizedBox(width: 8),
          _Badge(
            label: 'Sharp',
            ok: v.isSharp,
          ),
          const SizedBox(width: 8),
          _Badge(
            label: 'Light',
            ok: v.isWellLit,
          ),
          const SizedBox(width: 8),
          _Badge(label: 'Angle', ok: v.isFacingStraight),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isLowQuality) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        children: [
          if (_isUploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 4,
                backgroundColor: Colors.white12,
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF00E676)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _uploadProgress > 0
                  ? 'Uploading… ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                  : 'Preparing…',
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 16),
          ],

          if (!isLowQuality) ...[
            SizedBox(
              width: double.infinity,
              height: 54,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _isUploading ? Colors.white12 : const Color(0xFF0D47A1), 
                ),
                child: TextButton(
                  onPressed: _isUploading ? null : _usePhoto,
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white54,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 10),
                            Text(
                              'Upload Photo',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          // Retake button - Dark Grey
          SizedBox(
            width: double.infinity,
            height: 54,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF212121),
              ),
              child: TextButton(
                onPressed: _isUploading ? null : _retake,
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Retake',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }
}


class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 13),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 10),
      child: Icon(Icons.arrow_forward, color: Colors.white24, size: 16),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool ok;

  const _Badge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check : Icons.close,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
