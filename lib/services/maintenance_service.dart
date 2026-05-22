import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/utils/GlobalContext.dart';

class MaintenanceService {
  MaintenanceService._();
  static final MaintenanceService instance = MaintenanceService._();

  static const int _retryIntervalSeconds = 15;

  String? _healthCheckUrl;

  bool _isMaintenanceVisible = false;
  bool _isChecking = false;

  Timer? _retryTimer;
  Timer? _countdownTimer;
  int _countdown = _retryIntervalSeconds;

  final StreamController<bool> _maintenanceController =
      StreamController<bool>.broadcast();
  final StreamController<int> _countdownController =
      StreamController<int>.broadcast();

  Stream<bool> get maintenanceStream => _maintenanceController.stream;
  Stream<int> get retryCountdownStream => _countdownController.stream;

  bool get isMaintenanceVisible => _isMaintenanceVisible;

  void init(String baseUrl) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    _healthCheckUrl = '${base}status';
  }

  Future<void> checkOnStartup() async {
    await _checkServerHealth(isStartup: true);
  }

  void onServerDown() {
    if (_isMaintenanceVisible) return;
    _isMaintenanceVisible = true;
    _showMaintenanceScreen();
    _startRetryLoop();
  }

  void onServerUp() {
    if (!_isMaintenanceVisible) return;
    _dismissMaintenance();
  }

  void _showMaintenanceScreen() {
    final context = GlobalContext.navigatorKey.currentContext;
    if (context == null) return;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: true,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) {
          return _MaintenanceScreenWrapper(
            maintenanceStream: maintenanceStream,
            retryCountdownStream: retryCountdownStream,
          );
        },
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _dismissMaintenance() {
    _isMaintenanceVisible = false;
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _maintenanceController.add(false);
  }

  void _startRetryLoop() {
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _scheduleNextCheck();
  }

  void _scheduleNextCheck() {
    _countdown = _retryIntervalSeconds;
    _countdownController.add(_countdown);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _countdown--;
      if (_countdown <= 0) {
        t.cancel();
        _countdownController.add(0);
      } else {
        _countdownController.add(_countdown);
      }
    });

    _retryTimer = Timer(
      Duration(seconds: _retryIntervalSeconds),
      () => _checkServerHealth(),
    );
  }

  Future<void> _checkServerHealth({bool isStartup = false}) async {
    if (_isChecking || _healthCheckUrl == null) return;
    _isChecking = true;

    bool serverUp = false;
    try {
      final response = await http
          .get(Uri.parse(_healthCheckUrl!))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = response.body;
        serverUp = body.contains('"ok":true') || body.contains('"ok": true');
      }
    } catch (_) {
      serverUp = false;
    }

    _isChecking = false;

    if (serverUp) {
      if (_isMaintenanceVisible) {
        _dismissMaintenance();
      }
    } else {
      if (!_isMaintenanceVisible) {
        onServerDown();
      } else {
        _scheduleNextCheck();
      }
    }
  }

  void dispose() {
    _retryTimer?.cancel();
    _countdownTimer?.cancel();
    _maintenanceController.close();
    _countdownController.close();
  }
}

class _MaintenanceScreenWrapper extends StatefulWidget {
  final Stream<bool> maintenanceStream;
  final Stream<int> retryCountdownStream;

  const _MaintenanceScreenWrapper({
    required this.maintenanceStream,
    required this.retryCountdownStream,
  });

  @override
  State<_MaintenanceScreenWrapper> createState() =>
      _MaintenanceScreenWrapperState();
}

class _MaintenanceScreenWrapperState extends State<_MaintenanceScreenWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late StreamSubscription<bool> _sub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sub = widget.maintenanceStream.listen((isDown) {
      if (!isDown && mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: _illustration(),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'Server Maintenance',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Server is currently under maintenance.\nPlease try again after some time.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  _retryIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _illustration() {
    return Image.asset(
      'assets/images/ServerMaintenance.png',
      width: 260,
      height: 260,
      fit: BoxFit.contain,
    );
  }

  Widget _retryIndicator() {
    return StreamBuilder<int>(
      stream: widget.retryCountdownStream,
      builder: (context, snapshot) {
        final seconds = snapshot.data ?? 0;
        return Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF008F70)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              seconds > 0
                  ? 'Checking again in ${seconds}s...'
                  : 'Checking server status...',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        );
      },
    );
  }
}
