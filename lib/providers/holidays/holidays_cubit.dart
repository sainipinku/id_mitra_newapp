import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/holiday_local_ds.dart';
import 'package:idmitra/models/holidays/HolidayModel.dart';
import 'package:idmitra/providers/holidays/holidays_state.dart';

class HolidaysCubit extends Cubit<HolidaysState> {
  StreamSubscription? _connectivitySubscription;
  String? _lastSchoolId;
  int? _lastYear;
  String _lastSearch = '';

  final ApiManager _api = ApiManager();
  final _localDS = HolidayLocalDS();

  HolidaysCubit() : super(const HolidaysState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;
      if (_lastSchoolId != null) {
        await syncPendingHolidays(schoolId: _lastSchoolId!);
        // Refresh from server after sync
        await fetchHolidays(
          schoolId: _lastSchoolId!,
          year: _lastYear,
          search: _lastSearch,
        );
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
      final c = await Connectivity().checkConnectivity();
      if (c.contains(ConnectivityResult.none) && c.length == 1) return false;
      final r = await InternetAddress.lookup('google.com');
      return r.isNotEmpty && r[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static int _currentYear() => DateTime.now().year;

  // ── SYNC ─────────────────────────────────────────────────────────────────

  Future<void> syncPendingHolidays({required String schoolId}) async {
    if (!await _hasInternet()) return;

    // 1. Sync pending adds
    final adds = await _localDS.getAllPendingAdds();
    for (final row in adds) {
      try {
        final rowId = row['id'] as int;
        final rowSchoolId = row['school_id'] as String? ?? schoolId;
        final name = row['name'] as String;
        final dates =
            (jsonDecode(row['dates_json'] as String) as List).cast<String>();
        final type = row['type'] as String;
        final description = row['description'] as String? ?? '';
        final tempHolidayId = -rowId;

        final url = '${Config.baseUrl}auth/school/$rowSchoolId/holidays';
        final body = <String, dynamic>{
          'name': name,
          'dates': dates,
          'extra': {'type': type},
          if (description.isNotEmpty) 'description': description,
        };
        final response = await _api.postRequest(body, url);
        if (response != null) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            // Replace temp holiday in cache with real one
            final realHoliday = json['data'] != null
                ? HolidayModel.fromJson(
                    json['data'] as Map<String, dynamic>)
                : null;
            final year = dates.isNotEmpty
                ? (DateTime.tryParse(dates.first)?.year ?? _currentYear())
                : _currentYear();

            if (realHoliday != null) {
              // Swap temp → real in state
              final updated = state.holidays.map((h) {
                return h.id == tempHolidayId ? realHoliday : h;
              }).toList();
              emit(state.copyWith(holidays: updated, total: updated.length));
              // Swap in cache
              await _localDS.removeHolidayFromCache(
                  rowSchoolId, year, tempHolidayId);
              await _localDS.upsertHolidayInCache(
                  rowSchoolId, year, realHoliday);
            } else {
              // Remove temp from cache; real data will come on next fetch
              await _localDS.removeHolidayFromCache(
                  rowSchoolId, year, tempHolidayId);
            }
            await _localDS.deletePendingAdd(rowId);
            debugPrint('Synced pending add holiday id=$rowId');
          }
        }
      } catch (e) {
        debugPrint('Failed to sync pending add holiday: $e');
      }
    }

    // 2. Sync pending updates (real IDs only — negative means it was added offline
    //    and already synced above, or we skip it)
    final updates = await _localDS.getAllPendingUpdates();
    for (final row in updates) {
      try {
        final rowId = row['id'] as int;
        final rowSchoolId = row['school_id'] as String? ?? schoolId;
        final holidayId = row['holiday_id'] as int;
        if (holidayId < 0) {
          // Offline-added holiday — skip; its pending add handles it
          await _localDS.deletePendingUpdate(rowId);
          continue;
        }
        final name = row['name'] as String;
        final dates =
            (jsonDecode(row['dates_json'] as String) as List).cast<String>();
        final type = row['type'] as String;
        final description = row['description'] as String? ?? '';

        final url =
            '${Config.baseUrl}auth/school/$rowSchoolId/holidays/$holidayId';
        final body = <String, dynamic>{
          'name': name,
          'dates': dates,
          'extra': {'type': type},
          if (description.isNotEmpty) 'description': description,
        };
        final response = await _api.putRequestWithBody(url, body);
        if (response != null) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _localDS.deletePendingUpdate(rowId);
            debugPrint('Synced pending update holiday id=$rowId');
          }
        }
      } catch (e) {
        debugPrint('Failed to sync pending update holiday: $e');
      }
    }

