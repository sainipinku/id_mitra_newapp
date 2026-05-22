import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/models/attendance/AttendanceModel.dart';
import 'package:idmitra/providers/attendance/attendance_state.dart';

class AttendanceCubit extends Cubit<AttendanceState> {
  AttendanceCubit() : super(const AttendanceState());

  final ApiManager _api = ApiManager();

  Future<void> fetchAttendance({
    required String schoolId,
    int? classId,
    String? date,
  }) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      var url = '${Config.baseUrl}auth/school/$schoolId/attendance';
      final params = <String>[];
      if (classId != null && classId != 0) params.add('class_id=$classId');
      if (date != null && date.isNotEmpty) params.add('date=$date');
      if (params.isNotEmpty) url = '$url?${params.join('&')}';

      final response = await _api.getRequest(url);

      if (response == null) {
        emit(
          state.copyWith(loading: false, error: 'Failed to load attendance'),
        );
        return;
      }

      if (response.statusCode == 403) {
        emit(
          state.copyWith(
            loading: false,
            error:
            'Access denied. You do not have permission to view this class.',
          ),
        );
        return;
      }

      if (response.statusCode != 200) {
        emit(
          state.copyWith(
            loading: false,
            error: 'Server error (${response.statusCode})',
          ),
        );
        return;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        emit(
          state.copyWith(
            loading: false,
            error: json['message']?.toString() ?? 'Something went wrong',
          ),
        );
        return;
      }

      final result = AttendanceResponse.fromJson(json);

      // Ensure students are sorted alphabetically
      final sortedStudents = List<AttendanceStudent>.from(result.students);
      sortedStudents.sort((a, b) => (a.name ?? "").toLowerCase().compareTo((b.name ?? "").toLowerCase()));

      AttendanceClassItem? selected;
      if (result.classes.isNotEmpty) {
        try {
          selected = result.classes.firstWhere(
                (c) => c.id == result.selectedClassId,
          );
        } catch (_) {
          selected = result.classes.first;
        }
      }

      emit(
        state.copyWith(
          loading: false,
          classes: result.classes,
          selectedClass: selected,
          selectedDate: result.selectedDate.isNotEmpty
              ? result.selectedDate
              : date ?? _todayStr(),
          students: sortedStudents,
          stats: result.stats,
        ),
      );
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

    final presentCount = updated.where((s) => s.isPresent).length;
    final absentCount = updated.where((s) => s.isAbsent).length;
    final lateCount = updated.where((s) => s.isLate).length;
    final leaveCount = updated.where((s) => s.isLeave).length;
    final newStats = AttendanceStats(
      present: presentCount,
      absent: absentCount,
      late: lateCount,
      leave: leaveCount,
      total: state.stats.total,
    );

    emit(state.copyWith(students: updated, stats: newStats));

    try {
      final date = state.selectedDate.isNotEmpty
          ? state.selectedDate
          : _todayStr();
      final url = '${Config.baseUrl}auth/school/$schoolId/attendance/mark';
      final classId = state.selectedClass?.id ?? 0;
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
        }
      } else {
        print('--- toggleAttendance RESPONSE: null (network/server error) ---');
      }
    } catch (e) {
      print('--- toggleAttendance ERROR: $e ---');
    }
  }

  Future<void> _refreshStats(String schoolId) async {
    try {
      final classId = state.selectedClass?.id ?? 0;
      final date = state.selectedDate.isNotEmpty
          ? state.selectedDate
          : _todayStr();
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
    final allSelected = allIds.every(
          (id) => state.selectedStudentIds.contains(id),
    );
    emit(state.copyWith(selectedStudentIds: allSelected ? {} : allIds));
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
      final url = '${Config.baseUrl}auth/school/$schoolId/attendance/mark';

      final attendance = state.selectedStudentIds
          .map((id) => {'student_id': id, 'status': status})
          .toList();

      final body = {
        'date': date,
        'class_id': classId,
        'attendance': attendance,
      };

      print('--- bulkMarkAttendance REQUEST ---');
      print('URL : $url');
      print('Body: $body');

      final response = await _api.postRequest(body, url);

      if (response != null) {
        print('--- bulkMarkAttendance RESPONSE ---');
        print('Status Code : ${response.statusCode}');
        print('Body        : ${response.body}');
      } else {
        print('--- bulkMarkAttendance RESPONSE: null ---');
      }

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

      final presentCount = updated.where((s) => s.isPresent).length;
      final absentCount = updated.where((s) => s.isAbsent).length;
      final lateCount = updated.where((s) => s.isLate).length;
      final leaveCount = updated.where((s) => s.isLeave).length;
      final newStats = AttendanceStats(
        present: presentCount,
        absent: absentCount,
        late: lateCount,
        leave: leaveCount,
        total: state.stats.total,
      );

      emit(
        state.copyWith(
          bulkSubmitting: false,
          bulkMode: false,
          selectedStudentIds: {},
          students: updated,
          stats: newStats,
        ),
      );

      await _refreshStats(schoolId);
    } catch (e) {
      print('--- bulkMarkAttendance ERROR: $e ---');
      emit(state.copyWith(bulkSubmitting: false));
    }
  }
}
