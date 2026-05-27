import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/local_db/global_backup_local_ds.dart';

// Entity config: [apiResponseKey, dbEntityType, schoolIdField]
const _entityCfg = [
  ['schools', 'school', 'id'],
  ['students', 'student', 'school_id'],
  ['orders', 'order', 'school_id'],
  ['staff_orders', 'staff_order', 'school_id'],
  ['student_corrections', 'student_correction', 'school_id'],
  ['staff_corrections', 'staff_correction', 'school_id'],
];

const _entityDisplayNames = {
  'schools': 'Schools',
  'students': 'Students',
  'orders': 'Orders',
  'staff_orders': 'Staff Orders',
  'student_corrections': 'Student Corrections',
  'staff_corrections': 'Staff Corrections',
};

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

  bool _isSyncing = false;
  int _savedRecords = 0;
  int _totalRecords = 0;
  String _syncStatusLabel = '';
  DateTime? _lastSyncedAt;
  String? _syncError;

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

  // ── Internet check ────────────────────────────────────────────────────────
  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Offline: global_backup se stats load karo ─────────────────────────────
  Future<void> _loadOfflineBackup() async {
    try {
      final localDS = GlobalBackupLocalDS();
      final total = await localDS.getTotalBackupCount();
      final lastSync = await localDS.getLastSyncedAt();

      if (total == 0) {
        setState(() {
          _isSyncing = false;
          _syncError = 'Koi backup nahi mila. Pehle online ho kar sync karo.';
        });
        return;
      }

      setState(() {
        _isSyncing = false;
        _savedRecords = total;
        _totalRecords = total;
        _lastSyncedAt = lastSync;
      });
    } catch (_) {
      setState(() {
        _isSyncing = false;
        _syncError = 'Offline backup load karne mein error aaya.';
      });
    }
  }

  // Retries on 429 with a live countdown, max 5 attempts
  Future<dynamic> _getWithRetry(String url) async {
    const maxRetries = 5;
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await ApiManager().getRequest(url);
      if (response != null && response.statusCode == 429) {
        if (attempt < maxRetries) {
          for (int i = 5; i > 0; i--) {
            if (!mounted) return null;
            setState(() => _syncStatusLabel = 'Server busy, retrying in ${i}s...');
            await Future.delayed(const Duration(seconds: 1));
          }
          continue;
        }
      }
      return response;
    }
    return null;
  }

  Future<void> _syncBackup() async {
    setState(() {
      _isSyncing = true;
      _syncError = null;
      _savedRecords = 0;
      _totalRecords = 0;
      _syncStatusLabel = 'Checking internet...';
    });

    // ── Internet check ─────────────────────────────────────────────────────
    final online = await _isConnected();
    if (!online) {
      setState(() => _syncStatusLabel = 'Loading offline backup data...');
      await _loadOfflineBackup();
      return;
    }

    setState(() => _syncStatusLabel = 'Connecting to server...');

    try {
      // ── Fetch page 1 of all entities ──
      final response = await _getWithRetry(
        Config.url(Routes.getPartnerGlobalData()),
      );

      if (response == null) {
        setState(() {
          _isSyncing = false;
          _syncError = 'No internet connection. Please try again.';
        });
        return;
      }
      if (response.statusCode != 200) {
        setState(() {
          _isSyncing = false;
          _syncError = 'Server error (${response.statusCode}). Please try again.';
        });
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['success'] != true) {
        setState(() {
          _isSyncing = false;
          _syncError = body['message'] ?? 'Server returned an error.';
        });
        return;
      }

      final data = body['data'] as Map<String, dynamic>;

      // ── Calculate total records from pagination ──
      int total = 0;
      final paginationInfo = <String, Map<String, dynamic>>{};
      for (final cfg in _entityCfg) {
        final apiKey = cfg[0];
        final entityData = data[apiKey] as Map<String, dynamic>?;
        if (entityData != null) {
          paginationInfo[apiKey] = entityData;
          total += (entityData['total'] as int?) ??
              (entityData['data'] as List).length;
        }
      }

      if (mounted) setState(() => _totalRecords = total);

      // ── Save page 1 data ──
      final localDS = GlobalBackupLocalDS();
      for (final cfg in _entityCfg) {
        final apiKey = cfg[0];
        final dbType = cfg[1];
        final schoolIdKey = cfg[2];
        final entityData = data[apiKey] as Map<String, dynamic>?;
        if (entityData == null) continue;

        final items = entityData['data'] as List;
        if (items.isNotEmpty) {
          if (mounted) {
            setState(() => _syncStatusLabel =
                'Saving ${_entityDisplayNames[apiKey]}...');
          }
          await localDS.saveEntities(dbType, items, schoolIdKey: schoolIdKey);
          if (mounted) setState(() => _savedRecords += items.length);
        }
      }

      // ── Fetch and save remaining pages ──
      for (final cfg in _entityCfg) {
        final apiKey = cfg[0];
        final dbType = cfg[1];
        final schoolIdKey = cfg[2];
        final entityPagination = paginationInfo[apiKey];
        if (entityPagination == null) continue;

        final lastPage = entityPagination['last_page'] as int? ?? 1;
        for (int page = 2; page <= lastPage; page++) {
          if (mounted) {
            setState(() => _syncStatusLabel =
                'Fetching ${_entityDisplayNames[apiKey]} (page $page/$lastPage)...');
          }

          final pageResponse = await _getWithRetry(
            Config.url(Routes.getPartnerGlobalDataPage(apiKey, page)),
          );

          if (pageResponse == null || pageResponse.statusCode != 200) continue;

          final pageBody =
              jsonDecode(pageResponse.body) as Map<String, dynamic>;
          if (pageBody['success'] != true) continue;

          final pageEntityData =
              (pageBody['data'] as Map<String, dynamic>)[apiKey]
                  as Map<String, dynamic>?;
          if (pageEntityData == null) continue;

          final pageItems = pageEntityData['data'] as List;
          if (pageItems.isNotEmpty) {
            await localDS.saveEntities(dbType, pageItems,
                schoolIdKey: schoolIdKey);
            if (mounted) setState(() => _savedRecords += pageItems.length);
          }
        }
      }

      // ── Backup complete — home_cache populate karo taaki screens offline kaam karein
      if (mounted) {
        setState(() => _syncStatusLabel = 'Finalizing offline cache...');
      }
      await localDS.populateSchoolsHomeCache();

      if (mounted) {
        setState(() {
          _isSyncing = false;
          _lastSyncedAt = DateTime.now();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _syncError = 'Unexpected error. Please try again.';
        });
      }
    }
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── "How to Upload Image" label ──
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
                      style: MyStyles.boldText(
                          size: 16, color: AppTheme.black_Color),
                    ),
                  ],
                ),
              ),

              // ── Full-width video player ──
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

              // ── Sync section ──
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    _buildDotsRow(),
                    const SizedBox(height: 14),
                    _buildSyncProgressBar(),
                    const SizedBox(height: 10),
                    _buildSyncStatusText(),
                    const SizedBox(height: 20),
                    _buildSyncButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────
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
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.black87),
            ),
          ),
        ),
      ),
      title: Image.asset('assets/images/app_logo.png', height: 120),
    );
  }

  Widget _buildLoading() {
    return Container(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(
            color: AppTheme.MainColor, strokeWidth: 3),
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
                          isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
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
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(_fmt(duration),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 7),
                          overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 14),
                          activeTrackColor: AppTheme.MainColor,
                          inactiveTrackColor: Colors.white.withOpacity(0.3),
                          thumbColor: Colors.white,
                          overlayColor: AppTheme.MainColor.withOpacity(0.25),
                        ),
                        child: Slider(
                          value: progress,
                          onChanged: (val) {
                            _videoController.seekTo(Duration(
                              milliseconds:
                                  (val * duration.inMilliseconds).toInt(),
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

  // ─────────────────────────────────────────────
  // Sync section widgets
  // ─────────────────────────────────────────────
  Widget _buildDotsRow() {
    const int totalDots = 14;
    const int trailLength = 5;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.cloud_sync_outlined,
            color: AppTheme.graySubTitleColor, size: 28),
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
            dotColor = AppTheme.MainColor
                .withOpacity(1.0 - (nd / trailLength) * 0.8);
            dotSize = 6;
          } else {
            dotColor = AppTheme.borderLineColor.withOpacity(0.5);
            dotSize = 5;
          }
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: dotSize,
            height: dotSize,
            decoration:
                BoxDecoration(shape: BoxShape.circle, color: dotColor),
          );
        }),
        const SizedBox(width: 8),
        Icon(Icons.phone_android_rounded,
            color: AppTheme.graySubTitleColor, size: 28),
      ],
    );
  }

  Widget _buildSyncProgressBar() {
    double? value;
    Color barColor = AppTheme.MainColor;

    if (_isSyncing) {
      if (_totalRecords > 0) {
        value = (_savedRecords / _totalRecords).clamp(0.0, 1.0);
      } else {
        value = null; // indeterminate until we know total
      }
    } else if (_syncError != null) {
      value = 0.0;
      barColor = Colors.redAccent;
    } else if (_lastSyncedAt != null) {
      value = 1.0;
      barColor = Colors.green;
    } else {
      value = 0.0;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 7,
        backgroundColor: barColor.withOpacity(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(barColor),
      ),
    );
  }

  Widget _buildSyncStatusText() {
    String text;
    Color color = AppTheme.black_Color;

    if (_syncError != null) {
      text = _syncError!;
      color = Colors.redAccent;
    } else if (_isSyncing) {
      text = _totalRecords > 0
          ? '$_syncStatusLabel ($_savedRecords / $_totalRecords)'
          : _syncStatusLabel;
    } else if (_lastSyncedAt != null) {
      final h = _lastSyncedAt!.hour.toString().padLeft(2, '0');
      final m = _lastSyncedAt!.minute.toString().padLeft(2, '0');
      final d = '${_lastSyncedAt!.day}/${_lastSyncedAt!.month}/${_lastSyncedAt!.year}';
      text = 'Offline backup ready: $_savedRecords records ($d $h:$m)';
      color = Colors.green.shade700;
    } else {
      text = "Tap 'Sync Backup' to download all data";
    }

    return Text(
      text,
      style: MyStyles.regularText(size: 13, color: color),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSyncButton() {
    return GestureDetector(
      onTap: _isSyncing ? null : _syncBackup,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _isSyncing
              ? AppTheme.MainColor.withOpacity(0.6)
              : AppTheme.MainColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            else
              const Icon(Icons.cloud_download_rounded,
                  color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              _isSyncing ? 'Syncing...' : 'Sync Backup',
              style: MyStyles.boldText(size: 15, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
