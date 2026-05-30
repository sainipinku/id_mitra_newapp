import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../Widgets/face_overlay_widget.dart';
import '../../api_mamanger/api_manager.dart';
import '../../components/app_theme.dart';
import '../../components/my_font_weight.dart';
import '../../models/face_capture/upload_result.dart';
import '../../models/face_capture/validation_result.dart';
import '../../models/students/StudentsListModel.dart';
import '../../providers/students/students_cubit.dart';
import '../../services/face_validation_service.dart';
import '../../services/image_processing_service.dart';
import '../../utils/camera_utils.dart';

class CameraScreen extends StatefulWidget {
  final String? uploadUrl;
  final void Function(String photoUrl)? onUploaded;
  final void Function(String filePath)? onOfflineSave;
  final String imageFieldName;
  final List<StudentDetailsData>? bulkStudents;
  final String? schoolId;

  const CameraScreen({
    super.key,
    this.uploadUrl,
    this.onUploaded,
    this.onOfflineSave,
    this.imageFieldName = 'image',
    this.bulkStudents,
    this.schoolId,
  });

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
  bool _isUploading = false;
  bool _cameraReady = false;
  bool _isInitializing = false;
  bool _isAutoCapture = false;
  int _currentBulkIndex = 0;
  final Map<int, String> _bulkCapturedImages = {};
  late PageController _bulkPageController;
  String? _initError;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back;

  bool _isSearchVisible = false;
  final TextEditingController _searchCtrl = TextEditingController();

  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _frameInterval = Duration(milliseconds: 30);

