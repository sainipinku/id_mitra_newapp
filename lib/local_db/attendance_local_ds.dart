import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/attendance/AttendanceModel.dart';
import 'package:sqflite/sqflite.dart';

class AttendanceLocalDS {
  Future<void> saveAttendance({
    required String schoolId,
    required int classId,
    required String date,
    required List<AttendanceClassItem> classes,
    required List<AttendanceStudent> students,
    required AttendanceStats stats,
  }) async {
    final db = await DBHelper.db;
    final classesJson = jsonEncode(classes
        .map((c) => {
              'id': c.id,
              'name': c.name,
              'name_withprefix': c.nameWithprefix,
            })
        .toList());
    final studentsJson = jsonEncode(students
        .map((s) => {
              'id': s.id,
              'name': s.name,
              'roll_no': s.rollNo,
              'father_name': s.fatherName,
              'mother_name': s.motherName,
              'photo': s.photo,
              'section': s.section,
              'class_name': s.className,
              'status': s.status,
            })
        .toList());
    final statsJson = jsonEncode({
      'present': stats.present,
      'absent': stats.absent,
      'late': stats.late,
      'leave': stats.leave,
      'total': stats.total,
    });
    await db.insert(
      'attendance_cache',
      {
        'school_id': schoolId,
        'class_id': classId,
        'date': date,
        'classes_json': classesJson,
        'students_json': studentsJson,
        'stats_json': statsJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getAttendance({
    required String schoolId,
    required int classId,
    required String date,
  }) async {
    final db = await DBHelper.db;
    final rows = await db.query(
      'attendance_cache',
      where: 'school_id = ? AND class_id = ? AND date = ?',
      whereArgs: [schoolId, classId, date],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final classesJson =
        jsonDecode(row['classes_json'] as String) as List;
    final studentsJson =
        jsonDecode(row['students_json'] as String) as List;
    final statsJson =
        jsonDecode(row['stats_json'] as String) as Map<String, dynamic>;
    return {
      'classes': classesJson
          .map((e) =>
              AttendanceClassItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      'students': studentsJson
          .map((e) =>
              AttendanceStudent.fromJson(e as Map<String, dynamic>))
          .toList(),
      'stats': AttendanceStats.fromJson(statsJson),
    };
  }

  /// Returns the classes list from the most-recently cached attendance entry for this school.
  Future<List<AttendanceClassItem>> getClasses(String schoolId) async {
    final db = await DBHelper.db;
    final rows = await db.query(
      'attendance_cache',
      where: 'school_id = ?',
      whereArgs: [schoolId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) return [];
    final classesJson =
        jsonDecode(rows.first['classes_json'] as String) as List;
    return classesJson
        .map((e) =>
            AttendanceClassItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateCachedStudentStatus({
    required String schoolId,
    required int classId,
    required String date,
    required int studentId,
    required String status,
  }) async {
    final cached = await getAttendance(
        schoolId: schoolId, classId: classId, date: date);
    if (cached == null) return;
    final students =
        (cached['students'] as List<AttendanceStudent>).map((s) {
      if (s.id == studentId) {
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
    await saveAttendance(
      schoolId: schoolId,
      classId: classId,
      date: date,
      classes: cached['classes'] as List<AttendanceClassItem>,
      students: students,
      stats: _computeStats(
          students, (cached['stats'] as AttendanceStats).total),
    );
  }

  Future<void> updateCachedBulkStatus({
    required String schoolId,
    required int classId,
    required String date,
    required Set<int> studentIds,
    required String status,
  }) async {
    final cached = await getAttendance(
        schoolId: schoolId, classId: classId, date: date);
    if (cached == null) return;
    final students =
        (cached['students'] as List<AttendanceStudent>).map((s) {
      if (studentIds.contains(s.id)) {
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
    await saveAttendance(
      schoolId: schoolId,
      classId: classId,
      date: date,
      classes: cached['classes'] as List<AttendanceClassItem>,
      students: students,
      stats: _computeStats(
          students, (cached['stats'] as AttendanceStats).total),
    );
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

  Future<void> savePendingMark({
    required String schoolId,
    required int classId,
    required String date,
    required List<Map<String, dynamic>> attendance,
  }) async {
    final db = await DBHelper.db;
    await db.insert('pending_attendance', {
      'school_id': schoolId,
      'class_id': classId,
      'date': date,
      'attendance_json': jsonEncode(attendance),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getAllPending() async {
    final db = await DBHelper.db;
    return await db.query('pending_attendance',
        orderBy: 'created_at ASC');
  }

  Future<void> deletePending(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_attendance',
        where: 'id = ?', whereArgs: [id]);
  }
}