    // 3. Sync pending deletes (real positive IDs only)
    final deletes = await _localDS.getAllPendingDeletes();
    for (final row in deletes) {
      try {
        final rowId = row['id'] as int;
        final rowSchoolId = row['school_id'] as String? ?? schoolId;
        final holidayId = row['holiday_id'] as int;
        if (holidayId < 0) {
          // Was offline-added and offline-deleted — nothing to do on server
          await _localDS.deletePendingDelete(rowId);
          continue;
        }
        final url =
            '${Config.baseUrl}auth/school/$rowSchoolId/holidays/$holidayId';
        final result = await _api.deleteRequest(url);
        final isSuccess = result.statusCode == 200 ||
            result.statusCode == 201 ||
            (result.data != null && result.data['success'] == true);
        if (isSuccess) {
          await _localDS.deletePendingDelete(rowId);
          debugPrint('Synced pending delete holiday id=$rowId');
        }
      } catch (e) {
        debugPrint('Failed to sync pending delete holiday: $e');
      }
    }
  }

  // ── FETCH ─────────────────────────────────────────────────────────────────

  Future<void> fetchHolidays({
    required String schoolId,
    int? year,
    String search = '',
  }) async {
    _lastSchoolId = schoolId;
    _lastYear = year;
    _lastSearch = search;

    final effectiveYear = year ?? _currentYear();

    emit(state.copyWith(loading: true, holidays: [], clearError: true));

    try {
      // ── OFFLINE: load from cache ──
      if (!await _hasInternet()) {
        final cached =
            await _localDS.getHolidays(schoolId, effectiveYear, search);
        emit(state.copyWith(
          loading: false,
          holidays: cached,
          total: cached.length,
        ));
        return;
      }

      // ── ONLINE: fetch from API ──
      String url =
          '${Config.baseUrl}auth/school/$schoolId/holidays?per_page=100';
      if (year != null) url += '&year=$year';
      if (search.isNotEmpty) url += '&search=$search';

      final response = await _api.getRequest(url);

      if (response == null) {
        emit(state.copyWith(
            loading: false, error: 'Failed to load holidays'));
        return;
      }

      final json = jsonDecode(response.body);
      if (json['success'] != true) {
        emit(state.copyWith(
            loading: false,
            error: json['message'] ?? 'Something went wrong'));
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      final listPage = data?['list'] as Map<String, dynamic>?;
      final List rawList = listPage?['data'] ?? [];
      final int total = listPage?['total'] ?? rawList.length;

      final items = rawList
          .map((e) => HolidayModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Cache — only store unfiltered data (no search) to avoid stale partial cache
      if (search.isEmpty) {
        await _localDS.saveHolidays(schoolId, effectiveYear, items);
      }

      emit(state.copyWith(loading: false, holidays: items, total: total));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // ── ADD ───────────────────────────────────────────────────────────────────

  Future<String?> addHoliday({
    required String schoolId,
    required String name,
    required List<String> dates,
    required String type,
    String description = '',
  }) async {
    emit(state.copyWith(actionLoading: true, clearActionError: true));
    try {
      // ── OFFLINE ──
      if (!await _hasInternet()) {
        final pendingId = await _localDS.savePendingAdd(
          schoolId: schoolId,
          name: name,
          dates: dates,
          type: type,
          description: description,
        );
        final tempId = -pendingId; // negative = offline temp ID
        final year = dates.isNotEmpty
            ? (DateTime.tryParse(dates.first)?.year ?? _currentYear())
            : _currentYear();
        final tempHoliday = HolidayModel(
          id: tempId,
          name: name,
          dates: dates,
          type: type,
          year: year,
          description: description.isNotEmpty ? description : null,
          isActive: true,
        );
        // Add to cache
        await _localDS.upsertHolidayInCache(schoolId, year, tempHoliday);
        // Update state immediately
        final updated = [tempHoliday, ...state.holidays];
        emit(state.copyWith(
          actionLoading: false,
          holidays: updated,
          total: updated.length,
        ));
        return null; // treated as success
      }

      // ── ONLINE ──
      final url = '${Config.baseUrl}auth/school/$schoolId/holidays';
      final body = <String, dynamic>{
        'name': name,
        'dates': dates,
        'extra': {'type': type},
      };
      if (description.isNotEmpty) body['description'] = description;

      final response = await _api.postRequest(body, url);

      if (response == null) {
        emit(state.copyWith(
            actionLoading: false,
            actionError: 'Failed to add holiday'));
        return 'Failed to add holiday';
      }

      final json = jsonDecode(response.body);
      print('Add Holiday Response: ${response.statusCode} — ${response.body}');

      if (json['success'] == true) {
        emit(state.copyWith(actionLoading: false));
        return null;
      } else {
        final msg = json['message'] ?? 'Failed to add holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(
          actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }

  // ── DELETE ────────────────────────────────────────────────────────────────

  Future<String?> deleteHoliday({
    required String schoolId,
    required int holidayId,
  }) async {
    emit(state.copyWith(actionLoading: true, clearActionError: true));
    try {
      // ── OFFLINE ──
      if (!await _hasInternet()) {
        if (holidayId < 0) {
          // Offline-added holiday — cancel the pending add instead
          await _localDS.deletePendingAdd(-holidayId);
        } else {
          // Real holiday — queue delete
          await _localDS.savePendingDelete(
              schoolId: schoolId, holidayId: holidayId);
        }
        // Remove from cache
        final h = state.holidays.firstWhere(
          (h) => h.id == holidayId,
          orElse: () => const HolidayModel(),
        );
        final year = h.year ??
            (h.dates.isNotEmpty
                ? (DateTime.tryParse(h.dates.first)?.year ?? _currentYear())
                : _currentYear());
        await _localDS.removeHolidayFromCache(schoolId, year, holidayId);
        // Update state
        final updated =
            state.holidays.where((h) => h.id != holidayId).toList();
        emit(state.copyWith(
          actionLoading: false,
          holidays: updated,
          total: updated.length,
        ));
        return null;
      }

      // ── ONLINE ──
      final url =
          '${Config.baseUrl}auth/school/$schoolId/holidays/$holidayId';
      final result = await _api.deleteRequest(url);

      print(
          'Delete Holiday: ${result.statusCode} — ${result.message}');

      final isSuccess = result.statusCode == 200 ||
          result.statusCode == 201 ||
          (result.data != null && result.data['success'] == true);

      if (isSuccess) {
        final updated =
            state.holidays.where((h) => h.id != holidayId).toList();
        emit(state.copyWith(
            actionLoading: false,
            holidays: updated,
            total: updated.length));
        // Update cache
        final h = state.holidays.firstWhere(
          (h) => h.id == holidayId,
          orElse: () => const HolidayModel(),
        );
        final year = h.year ??
            (h.dates.isNotEmpty
                ? (DateTime.tryParse(h.dates.first)?.year ?? _currentYear())
                : _currentYear());
        await _localDS.removeHolidayFromCache(schoolId, year, holidayId);
        return null;
      } else {
        final msg = result.message.isNotEmpty
            ? result.message
            : 'Failed to delete holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(
          actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }

  // ── UPDATE ────────────────────────────────────────────────────────────────

  Future<String?> updateHoliday({
    required String schoolId,
    required int holidayId,
    required String name,
    required List<String> dates,
    required String type,
    String description = '',
  }) async {
    emit(state.copyWith(actionLoading: true, clearActionError: true));
    try {
      final year = dates.isNotEmpty
          ? (DateTime.tryParse(dates.first)?.year ?? _currentYear())
          : _currentYear();

      // ── OFFLINE ──
      if (!await _hasInternet()) {
        if (holidayId < 0) {
          // Offline-added: update the pending_add row directly
          final pendingId = -holidayId;
          final db = await DBHelper.db;
          await db.update(
            'pending_add_holidays',
            {
              'name': name,
              'dates_json': jsonEncode(dates),
              'type': type,
              'description': description,
            },
            where: 'id = ?',
            whereArgs: [pendingId],
          );
        } else {
          await _localDS.savePendingUpdate(
            schoolId: schoolId,
            holidayId: holidayId,
            name: name,
            dates: dates,
            type: type,
            description: description,
          );
        }
        final updatedHoliday = HolidayModel(
          id: holidayId,
          name: name,
          dates: dates,
          type: type,
          year: year,
          description: description.isNotEmpty ? description : null,
          isActive: true,
        );
        await _localDS.upsertHolidayInCache(schoolId, year, updatedHoliday);
        final updated = state.holidays.map((h) {
          return h.id == holidayId ? updatedHoliday : h;
        }).toList();
        emit(state.copyWith(
          actionLoading: false,
          holidays: updated,
          total: updated.length,
        ));
        return null;
      }

      // ── ONLINE ──
      final url =
          '${Config.baseUrl}auth/school/$schoolId/holidays/$holidayId';
      final body = <String, dynamic>{
        'name': name,
        'dates': dates,
        'extra': {'type': type},
      };
      if (description.isNotEmpty) body['description'] = description;

      final response = await _api.putRequestWithBody(url, body);

      if (response == null) {
        emit(state.copyWith(
            actionLoading: false,
            actionError: 'Failed to update holiday'));
        return 'Failed to update holiday';
      }

      final json = jsonDecode(response.body);
      print(
          'Update Holiday Response: ${response.statusCode} — ${response.body}');

      if (json['success'] == true) {
        // Update cache with new data
        final updatedHoliday = HolidayModel(
          id: holidayId,
          name: name,
          dates: dates,
          type: type,
          year: year,
          description: description.isNotEmpty ? description : null,
          isActive: true,
        );
        await _localDS.upsertHolidayInCache(schoolId, year, updatedHoliday);
        emit(state.copyWith(actionLoading: false));
        return null;
      } else {
        final msg = json['message'] ?? 'Failed to update holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(
          actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }
}
