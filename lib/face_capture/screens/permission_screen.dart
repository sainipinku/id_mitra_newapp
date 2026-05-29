import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:idmitra/face_capture/screens/camera_screen.dart';

class PermissionScreen extends StatefulWidget {
  final String? uploadUrl;
  const PermissionScreen({super.key, this.uploadUrl});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _checking = false;

  Future<void> _requestPermission() async {
    setState(() => _checking = true);

    final status = await Permission.camera.request();

    if (!mounted) return;
    setState(() => _checking = false);

    if (status.isGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CameraScreen(uploadUrl: widget.uploadUrl),
        ),
      );
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission is required to take a photo.'),
          backgroundColor: Color(0xFFFF5252),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                    border: Border.all(color: Colors.white12, width: 1.5),
                  ),
                  child: const Icon(Icons.camera_alt_outlined,
                      color: Colors.white54, size: 44),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Camera Access',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'We need camera access to take and validate your photo before upload.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00E676), Color(0xFF00BFA5)],
                      ),
                    ),
                    child: TextButton(
                      onPressed: _checking ? null : _requestPermission,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _checking
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black54,
                              ),
                            )
                          : const Text(
                              'Allow Camera',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