  final List<ProcessedImage> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    _bulkPageController = PageController(initialPage: 0);
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {

    if (state == AppLifecycleState.paused) {
      _stopStream();
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        setState(() => _cameraReady = false);
        controller.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && !_isInitializing) {
        _initCamera();
      }
    }
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _initError = 'No cameras found on this device');
        return;
      }

      final camera = CameraUtils.pickCameraByDirection(cameras, _currentLensDirection);
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await controller.initialize();
      if (!mounted) return;

      _controller = controller;
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await controller.startImageStream(_onCameraFrame);

      setState(() => _cameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _initError = 'Camera error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _toggleCamera() async {
    if (_controller == null || _isCapturing) return;

    _stopStream();
    setState(() => _cameraReady = false);

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
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < _frameInterval) return;
    if (!_faceService.isReady) return;
    _lastAnalysis = now;

    final rotation = CameraUtils.rotationFromDeviceOrientation(
      _controller!.description,
    );

    final faceResult = await _faceService.validateFrame(frame, rotation);
    if (!mounted) return;
    setState(() => _liveResult = faceResult);

    // Auto-capture logic
    if (_isAutoCapture &&
        !_isCapturing &&
        !_isUploading &&
        faceResult.hasFace &&
        faceResult.liveQualityScore >= 95) {
      _captureAndProcess();
    }
  }

  Future<void> _captureAndProcess() async {
    if (_isCapturing || _isUploading || _controller == null) return;
    if (!_liveResult.hasFace) {
      _showRetrySnack('Please position your face in the frame first');
      return;
    }

    setState(() => _isCapturing = true);

    try {
      _stopStream();
      final xFile = await _controller!.takePicture();
      HapticFeedback.mediumImpact();

      final analysedResult = await _imageService.analyseImage(
        xFile.path,
        existing: _liveResult,
      );

      final processed = await _imageService.compress(xFile.path, analysedResult);
      if (!mounted) return;

      final score = processed.validationResult.qualityScore;

      if (score < 90) {
        _showRetrySnack(_retakeReason(processed.validationResult));
        await _controller?.startImageStream(_onCameraFrame);
        setState(() => _isCapturing = false);
        return;
      }

      setState(() {
        _isCapturing = false;
        _isUploading = true;
        if (widget.bulkStudents != null) {
          _bulkCapturedImages[_currentBulkIndex] = processed.filePath;
        }
      });

      // Background upload
      await _doUpload(processed);

      // Bulk handling: move to next student after upload
      if (widget.bulkStudents != null && mounted) {
        if (_currentBulkIndex < widget.bulkStudents!.length - 1) {
          final nextIndex = _currentBulkIndex + 1;
          setState(() {
            _currentBulkIndex = nextIndex;
            _isUploading = false;
          });
          _bulkPageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          // Restart stream for next student
          await _controller?.startImageStream(_onCameraFrame);
        } else {
          _showSuccessSnack('All students in bulk list processed!');
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showRetrySnack('Something went wrong. Try again.');
      await _controller?.startImageStream(_onCameraFrame);
      setState(() => _isCapturing = false);
    }
  }

  String _retakeReason(ValidationResult v) {
    if (!v.isSharp) return 'Image is blurry — hold camera steady and try again.';
    if (!v.isWellLit) {
      final b = v.brightnessScore ?? 0;
      if (b < 70) return 'Too dark — move to a brighter area.';
      return 'Too bright — avoid direct sunlight.';
    }
    if (!v.singleFace) return 'Multiple faces detected — one person only.';
    if (!v.hasFace) return 'Face not detected — position face in frame.';
    return 'Quality too low (${v.qualityScore}/100) — try again.';
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _doUpload(ProcessedImage processed) async {
    if (widget.uploadUrl == null) {
      if (mounted) Navigator.pop(context, processed);
      return;
    }

    // Offline check
    final online = await _hasInternet();
    if (!online) {
      if (!mounted) return;
      // Offline callback → calling screen localDB me save karega
      widget.onOfflineSave?.call(processed.filePath);
      
      if (widget.bulkStudents != null) {
        // In bulk mode, we still need to call the cubit to update local state/DB
        final currentStudent = widget.bulkStudents![_currentBulkIndex];
        await context.read<StudentsCubit>().uploadStudentImage(
          path: processed.filePath,
          student: currentStudent,
        );
      }

      setState(() {
        _capturedImages.add(processed);
        _isUploading = false;
      });
      _showOfflineSnack('Saved offline — will upload when connected.');
      return;
    }

    try {
      // If bulk mode, we use StudentsCubit for upload logic to ensure consistency
      if (widget.bulkStudents != null) {
        final currentStudent = widget.bulkStudents![_currentBulkIndex];
        await context.read<StudentsCubit>().uploadStudentImage(
          path: processed.filePath,
          student: currentStudent,
        );
        
        if (mounted) {
          setState(() {
            _capturedImages.add(processed);
            _isUploading = false;
          });
          _showSuccessSnack('Photo uploaded for ${currentStudent.name}!');
        }
        return;
      }

      final response = await ApiManager().multiRequestRoute(
        processed.filePath,
        widget.uploadUrl!,
        fieldName: widget.imageFieldName,
      );

      if (!mounted) return;

      if (response == null ||
          (response.statusCode != 200 && response.statusCode != 201)) {
        setState(() => _isUploading = false);
        _showRetrySnack('Upload failed. Try again.');
        return;
      }

      // API response se naya photo URL nikalo
      String? newPhotoUrl;
      try {
        final json = jsonDecode(response.body);
        newPhotoUrl = json['data']?['profile_photo_url'] as String?;
      } catch (_) {}

      setState(() {
        _capturedImages.add(processed);
        _isUploading = false;
      });

      // Student list ko immediately update karo (camera screen pe hi rahe)
      if (newPhotoUrl != null && newPhotoUrl.isNotEmpty) {
        widget.onUploaded?.call(newPhotoUrl);
      }

      _showSuccessSnack('Photo uploaded!');
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        _showRetrySnack('Upload error. Try again.');
      }
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

  void _showSuccessSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showOfflineSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFF57C00),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSearchVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearchVisible) {
          setState(() {
            _isSearchVisible = false;
            _searchCtrl.clear();
          });
          FocusScope.of(context).unfocus();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initError != null) return _ErrorView(message: _initError!);
    if (!_cameraReady || _controller == null) return const _LoadingView();

    return _CameraView(
      controller: _controller!,
      liveResult: _liveResult,
      isCapturing: _isCapturing,
      isUploading: _isUploading,
      isAutoCapture: _isAutoCapture,
      onToggleAutoCapture: () => setState(() => _isAutoCapture = !_isAutoCapture),
      onCapture: _captureAndProcess,
      onToggleCamera: _toggleCamera,
      isSearchVisible: _isSearchVisible,
      onToggleSearch: () => setState(() {
        _isSearchVisible = !_isSearchVisible;
        if (!_isSearchVisible) {
          _searchCtrl.clear();
          FocusScope.of(context).unfocus();
        }
      }),
      searchController: _searchCtrl,
      capturedImages: _capturedImages,
      onOpenGallery: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _GalleryScreen(images: _capturedImages),
        ),
      ),
      bulkStudents: widget.bulkStudents,
      currentBulkIndex: _currentBulkIndex,
      bulkCapturedImages: _bulkCapturedImages,
      onBulkPageChanged: (index) {
        setState(() {
          _currentBulkIndex = index;
        });
        // Restart or stop camera stream based on if already captured
        if (!_bulkCapturedImages.containsKey(index)) {
          _controller?.startImageStream(_onCameraFrame);
        } else {
          _stopStream();
        }
      },
      bulkPageController: _bulkPageController,
      onStudentSelected: (index) {
        _bulkPageController.jumpToPage(index);
        setState(() {
          _isSearchVisible = false;
          _searchCtrl.clear();
          _currentBulkIndex = index;
        });
        FocusScope.of(context).unfocus();
        if (!_bulkCapturedImages.containsKey(index)) {
          _controller?.startImageStream(_onCameraFrame);
        } else {
          _stopStream();
        }
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopStream();
    _controller?.dispose();
    _faceService.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }
}



