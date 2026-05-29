import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:idmitra/face_capture/models/upload_result.dart';
import 'package:idmitra/face_capture/models/validation_result.dart';
import '../../Widgets/face_overlay_widget.dart';
import '../../services/face_validation_service.dart';
import '../../services/image_processing_service.dart';
import '../../utils/camera_utils.dart';
import 'preview_screen.dart';



class CameraScreen extends StatefulWidget {
  final String? uploadUrl;
  const CameraScreen({super.key, this.uploadUrl});


  @override
  State<CameraScreen> createState() => _CameraScreenState();
}


class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  final FaceValidationService _faceService = FaceValidationService();
  final ImageProcessingService _imageService = ImageProcessingService();


  ValidationResult _liveResult = const ValidationResult();
  bool _isCapturing = false;
  bool _cameraReady = false;
  String? _initError;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;
  
  DateTime? _readySince;
  int _autoCaptureSeconds = 0;
  bool _isAutoMode = false;


  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameInterval = Duration(milliseconds: 100);


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }


  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;


    if (state == AppLifecycleState.inactive) {
      _stopStream();
      setState(() {
        _cameraReady = false;
      });
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }



  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _initError = 'No cameras found on this device');
        return;
      }


      final camera = CameraUtils.pickCameraByDirection(cameras, _currentLensDirection);
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // Android
      );


      await controller.initialize();
      if (!mounted) return;


      _controller = controller;


      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);


      await controller.startImageStream(_onCameraFrame);


      setState(() => _cameraReady = true);
    } catch (e) {
      setState(() => _initError = 'Camera error: $e');
    }
  }


  Future<void> _toggleCamera() async {
    if (_controller == null || _isCapturing) return;


    _stopStream();
    setState(() {
      _cameraReady = false;
    });


    final oldController = _controller;
    _controller = null;
    await oldController?.dispose();


    setState(() {
      _currentLensDirection = _currentLensDirection == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
    });


    await _initCamera();
  }


  void _stopStream() {
    if (_controller?.value.isStreamingImages == true) {
      _controller?.stopImageStream();
    }
  }



  Future<void> _onCameraFrame(CameraImage frame) async {
    // Throttle
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < _frameInterval) return;
    if (!_faceService.isReady) return;
    _lastAnalysis = now;


    final rotation = CameraUtils.rotationFromDeviceOrientation(
      _controller!.description,
    );


    final faceResult = await _faceService.validateFrame(frame, rotation);


    if (!mounted) return;
    
    if (faceResult.isReady && !_isCapturing) {
      if (_readySince == null) {
        _readySince = DateTime.now();
      } else {
        final diff = DateTime.now().difference(_readySince!).inMilliseconds;
        final secondsLeft = 2 - (diff ~/ 1000); // Standard 2s countdown
        if (secondsLeft <= 0) {
          _readySince = null;
          _autoCaptureSeconds = 0;
          _captureAndProcess();
        } else if (secondsLeft != _autoCaptureSeconds) {
          setState(() => _autoCaptureSeconds = secondsLeft);
        }
      }
    } else {
      _readySince = null;
      if (_autoCaptureSeconds != 0) {
        setState(() => _autoCaptureSeconds = 0);
      }
    }


    setState(() => _liveResult = faceResult);
  }



  Future<void> _captureAndProcess() async {
    if (_isCapturing || _controller == null) return;
    if (!_liveResult.hasFace) {
      _showRetrySnack('Please position your face in the frame first');
      return;
    }

    setState(() => _isCapturing = true);


    try {
      _stopStream();


      final xFile = await _controller!.takePicture();


      HapticFeedback.mediumImpact();

      final fullResult = await _imageService.analyseImage(
        xFile.path,
        existing: _liveResult,
      );

      final processed = await _imageService.compress(xFile.path, fullResult);


      if (!mounted) return;


      final result = await Navigator.push<dynamic>(
        context,
        MaterialPageRoute(
          builder: (_) => PreviewScreen(
            processedImage: processed,
            uploadUrl: widget.uploadUrl,
          ),
        ),
      );


      if (result is ProcessedImage) {
        if (mounted) Navigator.pop(context, result);
        return;
      }

      if (result is Map<String, dynamic>) {
        if (mounted) Navigator.pop(context, result);
        return;
      }

      if (result != true) {
        await _controller!.startImageStream(_onCameraFrame);
        setState(() => _isCapturing = false);
      }
    } catch (e) {
      _showRetrySnack('Something went wrong. Try again.');
      await _controller?.startImageStream(_onCameraFrame);
      setState(() => _isCapturing = false);
    }
  }


  void _showRetrySnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFFF5252),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }


  Widget _buildBody() {
    if (_initError != null) return _ErrorView(message: _initError!);
    if (!_cameraReady || _controller == null) return _LoadingView();
    return _CameraView(
      controller: _controller!,
      liveResult: _liveResult,
      isCapturing: _isCapturing,
      onCapture: _captureAndProcess,
      onToggleCamera: _toggleCamera,
      autoCaptureSeconds: _autoCaptureSeconds,
    );
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _faceService.dispose();
    super.dispose();
  }
}



class _CameraView extends StatelessWidget {
  final CameraController controller;
  final ValidationResult liveResult;
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onToggleCamera;
  final int autoCaptureSeconds;


  const _CameraView({
    required this.controller,
    required this.liveResult,
    required this.isCapturing,
    required this.onCapture,
    required this.onToggleCamera,
    required this.autoCaptureSeconds,
  });


  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const Expanded(
                child: Text(
                  'Take Photo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.flip_camera_ios_outlined, color: Colors.white),
                onPressed: onToggleCamera,
              ),
            ],
          ),
        ),

        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: OverflowBox(
                  alignment: Alignment.center,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller.value.previewSize!.height,
                      height: controller.value.previewSize!.width,
                      child: CameraPreview(controller),
                    ),
                  ),
                ),
              ),


              FaceOverlayWidget(
                result: liveResult,
                previewSize: MediaQuery.of(context).size,
                countdown: autoCaptureSeconds,
              ),

              if (isCapturing)
                const ColoredBox(color: Colors.white24),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: _CaptureButton(
            isReady: !isCapturing,
            isCapturing: isCapturing,
            onTap: onCapture,
          ),
        ),
      ],
    );
  }
}


class _CaptureButton extends StatelessWidget {
  final bool isReady;
  final bool isCapturing;
  final VoidCallback onTap;


  const _CaptureButton({
    required this.isReady,
    required this.isCapturing,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    final color =
        isReady ? const Color(0xFF00E676) : Colors.white.withOpacity(0.3);


    return GestureDetector(
      onTap: isReady ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 4),
        ),
        child: Center(
          child: isCapturing
              ? const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
        ),
      ),
    );
  }
}


class _LoadingView extends StatelessWidget {
  const _LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text('Starting camera…',
              style: TextStyle(color: Colors.white70, fontSize: 15)),
        ],
      ),
    );
  }
}


class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});


  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white38, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
