import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/providers/global_summary/global_data_cubit.dart';
import 'package:idmitra/providers/global_summary/global_summary_state.dart';

class BackupGlobalDataScreen extends StatefulWidget {
  const BackupGlobalDataScreen({super.key});

  @override
  State<BackupGlobalDataScreen> createState() => _BackupGlobalDataScreenState();
}

class _BackupGlobalDataScreenState extends State<BackupGlobalDataScreen> {
  int _activeDotIndex = 0;
  Timer? _dotTimer;

  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;
  bool _hasVideoError = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  static const String _videoUrl =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

  @override
  void initState() {
    super.initState();
    _dotTimer = Timer.periodic(const Duration(milliseconds: 280), (timer) {
      if (mounted) setState(() => _activeDotIndex = (_activeDotIndex + 1) % 14);
    });
    _initVideo();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
    _videoController.addListener(_onVideoUpdate);
    _videoController.initialize().then((_) {
      if (mounted) setState(() => _isVideoInitialized = true);
    }).catchError((_) {
      if (mounted) setState(() => _hasVideoError = true);
    });
  }

  void _onVideoUpdate() {
    if (!mounted) return;
    if (_isVideoInitialized && _videoController.value.hasError) {
      setState(() => _hasVideoError = true);
      return;
    }
    setState(() {});
    if (_videoController.value.isPlaying && _showControls) {
      _scheduleHideControls();
    }
  }

  void _togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
      setState(() => _showControls = true);
      _hideControlsTimer?.cancel();
    } else {
      _videoController.play();
      _scheduleHideControls();
    }
  }

  void _seekBackward() {
    final pos = _videoController.value.position;
    final target = pos - const Duration(seconds: 10);
    _videoController.seekTo(target < Duration.zero ? Duration.zero : target);
  }

  void _seekForward() {
    final pos = _videoController.value.position;
    final dur = _videoController.value.duration;
    final target = pos + const Duration(seconds: 10);
    _videoController.seekTo(target > dur ? dur : target);
  }

  void _onVideoTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls && _videoController.value.isPlaying) {
      _scheduleHideControls();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoController.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _hideControlsTimer?.cancel();
    _videoController.removeListener(_onVideoUpdate);
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GlobalDataCubit(),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.MainColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'How to Upload Image',
                        style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                      ),
                    ],
                  ),
                ),

                // Video player
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.45,
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: _isVideoInitialized ? _onVideoTap : null,
                    child: _hasVideoError
                        ? _buildErrorWidget()
                        : _isVideoInitialized
                            ? _buildPlayer()
                            : _buildLoading(),
                  ),
                ),

                const SizedBox(height: 24),

                // Sync section — driven by BLoC
                BlocBuilder<GlobalDataCubit, GlobalSummaryState>(
                  builder: (context, state) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        children: [
                          _buildDotsRow(),
                          const SizedBox(height: 14),
                          _buildSyncProgressBar(state),
                          const SizedBox(height: 10),
                          _buildSyncStatusText(state),
                          const SizedBox(height: 20),
                          _buildSyncButton(context, state),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.all(10.0),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              border: Border.all(color: AppTheme.titleHintColor),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(5.0),
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
            ),
          ),
        ),
      ),
      title: Image.asset('assets/images/app_logo.png', height: 120),
    );
  }

  // ─── Video widgets ────────────────────────────────────────────────────────

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: AppTheme.MainColor, strokeWidth: 3),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white54, size: 36),
          const SizedBox(height: 10),
          Text('Unable Load Video',
              style: MyStyles.regularText(size: 13, color: Colors.white70)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              _videoController.removeListener(_onVideoUpdate);
              _videoController.dispose();
              setState(() {
                _hasVideoError = false;
                _isVideoInitialized = false;
              });
              _initVideo();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.MainColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Retry',
                  style: MyStyles.boldText(size: 13, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final position = _videoController.value.position;
    final duration = _videoController.value.duration;
    final progress = duration.inMilliseconds > 0
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final isPlaying = _videoController.value.isPlaying;

    return Stack(
      children: [
        Container(color: Colors.black),
        Center(
          child: AspectRatio(
            aspectRatio: _videoController.value.aspectRatio,
            child: VideoPlayer(_videoController),
          ),
        ),
        AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 250),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.25),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.2, 0.55, 1.0],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _seekBtn(Icons.replay_10_rounded, _seekBackward),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.MainColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.MainColor.withOpacity(0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    _seekBtn(Icons.forward_10_rounded, _seekForward),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(position),
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(_fmt(duration),
                              style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                          activeTrackColor: AppTheme.MainColor,
                          inactiveTrackColor: Colors.white.withOpacity(0.3),
                          thumbColor: Colors.white,
                          overlayColor: AppTheme.MainColor.withOpacity(0.25),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (val) {
                            _videoController.seekTo(Duration(
                              milliseconds: (val * duration.inMilliseconds).toInt(),
                            ));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _seekBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withOpacity(0.4),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  // ─── Sync section widgets ─────────────────────────────────────────────────

  Widget _buildDotsRow() {
    const int totalDots = 14;
    const int trailLength = 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_sync_outlined, color: AppTheme.graySubTitleColor, size: 28),
        const SizedBox(width: 8),
        ...List.generate(totalDots, (index) {
          final dist = (_activeDotIndex - index) % totalDots;
          final nd = dist < 0 ? dist + totalDots : dist;
          Color dotColor;
          double dotSize;
          if (nd == 0) {
            dotColor = AppTheme.MainColor;
            dotSize = 8;
          } else if (nd <= trailLength) {
            dotColor = AppTheme.MainColor.withOpacity(1.0 - (nd / trailLength) * 0.8);
            dotSize = 6;
          } else {
            dotColor = AppTheme.borderLineColor.withOpacity(0.5);
            dotSize = 5;
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          );
        }),
        const SizedBox(width: 8),
        Icon(Icons.phone_android_rounded, color: AppTheme.graySubTitleColor, size: 28),
      ],
    );
  }

  Widget _buildSyncProgressBar(GlobalSummaryState state) {
    Color barColor = AppTheme.MainColor;
    if (state.status == GlobalSyncStatus.error) barColor = Colors.red;
    if (state.status == GlobalSyncStatus.noInternet) barColor = Colors.orange;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        // Always show determinate progress — value drives the bar
        value: state.progress > 0 ? state.progress : null,
        minHeight: 7,
        backgroundColor: barColor.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }

  Widget _buildSyncStatusText(GlobalSummaryState state) {
    Color textColor = AppTheme.black_Color;
    if (state.status == GlobalSyncStatus.error) textColor = Colors.red;
    if (state.status == GlobalSyncStatus.noInternet) textColor = Colors.orange;
    if (state.status == GlobalSyncStatus.success) textColor = Colors.green;

    return Text(
      state.statusText,
      style: MyStyles.regularText(size: 13, color: textColor),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSyncButton(BuildContext context, GlobalSummaryState state) {
    final isSyncing = state.isSyncing;
    return GestureDetector(
      onTap: isSyncing
          ? null
          : () => context.read<GlobalDataCubit>().syncAll(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSyncing ? AppTheme.MainColor.withOpacity(0.6) : AppTheme.MainColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSyncing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            else
              const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              isSyncing ? 'Syncing...' : 'Sync Backup',
              style: MyStyles.boldText(size: 15, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

}