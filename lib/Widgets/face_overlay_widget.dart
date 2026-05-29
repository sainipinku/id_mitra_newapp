  import 'package:flutter/material.dart';

import '../face_capture/models/validation_result.dart';


class FaceOverlayWidget extends StatelessWidget {
  final ValidationResult result;
  final Size previewSize;
  final int countdown;

  const FaceOverlayWidget({
    super.key,
    required this.result,
    required this.previewSize,
    this.countdown = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          size: Size.infinite,
          painter: _OvalMaskPainter(state: result.state),
        ),
        
        if (countdown > 0)
          Positioned(
            bottom: 120,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: const Color(0xFF00E676), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'Capturing in $countdown...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Center(
            child: _StatusBar(result: result),
          ),
        ),
      ],
    );
  }
}


class _OvalMaskPainter extends CustomPainter {
  final ValidationState state;

  _OvalMaskPainter({required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = _faceRect(size);
    
    final stadiumPath = Path()
      ..addRRect(RRect.fromRectAndRadius(
        rect,
        Radius.circular(rect.width / 2),
      ));

    final bgPaint = Paint()..color = Colors.black.withOpacity(0.55);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPath(stadiumPath, Offset.zero)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    final ringPaint = Paint()
      ..color = _ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    if (state == ValidationState.bad || state == ValidationState.noFace) {
      _drawDashedPath(canvas, stadiumPath, ringPaint);
    } else {
      canvas.drawPath(stadiumPath, ringPaint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 10.0;
    const dashSpace = 6.0;
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final extractPath = metric.extractPath(distance, distance + dashWidth);
        canvas.drawPath(extractPath, paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  Color get _ringColor {
    switch (state) {
      case ValidationState.ready:
      case ValidationState.partial:
        return const Color(0xFF00E676);
      case ValidationState.bad:
        return const Color(0xFFFF5252);
      case ValidationState.noFace:
        return Colors.white.withOpacity(0.6);
    }
  }

  Rect _faceRect(Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.42;
    final w = size.width * 0.65;
    final h = w * 1.35; 
    return Rect.fromCenter(
      center: Offset(cx, cy),
      width: w,
      height: h,
    );
  }

  @override
  bool shouldRepaint(_OvalMaskPainter old) => old.state != state;
}


class _StatusBar extends StatelessWidget {
  final ValidationResult result;

  const _StatusBar({required this.result});

  @override
  Widget build(BuildContext context) {
    final color = _barColor;
    final hintLines = result.hint.split('\n');
    final title = hintLines.first;
    final subtitle = hintLines.length > 1 ? hintLines[1] : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIcon(state: result.state, color: Colors.white),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _barColor {
    switch (result.state) {
      case ValidationState.ready:
        return const Color(0xFF2E7D32); // Dark Green
      case ValidationState.bad:
      case ValidationState.noFace:
        return const Color(0xFFD32F2F); // Dark Red
      case ValidationState.partial:
        return const Color(0xFFF9A825); // Amber
      default:
        return Colors.black87;
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final ValidationState state;
  final Color color;

  const _StatusIcon({required this.state, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (state) {
      case ValidationState.ready:
        icon = Icons.check_circle_rounded;
        break;
      case ValidationState.bad:
      case ValidationState.noFace:
        icon = Icons.cancel_rounded; // Cross icon for failures
        break;
      case ValidationState.partial:
      default:
        icon = Icons.info_rounded;
        break;
    }

    return Icon(icon, color: color, size: 28);
  }
}
