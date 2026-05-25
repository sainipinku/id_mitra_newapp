import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/local_db/attendance_local_ds.dart';
import 'package:idmitra/models/attendance/AttendanceModel.dart';
import 'package:idmitra/providers/attendance/attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  StreamSubscription? _connectivitySubscription;
  String? _lastSchoolId;

  final ApiManager _api = ApiManager();
  final _localDS = AttendanceLocalDS();

  AttendanceCubit() : super(const AttendanceState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;
      if (_lastSchoolId != null) {
        await syncPendingAttendance(schoolId: _lastSchoolId!);
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
          connectivity.length == 1) return false;
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> syncPendingAttendance({required String schoolId}) async {
    if (!await _hasInternet()) return;
    final pending = await _localDS.getAllPending();
    if (pending.isEmpty) return;
    debugPrint('Syncing ${pending.length} pending attendance marks...');
    for (final row in pending) {
      try {
        final rowId = row['id'] as int;
        final rowSchoolId = row['school_id'] as String? ?? schoolId;
        final classId = row['class_id'] as int;
        final date = row['date'] as String;
        final attendance =
            jsonDecode(row['attendance_json'] as String) as List;
        final url =
            '${Config.baseUrl}auth/school/$rowSchoolId/attendance/mark';
        final body = {
          'date': date,
          'class_id': classId,
          'attendance': attendance,
        };
        final response = await _api.postRequest(body, url);
        if (response != null &&
            (response.statusCode == 200 || response.statusCode == 201)) {
          await _localDS.deletePending(rowId);
          debugPrint('Synced pending attendance id=$rowId');
        }
      } catch (e) {
        debugPrint('Failed to sync pending attendance: $e');
      }
    }
  }

  Future<void> fetchAttendance({
    required String schoolId,
    int? classId,
    String? date,
  }) async {
    _lastSchoolId = schoolId;
    emit(state.copyWith(loading: true, clearError: true));

    final effectiveDate = date ?? _todayStr();
    final effectiveClassId = classId ?? 0;

    try {
      // ── OFFLINE: load from local DB cache ──
      if (!await _hasInternet()) {
        final cached = await _localDS.getAttendance(
          schoolId: schoolId,
          classId: effectiveClassId,
          date: effectiveDate,
        );

        if (cached != null) {
          final students =
              List<AttendanceStudent>.from(cached['students'] as List)
                ..sort((a, b) =>
                    a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          final classes =
              cached['classes'] as List<AttendanceClassItem>;
          final stats = cached['stats'] as AttendanceStats;

          AttendanceClassItem? selected;
          if (classes.isNotEmpty) {
            try {
              selected =
                  classes.firstWhere((c) => c.id == effectiveClassId);
            } catch (_) {
              selected = classes.first;
            }
          }

          emit(state.copyWith(
            loading: false,
            classes: classes,
            selectedClass: selected ?? state.selectedClass,
            selectedDate: effectiveDate,
            students: students,
            stats: stats,
          ));
        } else {
          // No cache for this class/date — show classes list from any cached entry
          final classes = await _localDS.getClasses(schoolId);
          emit(state.copyWith(
            loading: false,
            classes: classes.isNotEmpty ? classes : state.classes,
            selectedDate: effectiveDate,
            students: [],
            stats: const AttendanceStats(),
          ));
        }
        return;
      }

      // ── ONLINE: fetch from API ──
      var url = '${Config.baseUrl}auth/school/$schoolId/attendance';
      final params = <String>[];
      if (classId != null && classId != 0) params.add('class_id=$classId');
      if (date != null && date.isNotEmpty) params.add('date=$date');
      if (params.isNotEmpty) url = '$url?${params.join('&')}';

      final response = await _api.getRequest(url);

      if (response == null) {
        emit(state.copyWith(
            loading: false, error: 'Failed to load attendance'));
        return;
      }

      if (response.statusCode == 403) {
        emit(state.copyWith(
            loading: false,
            error:
                'Access denied. You do not have permission to view this class.'));
        return;
      }

      if (response.statusCode != 200) {
        emit(state.copyWith(
            loading: false,
            error: 'Server error (${response.statusCode})'));
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        emit(state.copyWith(
            loading: false,
            error: json['message']?.toString() ?? 'Something went wrong'));
        return;
      }

      final result = AttendanceResponse.fromJson(json);
      final sortedStudents = List<AttendanceStudent>.from(result.students)
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      AttendanceClassItem? selected;
      if (result.classes.isNotEmpty) {
        try {
          selected = result.classes
              .firstWhere((c) => c.id == result.selectedClassId);
        } catch (_) {
          selected = result.classes.first;
        }
      }

      // Cache to local DB
      await _localDS.saveAttendance(
        schoolId: schoolId,
        classId: result.selectedClassId,
        date: result.selectedDate.isNotEmpty
            ? result.selectedDate
            : effectiveDate,
        classes: result.classes,
        students: sortedStudents,
        stats: result.stats,
      );

      emit(state.copyWith(
        loading: false,
        classes: result.classes,
        selectedClass: selected,
        selectedDate: result.selectedDate.isNotEmpty
            ? result.selectedDate
            : effectiveDate,
        students: sortedStudents,
        stats: result.stats,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> selectClassAndFetch({
    required String schoolId,
    required AttendanceClassItem cls,
    required String date,
  }) async {
    emit(state.copyWith(selectedClass: cls, selectedDate: date));
    await fetchAttendance(schoolId: schoolId, classId: cls.id, date: date);
  }

  Future<void> toggleAttendance({
    required String schoolId,
    required int studentId,
  }) async {
    final idx = state.students.indexWhere((s) => s.id == studentId);
    if (idx == -1) return;

    final student = state.students[idx];
    final newStatus = student.isPresent ? 'absent' : 'present';

    // Optimistic UI update
    final updated = List<AttendanceStudent>.from(state.students);
    updated[idx] = AttendanceStudent(
      id: student.id,
      name: student.name,
      rollNo: student.rollNo,
      fatherName: student.fatherName,
      motherName: student.motherName,
      photo: student.photo,
      section: student.section,
      className: student.className,
      status: newStatus,
    );

    final newStats = _computeStats(updated, state.stats.total);
    emit(state.copyWith(students: updated, stats: newStats));

    final date =
        state.selectedDate.isNotEmpty ? state.selectedDate : _todayStr();
    final classId = state.selectedClass?.id ?? 0;

    // ── OFFLINE: save to pending + update cache ──
    if (!await _hasInternet()) {
      await _localDS.updateCachedStudentStatus(
        schoolId: schoolId,
        classId: classId,
        date: date,
        studentId: studentId,
        status: newStatus,
      );
      await _localDS.savePendingMark(
        schoolId: schoolId,
        classId: classId,
        date: date,
        attendance: [
          {'student_id': studentId, 'status': newStatus}
        ],
      );
      return;
    }

    // ── ONLINE: call API ──
    try {
      final url =
          '${Config.baseUrl}auth/school/$schoolId/attendance/mark';
      final body = {
        'student_id': studentId,
        'class_id': classId,
        'status': newStatus,
        'date': date,
      };

      print('--- toggleAttendance REQUEST ---');
      print('URL : $url');
      print('Body: $body');

      final response = await _api.postRequest(body, url);

      if (response != null) {
        print('--- toggleAttendance RESPONSE ---');
        print('Status Code : ${response.statusCode}');
        print('Body        : ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          await _refreshStats(schoolId);
          // Update the DB cache with the new status
          await _localDS.updateCachedStudentStatus(
            schoolId: schoolId,
            classId: classId,
            date: date,
            studentId: studentId,
            status: newStatus,
          );
        }
      } else {
        print(
            '--- toggleAttendance RESPONSE: null (network/server error) ---');
      }
    } catch (e) {
      print('--- toggleAttendance ERROR: $e ---');
    }
  }

  Future<void> _refreshStats(String schoolId) async {
    try {
      final classId = state.selectedClass?.id ?? 0;
      final date =
          state.selectedDate.isNotEmpty ? state.selectedDate : _todayStr();
      if (classId == 0) return;

      final url =
          '${Config.baseUrl}auth/school/$schoolId/attendance/stats?class_id=$classId&date=$date';
      final response = await _api.getRequest(url);

      if (response == null || response.statusCode != 200) return;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) return;

      final data = json['data'] as Map<String, dynamic>? ?? {};
      final newStats = AttendanceStats.fromJson(data);
      emit(state.copyWith(stats: newStats));
    } catch (_) {}
  }

  static String _todayStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  void toggleBulkMode() {
    emit(state.copyWith(bulkMode: !state.bulkMode, selectedStudentIds: {}));
  }

  void toggleStudentSelection(int studentId) {
    final updated = Set<int>.from(state.selectedStudentIds);
    if (updated.contains(studentId)) {
      updated.remove(studentId);
    } else {
      updated.add(studentId);
    }
    emit(state.copyWith(selectedStudentIds: updated));
  }

  void selectAllStudents(List<AttendanceStudent> students) {
    final allIds = students.map((s) => s.id).toSet();
    final allSelected =
        allIds.every((id) => state.selectedStudentIds.contains(id));
    emit(state.copyWith(
        selectedStudentIds: allSelected ? {} : allIds));
  }

  Future<void> bulkMarkAttendance({
    required String schoolId,
    required String status,
  }) async {
    if (state.selectedStudentIds.isEmpty) return;

    emit(state.copyWith(bulkSubmitting: true));

    try {
      final date = state.selectedDate.isNotEmpty
          ? state.selectedDate
          : _todayStr();
      final classId = state.selectedClass?.id ?? 0;

      // Build updated student list
      final updated = state.students.map((s) {
        if (state.selectedStudentIds.contains(s.id)) {
          return AttendanceStudent(
            id: s.id,
            name: s.name,
            rollNo: s.rollNo,
            fatherName: s.fatherName,
            motherName: s.motherName,
            photo: s.photo,
            section: s.section,
            className: s.className,
            status: status,
          );
        }
        return s;
      }).toList();

      final newStats = _computeStats(updated, state.stats.total);

      // ── OFFLINE: save pending + update cache ──
      if (!await _hasInternet()) {
        final attendanceList = state.selectedStudentIds
            .map((id) => {'student_id': id, 'status': status})
            .toList();

        await _localDS.updateCachedBulkStatus(
          schoolId: schoolId,
          classId: classId,
          date: date,
          studentIds: Set.from(state.selectedStudentIds),
          status: status,
        );
        await _localDS.savePendingMark(
          schoolId: schoolId,
          classId: classId,
          date: date,
          attendance: attendanceList,
        );

        emit(state.copyWith(
          bulkSubmitting: false,
          bulkMode: false,
          selectedStudentIds: {},
          students: updated,
          stats: newStats,
        ));
        return;
      }

      // ── ONLINE: call API ──
      final url =
          '${Config.baseUrl}auth/school/$schoolId/attendance/mark';
      final attendanceList = state.selectedStudentIds
          .map((id) => {'student_id': id, 'status': status})
          .toList();

      final body = {
        'date': date,
        'class_id': classId,
        'attendance': attendanceList,
      };

      print('--- bulkMarkAttendance REQUEST ---');
      print('URL : $url');
      print('Body: $body');

      final response = await _api.postRequest(body, url);

      if (response != null) {
        print('--- bulkMarkAttendance RESPONSE ---');
        print('Status Code : ${response.statusCode}');
        print('Body        : ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          // Update cache with new statuses
          await _localDS.updateCachedBulkStatus(
            schoolId: schoolId,
            classId: classId,
            date: date,
            studentIds: Set.from(state.selectedStudentIds),
            status: status,
          );
        }
      } else {
        print('--- bulkMarkAttendance RESPONSE: null ---');
      }

      emit(state.copyWith(
        bulkSubmitting: false,
        bulkMode: false,
        selectedStudentIds: {},
        students: updated,
        stats: newStats,
      ));

      await _refreshStats(schoolId);
    } catch (e) {
      print('--- bulkMarkAttendance ERROR: $e ---');
      emit(state.copyWith(bulkSubmitting: false));
    }
  }

  AttendanceStats _computeStats(
      List<AttendanceStudent> students, int cachedTotal) {
    return AttendanceStats(
      present: students.where((s) => s.isPresent).length,
      absent: students.where((s) => s.isAbsent).length,
      late: students.where((s) => s.isLate).length,
      leave: students.where((s) => s.isLeave).length,
      total: cachedTotal > 0 ? cachedTotal : students.length,
    );
  }
}
