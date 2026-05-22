import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/staff_local_ds/staff_local_ds.dart';
import 'package:idmitra/local_db/order_local_ds/order_local_ds.dart';
import 'package:idmitra/models/staff/StaffListModel.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../screens/orders/order_staff_page.dart';


class StaffListState {
  final bool loading;
  final bool paginationLoading;
  final List<StaffListModel> list;
  final int page;
  final bool hasMore;
  final int total;
  final String? error;

  final List<OrderStaffItem> orders;
  final bool ordersLoading;
  final bool ordersPaginationLoading;
  final bool ordersHasMore;
  final int ordersPage;
  final int ordersTotal;
  final String? ordersError;
  final String ordersSelectedStatus;
  final String ordersDateFrom;
  final String ordersDateTo;
  final String ordersSearch;

  final Map<String, bool> orderUpdatingMap;
  final Map<String, String> orderStatusMap;

  final Map<String, bool> photoUploadingMap;

  final bool signatureUploading;
  final String? signatureUploadError;
  final String? signatureUploadSuccess;

  final bool deleting;

  final bool togglingStatus;

  final bool changingPassword;

  final bool isSyncing;

  final bool assigningClass;
  final bool removingClass;

  final List<Map<String, dynamic>> assignedClasses;
  final bool assignedClassesLoading;

  final Set<int> selectedStaffOrderIds;

  const StaffListState({
    this.loading = false,
    this.paginationLoading = false,
    this.list = const [],
    this.page = 1,
    this.hasMore = true,
    this.total = 0,
    this.error,

    this.orders = const [],
    this.ordersLoading = false,
    this.ordersPaginationLoading = false,
    this.ordersHasMore = true,
    this.ordersPage = 1,
    this.ordersTotal = 0,
    this.ordersError,
    this.ordersSelectedStatus = '',
    this.ordersDateFrom = '',
    this.ordersDateTo = '',
    this.ordersSearch = '',

    this.orderUpdatingMap = const {},
    this.orderStatusMap = const {},

    this.photoUploadingMap = const {},

    this.signatureUploading = false,
    this.signatureUploadError,
    this.signatureUploadSuccess,

    this.deleting = false,
    this.togglingStatus = false,
    this.changingPassword = false,
    this.isSyncing = false,
    this.assigningClass = false,
    this.removingClass = false,

    this.assignedClasses = const [],
    this.assignedClassesLoading = false,

    this.selectedStaffOrderIds = const {},
  });

  StaffListState copyWith({
    bool? loading,
    bool? paginationLoading,
    List<StaffListModel>? list,
    int? page,
    bool? hasMore,
    int? total,
    String? error,

    List<OrderStaffItem>? orders,
    bool? ordersLoading,
    bool? ordersPaginationLoading,
    bool? ordersHasMore,
    int? ordersPage,
    int? ordersTotal,
    String? ordersError,
    String? ordersSelectedStatus,
    String? ordersDateFrom,
    String? ordersDateTo,
    String? ordersSearch,

    Map<String, bool>? orderUpdatingMap,
    Map<String, String>? orderStatusMap,

    Map<String, bool>? photoUploadingMap,

    bool? signatureUploading,
    String? signatureUploadError,
    String? signatureUploadSuccess,

    bool? deleting,
    bool? togglingStatus,
    bool? changingPassword,
    bool? isSyncing,
    bool? assigningClass,
    bool? removingClass,

    List<Map<String, dynamic>>? assignedClasses,
    bool? assignedClassesLoading,

    Set<int>? selectedStaffOrderIds,

    bool clearError = false,
    bool clearOrdersError = false,
    bool clearSignatureMessages = false,
  }) =>
      StaffListState(
        loading: loading ?? this.loading,
        paginationLoading: paginationLoading ?? this.paginationLoading,
        list: list ?? this.list,
        page: page ?? this.page,
        hasMore: hasMore ?? this.hasMore,
        total: total ?? this.total,
        error: clearError ? null : (error ?? this.error),

        orders: orders ?? this.orders,
        ordersLoading: ordersLoading ?? this.ordersLoading,
        ordersPaginationLoading: ordersPaginationLoading ?? this.ordersPaginationLoading,
        ordersHasMore: ordersHasMore ?? this.ordersHasMore,
        ordersPage: ordersPage ?? this.ordersPage,
        ordersTotal: ordersTotal ?? this.ordersTotal,
        ordersError: clearOrdersError ? null : (ordersError ?? this.ordersError),
        ordersSelectedStatus: ordersSelectedStatus ?? this.ordersSelectedStatus,
        ordersDateFrom: ordersDateFrom ?? this.ordersDateFrom,
        ordersDateTo: ordersDateTo ?? this.ordersDateTo,
        ordersSearch: ordersSearch ?? this.ordersSearch,

        orderUpdatingMap: orderUpdatingMap ?? this.orderUpdatingMap,
        orderStatusMap: orderStatusMap ?? this.orderStatusMap,

        photoUploadingMap: photoUploadingMap ?? this.photoUploadingMap,

        signatureUploading: signatureUploading ?? this.signatureUploading,
        signatureUploadError: clearSignatureMessages ? null : (signatureUploadError ?? this.signatureUploadError),
        signatureUploadSuccess: clearSignatureMessages ? null : (signatureUploadSuccess ?? this.signatureUploadSuccess),

        deleting: deleting ?? this.deleting,
        togglingStatus: togglingStatus ?? this.togglingStatus,
        changingPassword: changingPassword ?? this.changingPassword,
        isSyncing: isSyncing ?? this.isSyncing,
        assigningClass: assigningClass ?? this.assigningClass,
        removingClass: removingClass ?? this.removingClass,

        assignedClasses: assignedClasses ?? this.assignedClasses,
        assignedClassesLoading: assignedClassesLoading ?? this.assignedClassesLoading,

        selectedStaffOrderIds: selectedStaffOrderIds ?? this.selectedStaffOrderIds,
      );


