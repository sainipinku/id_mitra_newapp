import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/utils/GlobalContext.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const String _packageName = 'com.hoics.idmitra';

  static const String _androidStoreUrl =
      'https://play.google.com/store/apps/details?id=$_packageName';

  static const String _iosStoreUrl =
      'https://apps.apple.com/app/idmitra/id0000000000';

  Future<void> checkForUpdate() async {
    // Android: use official In-App Update API first
    if (Platform.isAndroid) {
      await _checkInAppUpdate();
      return;
    }

    // iOS: fallback to App Store version check
    if (Platform.isIOS) {
      await _checkStoreVersion();
    }
  }

  /// Google Play In-App Update API (Android only)
  Future<void> _checkInAppUpdate() async {
    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        // Immediate update — full screen force update
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      print('In-App Update error: $e — falling back to store check');
      // Fallback: manual Play Store version check
      await _checkStoreVersion();
    }
  }

  /// Manual version check via store scraping (fallback / iOS)
  Future<void> _checkStoreVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      print('Current version: $currentVersion');

      String? latestVersion;

      if (Platform.isAndroid) {
        latestVersion = await _getPlayStoreVersion();
      } else if (Platform.isIOS) {
        latestVersion = await _getAppStoreVersion();
      }

      if (latestVersion == null) {
        print('Could not fetch latest version');
        return;
      }

      print('Latest version: $latestVersion');

      if (_isNewVersionAvailable(currentVersion, latestVersion)) {
        print('Update available! Showing dialog...');
        _showUpdateDialog(
          currentVersion: currentVersion,
          latestVersion: latestVersion,
        );
      } else {
        print('App is up to date.');
      }
    } catch (e) {
      print('Error checking update: $e');
    }
  }

  Future<String?> _getPlayStoreVersion() async {
    try {
      final url =
          'https://play.google.com/store/apps/details?id=$_packageName&hl=en';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;

        final RegExp regExp1 = RegExp(r'\[\[\["(\d+\.\d+\.\d+)"]]],\["(\d+)"');
        final match1 = regExp1.firstMatch(body);
        if (match1 != null) {
          print('Play Store version (m1): ${match1.group(1)}');
          return match1.group(1);
        }

        final RegExp regExp2 = RegExp(r'"softwareVersion":\s*"([\d.]+)"');
        final match2 = regExp2.firstMatch(body);
        if (match2 != null) {
          print(' Play Store version (m2): ${match2.group(1)}');
          return match2.group(1);
        }

        final RegExp regExp3 =
        RegExp(r'itemprop="softwareVersion"[^>]*>\s*([\d.]+)\s*<');
        final match3 = regExp3.firstMatch(body);
        if (match3 != null) {
          print('Play Store version (m3): ${match3.group(1)}');
          return match3.group(1);
        }

        final RegExp regExp4 = RegExp(r'"version"\s*:\s*"([\d.]+)"');
        final match4 = regExp4.firstMatch(body);
        if (match4 != null) {
          print(' Play Store version (m4): ${match4.group(1)}');
          return match4.group(1);
        }

        print('Could not extract version from Play Store');
      } else {
        print('Play Store response: ${response.statusCode}');
      }
    } catch (e) {
      print('Play Store fetch error: $e');
    }
    return null;
  }

  Future<String?> _getAppStoreVersion() async {
    try {
      final url =
          'https://itunes.apple.com/lookup?bundleId=$_packageName&country=in';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = response.body;
        final RegExp regExp = RegExp(r'"version"\s*:\s*"([\d.]+)"');
        final match = regExp.firstMatch(body);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      print('App Store fetch error: $e');
    }
    return null;
  }

  bool _isNewVersionAvailable(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();

      while (currentParts.length < latestParts.length) currentParts.add(0);
      while (latestParts.length < currentParts.length) latestParts.add(0);

      for (int i = 0; i < latestParts.length; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      return false;
    } catch (e) {
      print(' Version compare error: $e');
      return false;
    }
  }

  void _showUpdateDialog({
    required String currentVersion,
    required String latestVersion,
  }) {
    final context = GlobalContext.navigatorKey.currentContext;
    if (context == null) {
      print('Context is null — cannot show dialog');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _UpdateDialog(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        onUpdate: _openStore,
      ),
    );
  }

  void _openStore() async {
    final url = Platform.isIOS ? _iosStoreUrl : _androidStoreUrl;
    final uri = Uri.parse(url);
    print('Opening store: $url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print(' Could not launch store URL');
    }
  }
}


class _UpdateDialog extends StatelessWidget {
  final String currentVersion;
  final String latestVersion;
  final VoidCallback onUpdate;

  const _UpdateDialog({
    required this.currentVersion,
    required this.latestVersion,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppTheme.whiteColor,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIllustration(),
              const SizedBox(height: 20),
              const Text(
                'New Update Available!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.TitleBlackColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _versionChip(currentVersion, isNew: false),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppTheme.graySubTitleColor,
                    ),
                  ),
                  _versionChip(latestVersion, isNew: true),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'A new version of IDMitra is available\n Please update to get the latest features and improvements.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.graySubTitleColor,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              AppButton(
                title: 'Update Now',
                onTap: onUpdate,
                color: AppTheme.mainColor,
                height: 50,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderLineColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Later',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.graySubTitleColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.main10perOpacityColor,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.system_update_rounded,
            size: 48,
            color: AppTheme.mainColor,
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppTheme.orangeColor,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_upward_rounded,
                size: 13,
                color: AppTheme.whiteColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _versionChip(String version, {required bool isNew}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNew ? AppTheme.main10perOpacityColor : AppTheme.appBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNew ? AppTheme.mainColor : AppTheme.borderLineColor,
          width: 0.8,
        ),
      ),
      child: Text(
        'v$version',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isNew ? AppTheme.mainColor : AppTheme.graySubTitleColor,
        ),
      ),
    );
  }
}