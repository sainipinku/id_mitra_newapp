import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:idmitra/utils/GlobalContext.dart';

class NoInternetService {
  NoInternetService._();
  static final NoInternetService instance = NoInternetService._();

  StreamSubscription? _subscription;
  OverlayEntry? _overlayEntry;

  bool _lastStatus = true;
  bool _isInitialized = false;

  void init() {
    Future.delayed(const Duration(seconds: 2), () {
      _isInitialized = true;
      _startListening();
      _checkInitial();
    });
  }

  void _startListening() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((_) async {
      final hasInternet = await _hasRealInternet();

      if (hasInternet == _lastStatus) return;
      _lastStatus = hasInternet;

      _showBanner(isConnected: hasInternet);
    });
  }

  Future<void> _checkInitial() async {
    final hasInternet = await _hasRealInternet();
    _lastStatus = hasInternet;

    if (!hasInternet) {
      _showBanner(isConnected: false);
    }
  }

  Future<bool> _hasRealInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _showBanner({required bool isConnected}) {
    if (!_isInitialized) return;

    final context = GlobalContext.navigatorKey.currentContext;
    if (context == null) {
      return;
    }

    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _TopBanner(
        isConnected: isConnected,
        onDismiss: () {
          if (_overlayEntry != null && _overlayEntry!.mounted) {
            _overlayEntry!.remove();
          }
          _overlayEntry = null;
        },
      ),
    );

    try {
      final navigatorState = GlobalContext.navigatorKey.currentState;
      if (navigatorState != null) {
        final overlayState = navigatorState.overlay;
        if (overlayState != null) {
          overlayState.insert(_overlayEntry!);
        } else {
          _overlayEntry = null;
        }
      } else {
        _overlayEntry = null;
      }
    } catch (e) {
      _overlayEntry = null;
    }
  }

  void dispose() {
    _subscription?.cancel();
    if (_overlayEntry != null && _overlayEntry!.mounted) {
      _overlayEntry!.remove();
    }
  }
}

class _TopBanner extends StatefulWidget {
  final bool isConnected;
  final VoidCallback onDismiss;

  const _TopBanner({
    required this.isConnected,
    required this.onDismiss,
  });

  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    if (widget.isConnected) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _controller.reverse().then((_) => widget.onDismiss());
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          elevation: 4,
          child: Container(
            padding: EdgeInsets.only(
              top: statusBarHeight,
              bottom: 0,
              left: 12,
              right: 12,
            ),
            color: widget.isConnected ? Colors.green : Colors.red,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isConnected
                      ? Icons.wifi
                      : Icons.wifi_off,
                  color: Colors.white,
                  size: 12,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.isConnected
                      ? "Back online"
                      : "No connection",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
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