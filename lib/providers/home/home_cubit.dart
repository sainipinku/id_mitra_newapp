import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/home/PartnerDashboardModel.dart';
import 'package:idmitra/models/home/UserDetailsModel.dart';
import 'package:sqflite/sqflite.dart';

part 'home_state.dart';

const _kDashboardKey = 'dashboard';
const _kUserKey = 'user';

class HomeCubit extends Cubit<HomeState> {
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  HomeCubit() : super(HomeState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;
      if (_isSyncing) return; // duplicate call se bachao
      _isSyncing = true;
      await loadHomeData();
      _isSyncing = false;
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  ApiManager apiManager = ApiManager();
  final localDS = StudentLocalDS();

  Future<void> _saveToLocal(String key, Map<String, dynamic> json) async {
    try {
      final db = await DBHelper.db;
      await db.insert('home_cache', {
        'key': key,
        'json_data': jsonEncode(json),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print('HomeCubit saved to local DB: $key');
    } catch (e) {
      print('HomeCubit local save error: $e');
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
      final data =
          jsonDecode(rows.first['json_data'] as String) as Map<String, dynamic>;
      return data;
    } catch (e) {
      print('HomeCubit local load error: $e');
      return null;
    }
  }

  Future<PartnerDashboardModel> _injectLocalStudentCount(
    PartnerDashboardModel model,
  ) async {
    try {
      final localCount = await localDS.getCount();
      if (localCount > 0 && model.data != null) {
        final updatedStudents = Employees(
          total: localCount,
          active: model.data!.students?.active,
          inactive: model.data!.students?.inactive,
        );
        final updatedData = Data(
          filters: model.data!.filters,
          orders: model.data!.orders,
          schools: model.data!.schools,
          users: model.data!.users,
          schoolAdmins: model.data!.schoolAdmins,
          students: updatedStudents,
          subPartners: model.data!.subPartners,
          employees: model.data!.employees,
          partner: model.data!.partner,
          period: model.data!.period,
          dateRange: model.data!.dateRange,
          summary: model.data!.summary,
        );
        print('HomeCubit: injected local student count = $localCount');
        return PartnerDashboardModel(
          success: model.success,
          message: model.message,
          data: updatedData,
        );
      }
    } catch (e) {
      print('HomeCubit: local student count error: $e');
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

  Future<void> loadHomeData() async {
    emit(state.copyWith(loading: true));

    // Step 1: Pehle cache dikhao — instant, no waiting
    final localDashboard = await _loadFromLocal(_kDashboardKey);
    final localUser = await _loadFromLocal(_kUserKey);

    if (localDashboard != null && localUser != null) {
      final dashboardModel = PartnerDashboardModel.fromJson(localDashboard);
      final userModel = UserDetailsModel.fromJson(localUser);
      emit(state.copyWith(
        loading: false,
        dashboard: dashboardModel,
        user: userModel,
        isOffline: false,
      ));
      print('HomeCubit: cache shown instantly, checking internet in background');

      // Step 2: Internet check background mein — agar online hai toh sync karo
      final connected = await _isConnected();
      print('HomeCubit: internet connected = $connected');
      if (!connected) {
        emit(state.copyWith(isOffline: true));
        return;
      }
      _syncFromApi();
      return;
    }

    // Step 3: Koi cache nahi — internet check karo phir API call karo
    final connected = await _isConnected();
    print('HomeCubit: internet connected = $connected');

    if (!connected) {
      print('HomeCubit: offline — no local data available');
      emit(state.copyWith(loading: false, isOffline: true, error: 'offline'));
      return;
    }

    await _syncFromApi(emitStates: true);
  }

  Future<void> _syncFromApi({bool emitStates = false}) async {
    try {
      final dashboardResponse = await apiManager.getRequest(
        Config.baseUrl + Routes.getPartnerDashboardData(),
      );
      final userResponse = await apiManager.getRequest(
        Config.baseUrl + Routes.getUserDetails(),
      );

      if (dashboardResponse == null || userResponse == null) {
        print('HomeCubit sync: no response (offline)');
        if (emitStates) emit(state.copyWith(loading: false, error: 'offline'));
        return;
      }

      print('HomeCubit sync dashboard status: ${dashboardResponse.statusCode}');
      print('HomeCubit sync dashboard body: ${dashboardResponse.body}');
      print('HomeCubit sync user status: ${userResponse.statusCode}');
      print('HomeCubit sync user body: ${userResponse.body}');

      if (dashboardResponse.statusCode == 403 ||
          userResponse.statusCode == 403) {
        if (emitStates) emit(state.copyWith(loading: false, error: 'On Hold'));
        return;
      }

      if (dashboardResponse.statusCode == 200 &&
          userResponse.statusCode == 200) {
        final dashboardBody = dashboardResponse.body.trim();
        final userBody = userResponse.body.trim();

        if (dashboardBody.startsWith('<') || userBody.startsWith('<')) {
          if (emitStates) emit(state.copyWith(loading: false));
          return;
        }

        final dashboardJson = jsonDecode(dashboardBody) as Map<String, dynamic>;
        final userJson = jsonDecode(userBody) as Map<String, dynamic>;

        final dashboardModel = PartnerDashboardModel.fromJson(dashboardJson);
        final userModel = UserDetailsModel.fromJson(userJson);

        // Transaction mein dono ek saath save — ek fail toh dono fail
        try {
          final db = await DBHelper.db;
          await db.transaction((txn) async {
            await txn.insert('home_cache', {'key': _kDashboardKey, 'json_data': jsonEncode(dashboardJson), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
            await txn.insert('home_cache', {'key': _kUserKey, 'json_data': jsonEncode(userJson), 'updated_at': DateTime.now().millisecondsSinceEpoch}, conflictAlgorithm: ConflictAlgorithm.replace);
          });
        } catch (e) {
          print('HomeCubit transaction save error: $e');
        }

        print(
          'HomeCubit synced — schools: ${dashboardModel.data?.schools?.total}, students: ${dashboardModel.data?.students?.total}, user: ${userModel.user?.name}',
        );

        emit(
          state.copyWith(
            loading: false,
            dashboard: dashboardModel,
            user: userModel,
            isOffline: false,
          ),
        );
      } else {
        if (emitStates) emit(state.copyWith(loading: false));
      }
    } catch (e) {
      print('HomeCubit sync error: $e');
      if (emitStates) emit(state.copyWith(loading: false));
    }
  }
}