class _CameraView extends StatelessWidget {
  final CameraController controller;
  final ValidationResult liveResult;
  final bool isCapturing;
  final bool isUploading;
  final bool isAutoCapture;
  final VoidCallback onToggleAutoCapture;
  final VoidCallback onCapture;
  final VoidCallback onToggleCamera;
  final bool isSearchVisible;
  final VoidCallback onToggleSearch;
  final TextEditingController searchController;
  final List<ProcessedImage> capturedImages;
  final VoidCallback onOpenGallery;
  final List<StudentDetailsData>? bulkStudents;
  final int currentBulkIndex;
  final Map<int, String> bulkCapturedImages;
  final Function(int) onBulkPageChanged;
  final PageController bulkPageController;
  final Function(int) onStudentSelected;

  const _CameraView({
    required this.controller,
    required this.liveResult,
    required this.isCapturing,
    required this.isUploading,
    required this.isAutoCapture,
    required this.onToggleAutoCapture,
    required this.onCapture,
    required this.onToggleCamera,
    required this.isSearchVisible,
    required this.onToggleSearch,
    required this.searchController,
    required this.capturedImages,
    required this.onOpenGallery,
    this.bulkStudents,
    required this.currentBulkIndex,
    required this.bulkCapturedImages,
    required this.onBulkPageChanged,
    required this.bulkPageController,
    required this.onStudentSelected,
  });

