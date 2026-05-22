import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/correction_local_ds/correction_local_ds.dart';
import 'package:idmitra/local_db/order_local_ds/order_local_ds.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/providers/orders/orders_state.dart';
import 'package:sqflite/sqflite.dart';

class OrdersCubit extends Cubit<OrdersState> {
  StreamSubscription? _connectivitySubscription;

  OrdersCubit() : super(const OrdersState()) {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (hasInternet) {
        syncPendingStatusUpdates();
        syncPendingOrders();
      }
    });
    _initSync();
  }

  Future<void> _initSync() async {
    if (await _hasInternet()) {
      await syncPendingOrders();
      await syncPendingStatusUpdates();
    }
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  final ApiManager _api = ApiManager();
  final CorrectionLocalDS _localDS = CorrectionLocalDS();
  final OrderLocalDS _orderLocalDS = OrderLocalDS();

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

  static const _classOrder = [
    'pre nursery', 'prenursery', 'pre-nursery',
    'nursery',
    'prep', 'pre prep', 'preprep', 'pre-prep',
    'lkg', 'l.k.g', 'lower kg', 'lower kindergarten', 'l kg',
    'ukg', 'u.k.g', 'upper kg', 'upper kindergarten', 'u kg',
    'kg', 'k.g', 'kindergarten',
    '1', 'i', 'class 1', 'grade 1',
    '2', 'ii', 'class 2', 'grade 2',
    '3', 'iii', 'class 3', 'grade 3',
    '4', 'iv', 'class 4', 'grade 4',
    '5', 'v', 'class 5', 'grade 5',
    '6', 'vi', 'class 6', 'grade 6',
    '7', 'vii', 'class 7', 'grade 7',
    '8', 'viii', 'class 8', 'grade 8',
    '9', 'ix', 'class 9', 'grade 9',
    '10', 'x', 'class 10', 'grade 10',
    '11', 'xi', 'class 11', 'grade 11',
    '12', 'xii', 'class 12', 'grade 12',
  ];

  static int _classSortIndex(String name) {
    final lower = name.trim().toLowerCase();
    // Exact match first
    for (int i = 0; i < _classOrder.length; i++) {
      if (lower == _classOrder[i]) return i;
    }
    // Then starts-with match (e.g. "class 1 a" → "class 1")
    for (int i = 0; i < _classOrder.length; i++) {
      if (lower.startsWith(_classOrder[i])) return i;
    }
    return 999;
  }

  static List<OrderClass> _sortClasses(List<OrderClass> classes) {
    final sorted = [...classes];
    sorted.sort((a, b) {
      final aName = a.nameWithprefix ?? a.name;
      final bName = b.nameWithprefix ?? b.name;
      final ai = _classSortIndex(aName);
      final bi = _classSortIndex(bName);
      if (ai != bi) return ai.compareTo(bi);
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return sorted;
  }


  Future<void> fetchSchoolClasses(String schoolId) async {
    if (schoolId.isEmpty) return;
    emit(state.copyWith(classesLoading: true));

    // ── STEP 1: Load from local DB first ──
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_data',
        where: 'school_id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final row = rows.first;
        final classesJson = jsonDecode(row['classes_json'] as String? ?? '[]') as List;
        final List<OrderClass> localClasses = _parseClasses(classesJson);
        if (localClasses.isNotEmpty) {
          emit(state.copyWith(
            availableClasses: _sortClasses(localClasses),
            classesLoading: false,
          ));
          // If we have local data, we can still try to sync from API in background
          _syncClassesFromApi(schoolId);
          return;
        }
      }
    } catch (e) {
      print('fetchSchoolClasses local load error: $e');
    }

    // ── STEP 2: Fetch from API if no local data ──
    await _syncClassesFromApi(schoolId, emitLoading: true);
  }

  Future<void> _syncClassesFromApi(String schoolId, {bool emitLoading = false}) async {
    if (emitLoading) emit(state.copyWith(classesLoading: true));
    try {
      final url = '${Config.baseUrl}auth/school/$schoolId/students/form-data';
      final response = await _api.getRequest(url);
      if (response == null) {
        if (emitLoading) emit(state.copyWith(classesLoading: false));
        return;
      }
      final json = jsonDecode(response.body);
      final data = json['data'] ?? json;
      final List rawClasses = data['classes'] ?? [];

      // ── STEP 3: Save to local DB ──
      try {
        final db = await DBHelper.db;
        await db.insert(
          'school_form_data',
          {
            'school_id': schoolId,
            'classes_json': jsonEncode(rawClasses),
            'sessions_json': jsonEncode(data['sessions'] ?? []),
            'houses_json': jsonEncode(data['houses'] ?? []),
            'updated_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        print('fetchSchoolClasses: Saved fresh classes to local DB');
      } catch (e) {
        print('fetchSchoolClasses local save error: $e');
      }

      final List<OrderClass> classes = _parseClasses(rawClasses);
      emit(state.copyWith(availableClasses: _sortClasses(classes), classesLoading: false));
    } catch (e) {
      print('fetchSchoolClasses API sync error: $e');
      if (emitLoading) emit(state.copyWith(classesLoading: false));
    }
  }

  List<OrderClass> _parseClasses(List rawClasses) {
    final List<OrderClass> classes = [];
    for (final e in rawClasses) {
      final int classId = e['id'] is int
          ? e['id'] as int
          : int.tryParse(e['id']?.toString() ?? '') ?? 0;
      final String name = e['name']?.toString() ?? '';
      final String? nameWithprefix = e['name_withprefix']?.toString() ??
          e['name_with_prefix']?.toString();

      final List sections = e['sections'] as List? ??
          e['class_sections'] as List? ??
          e['classSections'] as List? ??
          [];

      if (sections.isNotEmpty) {
        for (final sec in sections) {
          final rawId = sec['id'] ?? sec['section_id'] ?? sec['class_section_id'];
          final int? sectionId = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
          final String sectionName = (sec['name']?.toString().trim().isNotEmpty == true)
              ? sec['name'].toString().trim()
              : (sec['section_name']?.toString().trim() ??
              sec['title']?.toString().trim() ?? '');
          classes.add(OrderClass(
            classId: classId,
            sectionId: sectionId,
            name: name,
            nameWithprefix: nameWithprefix,
            sectionName: sectionName,
          ));
        }
      } else {
        classes.add(OrderClass(
          classId: classId,
          sectionId: null,
          name: name,
          nameWithprefix: nameWithprefix,
        ));
      }
    }
    return classes;
  }

  Future<void> fetchSchoolOrders({
    bool isLoadMore = false,
    String search = '',
    String status = '',
    String classFilter = '',
    String dateFrom = '',
    String dateTo = '',
    required String schoolId,
  }) async {
    if (isLoadMore && (state.isPaginationLoading || !state.hasMore)) return;

    const int perPage = 50;
    final currentPage = isLoadMore ? state.page : 1;
    final int offset = (currentPage - 1) * perPage;

    if (!isLoadMore) {
      emit(state.copyWith(
        loading: true,
        isPaginationLoading: false,
        page: 1,
        ordersList: [],
        hasMore: true,
        clearError: true,
        schoolId: schoolId,
      ));
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    try {
      // 1. Fetch pending orders from local DB
      final pendingRaw = await _localDS.getAllPendingOrders(schoolId: schoolId);
      final List<OrderModel> pendingOrders = pendingRaw.map((e) {
        final orderJson = jsonDecode(e['order_json']);
        return OrderModel.fromJson(orderJson);
      }).toList();

      // 2. Fetch cached school classes for dropdown
      final localClasses = await _orderLocalDS.getSchoolClasses(schoolId);

      // 3. Fetch cached regular orders from local DB
      final localOrders = await _orderLocalDS.getOrders(
        schoolId: schoolId,
        search: search,
        status: status,
        classFilter: classFilter,
        startDate: dateFrom,
        endDate: dateTo,
        limit: perPage,
        offset: offset,
      );

      final totalLocalCount = await _orderLocalDS.getCount(
        schoolId: schoolId,
        search: search,
        status: status,
        classFilter: classFilter,
        startDate: dateFrom,
        endDate: dateTo,
      );

      if (localOrders.isNotEmpty || pendingOrders.isNotEmpty || localClasses.isNotEmpty) {
        final List<OrderModel> combinedLocal = isLoadMore
            ? [...state.ordersList, ...localOrders]
            : [...pendingOrders, ...localOrders];

        bool hasMoreLocal = (combinedLocal.length - pendingOrders.length) < totalLocalCount;

        emit(state.copyWith(
          loading: false,
          isPaginationLoading: false,
          ordersList: combinedLocal,
          page: currentPage + 1,
          hasMore: hasMoreLocal || await _hasInternet(),
          schoolClassesWithSections: localClasses.isNotEmpty ? localClasses : state.schoolClassesWithSections,
        ));

        if (isLoadMore && localOrders.length == perPage) return;
        if (!await _hasInternet()) return;
      }

      if (!await _hasInternet()) {
        emit(state.copyWith(loading: false, isPaginationLoading: false));
        return;
      }

      String url = '${Config.baseUrl}auth/school/$schoolId/orders?page=$currentPage&per_page=$perPage';
      if (search.isNotEmpty) url += '&search=$search';
      if (status.isNotEmpty) url += '&status=$status';
      if (classFilter.isNotEmpty) url += '&class_filters=$classFilter';
      if (dateFrom.isNotEmpty) url += '&start_date=$dateFrom';
      if (dateTo.isNotEmpty) url += '&end_date=$dateTo';

      var response = await _api.getRequest(url);

      if (response != null && response.statusCode == 403) {
        String partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/orders?page=$currentPage&per_page=$perPage';
        if (search.isNotEmpty) partnerUrl += '&search=$search';
        if (status.isNotEmpty) partnerUrl += '&status=$status';
        if (classFilter.isNotEmpty) partnerUrl += '&class_filters=$classFilter';
        if (dateFrom.isNotEmpty) partnerUrl += '&start_date=$dateFrom';
        if (dateTo.isNotEmpty) partnerUrl += '&end_date=$dateTo';
        response = await _api.getRequest(partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(loading: false, isPaginationLoading: false, error: 'Failed to load orders'));
        return;
      }

      final json = jsonDecode(response.body);
      final data = json['data'] as Map<String, dynamic>?;
      if (data == null) {
        emit(state.copyWith(loading: false, isPaginationLoading: false, error: 'Invalid response'));
        return;
      }

      final ordersData = data['orders'] ?? data;
      final List rawList = ordersData['data'] ?? [];
      final int total = int.tryParse(ordersData['total']?.toString() ?? '0') ?? 0;
      final int lastPage = int.tryParse(ordersData['last_page']?.toString() ?? '1') ?? 1;
      final int respPage = int.tryParse(ordersData['current_page']?.toString() ?? '1') ?? 1;

      final apiOrders = rawList.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();

      // Cache fresh orders
      if (!isLoadMore && search.isEmpty && status.isEmpty && classFilter.isEmpty && dateFrom.isEmpty) {
        await _orderLocalDS.clearForSchool(schoolId);
      }
      await _orderLocalDS.insertOrders(apiOrders, schoolId);

      final List<OrderModel> updatedList =
          isLoadMore ? [...state.ordersList, ...apiOrders] : [...pendingOrders, ...apiOrders];

      // Extract classes_with_sections for dropdown (only on first page)
      List<SchoolOrderClass> classesWithSections = state.schoolClassesWithSections;
      if (!isLoadMore && data['classes_with_sections'] != null) {
        final List rawClasses = data['classes_with_sections'] as List;
        classesWithSections = rawClasses
            .map((e) => SchoolOrderClass(value: e['value'] ?? '', label: e['label'] ?? ''))
            .toList();
        await _orderLocalDS.saveSchoolClasses(schoolId, classesWithSections);
      }

      emit(state.copyWith(
        loading: false,
        isPaginationLoading: false,
        ordersList: updatedList,
        page: respPage + 1,
        hasMore: respPage < lastPage,
        total: total + pendingOrders.length,
        schoolClassesWithSections: classesWithSections,
      ));
    } catch (e) {
      print('fetchSchoolOrders error: $e');
      emit(state.copyWith(loading: false, isPaginationLoading: false, error: e.toString()));
    }
  }

  Future<void> fetchOrders({
    bool isLoadMore = false,
    String search = '',
    String status = '',
    String classId = '',
    String dateFrom = '',
    String dateTo = '',
    String schoolId = '',
    bool isSchool = false,
  }) async {
    if (isLoadMore && (state.isPaginationLoading || !state.hasMore)) return;

    const int perPage = 50;
    final currentPage = isLoadMore ? state.page : 1;
    final int offset = (currentPage - 1) * perPage;

    if (!isLoadMore) {
      emit(state.copyWith(
        loading: true,
        isPaginationLoading: false,
        page: 1,
        ordersList: [],
        hasMore: true,
        clearError: true,
        schoolId: schoolId,
      ));
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    try {
      // 1. Fetch pending orders from local DB (only if schoolId is specified)
      List<OrderModel> pendingOrders = [];
      if (schoolId.isNotEmpty) {
        final pendingRaw = await _localDS.getAllPendingOrders(schoolId: schoolId);
        pendingOrders = pendingRaw.map((e) {
          final orderJson = jsonDecode(e['order_json']);
          return OrderModel.fromJson(orderJson);
        }).toList();
      }

      // 2. Fetch cached school classes if schoolId is provided
      List<SchoolOrderClass> localClasses = [];
      if (schoolId.isNotEmpty) {
        localClasses = await _orderLocalDS.getSchoolClasses(schoolId);
      }

      // 3. Fetch cached regular orders from local DB
      final localOrders = await _orderLocalDS.getOrders(
        schoolId: schoolId.isNotEmpty ? schoolId : "0", // 0 for global if needed, or handle separately
        search: search,
        status: status,
        classFilter: classId,
        startDate: dateFrom,
        endDate: dateTo,
        limit: perPage,
        offset: offset,
      );

      final totalLocalCount = await _orderLocalDS.getCount(
        schoolId: schoolId.isNotEmpty ? schoolId : "0",
        search: search,
        status: status,
        classFilter: classId,
        startDate: dateFrom,
        endDate: dateTo,
      );

      if (localOrders.isNotEmpty || pendingOrders.isNotEmpty || localClasses.isNotEmpty) {
        final List<OrderModel> combinedLocal = isLoadMore
            ? [...state.ordersList, ...localOrders]
            : [...pendingOrders, ...localOrders];

        bool hasMoreLocal = (combinedLocal.length - pendingOrders.length) < totalLocalCount;

        emit(state.copyWith(
          loading: false,
          isPaginationLoading: false,
          ordersList: combinedLocal,
          page: currentPage + 1,
          hasMore: hasMoreLocal || await _hasInternet(),
          schoolClassesWithSections: localClasses.isNotEmpty ? localClasses : state.schoolClassesWithSections,
        ));

        if (isLoadMore && localOrders.length == perPage) return;
        if (!await _hasInternet()) return;
      }

      if (!await _hasInternet()) {
        if (!isLoadMore && localOrders.isEmpty && pendingOrders.isEmpty) {
          emit(state.copyWith(loading: false, isPaginationLoading: false, error: 'No internet connection'));
        } else {
          emit(state.copyWith(loading: false, isPaginationLoading: false));
        }
        return;
      }

      String url;
      if (schoolId.isNotEmpty) {
        url = '${Config.baseUrl}auth/partner/orders?page=$currentPage&per_page=$perPage&school_id=$schoolId';
      } else {
        url = '${Config.baseUrl}auth/partner/orders?page=$currentPage&per_page=$perPage';
      }
      if (status.isNotEmpty) url += '&status=$status';
      if (search.isNotEmpty) url += '&search=$search';
      if (dateFrom.isNotEmpty) url += '&start_date=$dateFrom';
      if (dateTo.isNotEmpty) url += '&end_date=$dateTo';

      var response = await _api.getRequest(url);

      if (response == null) {
        emit(state.copyWith(loading: false, isPaginationLoading: false, error: 'Failed to load orders'));
        return;
      }

      final json = jsonDecode(response.body);
      final List rawList = json['data']?['data'] ?? [];
      final int total = int.tryParse(json['data']?['total']?.toString() ?? '0') ?? 0;
      final int lastPage = int.tryParse(json['data']?['last_page']?.toString() ?? '1') ?? 1;
      final int respPage = int.tryParse(json['data']?['current_page']?.toString() ?? '1') ?? 1;

      final apiOrders =
          rawList.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();

      // Cache fresh orders
      if (!isLoadMore && search.isEmpty && status.isEmpty && dateFrom.isEmpty) {
        if (schoolId.isNotEmpty) await _orderLocalDS.clearForSchool(schoolId);
      }
      await _orderLocalDS.insertOrders(apiOrders, schoolId.isNotEmpty ? schoolId : "0");

      final List<OrderModel> updatedList =
          isLoadMore ? [...state.ordersList, ...apiOrders] : [...pendingOrders, ...apiOrders];

      emit(state.copyWith(
        loading: false,
        isPaginationLoading: false,
        ordersList: updatedList,
        page: respPage + 1,
        hasMore: respPage < lastPage,
        total: total + pendingOrders.length,
      ));
    } catch (e) {
      print('fetchOrders error: $e');
      emit(state.copyWith(loading: false, isPaginationLoading: false, error: e.toString()));
    }
  }

  // ─── Update order status

  Future<bool> updateOrderStatus(String uuid, String newStatus, {String schoolId = '', bool isSchool = false}) async {
    try {
      bool hasInternet = await _hasInternet();

      if (!hasInternet) {
        final school = await UserLocal.getSchool();
        final effectiveSchoolId = schoolId.isNotEmpty ? schoolId : (school['schoolId'] ?? '').toString();

        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: effectiveSchoolId,
          uuids: [uuid],
          status: newStatus,
        );

        // Update state immediately
        final updatedOrders = state.ordersList.map((o) {
          if (o.uuid == uuid) {
            final map = jsonDecode(jsonEncode(o));
            map['status'] = newStatus;
            return OrderModel.fromJson(map);
          }
          return o;
        }).toList();
        emit(state.copyWith(ordersList: updatedOrders));

        return true;
      }

      final url = '${Config.baseUrl}auth/partner/orders/$uuid/status';
      final response = await _api.patchRequestWithBody(url, {'status': newStatus});

      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        // Fallback to offline if server error or null response
        final school = await UserLocal.getSchool();
        final effectiveSchoolId = schoolId.isNotEmpty ? schoolId : (school['schoolId'] ?? '').toString();
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: effectiveSchoolId,
          uuids: [uuid],
          status: newStatus,
        );
        return true;
      }

      final json = jsonDecode(response.body);
      if (json['success'] == true) return true;

      return false;
    } catch (e) {
      print('updateOrderStatus error: $e');
      // On any exception (Timeout, FormatException, etc.), fallback to offline
      try {
        final school = await UserLocal.getSchool();
        final effectiveSchoolId = schoolId.isNotEmpty ? schoolId : (school['schoolId'] ?? '').toString();
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: effectiveSchoolId,
          uuids: [uuid],
          status: newStatus,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ─── Order selection for bulk status update ──────────────────────────────
  void toggleOrderSelection(String uuid) {
    final current = Set<String>.from(state.selectedOrderUuids);
    if (current.contains(uuid)) {
      current.remove(uuid);
    } else {
      current.add(uuid);
    }
    emit(state.copyWith(selectedOrderUuids: current));
  }

  void selectAllOrders() {
    final all = state.ordersList.map((o) => o.uuid).toSet();
    emit(state.copyWith(selectedOrderUuids: all));
  }

  void clearOrderSelection() {
    emit(state.copyWith(selectedOrderUuids: {}));
  }

  // ─── Bulk update order status (school-scoped API) ─────────────────────────
  Future<bool> bulkUpdateOrderStatus({
    required String schoolId,
    required List<String> uuids,
    required String status,
    String issueNote = '',
  }) async {
    try {
      bool hasInternet = await _hasInternet();

      if (!hasInternet) {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: status,
          issueNote: issueNote,
        );

        // Update state immediately
        final updatedOrders = state.ordersList.map((o) {
          if (uuids.contains(o.uuid)) {
            final map = jsonDecode(jsonEncode(o));
            map['status'] = status;
            return OrderModel.fromJson(map);
          }
          return o;
        }).toList();
        emit(state.copyWith(ordersList: updatedOrders));

        return true;
      }

      final url = '${Config.baseUrl}auth/school/$schoolId/orders/status';
      final statusBody = <String, dynamic>{'status': status};
      if (issueNote.isNotEmpty) statusBody['issueNote'] = issueNote;
      final body = <String, dynamic>{'uuids': uuids, 'status': statusBody};

      final response = await _api.patchRequestWithBody(url, body);

      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: status,
          issueNote: issueNote,
        );
        return true;
      }

      final json = jsonDecode(response.body);
      return json['success'] == true;
    } catch (e) {
      print('bulkUpdateOrderStatus error: $e');
      try {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: status,
          issueNote: issueNote,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  // ─── Re-Order with printing_issue status (school-scoped bulk API)
  Future<bool> reOrderWithPrintingIssue({
    required String schoolId,
    required List<String> uuids,
    String issueNote = '',
  }) async {
    try {
      bool hasInternet = await _hasInternet();

      if (!hasInternet) {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: 'printing_issue',
          issueNote: issueNote,
        );

        // Update state immediately
        final updatedOrders = state.ordersList.map((o) {
          if (uuids.contains(o.uuid)) {
            final map = jsonDecode(jsonEncode(o));
            map['status'] = 'printing_issue';
            return OrderModel.fromJson(map);
          }
          return o;
        }).toList();
        emit(state.copyWith(ordersList: updatedOrders));

        return true;
      }

      final url = '${Config.baseUrl}auth/school/$schoolId/orders/status';
      final body = <String, dynamic>{
        'uuids': uuids,
        'status': {
          'status': 'printing_issue',
          if (issueNote.isNotEmpty) 'issueNote': issueNote,
        },
      };

      final response = await _api.patchRequestWithBody(url, body);

      if (response == null || response.statusCode < 200 || response.statusCode >= 300) {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: 'printing_issue',
          issueNote: issueNote,
        );
        return true;
      }

      final json = jsonDecode(response.body);
      return json['success'] == true;
    } catch (e) {
      try {
        await _orderLocalDS.savePendingStatusUpdate(
          schoolId: schoolId,
          uuids: uuids,
          status: 'printing_issue',
          issueNote: issueNote,
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<void> syncPendingStatusUpdates() async {
    if (!await _hasInternet()) return;

    final pending = await _orderLocalDS.getAllPendingStatusUpdates();
    if (pending.isEmpty) return;


    for (var item in pending) {
      try {
        final schoolId = item['school_id'];
        final uuids = List<String>.from(jsonDecode(item['uuids_json'] ?? '[]'));
        final status = item['status'];
        final issueNote = item['issue_note'] ?? '';

        final url = '${Config.baseUrl}auth/school/$schoolId/orders/status';
        final statusBody = <String, dynamic>{'status': status};
        if (issueNote.isNotEmpty) statusBody['issueNote'] = issueNote;
        final body = <String, dynamic>{'uuids': uuids, 'status': statusBody};

        final response = await _api.patchRequestWithBody(url, body);
        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _orderLocalDS.deletePendingStatusUpdate(item['id']);
            print("Successfully pending status: ${item['id']}");
          }
        }
      } catch (e) {
        print("Error syncing pending status update: $e");
      }
    }

    // Refresh orders after sync
    final school = await UserLocal.getSchool();
    final currentSchoolId = school['schoolId'];
    if (currentSchoolId != null && currentSchoolId.isNotEmpty) {
      fetchSchoolOrders(schoolId: currentSchoolId);
    }
  }



  Future<void> syncPendingOrders() async {
    if (!await _hasInternet()) return;

    final pendingChecklists = await _localDS.getAllPendingChecklists();
    if (pendingChecklists.isNotEmpty) {
      print("OrdersCubit: Pending checklists found, waiting 6s for checklist sync to finish...");
      await Future.delayed(const Duration(seconds: 6));
      final stillPending = await _localDS.getAllPendingChecklists();
      if (stillPending.isNotEmpty) {
        print("OrdersCubit: Checklists still pending after wait, deferring order sync");
        return;
      }
    }

    final pending = await _localDS.getAllPendingOrders();
    if (pending.isEmpty) return;

    print("OrdersCubit: Syncing ${pending.length} pending orders...");
    bool anySynced = false;

    for (var item in pending) {
      try {
        final schoolId = item['school_id'];
        final cardType = item['card_type'];
        final cardFor = List<String>.from(jsonDecode(item['card_for_json'] ?? '[]'));
        var cardUsers = List<String>.from(jsonDecode(item['card_users_json'] ?? '[]'));

        // Resolve student UUIDs → correction list item UUIDs using local DB
        try {
          final correctionStudents = await _localDS.getCorrectionStudents(schoolId: schoolId);
          final Map<String, String> studentToItemUuid = {};
          for (final s in correctionStudents) {
            if (s.student?.uuid != null && s.uuid != null && s.uuid!.trim().isNotEmpty) {
              studentToItemUuid[s.student!.uuid!.trim()] = s.uuid!.trim();
            }
          }
          if (studentToItemUuid.isNotEmpty) {
            cardUsers = cardUsers.map((uuid) => studentToItemUuid[uuid] ?? uuid).toList();
          }
        } catch (_) {}

        final String url = '${Config.baseUrl}auth/school/$schoolId/orders';
        final Map<String, dynamic> body = {
          "card_users": cardUsers,
          "card_type": cardType,
          "student_card": cardFor.contains('student_card') ? 1 : 0,
          "parent_card": cardFor.contains('parent_card') ? 1 : 0,
          "admit_card": cardFor.contains('admit_card') ? 1 : 0,
        };

        var response = await _api.postRequest(body, url);

        // 403 fallback to partner URL
        if (response != null && response.statusCode == 403) {
          final partnerUrl = '${Config.baseUrl}auth/partner/school/$schoolId/orders';
          response = await _api.postRequest(body, partnerUrl);
        }

        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _localDS.deletePendingOrder(item['id']);
            anySynced = true;
          } else {
            // Server rejected — invalid UUID or data, delete so it doesn't block forever
            await _localDS.deletePendingOrder(item['id']);
            anySynced = true;
          }
        } else if (response != null && (response.statusCode == 422 || response.statusCode == 400 || response.statusCode == 500)) {
          // Permanent server rejection — delete to prevent infinite retry
          await _localDS.deletePendingOrder(item['id']);
          anySynced = true;
        } else {
        }
      } catch (e) {
      }
    }

    if (anySynced) {
      final updatedOrders = state.ordersList
          .where((o) => !o.uuid.startsWith('offline_'))
          .toList();
      if (updatedOrders.length != state.ordersList.length) {
        emit(state.copyWith(ordersList: updatedOrders));
      }
      // Refresh from server using the school endpoint (matches what the UI loaded)
      if (state.schoolId.isNotEmpty) {
        fetchSchoolOrders(schoolId: state.schoolId);
      }
    }
  }

  Future<void> fetchStaffOrdersTotal({required String schoolId}) async {
    if (schoolId.isEmpty) return;
    emit(state.copyWith(staffTotalLoading: true));
    try {
      final url = '${Config.baseUrl}auth/school/$schoolId/staff/orders?page=1&per_page=1';
      print('fetchStaffOrdersTotal URL: $url');
      final response = await _api.getRequest(url);
      if (response == null) {
        emit(state.copyWith(staffTotalLoading: false));
        return;
      }
      print('fetchStaffOrdersTotal status: ${response.statusCode}, body: ${response.body}');
      final json = jsonDecode(response.body);
      final data = json['data'] as Map<String, dynamic>?;
      int total = 0;
      if (data != null) {
        if (data['list'] is Map) {
          final listData = data['list'] as Map<String, dynamic>;
          total = listData['total'] ?? 0;
        }
        else if (data['orders'] is List) {
          final pagination = data['pagination'] as Map<String, dynamic>?;
          total = pagination?['total'] ?? (data['orders'] as List).length;
        }
        else if (data['orders'] is Map) {
          final ordersData = data['orders'] as Map<String, dynamic>;
          total = ordersData['total'] ?? 0;
        }
        else if (data['total'] != null) {
          total = data['total'] ?? 0;
        }
      }
      emit(state.copyWith(staffTotalLoading: false, staffTotal: total));
    } catch (e) {
      print('fetchStaffOrdersTotal error: $e');
      emit(state.copyWith(staffTotalLoading: false));
    }
  }
}