  bool isPhotoUploading(String uuid) => photoUploadingMap[uuid] ?? false;
  bool isOrderUpdating(String uuid) => orderUpdatingMap[uuid] ?? false;
  String orderStatus(String uuid, String fallback) =>
      orderStatusMap[uuid] ?? fallback;
}


class StaffListCubit extends Cubit<StaffListState> {
  StreamSubscription? _connectivitySubscription;
  String? _lastSchoolId;
  final localDS = StaffLocalDS();
  final _orderLocalDS = OrderLocalDS();

  StaffListCubit() : super(const StaffListState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;

      if (_lastSchoolId != null) {
        syncOfflineStaff(schoolId: _lastSchoolId!);
        syncPendingStaffOrders(schoolId: _lastSchoolId!);
      } else {
        final school = await UserLocal.getSchool();
        final schoolId = school['schoolId'];
        if (schoolId != null && schoolId.isNotEmpty) {
          syncOfflineStaff(schoolId: schoolId);
          syncPendingStaffOrders(schoolId: schoolId);
        }
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
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none) &&
          connectivity.length == 1) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  final Map<String, String> _uploadedPhotos = {};

  void updateStaffPhoto(String uuid, String photoUrl) {
    _uploadedPhotos[uuid] = photoUrl;
    final updated = state.list.map((s) {
      if (s.uuid != uuid) return s;
      return s.copyWith(profilePhotoUrl: photoUrl);
    }).toList();
    emit(state.copyWith(list: updated));
  }

  Future<void> fetchStaff({
    required String schoolId,
    String search = '',
    bool isLoadMore = false,
  }) async {
    if (state.paginationLoading) return;
    if (isLoadMore && !state.hasMore) return;

    if (schoolId.isNotEmpty) {
      _lastSchoolId = schoolId;
    }

    const int perPage = 50;
    final page = isLoadMore ? state.page : 1;
    int offset = (page - 1) * perPage;

    if (!isLoadMore) {
      emit(state.copyWith(
        loading: true,
        clearError: true,
        list: [],
        page: 1,
        hasMore: true,
      ));
    } else {
      emit(state.copyWith(paginationLoading: true));
    }

    try {
      // 1. Try local DB first
      final localList = await localDS.getStaff(
        search: search,
        schoolId: schoolId,
        limit: perPage,
        offset: offset,
      );

      // 2. Get pending/offline staff to ensure they never disappear
      final pendingStaff = await localDS.getOfflineStaff(
        schoolId: schoolId,
      );

      final int totalLocalCount = await localDS.getCount(
        search: search,
        schoolId: schoolId,
      );

      debugPrint("LOCAL STAFF DATA: Page=${localList.length}, Pending=${pendingStaff.length}");

      // If we have local or pending data, show it.
      if (localList.isNotEmpty || pendingStaff.isNotEmpty) {
        final Set<String> seenUuids = {};
        final List<StaffListModel> mergedLocal = [];

        // Add pending staff first (they take priority)
        for (var s in pendingStaff) {
          if (s.uuid.isNotEmpty && !seenUuids.contains(s.uuid)) {
            bool matchesSearch = search.isEmpty ||
                (s.name).toLowerCase().contains(search.toLowerCase());
            if (matchesSearch) {
              mergedLocal.add(s);
              seenUuids.add(s.uuid);
            }
          }
        }

        // Add page results
        for (var s in localList) {
          if (s.uuid.isNotEmpty && !seenUuids.contains(s.uuid)) {
            mergedLocal.add(s);
            seenUuids.add(s.uuid);
          }
        }

        final updatedList =
            isLoadMore ? [...state.list, ...mergedLocal] : mergedLocal;

        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
          list: updatedList,
          hasMore: updatedList.length < totalLocalCount,
        ));
      }

