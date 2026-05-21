import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/models/holidays/HolidayModel.dart';
import 'package:idmitra/providers/holidays/holidays_state.dart';

class HolidaysCubit extends Cubit<HolidaysState> {
  HolidaysCubit() : super(const HolidaysState());

  final ApiManager _api = ApiManager();

  Future<void> fetchHolidays({
    required String schoolId,
    int? year,
    String search = '',
  }) async {
    emit(state.copyWith(loading: true, holidays: [], clearError: true));

    try {
      String url = '${Config.baseUrl}auth/school/$schoolId/holidays?per_page=100';
      if (year != null) url += '&year=$year';
      if (search.isNotEmpty) url += '&search=$search';

      final response = await _api.getRequest(url);

      if (response == null) {
        emit(state.copyWith(loading: false, error: 'Failed to load holidays'));
        return;
      }

      final json = jsonDecode(response.body);
      if (json['success'] != true) {
        emit(state.copyWith(loading: false, error: json['message'] ?? 'Something went wrong'));
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      final listPage = data?['list'] as Map<String, dynamic>?;
      final List rawList = listPage?['data'] ?? [];
      final int total = listPage?['total'] ?? rawList.length;

      final items = rawList
          .map((e) => HolidayModel.fromJson(e as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(loading: false, holidays: items, total: total));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<String?> addHoliday({
    required String schoolId,
    required String name,
    required List<String> dates,
    required String type,
    String description = '',
  }) async {
    emit(state.copyWith(actionLoading: true, clearActionError: true));
    try {
      final url = '${Config.baseUrl}auth/school/$schoolId/holidays';
      final body = <String, dynamic>{
        'name': name,
        'dates': dates,
        'extra': {'type': type},
      };
      if (description.isNotEmpty) body['description'] = description;

      final response = await _api.postRequest(body, url);

      if (response == null) {
        emit(state.copyWith(actionLoading: false, actionError: 'Failed to add holiday'));
        return 'Failed to add holiday';
      }

      final json = jsonDecode(response.body);
      print(' Add Holiday Response: ${response.statusCode} — ${response.body}');

      if (json['success'] == true) {
        emit(state.copyWith(actionLoading: false));
        return null; // success
      } else {
        final msg = json['message'] ?? 'Failed to add holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }

  Future<String?> deleteHoliday({
    required String schoolId,
    required int holidayId,
  }) async {
    emit(state.copyWith(actionLoading: true, clearActionError: true));
    try {
      final url = '${Config.baseUrl}auth/school/$schoolId/holidays/$holidayId';
      final result = await _api.deleteRequest(url);

      print('Delete Holiday: ${result.statusCode} — ${result.message}');

      final isSuccess = result.statusCode == 200 || result.statusCode == 201 ||
          (result.data != null && result.data['success'] == true);

      if (isSuccess) {
        final updated = state.holidays.where((h) => h.id != holidayId).toList();
        emit(state.copyWith(actionLoading: false, holidays: updated, total: updated.length));
        return null;
      } else {
        final msg = result.message.isNotEmpty ? result.message : 'Failed to delete holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }

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
      final url = '${Config.baseUrl}auth/school/$schoolId/holidays/$holidayId';
      final body = <String, dynamic>{
        'name': name,
        'dates': dates,
        'extra': {'type': type},
      };
      if (description.isNotEmpty) body['description'] = description;

      final response = await _api.putRequestWithBody(url, body);

      if (response == null) {
        emit(state.copyWith(actionLoading: false, actionError: 'Failed to update holiday'));
        return 'Failed to update holiday';
      }

      final json = jsonDecode(response.body);
      print('Update Holiday Response: ${response.statusCode} — ${response.body}');

      if (json['success'] == true) {
        emit(state.copyWith(actionLoading: false));
        return null;
      } else {
        final msg = json['message'] ?? 'Failed to update holiday';
        emit(state.copyWith(actionLoading: false, actionError: msg));
        return msg;
      }
    } catch (e) {
      emit(state.copyWith(actionLoading: false, actionError: e.toString()));
      return e.toString();
    }
  }
}
