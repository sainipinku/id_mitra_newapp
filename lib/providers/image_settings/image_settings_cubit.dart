import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/local_db/image_settings_local_ds/image_settings_local_ds.dart';

part 'image_settings_state.dart';

class ImageSettingsCubit extends Cubit<ImageSettingsState> {
  StreamSubscription? _connectivitySubscription;

  ImageSettingsCubit() : super(ImageSettingsInitial()) {
    _startConnectivityListener();
  }

  final ApiManager _apiManager = ApiManager();
  final ImageSettingsLocalDS _localDS = ImageSettingsLocalDS();

  void _startConnectivityListener() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((_) async {
      if (await _hasInternet()) {
        syncPendingSettings();
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncPendingSettings() async {
    if (!await _hasInternet()) return;

    final pending = await _localDS.getAllPendingSync();
    if (pending.isEmpty) return;

    debugPrint('Syncing ${pending.length} pending image settings...');
    for (var item in pending) {
      final id = item['id'] as int;
      final schoolId = item['school_id'] as String;
      final body = jsonDecode(item['body_json'] as String) as Map<String, dynamic>;

      try {
        final url = Config.baseUrl + Routes.updateImageSettings(schoolId);
        final response = await _apiManager.putRequestWithBody(url, body);

        if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
          await _localDS.deletePendingSync(id);
          debugPrint('Synced pending settings for school $schoolId');
        }
      } catch (e) {
        debugPrint('Failed to sync pending settings for school $schoolId: $e');
      }
    }
  }

  Future<void> fetchImageSettings({required String schoolId}) async {
    emit(ImageSettingsFetchLoading());

    // Sync pending before fetching if online
    await syncPendingSettings();

    final isOnline = await _hasInternet();
    if (!isOnline) {
      final localData = await _localDS.getImageSettings(schoolId);
      if (localData != null) {
        debugPrint('Loaded image settings from local DB for school $schoolId');
        emit(ImageSettingsFetchLoaded(data: localData));
        return;
      }
      emit(ImageSettingsFetchFailed(message: "No internet connection and no local data found"));
      return;
    }

    try {
      final url = Config.baseUrl + Routes.updateImageSettings(schoolId);
      final response = await _apiManager.getRequest(url);

      if (response == null) {
        emit(ImageSettingsFetchFailed(message: "No response from server"));
        return;
      }

      final json = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        // API may return data directly or nested under 'settings'/'image_settings'
        final rawData = json["data"];
        final Map<String, dynamic> data;
        if (rawData is Map<String, dynamic>) {
          // Check if actual settings are nested deeper
          if (rawData.containsKey('image_settings') && rawData['image_settings'] is Map) {
            data = rawData['image_settings'] as Map<String, dynamic>;
          } else if (rawData.containsKey('settings') && rawData['settings'] is Map) {
            data = rawData['settings'] as Map<String, dynamic>;
          } else {
            data = rawData;
          }
        } else {
          data = {};
        }

        // Save to local DB
        await _localDS.saveImageSettings(schoolId, data);

        debugPrint('ImageSettings API data: $data');
        emit(ImageSettingsFetchLoaded(data: data));
      } else {
        emit(ImageSettingsFetchFailed(message: json["message"] ?? "Failed to load settings"));
      }
    } catch (e) {
      debugPrint('fetchImageSettings error: $e');
      emit(ImageSettingsFetchFailed(message: e.toString()));
    }
  }

  Future<void> saveImageSettings({
    required String schoolId,
    required Map<String, dynamic> body,
  }) async {
    emit(ImageSettingsLoading());

    final isOnline = await _hasInternet();
    if (!isOnline) {
      // Save to pending sync
      await _localDS.savePendingImageSettings(schoolId, body);
      // Also update local cache so UI reflects change immediately
      await _localDS.saveImageSettings(schoolId, body);

      emit(ImageSettingsSuccess(
        message: "Settings saved locally. Will sync when online.",
        imageShape: body['image_shape']?.toString(),
      ));
      return;
    }

    try {
      final url = Config.baseUrl + Routes.updateImageSettings(schoolId);
      final response = await _apiManager.putRequestWithBody(url, body);

      if (response == null) {
        emit(ImageSettingsFailed(message: "No response from server"));
        return;
      }

      final json = jsonDecode(response.body);
      debugPrint('saveImageSettings response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final shape = json["data"]?["image_shape"]?.toString();

        // Update local cache
        await _localDS.saveImageSettings(schoolId, body);

        emit(ImageSettingsSuccess(
          message: json["message"] ?? "Settings saved successfully",
          imageShape: shape,
        ));
      } else {
        emit(ImageSettingsFailed(message: json["message"] ?? "Something went wrong"));
      }
    } catch (e) {
      debugPrint('saveImageSettings error: $e');
      emit(ImageSettingsFailed(message: e.toString()));
    }
  }
}