      // 3. Fetch from API (Only if online)
      if (!await _hasInternet()) {
        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
        ));
        return;
      }

      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
          error: 'Session expired. Please login again.',
        ));
        return;
      }
      final role = await UserSecureStorage.fetchRole();
      final isPartner = role == 'partner';
      final url =
          '${Config.baseUrl}${Routes.getStaffList(schoolId, page: page, search: search, isPartner: isPartner)}';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final listData = json['data']?['list'] ?? {};
        final List raw = listData['data'] ?? [];
        final int total = listData['total'] ?? 0;

        final newItems = raw
            .map((e) => StaffListModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Sync to local DB
        await localDS.insertStaff(newItems);

        // Fetch latest merged data from local DB after API sync
        final latestLocalList = await localDS.getStaff(
          search: search,
          schoolId: schoolId,
          limit: perPage,
          offset: offset,
        );

        final latestPending = await localDS.getOfflineStaff(
          schoolId: schoolId,
        );

        final Set<String> apiSeenUuids = {};
        final List<StaffListModel> finalMerged = [];

        for (var s in latestPending) {
          if (s.uuid.isNotEmpty && !apiSeenUuids.contains(s.uuid)) {
            bool matchesSearch = search.isEmpty ||
                (s.name).toLowerCase().contains(search.toLowerCase());
            if (matchesSearch) {
              finalMerged.add(s);
              apiSeenUuids.add(s.uuid);
            }
          }
        }

        for (var s in latestLocalList) {
          if (s.uuid.isNotEmpty && !apiSeenUuids.contains(s.uuid)) {
            finalMerged.add(s);
            apiSeenUuids.add(s.uuid);
          }
        }

        final updated = isLoadMore ? [...state.list, ...finalMerged] : finalMerged;

        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
          list: updated,
          page: page + 1,
          hasMore: updated.length < total,
          total: total,
        ));
      } else {
        // If API fails but we have local data, don't show error unless it's the first load and we have NO data
        if (state.list.isEmpty) {
          emit(state.copyWith(
            loading: false,
            paginationLoading: false,
            error: _parseErrorMessage(response),
          ));
        } else {
          emit(state.copyWith(
            loading: false,
            paginationLoading: false,
          ));
        }
      }
    } catch (e) {
      if (state.list.isEmpty) {
        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
          error: e.toString(),
        ));
      } else {
        emit(state.copyWith(
          loading: false,
          paginationLoading: false,
        ));
      }
    }
  }

  void prependStaff(StaffListModel staff) {
    emit(state.copyWith(
      list: [staff, ...state.list],
      total: state.total + 1,
    ));
  }


  Future<void> syncOfflineStaff({required String schoolId}) async {
    _lastSchoolId = schoolId;
    if (!await _hasInternet()) return;

    final offlineStaff = await localDS.getOfflineStaff(schoolId: schoolId);
    if (offlineStaff.isEmpty) return;

    debugPrint("Syncing ${offlineStaff.length} offline staff...");
    emit(state.copyWith(isSyncing: true));

    try {
      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        debugPrint("Sync failed: No token found");
        return;
      }

      for (var staff in offlineStaff) {
        try {
          StaffListModel currentStaff = staff;

          // 1. Delete sync
          if (currentStaff.isDeletePendingSync) {
            final success = await _syncDelete(
              token: token,
              schoolId: schoolId,
              staff: currentStaff,
            );
            if (success) {
              await localDS.deleteStaffByUuid(currentStaff.uuid);
              debugPrint("Synced delete for staff: ${currentStaff.name}");
            }
            continue;
          }

          // 2. Status sync
          if (currentStaff.isStatusPendingSync) {
            final success = await _syncStatus(
              token: token,
              schoolId: schoolId,
              staff: currentStaff,
            );
            if (success) {
              await localDS.insertStaff([currentStaff.copyWith(isStatusPendingSync: false)]);
              debugPrint("Synced status for staff: ${currentStaff.name}");
            }
          }

          // 3. Photo sync
          if (currentStaff.isPhotoPendingSync && currentStaff.offlinePhotoPath != null) {
            final newUrl = await _syncPhoto(
              token: token,
              schoolId: schoolId,
              staff: currentStaff,
            );
            if (newUrl != null) {
              await localDS.insertStaff([
                currentStaff.copyWith(
                  isPhotoPendingSync: false,
                  profilePhotoUrl: newUrl,
                  offlinePhotoPath: null,
                )
              ]);
              debugPrint("Synced photo for staff: ${currentStaff.name}");
            }
          }

          // 4. New Staff / Update sync
          if (currentStaff.isOffline || currentStaff.isOfflineUpdate) {
            final success = await _syncAddOrUpdate(
              token: token,
              schoolId: schoolId,
              staff: currentStaff,
            );
            if (success) {
              // After successful add/update, the staff will be fetched from API in next fetchStaff call
              // For now, we mark it as no longer offline
              await localDS.insertStaff([
                currentStaff.copyWith(
                  isOffline: false,
                  isOfflineUpdate: false,
                )
              ]);
              debugPrint("Synced add/update for staff: ${currentStaff.name}");
            }
          }
        } catch (e) {
          debugPrint("Error syncing staff ${staff.name}: $e");
        }
      }
    } finally {
      emit(state.copyWith(isSyncing: false));
      // Refresh list after sync
      fetchStaff(schoolId: schoolId);
    }
  }

  Future<bool> _syncDelete({
    required String token,
    required String schoolId,
    required StaffListModel staff,
  }) async {
    final url = '${Config.baseUrl}${Routes.deleteStaff(schoolId, staff.uuid)}';
    final response = await http.delete(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 404;
  }

  Future<bool> _syncStatus({
    required String token,
    required String schoolId,
    required StaffListModel staff,
  }) async {
    final url = '${Config.baseUrl}${Routes.toggleStaffStatus(schoolId, staff.uuid)}';
    final response = await http.patch(
      Uri.parse(url),
      body: jsonEncode({'status': staff.status == 1}),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<String?> _syncPhoto({
    required String token,
    required String schoolId,
    required StaffListModel staff,
  }) async {
    final url = '${Config.baseUrl}${Routes.uploadStaffPhoto(schoolId, staff.uuid)}';
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('photo', staff.offlinePhotoPath!));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return json['data']?['profile_photo_url'] as String?;
    }
    return null;
  }

  Future<bool> _syncAddOrUpdate({
    required String token,
    required String schoolId,
    required StaffListModel staff,
  }) async {
    // If it's a new staff, we need to use the AddStaff API logic
    // If it's an update, use the UpdateStaff API logic
    // This logic is complex because it involves many fields.
    // For now, let's assume AddStaffCubit will handle the initial offline save.
    // Here we just need the API call.

    final isUpdate = staff.isOfflineUpdate && !staff.isOffline;
    final url = isUpdate
        ? Config.url(Routes.updateStaff(schoolId, staff.uuid))
        : Config.url(Routes.addStaff(schoolId));

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    if (isUpdate) {
      request.fields['_method'] = 'PUT';
    }

    // Decode fields from offlineFieldsJson
    if (staff.offlineFieldsJson != null) {
      final Map<String, dynamic> fields = jsonDecode(staff.offlineFieldsJson!);
      fields.forEach((k, v) {
        if (v != null) request.fields[k] = v.toString();
      });
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return response.statusCode == 200 || response.statusCode == 201;
  }

  Future<bool> deleteStaff({
    required String schoolId,
    required String uuid,
  }) async {
    emit(state.copyWith(deleting: true));
    try {
      final staff = state.list.firstWhere(
        (s) => s.uuid == uuid,
        orElse: () => StaffListModel(
          id: 0,
          uuid: uuid,
          name: '',
          designation: '',
          department: '',
          email: '',
          phone: '',
          roleName: '',
          status: 1,
          assignedClasses: [],
        ),
      );

      if (!await _hasInternet()) {
        debugPrint("Deleting staff locally (offline): $uuid");
        if (uuid.startsWith('offline_')) {
          await localDS.deleteStaffByUuid(uuid);
        } else {
          final updatedStaff = staff.copyWith(isDeletePendingSync: true);
          await localDS.insertStaff([updatedStaff]);
        }
        final updated = state.list.where((s) => s.uuid != uuid).toList();
        emit(state.copyWith(
          deleting: false,
          list: updated,
          total: state.total - 1,
        ));
        return true;
      }

      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        emit(state.copyWith(deleting: false));
        return false;
      }
      final url = '${Config.baseUrl}${Routes.deleteStaff(schoolId, uuid)}';
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        await localDS.deleteStaffByUuid(uuid);
        final updated = state.list.where((s) => s.uuid != uuid).toList();
        emit(state.copyWith(
          deleting: false,
          list: updated,
          total: state.total - 1,
        ));
        return true;
      }
      emit(state.copyWith(deleting: false));
      return false;
    } catch (_) {
      emit(state.copyWith(deleting: false));
      return false;
    }
  }


  Future<bool> changeStaffPassword({
    required String schoolId,
    required String uuid,
    required String password,
  }) async {
    emit(state.copyWith(changingPassword: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}${Routes.changeStaffPassword(schoolId, uuid)}';
      final response = await http.put(
        Uri.parse(url),
        body: jsonEncode({
          'password': password,
          'password_confirmation': password,
        }),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      final success =
          response.statusCode == 200 || response.statusCode == 201;
      emit(state.copyWith(changingPassword: false));
      return success;
    } catch (_) {
      emit(state.copyWith(changingPassword: false));
      return false;
    }
  }


  Future<bool> toggleStaffStatus({
    required String schoolId,
    required String uuid,
    required int currentStatus,
  }) async {
    emit(state.copyWith(togglingStatus: true));
    try {
      final newStatusInt = currentStatus == 1 ? 0 : 1;
      final staff = state.list.firstWhere((s) => s.uuid == uuid);

      if (!await _hasInternet()) {
        debugPrint("Toggling staff status locally (offline): $uuid");
        final updatedStaff = staff.copyWith(
          status: newStatusInt,
          isStatusPendingSync: true,
        );
        await localDS.insertStaff([updatedStaff]);
        final updated = state.list.map((s) {
          if (s.uuid == uuid) return updatedStaff;
          return s;
        }).toList();
        emit(state.copyWith(togglingStatus: false, list: updated));
        return true;
      }

      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        emit(state.copyWith(togglingStatus: false));
        return false;
      }
      final url = '${Config.baseUrl}${Routes.toggleStaffStatus(schoolId, uuid)}';
      final newStatus = currentStatus == 1 ? false : true;
      final response = await http.patch(
        Uri.parse(url),
        body: jsonEncode({'status': newStatus}),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final updatedStaff = staff.copyWith(
          status: newStatusInt,
          isStatusPendingSync: false,
        );
        await localDS.insertStaff([updatedStaff]);
        final updated = state.list.map((s) {
          if (s.uuid == uuid) return updatedStaff;
          return s;
        }).toList();
        emit(state.copyWith(togglingStatus: false, list: updated));
        return true;
      }
      emit(state.copyWith(togglingStatus: false));
      return false;
    } catch (_) {
      emit(state.copyWith(togglingStatus: false));
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAssignedClasses({
    required String schoolId,
    required String uuid,
  }) async {
    emit(state.copyWith(assignedClassesLoading: true, assignedClasses: []));

    final String cacheKey = 'assigned_classes_$uuid';

    // ── STEP 1: Load from local DB first ──
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'home_cache',
        where: 'key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final List<Map<String, dynamic>> localData =
            (jsonDecode(row['json_data'] as String? ?? '[]') as List)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        if (localData.isNotEmpty) {
          debugPrint('fetchAssignedClasses: Loaded ${localData.length} classes from local DB');
          emit(state.copyWith(
            assignedClassesLoading: false,
            assignedClasses: localData,
          ));
          // Sync from API in background
          _syncAssignedClassesFromApi(schoolId, uuid, cacheKey);
          return localData;
        }
      }
    } catch (e) {
      debugPrint('fetchAssignedClasses local load error: $e');
    }

    // ── STEP 2: Fetch from API if no local data ──
    return await _syncAssignedClassesFromApi(schoolId, uuid, cacheKey, emitLoading: true);
  }

  Future<List<Map<String, dynamic>>> _syncAssignedClassesFromApi(
    String schoolId,
    String uuid,
    String cacheKey, {
    bool emitLoading = false,
  }) async {
    if (emitLoading) emit(state.copyWith(assignedClassesLoading: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url =
          '${Config.baseUrl}${Routes.staffAssignedClasses(schoolId, uuid)}';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final rawData = json['data']?['assigned_classes'];
        List<Map<String, dynamic>> result = [];
        if (rawData is Map) {
          rawData.forEach((key, value) {
            final item = Map<String, dynamic>.from(value as Map);
            item['assigned_uuid'] = key;
            result.add(item);
          });
        } else if (rawData is List) {
          result = rawData.map((e) => Map<String, dynamic>.from(e)).toList();
        }

        // ── STEP 3: Save to local DB ──
        try {
          final db = await DBHelper.db;
          await db.insert(
            'home_cache',
            {
              'key': cacheKey,
              'json_data': jsonEncode(result),
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          debugPrint('fetchAssignedClasses: Saved fresh classes to local DB');
        } catch (e) {
          debugPrint('fetchAssignedClasses local save error: $e');
        }

        emit(state.copyWith(
          assignedClassesLoading: false,
          assignedClasses: result,
        ));
        return result;
      }
    } catch (e) {
      debugPrint('fetchAssignedClasses API sync error: $e');
    }
    if (emitLoading) emit(state.copyWith(assignedClassesLoading: false, assignedClasses: []));
    return [];
  }

  Future<bool> assignClass({
    required String schoolId,
    required String uuid,
    required int classId,
    required List<int> sectionIds,
  }) async {
    emit(state.copyWith(assigningClass: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url =
          '${Config.baseUrl}${Routes.staffAssignClass(schoolId, uuid)}';
      final body = jsonEncode({'class': classId, 'section': sectionIds});
      print('AssignClass URL: $url');
      print('AssignClass Body: $body');
      final response = await http.post(
        Uri.parse(url),
        body: body,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      print('AssignClass Status: ${response.statusCode}');
      print('AssignClass Response: ${response.body}');
      final success =
          response.statusCode == 200 || response.statusCode == 201;
      emit(state.copyWith(assigningClass: false));
      return success;
    } catch (e) {
      print('AssignClass Error: $e');
      emit(state.copyWith(assigningClass: false));
      return false;
    }
  }

  Future<bool> removeAssignedClass({
    required String schoolId,
    required String assignedClassUuid,
  }) async {
    emit(state.copyWith(removingClass: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url =
          '${Config.baseUrl}${Routes.staffRemoveAssignedClass(schoolId, assignedClassUuid)}';
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      final success =
          response.statusCode == 200 || response.statusCode == 201;
      emit(state.copyWith(removingClass: false));
      return success;
    } catch (_) {
      emit(state.copyWith(removingClass: false));
      return false;
    }
  }


  Future<String?> uploadStaffPhoto({
    required String schoolId,
    required String uuid,
    required String imagePath,
  }) async {
    final uploadingMap = Map<String, bool>.from(state.photoUploadingMap);
    uploadingMap[uuid] = true;
    emit(state.copyWith(photoUploadingMap: uploadingMap));

    try {
      final staff = state.list.firstWhere((s) => s.uuid == uuid);

      if (!await _hasInternet()) {
        debugPrint("Uploading staff photo locally (offline): $uuid");
        final updatedStaff = staff.copyWith(
          isPhotoPendingSync: true,
          offlinePhotoPath: imagePath,
        );
        await localDS.insertStaff([updatedStaff]);
        updateStaffPhoto(uuid, imagePath); // Use local path for preview
        final doneMap = Map<String, bool>.from(state.photoUploadingMap);
        doneMap.remove(uuid);
        emit(state.copyWith(photoUploadingMap: doneMap));
        return imagePath;
      }

      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        final doneMap = Map<String, bool>.from(state.photoUploadingMap);
        doneMap.remove(uuid);
        emit(state.copyWith(photoUploadingMap: doneMap));
        return null;
      }
      final url =
          '${Config.baseUrl}${Routes.uploadStaffPhoto(schoolId, uuid)}';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', imagePath));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        String? newUrl = json['data']?['profile_photo_url'] as String?;
        if (newUrl != null) {
          final regex = RegExp(r'https?://');
          final matches = regex.allMatches(newUrl).toList();
          if (matches.length > 1) newUrl = newUrl.substring(matches.last.start);
          newUrl = newUrl
              .replaceAll('http://localhost:8000', 'https://idmitra.com')
              .replaceAll('http://localhost', 'https://idmitra.com');
        }
        if (newUrl != null) {
          updateStaffPhoto(uuid, newUrl);
          final updatedStaff = staff.copyWith(
            profilePhotoUrl: newUrl,
            isPhotoPendingSync: false,
            offlinePhotoPath: null,
          );
          await localDS.insertStaff([updatedStaff]);
        }
        final doneMap = Map<String, bool>.from(state.photoUploadingMap);
        doneMap.remove(uuid);
        emit(state.copyWith(photoUploadingMap: doneMap));
        return newUrl;
      }
    } catch (_) {
    }

    final doneMap = Map<String, bool>.from(state.photoUploadingMap);
    doneMap.remove(uuid);
    emit(state.copyWith(photoUploadingMap: doneMap));
    return null;
  }


  Future<String?> uploadStaffSignature({
    required String schoolId,
    required String uuid,
    required String imagePath,
  }) async {
    emit(state.copyWith(
      signatureUploading: true,
      clearSignatureMessages: true,
    ));
    try {
      final token = await UserSecureStorage.fetchToken();
      if (token == null) {
        emit(state.copyWith(
          signatureUploading: false,
          signatureUploadError: 'Session expired. Please login again.',
        ));
        return null;
      }
      final url =
          '${Config.baseUrl}${Routes.uploadStaffSignature(schoolId, uuid)}';
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files
          .add(await http.MultipartFile.fromPath('signature', imagePath));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final signatureUrl = json['data']?['signature_url'] as String?;
        emit(state.copyWith(
          signatureUploading: false,
          signatureUploadSuccess: 'Signature uploaded successfully',
        ));
        return signatureUrl;
      }
    } catch (_) {
    }
    emit(state.copyWith(
      signatureUploading: false,
      signatureUploadError: 'Failed to upload signature',
    ));
    return null;
  }

  void clearSignatureMessages() {
    emit(state.copyWith(clearSignatureMessages: true));
  }


  Future<void> fetchStaffOrders({
    required String schoolId,
    bool reset = false,
    String? search,
    String? status,
    String? dateFrom,
    String? dateTo,
  }) async {
    final effectiveSearch = search ?? state.ordersSearch;
    final effectiveStatus = status ?? state.ordersSelectedStatus;
    final effectiveDateFrom = dateFrom ?? state.ordersDateFrom;
    final effectiveDateTo = dateTo ?? state.ordersDateTo;

    if (!reset && (state.ordersLoading || state.ordersPaginationLoading)) return;
    if (!reset && !state.ordersHasMore) return;

    final currentPage = reset ? 1 : state.ordersPage;
    const int perPage = 50;
    final int offset = (currentPage - 1) * perPage;

    if (reset || state.orders.isEmpty) {
      emit(state.copyWith(
        ordersLoading: true,
        clearOrdersError: true,
        orders: reset ? [] : state.orders,
        ordersPage: 1,
        ordersHasMore: true,
        ordersSearch: effectiveSearch,
        ordersSelectedStatus: effectiveStatus,
        ordersDateFrom: effectiveDateFrom,
        ordersDateTo: effectiveDateTo,
      ));
    } else {
      emit(state.copyWith(ordersPaginationLoading: true));
    }

    try {
      // 1. Try local DB first
      final localOrders = await _orderLocalDS.getOrders(
        schoolId: schoolId,
        search: effectiveSearch,
        status: effectiveStatus,
        startDate: effectiveDateFrom,
        endDate: effectiveDateTo,
        limit: perPage,
        offset: offset,
      );

      final totalLocalCount = await _orderLocalDS.getCount(
        schoolId: schoolId,
        search: effectiveSearch,
        status: effectiveStatus,
        startDate: effectiveDateFrom,
        endDate: effectiveDateTo,
      );

      // Filter for staff orders only (orders that have staff info OR are offline staff orders)
      // Exclude is_offline rows when online — they will be wiped by API sync
      final localStaffOrders = localOrders
          .where((o) => o.staff != null || o.uuid.startsWith('offline_'))
          .map((o) => OrderStaffItem(
                id: o.id,
                uuid: o.uuid,
                status: o.status,
                type: o.type,
                orderedAt: o.orderedAt,
                staffName: o.staff?.name ?? 'Pending Sync',
                staffPhoto: o.staff?.profilePhotoUrl,
                schoolName: o.school?.name,
              ))
          .toList();

      final hasNet = await _hasInternet();

      if (!hasNet) {
        // Offline: emit local data as final state (no API call follows)
        emit(state.copyWith(
          ordersLoading: false,
          ordersPaginationLoading: false,
          orders: reset ? localStaffOrders : [...state.orders, ...localStaffOrders],
          ordersTotal: localStaffOrders.length,
          ordersHasMore: false,
        ));
        return;
      }

      // Online: exclude offline placeholders — API data is the source of truth
      final onlineLocalOrders = localStaffOrders
          .where((o) => !o.uuid.startsWith('offline_'))
          .toList();

      // For load-more only, show non-offline local data while API loads
      if (!reset && onlineLocalOrders.isNotEmpty) {
        final merged = [...state.orders, ...onlineLocalOrders];
        emit(state.copyWith(
          ordersLoading: false,
          ordersPaginationLoading: false,
          orders: merged,
          ordersTotal: totalLocalCount,
          ordersHasMore: merged.length < totalLocalCount,
        ));
      }

      String url =
          '${Config.baseUrl}auth/school/$schoolId/staff/orders?page=$currentPage';
      if (effectiveStatus.isNotEmpty) url += '&status=$effectiveStatus';
      if (effectiveSearch.isNotEmpty) url += '&search=$effectiveSearch';
      if (effectiveDateFrom.isNotEmpty) url += '&start_date=$effectiveDateFrom';
      if (effectiveDateTo.isNotEmpty) url += '&end_date=$effectiveDateTo';

      final response = await ApiManager().getRequest(url);
      if (response == null) {
        emit(state.copyWith(
          ordersLoading: false,
          ordersPaginationLoading: false,
        ));
        return;
      }

      final json = jsonDecode(response.body);
      final isSuccess =
          json['status'] == true || json['success'] == true;
      if (!isSuccess) {
        if (state.orders.isEmpty) {
          emit(state.copyWith(
            ordersLoading: false,
            ordersPaginationLoading: false,
            ordersError: json['message'] ?? 'Failed to load staff orders',
          ));
        } else {
          emit(state.copyWith(
            ordersLoading: false,
            ordersPaginationLoading: false,
          ));
        }
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        emit(state.copyWith(
          ordersLoading: false,
          ordersPaginationLoading: false,
        ));
        return;
      }

      List rawList = [];
      int total = 0, lastPage = 1, respPage = 1;

      if (data.containsKey('list') && data['list'] is Map) {
        final listData = data['list'] as Map<String, dynamic>;
        rawList = listData['data'] ?? [];
        total = listData['total'] ?? 0;
        lastPage = listData['last_page'] ?? 1;
        respPage = listData['current_page'] ?? 1;
      } else if (data.containsKey('orders')) {
        final ordersData = data['orders'];
        if (ordersData is List) {
          rawList = ordersData;
          total = rawList.length;
        } else if (ordersData is Map) {
          rawList = ordersData['data'] ?? [];
          total = ordersData['total'] ?? 0;
          lastPage = ordersData['last_page'] ?? 1;
          respPage = ordersData['current_page'] ?? 1;
        }
      } else if (data.containsKey('data') && data['data'] is List) {
        rawList = data['data'] as List;
        total = data['total'] ?? rawList.length;
        lastPage = data['last_page'] ?? 1;
        respPage = data['current_page'] ?? 1;
      }

      final apiOrders = rawList.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();

      // Sync to local DB — fromApi:true + page clears stale data on first page
      await _orderLocalDS.insertOrders(apiOrders, schoolId, fromApi: true, page: currentPage);

      final newOrders = apiOrders.map((o) => OrderStaffItem(
        id: o.id,
        uuid: o.uuid,
        status: o.status,
        type: o.type,
        orderedAt: o.orderedAt,
        staffName: o.staff?.name,
        staffPhoto: o.staff?.profilePhotoUrl,
        schoolName: o.school?.name,
      )).toList();

      List<OrderStaffItem> mergedOrders;
      if (reset) {
        mergedOrders = newOrders;
      } else {
        // Deduplicate: remove from existing state any items whose uuid matches API items
        final apiUuids = newOrders.map((o) => o.uuid).toSet();
        final existing = state.orders
            .where((o) => !apiUuids.contains(o.uuid) && !o.uuid.startsWith('offline_'))
            .toList();
        mergedOrders = [...existing, ...newOrders];
      }

      emit(state.copyWith(
        ordersLoading: false,
        ordersPaginationLoading: false,
        ordersTotal: total,
        ordersPage: respPage + 1,
        ordersHasMore: respPage < lastPage,
        orders: mergedOrders,
        ordersSearch: effectiveSearch,
        ordersSelectedStatus: effectiveStatus,
        ordersDateFrom: effectiveDateFrom,
        ordersDateTo: effectiveDateTo,
      ));
    } catch (e) {
      if (state.orders.isEmpty) {
        final hasNet = await _hasInternet();
        if (hasNet) {
          emit(state.copyWith(
            ordersLoading: false,
            ordersPaginationLoading: false,
            ordersError: e.toString(),
          ));
        } else {
          emit(state.copyWith(
            ordersLoading: false,
            ordersPaginationLoading: false,
          ));
        }
      } else {
        emit(state.copyWith(
          ordersLoading: false,
          ordersPaginationLoading: false,
        ));
      }
    }
  }

  void setOrdersFilter({
    required String schoolId,
    String? status,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) {
    fetchStaffOrders(
      schoolId: schoolId,
      reset: true,
      status: status ?? state.ordersSelectedStatus,
      dateFrom: dateFrom ?? state.ordersDateFrom,
      dateTo: dateTo ?? state.ordersDateTo,
      search: search ?? state.ordersSearch,
    );
  }

  void clearOrdersFilters(String schoolId) {
    fetchStaffOrders(
      schoolId: schoolId,
      reset: true,
      status: '',
      dateFrom: '',
      dateTo: '',
      search: '',
    );
  }

  Future<bool> updateOrderStatus({
    required String orderUuid,
    required String newStatus,
  }) async {
    // Mark as updating
    final updatingMap = Map<String, bool>.from(state.orderUpdatingMap);
    updatingMap[orderUuid] = true;
    emit(state.copyWith(orderUpdatingMap: updatingMap));

    try {
      final api = ApiManager();
      final url =
          '${Config.baseUrl}auth/partner/orders/$orderUuid/status';
      final response =
      await api.patchRequestWithBody(url, {'status': newStatus});

      bool success = false;
      if (response != null) {
        final json = jsonDecode(response.body);
        success = json['success'] == true;
      }

      if (success) {
        final updatedOrders = state.orders.map((o) {
          if (o.uuid == orderUuid) {
            return o;
          }
          return o;
        }).toList();

        final statusMap = Map<String, String>.from(state.orderStatusMap);
        statusMap[orderUuid] = newStatus;

        final doneUpdatingMap = Map<String, bool>.from(state.orderUpdatingMap);
        doneUpdatingMap.remove(orderUuid);

        emit(state.copyWith(
          orderUpdatingMap: doneUpdatingMap,
          orderStatusMap: statusMap,
          orders: updatedOrders,
        ));
        return true;
      }

      final doneUpdatingMap = Map<String, bool>.from(state.orderUpdatingMap);
      doneUpdatingMap.remove(orderUuid);
      emit(state.copyWith(orderUpdatingMap: doneUpdatingMap));
      return false;
    } catch (_) {
      final doneUpdatingMap = Map<String, bool>.from(state.orderUpdatingMap);
      doneUpdatingMap.remove(orderUuid);
      emit(state.copyWith(orderUpdatingMap: doneUpdatingMap));
      return false;
    }
  }

  void toggleStaffOrderSelection(int id) {
    final current = Set<int>.from(state.selectedStaffOrderIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    emit(state.copyWith(selectedStaffOrderIds: current));
  }

  void selectAllStaffOrders() {
    final all = state.orders.map((o) => o.id).toSet();
    emit(state.copyWith(selectedStaffOrderIds: all));
  }

  void clearStaffOrderSelection() {
    emit(state.copyWith(selectedStaffOrderIds: {}));
  }

  Future<bool> bulkUpdateStaffOrderStatus({
    required String schoolId,
    required List<int> ids,
    required String status,
    String issueNote = '',
  }) async {
    // Resolve uuids from current orders state
    final uuids = state.orders
        .where((o) => ids.contains(o.id) && o.uuid.isNotEmpty)
        .map((o) => o.uuid)
        .toList();

    // ── OFFLINE: save locally ──
    if (!await _hasInternet()) {
      try {
        // Save to pending_status_updates for later sync
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: status,
          issueNote: issueNote,
        );

        // Update local orders table immediately (savePendingStatusUpdate already does this by uuid)
        // Also update state so UI reflects the change right away
        final updatedOrders = state.orders.map((o) {
          if (ids.contains(o.id)) {
            return OrderStaffItem(
              id: o.id,
              uuid: o.uuid,
              status: status,
              type: o.type,
              orderedAt: o.orderedAt,
              staffName: o.staffName,
              staffPhoto: o.staffPhoto,
              schoolName: o.schoolName,
            );
          }
          return o;
        }).toList();

        emit(state.copyWith(
          orders: updatedOrders,
          selectedStaffOrderIds: {},
        ));

        debugPrint("Saved offline status update for ${uuids.length} orders");
        return true;
      } catch (e) {
        debugPrint("Failed to save offline status update: $e");
        return false;
      }
    }

    // ── ONLINE: send to API ──
    try {
      final api = ApiManager();
      final url = '${Config.baseUrl}auth/school/$schoolId/staff/orders/status';
      final statusBody = <String, dynamic>{'status': status};
      if (issueNote.isNotEmpty) statusBody['issueNote'] = issueNote;
      final body = <String, dynamic>{'ids': ids, 'status': statusBody};
      print('bulkUpdateStaffOrderStatus URL: $url');
      print('bulkUpdateStaffOrderStatus Body: $body');
      final response = await api.patchRequestWithBody(url, body);
      if (response == null) return false;
      final json = jsonDecode(response.body);
      print('bulkUpdateStaffOrderStatus response: ${response.body}');
      if (json['success'] == true) {
        // Update state immediately on success
        final updatedOrders = state.orders.map((o) {
          if (ids.contains(o.id)) {
            return OrderStaffItem(
              id: o.id,
              uuid: o.uuid,
              status: status,
              type: o.type,
              orderedAt: o.orderedAt,
              staffName: o.staffName,
              staffPhoto: o.staffPhoto,
              schoolName: o.schoolName,
            );
          }
          return o;
        }).toList();
        emit(state.copyWith(orders: updatedOrders));
        return true;
      }
      return false;
    } catch (e) {
      print('bulkUpdateStaffOrderStatus error: $e');
      return false;
    }
  }

  String _parseErrorMessage(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      return json['message'] ?? json['error'] ?? 'Something went wrong';
    } catch (_) {
      switch (response.statusCode) {
        case 403:
          return 'Permission Denied';
        case 401:
          return 'Unauthorized. Please login again.';
        default:
          return 'Failed to load staff (${response.statusCode})';
      }
    }
  }

  /// Sync pending offline staff orders when internet is restored
  Future<void> syncPendingStaffOrders({required String schoolId}) async {
    if (!await _hasInternet()) return;

    final db = await DBHelper.db;

    // ── 1. Sync pending status updates ──
    final pendingStatusRows = await _orderLocalDS.getAllPendingStatusUpdates();
    final staffStatusRows = pendingStatusRows
        .where((r) => (r['school_id'] as String?) == schoolId)
        .toList();

    for (final row in staffStatusRows) {
      try {
        final rowId = row['id'] as int;
        final uuids = jsonDecode(row['uuids_json'] as String? ?? '[]') as List;
        final status = row['status'] as String? ?? '';
        final issueNote = row['issue_note'] as String? ?? '';

        // Fetch order ids from local DB by uuid
        final orderRows = await db.query(
          'orders',
          columns: ['id'],
          where: 'uuid IN (${uuids.map((_) => '?').join(',')})',
          whereArgs: uuids,
        );
        final orderIds = orderRows.map((r) => r['id'] as int).toList();

        if (orderIds.isEmpty) {
          await _orderLocalDS.deletePendingStatusUpdate(rowId);
          continue;
        }

        final url = '${Config.baseUrl}auth/school/$schoolId/staff/orders/status';
        final statusBody = <String, dynamic>{'status': status};
        if (issueNote.isNotEmpty) statusBody['issueNote'] = issueNote;
        final body = <String, dynamic>{'ids': orderIds, 'status': statusBody};

        final response = await ApiManager().patchRequestWithBody(url, body);
        if (response != null) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _orderLocalDS.deletePendingStatusUpdate(rowId);
            debugPrint("Synced pending status update id=$rowId");
          }
        }
      } catch (e) {
        debugPrint("Failed to sync pending status update: $e");
      }
    }

    // ── 2. Sync pending new orders ──
    final pendingRows = await db.query(
      'pending_orders',
      where: 'school_id = ?',
      whereArgs: [schoolId],
      orderBy: 'created_at ASC',
    );

    if (pendingRows.isNotEmpty) {
      debugPrint("Syncing ${pendingRows.length} pending staff orders...");

      for (final row in pendingRows) {
        try {
          final rowId = row['id'] as int;
          final cardType = row['card_type'] as String? ?? '';
          final cardUsers = jsonDecode(row['card_users_json'] as String? ?? '[]') as List;
          final orderJson = jsonDecode(row['order_json'] as String? ?? '{}') as Map<String, dynamic>;
          final tempUuid = orderJson['temp_uuid'] as String?;

          final url = '${Config.baseUrl}auth/school/$schoolId/staff/orders';
          final body = <String, dynamic>{
            'card_type': cardType,
            'card_users': cardUsers.cast<String>(),
          };

          final response = await ApiManager().postRequest(body, url);
          if (response != null) {
            final json = jsonDecode(response.body);
            if (json['success'] == true) {
              await db.delete('pending_orders', where: 'id = ?', whereArgs: [rowId]);
              if (tempUuid != null) {
                await _orderLocalDS.deleteOrderByUuid(tempUuid);
              }

              // Remove synced correction items from staff_corrections local table
              // so they no longer appear in the correction list
              final uuids = cardUsers.cast<String>().where((u) => u.isNotEmpty).toList();
              if (uuids.isNotEmpty) {
                await db.delete(
                  'staff_corrections',
                  where: 'uuid IN (${uuids.map((_) => '?').join(',')})',
                  whereArgs: uuids,
                );
              }

              debugPrint("Synced pending staff order id=$rowId, removed ${uuids.length} correction items");
            }
          }
        } catch (e) {
          debugPrint("Failed to sync pending staff order: $e");
        }
      }
    }

    // Refresh orders list after sync
    if (_lastSchoolId != null) {
      // Wipe ALL offline placeholder orders before refreshing so they never
      // appear alongside the freshly-fetched server orders.
      await db.delete(
        'orders',
        where: 'school_id = ? AND is_offline = 1',
        whereArgs: [_lastSchoolId!],
      );
      fetchStaffOrders(schoolId: _lastSchoolId!, reset: true);
    }
  }
}