  Widget _buildStudentImage({
    required bool isSessionCaptured,
    required bool hasOfflinePhoto,
    required int currentBulkIndex,
    required List<StudentDetailsData> bulkStudents,
    required Map<int, String> bulkCapturedImages,
  }) {
    if (isSessionCaptured) {
      final path = bulkCapturedImages[currentBulkIndex]!;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
      );
    } else if (hasOfflinePhoto) {
      final path = bulkStudents[currentBulkIndex].offlinePhotoPath!;
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          // Fallback check if path is valid but file missing
          return _imagePlaceholder();
        },
      );
    } else {
      final student = bulkStudents[currentBulkIndex];
      final url = student.profilePhotoUrl?.trim();

      if (url == null || url.isEmpty || url.contains('ui-avatars.com')) {
        return _imagePlaceholder();
      }

      // Special case: check if profilePhotoUrl is actually a local path
      if (!url.startsWith('http')) {
        return Image.file(
          File(url),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _imagePlaceholder(),
        );
      }

      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
          ),
        ),
        errorWidget: (context, url, error) => _imagePlaceholder(),
        // Force use of cache if offline
        useOldImageOnUrlChange: true,
        cacheKey: url, // Use URL as cache key to ensure consistency
      );
    }
  }

  Widget _imagePlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.1),
      child: const Icon(
        Icons.person_outline,
        color: Colors.white24,
        size: 24,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveScore = liveResult.liveQualityScore;
    final liveColor = liveResult.liveQualityColor;
    final bool hasImages = capturedImages.isNotEmpty;
    final bool isSessionCaptured =
        bulkCapturedImages.containsKey(currentBulkIndex);
    final bool hasServerPhoto = bulkStudents != null &&
        bulkStudents![currentBulkIndex].profilePhotoUrl != null &&
        bulkStudents![currentBulkIndex].profilePhotoUrl!.isNotEmpty;
    final bool hasOfflinePhoto = bulkStudents != null &&
        bulkStudents![currentBulkIndex].offlinePhotoPath != null &&
        bulkStudents![currentBulkIndex].offlinePhotoPath!.isNotEmpty;

    // Only consider it "captured" if it was done in this session
    final bool isAlreadyCaptured = isSessionCaptured;
    final bool hasAnyPhoto =
        isSessionCaptured || hasServerPhoto || hasOfflinePhoto;

    return MediaQuery.removeViewInsets(
      context: context,
      removeBottom: true,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                  onPressed: isSearchVisible
                      ? onToggleSearch
                      : () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Text(
                    isAlreadyCaptured ? 'Photo Preview' : 'Take Photo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isAlreadyCaptured)
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios_outlined,
                      color: Colors.white,
                    ),
                    onPressed: onToggleCamera,
                  )
                else
                  const SizedBox(width: 48),
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
                        child: isAlreadyCaptured 
                            ? _buildStudentImage(
                                isSessionCaptured: isSessionCaptured,
                                hasOfflinePhoto: hasOfflinePhoto,
                                currentBulkIndex: currentBulkIndex,
                                bulkStudents: bulkStudents!,
                                bulkCapturedImages: bulkCapturedImages,
                              )
                            : CameraPreview(controller),
                      ),
                    ),
                  ),
                ),

                if (!isAlreadyCaptured)
                  FaceOverlayWidget(
                    result: liveResult,
                    previewSize: MediaQuery.of(context).size,
                  ),

                if (isCapturing)
                  const ColoredBox(color: Colors.white24),

                // Uploading indicator — thin bar at top
                if (isUploading)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF00E676)),
                      ),
                    ),
                  ),

                if (liveResult.hasFace && !isCapturing && !isUploading && !isAlreadyCaptured)
                  Positioned(
                    top: 12,
                    right: 14,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: liveColor.withOpacity(0.6), width: 1.2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$liveScore',
                            style: TextStyle(
                              color: liveColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                          Text(
                            'Quality',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 9),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Horizontal PageView for Bulk Navigation
                if (bulkStudents != null)
                  Positioned.fill(
                    child: PageView.builder(
                      controller: bulkPageController,
                      itemCount: bulkStudents!.length,
                      onPageChanged: onBulkPageChanged,
                      itemBuilder: (context, index) => const SizedBox.expand(),
                    ),
                  ),

                // Manual / Auto Capture Toggle (Right Side)
                if (!isAlreadyCaptured && !isSearchVisible)
                  Positioned(
                    right: 16,
                    top: MediaQuery.of(context).size.height * 0.45,
                    child: Column(
                      children: [
                        _ToggleIconButton(
                          icon: Icons.touch_app_outlined,
                          label: 'Manual',
                          isActive: !isAutoCapture,
                          onTap: isAutoCapture ? onToggleAutoCapture : null,
                        ),
                        const SizedBox(height: 20),
                        _ToggleIconButton(
                          icon: Icons.auto_fix_high_outlined,
                          label: 'Auto',
                          isActive: isAutoCapture,
                          onTap: !isAutoCapture ? onToggleAutoCapture : null,
                        ),
                      ],
                    ),
                  ),

                Positioned(
                  top: 8,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      IgnorePointer(
                        ignoring: !isSearchVisible,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isSearchVisible ? 1.0 : 0.0,
                          child: Material(
                            color: Colors.transparent,
                            child: TextField(
                              controller: searchController,
                              autofocus: isSearchVisible,
                              style: MyStyles.regularText(
                                size: 14,
                                color: AppTheme.black_Color,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: AppTheme.whiteColor,
                                contentPadding: const EdgeInsets.all(12),
                                hintText: 'Search by name...',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: searchController,
                                  builder: (_, value, __) {
                                    return value.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, size: 18),
                                            onPressed: () =>
                                                searchController.clear(),
                                          )
                                        : const SizedBox.shrink();
                                  },
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppTheme.backBtnBgColor),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppTheme.backBtnBgColor),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                hintStyle: MyStyles.regularText(
                                  size: 14,
                                  color: AppTheme.graySubTitleColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isSearchVisible)
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: searchController,
                          builder: (context, value, _) {
                            if (value.text.isEmpty || bulkStudents == null) {
                              return const SizedBox.shrink();
                            }

                            final results = bulkStudents!
                                .asMap()
                                .entries
                                .where((e) => e.value.name!
                                    .toLowerCase()
                                    .contains(value.text.toLowerCase()))
                                .toList();

                            if (results.isEmpty) return const SizedBox.shrink();

                            return Container(
                              margin: const EdgeInsets.only(top: 4),
                              constraints: const BoxConstraints(maxHeight: 250),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemBuilder: (context, i) {
                                  final index = results[i].key;
                                  final student = results[i].value;
                                  return ListTile(
                                    dense: true,
                                    title: Text(student.name ?? '',
                                        style: MyStyles.mediumText(
                                            size: 14,
                                            color: AppTheme.black_Color)),
                                    subtitle: Text(
                                        "${student.datumClass?.nameWithprefix ?? ''} - ${student.section?.name ?? ''}",
                                        style: MyStyles.regularText(
                                            size: 12,
                                            color: AppTheme.graySubTitleColor)),
                                    trailing: bulkCapturedImages.containsKey(index)
                                        ? const Icon(Icons.check_circle,
                                            color: Colors.green, size: 18)
                                        : null,
                                    onTap: () => onStudentSelected(index),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bulk Student Details (Integrated Container Below Frame)
          if (bulkStudents != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Student Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.btnColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Student ${currentBulkIndex + 1}/${bulkStudents!.length}",
                                  style: const TextStyle(
                                      color: AppTheme.btnColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            bulkStudents![currentBulkIndex].name ?? 'Unknown',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${bulkStudents![currentBulkIndex].datumClass?.nameWithprefix ?? ''} - ${bulkStudents![currentBulkIndex].section?.name ?? ''}",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Image Preview (Integrated)
                    if (hasAnyPhoto)
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isSessionCaptured
                                  ? Colors.green
                                  : (hasOfflinePhoto
                                      ? Colors.blue
                                      : (hasServerPhoto
                                          ? AppTheme.btnColor // Use theme color instead of orange
                                          : Colors.white24)),
                              width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildStudentImage(
                                isSessionCaptured: isSessionCaptured,
                                hasOfflinePhoto: hasOfflinePhoto,
                                currentBulkIndex: currentBulkIndex,
                                bulkStudents: bulkStudents!,
                                bulkCapturedImages: bulkCapturedImages,
                              ),
                            ),
                            if (hasOfflinePhoto && !isSessionCaptured)
                              const Positioned(
                                top: 2,
                                right: 2,
                                child: Icon(Icons.cloud_off,
                                    color: Colors.white70, size: 12),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

          // Bottom row: Gallery | Capture | Search
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Gallery button (left) — native camera style
                if (!isAlreadyCaptured)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: hasImages ? onOpenGallery : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasImages
                                ? Colors.white.withOpacity(0.8)
                                : Colors.white.withOpacity(0.25),
                            width: 2,
                          ),
                          color: Colors.white12,
                        ),
                        child: hasImages
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      File(capturedImages.last.filePath),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (capturedImages.length > 1)
                                    Positioned(
                                      bottom: 3,
                                      right: 3,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(5),
                                        ),
                                        child: Text(
                                          '${capturedImages.length}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : const Icon(
                                Icons.photo_library_outlined,
                                color: Colors.white30,
                                size: 24,
                              ),
                      ),
                    ),
                  ),

                _CaptureButton(
                  isReady: !isCapturing && !isUploading && !isAlreadyCaptured,
                  isCapturing: isCapturing || isUploading,
                  onTap: onCapture,
                  isHidden: isAlreadyCaptured,
                ),

                if (!isAlreadyCaptured)
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: onToggleSearch,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSearchVisible
                              ? Colors.white.withOpacity(0.2)
                              : Colors.transparent,
                          border: Border.all(
                            color: isSearchVisible
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isSearchVisible ? Icons.search_off : Icons.search,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _ToggleIconButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? AppTheme.btnColor : Colors.black.withOpacity(0.5),
              border: Border.all(
                color: isActive ? Colors.white : Colors.white24,
                width: 1.5,
              ),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppTheme.btnColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final bool isReady;
  final bool isCapturing;
  final VoidCallback onTap;
  final bool isHidden;

  const _CaptureButton({
    required this.isReady,
    required this.isCapturing,
    required this.onTap,
    this.isHidden = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isHidden) return const SizedBox(width: 80, height: 80);
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


// ─── Gallery Screen ─────────────────────────────────────────────────────────

class _GalleryScreen extends StatelessWidget {
  final List<ProcessedImage> images;
  const _GalleryScreen({required this.images});

  @override
  Widget build(BuildContext context) {
    final total = images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$total Photo${total != 1 ? 's' : ''}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: total,
        itemBuilder: (_, i) {
          // Newest first
          final img = images[total - 1 - i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _CapturePreviewPage(image: img),
              ),
            ),
            child: Image.file(
              File(img.filePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF1C1C1E),
                child: Icon(Icons.broken_image_outlined,
                    color: Colors.white24, size: 28),
              ),
            ),
          );
        },
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
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}



class _CapturePreviewPage extends StatelessWidget {
  final ProcessedImage image;
  const _CapturePreviewPage({required this.image});

  @override
  Widget build(BuildContext context) {
    final score = image.validationResult.qualityScore;
    final scoreColor = image.validationResult.qualityColor;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: Text(
                      'Captured Photo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Image fullscreen with quality badge
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(image.filePath),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF1C1C1E),
                          child: Center(
                            child: Icon(Icons.broken_image_outlined,
                                color: Colors.white24, size: 48),
                          ),
                        ),
                      ),
                    ),

                    // Quality score badge
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scoreColor.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Quality Score',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 11),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '$score',
                                  style: TextStyle(
                                    color: scoreColor,
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '/100',
                                  style: TextStyle(
                                      color: Colors.white38, fontSize: 14),
                                ),
                              ],
                            ),
                            Text(
                              image.validationResult.qualityLabel,
                              style: TextStyle(
                                color: scoreColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Validation badges (top right)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _PreviewBadge(
                              label: 'Face',
                              ok: image.validationResult.singleFace),
                          const SizedBox(height: 6),
                          _PreviewBadge(
                              label: 'Sharp',
                              ok: image.validationResult.isSharp),
                          const SizedBox(height: 6),
                          _PreviewBadge(
                              label: 'Light',
                              ok: image.validationResult.isWellLit),
                          const SizedBox(height: 6),
                          _PreviewBadge(
                              label: 'Angle',
                              ok: image.validationResult.isFacingStraight),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  final String label;
  final bool ok;
  const _PreviewBadge({required this.label, required this.ok});

  @override
  Widget build(BuildContext context) {
    final color = ok ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close, color: color, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
