import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/home/SchoolDashboardModel.dart';
import 'package:sqflite/sqflite.dart';
part 'admin_dashboard_state.dart';

const _kAdminDashboardKey = 'admin_dashboard';

class AdminDashboardCubit extends Cubit<AdminDashboardState> {
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  AdminDashboardCubit() : super(AdminDashboardState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;
      if (_isSyncing) return; // duplicate call se bachao
      _isSyncing = true;
      await loadDashboard();
      _isSyncing = false;
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  final ApiManager _api = ApiManager();
  final _studentLocalDS = StudentLocalDS();

  Future<void> _saveToLocal(String key, Map<String, dynamic> json) async {
    try {
      final db = await DBHelper.db;
      await db.insert(
        'home_cache',
        {
          'key': key,
          'json_data': jsonEncode(json),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('AdminDashboardCubit local save error: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadFromLocal(String key) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'home_cache',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
    } catch (e) {
      print('AdminDashboardCubit local load error: $e');
      return null;
    }
  }

  Future<SchoolDashboardModel> _injectLocalStudentCount(SchoolDashboardModel model) async {
    try {
      final schoolData = await UserLocal.getSchool();
      final schoolId = schoolData['schoolId'];
      
      final localCount = await _studentLocalDS.getCount(schoolId: schoolId ?? '');
      if (localCount > 0) {
        final summary = model.data.summary;
        final updatedSummary = DashSummary(
          orders: summary.orders,
          students: localCount,
          staff: summary.staff,
          classes: summary.classes,
          checklists: summary.checklists,
        );
        final updatedData = SchoolDashboardData(
          summary: updatedSummary,
          attendance: model.data.attendance,
          school: model.data.school,
          currentSession: model.data.currentSession,
          recentActivity: model.data.recentActivity,
          user: model.data.user,
        );
        return SchoolDashboardModel(
          success: model.success,
          message: model.message,
          data: updatedData,
        );
      }
    } catch (e) {
      print('AdminDashboardCubit student count injection error: $e');
    }
    return model;
  }

  Future<bool> _isConnected() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> loadDashboard() async {
    emit(state.copyWith(loading: true, error: null));

    // Step 1: Cache ho toh INSTANTLY dikhao — koi wait nahi
    final localData = await _loadFromLocal(_kAdminDashboardKey);
    if (localData != null) {
      try {
        final model = SchoolDashboardModel.fromJson(localData);
        emit(state.copyWith(loading: false, dashboard: model, isOffline: false));
        print('AdminDashboardCubit: cache shown instantly, checking internet in background');

        // Step 2: Internet check background mein
        final connected = await _isConnected();
        print('AdminDashboardCubit: internet connected = $connected');
        if (!connected) {
          emit(state.copyWith(isOffline: true));
          return;
        }
        _syncFromApi();
        return;
      } catch (e) {
        print('AdminDashboardCubit: local parse error: $e');
      }
    }

    // Step 3: Koi cache nahi — internet check phir API call
    final connected = await _isConnected();
    print('AdminDashboardCubit: internet connected = $connected');

    if (!connected) {
      print('AdminDashboardCubit: offline — no local data');
      emit(state.copyWith(loading: false, error: 'No internet connection', isOffline: true));
      return;
    }

    await _syncFromApi(emitLoading: true);
  }

  Future<void> _syncFromApi({bool emitLoading = false}) async {
    if (emitLoading) emit(state.copyWith(loading: true));
    try {
      final response = await _api.getRequest(
        Config.baseUrl + Routes.getSchoolDashboard(),
      );
      if (response == null) {
        if (emitLoading) emit(state.copyWith(loading: false, error: 'No response from server'));
        return;
      }
      if (response.statusCode == 200) {
        final body = response.body as String;
        final json = jsonDecode(body);
        var model = SchoolDashboardModel.fromJson(json);
        
        // Save to local
        await _saveToLocal(_kAdminDashboardKey, json);

        emit(state.copyWith(loading: false, dashboard: model, error: null, isOffline: false));
      } else {
        if (emitLoading) {
          emit(state.copyWith(
            loading: false,
            error: 'Error ${response.statusCode}',
          ));
        }
      }
    } catch (e) {
      if (emitLoading) emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
