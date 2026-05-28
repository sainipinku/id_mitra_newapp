import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/providers/school/school_state.dart';
import 'package:sqflite/sqflite.dart';

const _kSchoolsKey = 'schools_list';

class SchoolCubit extends Cubit<SchoolState> {
  SchoolCubit() : super(SchoolState());

  ApiManager apiManager = ApiManager();

  // ─── LOCAL DB ────────
  Future<void> loadSchoolsData() async {
    await fetchStudents(
      isLoadMore: false,
      search: '',
    );
  }

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
      //   print('SchoolCubit saved to local DB: $key');
    } catch (e) {
      print('SchoolCubit local save error: $e');
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
      //   print('SchoolCubit loaded from local DB: $key');
      return data;
    } catch (e) {
      print('SchoolCubit local load error: $e');
      return null;
    }
  }

  String _cacheKey({int page = 1, String search = ''}) =>
      '${_kSchoolsKey}_page_${page}_search_$search';

  // ─── MAIN FETCH ─

  Future<void> fetchStudents({
    bool isLoadMore = false,
    String search = '',
  }) async {
    // 🔴 Prevent duplicate calls
    if (state.isPaginationLoading || (!state.hasMore && isLoadMore)) return;

    final int currentPage = isLoadMore ? state.page : 1;
    final bool isFirstPage = !isLoadMore && currentPage == 1;
    final bool isCacheable = isFirstPage && search.isEmpty;

    // ── RESET state on fresh load ─────
    if (!isLoadMore) {
      emit(state.copyWith(
        loading: true,
        page: 1,
        students: [],
        hasMore: true,
        error: null,
      ));
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    // ── Step 1: Load from local DB (only page-1, no search) ─
    if (isCacheable) {
      final localData = await _loadFromLocal(_cacheKey());
      if (localData != null) {
        final parsed = _parseSchoolsFromJson(localData);
        if (parsed.isNotEmpty) {
          final total = localData['data']?['schools']?['total'] ?? parsed.length;
          emit(state.copyWith(
            loading: false,
            students: parsed,
            page: 2,
            hasMore: parsed.length < total,
          ));
          print('SchoolCubit: loaded ${parsed.length} schools from local DB');

          // Step 2: Background sync — silently update cache then refresh UI
          _syncFromApi(
            page: 1,
            search: search,
            isCacheable: true,
            isLoadMore: false,
            emitStates: true,
          );
          return;
        }
      }
    }

    await _syncFromApi(
      page: currentPage,
      search: search,
      isCacheable: isCacheable,
      isLoadMore: isLoadMore,
      emitStates: true,
    );
  }

  Future<void> _syncFromApi({
    required int page,
    required String search,
    required bool isCacheable,
    required bool isLoadMore,
    required bool emitStates,
  }) async {
    try {
      if (!emitStates) emit(state.copyWith(isSyncing: true));

      final response = await apiManager.getRequest(
        '${Config.baseUrl}auth/partner/schools?page=$page&search=$search',
      );

      if (response == null) {
        print('SchoolCubit sync: no response — trying backup local DB');
        if (emitStates) {
          // Try loading from the `schools` table saved by backup sync
          final backupSchools = await _loadFromBackupTable(search: search);
          if (backupSchools.isNotEmpty) {
            emit(state.copyWith(
              loading: false,
              isSyncing: false,
              isPaginationLoading: false,
              students: backupSchools,
              hasMore: false,
              error: null,
            ));
            print('SchoolCubit: loaded ${backupSchools.length} schools from backup table');
          } else {
            emit(state.copyWith(
              loading: false,
              isSyncing: false,
              isPaginationLoading: false,
              error: 'No response from server',
            ));
          }
        } else {
          emit(state.copyWith(isSyncing: false));
        }
        return;
      }

      print('SchoolCubit sync status: ${response.statusCode}');

      if (response.statusCode == 401 || response.statusCode == 403) {
        if (emitStates) {
          emit(state.copyWith(
            loading: false,
            isSyncing: false,
            isPaginationLoading: false,
            error: 'Unauthorized',
          ));
        } else {
          emit(state.copyWith(isSyncing: false));
        }
        return;
      }

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<')) {
          if (emitStates) {
            emit(state.copyWith(
                loading: false,
                isSyncing: false,
                isPaginationLoading: false));
          } else {
            emit(state.copyWith(isSyncing: false));
          }
          return;
        }

        final jsonData = jsonDecode(body) as Map<String, dynamic>;

        if (jsonData['data'] == null || jsonData['data']['schools'] == null) {
          if (emitStates) {
            emit(state.copyWith(
              loading: false,
              isSyncing: false,
              isPaginationLoading: false,
              students: [],
              hasMore: false,
            ));
          } else {
            emit(state.copyWith(isSyncing: false));
          }
          return;
        }

        final newList = _parseSchoolsFromJson(jsonData);
        final total = jsonData['data']['schools']['total'] ?? 0;

        if (isCacheable) {
          await _saveToLocal(_cacheKey(), jsonData);
        }

        final List<SchoolDetailsModel> updatedList =
            isLoadMore ? [...state.students, ...newList] : newList;

        final bool hasMore = updatedList.length < total;

        print(
            'SchoolCubit synced — ${newList.length} schools, total: $total, page: $page');

        emit(state.copyWith(
          loading: false,
          isSyncing: false,
          isPaginationLoading: false,
          students: updatedList,
          page: page + 1,
          hasMore: hasMore,
        ));
      } else {
        if (emitStates) {
          emit(state.copyWith(
              loading: false, isSyncing: false, isPaginationLoading: false));
        } else {
          emit(state.copyWith(isSyncing: false));
        }
      }
    } catch (e) {
      print('SchoolCubit sync error: $e');
      if (emitStates) {
        emit(state.copyWith(
          loading: false,
          isSyncing: false,
          isPaginationLoading: false,
          error: e.toString(),
        ));
      } else {
        emit(state.copyWith(isSyncing: false));
      }
    }
  }

  List<SchoolDetailsModel> _parseSchoolsFromJson(Map<String, dynamic> jsonData) {
    final List list = jsonData['data']?['schools']?['data'] ?? [];
    final List<SchoolDetailsModel> result = [];

    for (final e in list) {
      try {
        result.add(SchoolDetailsModel.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        result.add(SchoolDetailsModel(
          id: e['id'],
          uuid: e['uuid']?.toString(),
          name: e['name']?.toString(),
          schoolPrefix: e['school_prefix']?.toString(),
          folderPrefix: e['folder_prefix']?.toString(),
          address: e['address']?.toString(),
          pincode: e['pincode']?.toString(),
          logoPhoto: e['logo_photo']?.toString(),
          logoUrl: e['logo_url']?.toString(),
          status: e['status'],
          partnerId: e['partner_id'],
          schoolAdminId: e['school_admin_id'],
          studentCount: e['student_count'],
          orderCount: e['order_count'],
          staffCount: e['staff_count'],
          countryId: e['country_id'],
          stateId: e['state_id'],
          cityId: e['city_id'],
          currentSession: e['current_session'],
          socialLinks: e['social_links'],
          deletedAt: e['deleted_at'],
          createdAt: e['created_at'] == null
              ? null
              : DateTime.tryParse(e['created_at']),
          updatedAt: e['updated_at'] == null
              ? null
              : DateTime.tryParse(e['updated_at']),
          studentFormFields: [],
          availableStudentFormFields: [],
        ));
      }
    }

    return result;
  }

  /// Update imageShape for a specific school after image settings are saved
  void updateSchoolImageShape(int schoolId, String imageShape) {
    final updated = state.students.map((s) {
      if (s.id == schoolId) return s.copyWith(imageShape: imageShape);
      return s;
    }).toList();
    final newMap = Map<int, String>.from(state.imageShapeMap)..[schoolId] =
        imageShape;
    emit(state.copyWith(students: updated, imageShapeMap: newMap));
  }

  /// Fetch image settings for a school and update imageShape in state
  Future<void> fetchAndApplyImageShape(int schoolId) async {
    try {
      final url =
          Config.baseUrl + Routes.updateImageSettings(schoolId.toString());
      final response = await apiManager.getRequest(url);
      if (response == null) return;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final shape = json["data"]?["image_shape"]?.toString();
        if (shape != null && shape.isNotEmpty) {
          updateSchoolImageShape(schoolId, shape);
        }
      }
    } catch (e) {
      debugPrint('fetchAndApplyImageShape error: $e');
    }
  }

  /// Load schools from the `schools` table populated by backup sync
  Future<List<SchoolDetailsModel>> _loadFromBackupTable({String search = ''}) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query('schools', orderBy: 'id DESC');
      final List<SchoolDetailsModel> result = [];
      for (final row in rows) {
        try {
          final map = jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
          final school = SchoolDetailsModel.fromJson(map);
          if (search.isEmpty ||
              (school.name ?? '').toLowerCase().contains(search.toLowerCase())) {
            result.add(school);
          }
        } catch (_) {}
      }
      return result;
    } catch (e) {
      print('SchoolCubit _loadFromBackupTable error: $e');
      return [];
    }
  }
}
