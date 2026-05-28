import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/global_summary/global_summary_model.dart';

class GlobalSummaryLocalDS {
  // ─── Save full summary ────────────────────────────────────────────────────

  Future<void> saveSummary(GlobalSummaryModel model) async {
    final db = await DBHelper.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final rawJson = jsonEncode(model.data.toJson());

    await db.transaction((txn) async {
      // 1. Cache the full raw response
      await txn.delete('global_summary_cache');
      await txn.insert('global_summary_cache', {
        'id': 1,
        'raw_json': rawJson,
        'synced_at': now,
      });

      final latest = model.data.latest;

      // 2. Schools
      await txn.delete('gs_schools');
      for (final s in latest.schools) {
        await txn.insert('gs_schools', {
          'id': s.id,
          'uuid': s.uuid,
          'name': s.name,
          'school_prefix': s.schoolPrefix,
          'status': s.status,
          'created_at': s.createdAt,
          'raw_json': jsonEncode(s.toJson()),
        });
      }

      // 3. Students
      await txn.delete('gs_students');
      for (final s in latest.students) {
        await txn.insert('gs_students', {
          'id': s.id,
          'uuid': s.uuid,
          'school_id': s.schoolId,
          'school_name': s.schoolName,
          'school_prefix': s.schoolPrefix,
          'name': s.name,
          'admission_no': s.admissionNo?.toString(),
          'phone': s.phone?.toString(),
          'status': s.status,
          'created_at': s.createdAt,
          'raw_json': jsonEncode(s.toJson()),
        });
      }

      // 4. Orders
      await txn.delete('gs_orders');
      for (final o in latest.orders) {
        await txn.insert('gs_orders', {
          'id': o.id,
          'uuid': o.uuid,
          'school_id': o.schoolId,
          'school_name': o.schoolName,
          'school_prefix': o.schoolPrefix,
          'student_id': o.studentId,
          'student_name': o.studentName,
          'type': o.type,
          'status': o.status,
          'created_at': o.createdAt,
          'raw_json': jsonEncode(o.toJson()),
        });
      }

      // 5. Staff orders
      await txn.delete('gs_staff_orders');
      for (final so in latest.staffOrders) {
        await txn.insert('gs_staff_orders', {
          'id': so.id,
          'uuid': so.uuid,
          'school_id': so.schoolId,
          'school_name': so.schoolName,
          'school_prefix': so.schoolPrefix,
          'school_staff_id': so.schoolStaffId,
          'staff_name': so.staffName,
          'type': so.type,
          'quantity': so.quantity,
          'status': so.status,
          'created_at': so.createdAt,
          'raw_json': jsonEncode(so.toJson()),
        });
      }

      // 6. Student corrections
      await txn.delete('gs_student_corrections');
      for (final sc in latest.studentCorrections) {
        await txn.insert('gs_student_corrections', {
          'id': sc.id,
          'uuid': sc.uuid,
          'school_id': sc.schoolId,
          'school_name': sc.schoolName,
          'school_prefix': sc.schoolPrefix,
          'list_type': sc.listType,
          'status': sc.status,
          'class_name': sc.className,
          'section_name': sc.sectionName?.toString(),
          'created_at': sc.createdAt,
          'raw_json': jsonEncode(sc.toJson()),
        });
      }

      // 7. Staff corrections
      await txn.delete('gs_staff_corrections');
      for (final sc in latest.staffCorrections) {
        await txn.insert('gs_staff_corrections', {
          'id': sc.id,
          'school_id': sc.schoolId,
          'school_name': sc.schoolName,
          'school_prefix': sc.schoolPrefix,
          'school_staff_id': sc.schoolStaffId,
          'staff_name': sc.staffName,
          'created_at': sc.createdAt,
          'raw_json': jsonEncode(sc.toJson()),
        });
      }
    });
  }

  // ─── Load cached summary ──────────────────────────────────────────────────

  Future<GlobalSummaryLocalData?> loadCachedSummary() async {
    final db = await DBHelper.db;

    final cacheRows = await db.query('global_summary_cache', limit: 1);
    if (cacheRows.isEmpty) return null;

    final syncedAt = cacheRows.first['synced_at'] as int;

    final schools = await db.query('gs_schools', orderBy: 'id DESC');
    final students = await db.query('gs_students', orderBy: 'id DESC');
    final orders = await db.query('gs_orders', orderBy: 'id DESC');
    final staffOrders = await db.query('gs_staff_orders', orderBy: 'id DESC');
    final studentCorrections = await db.query('gs_student_corrections', orderBy: 'id DESC');
    final staffCorrections = await db.query('gs_staff_corrections', orderBy: 'id DESC');

    return GlobalSummaryLocalData(
      syncedAt: DateTime.fromMillisecondsSinceEpoch(syncedAt),
      schools: schools
          .map((r) => SummarySchool.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
      students: students
          .map((r) => SummaryStudent.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
      orders: orders
          .map((r) => SummaryOrder.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
      staffOrders: staffOrders
          .map((r) => SummaryStaffOrder.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
      studentCorrections: studentCorrections
          .map((r) => SummaryStudentCorrection.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
      staffCorrections: staffCorrections
          .map((r) => SummaryStaffCorrection.fromJson(jsonDecode(r['raw_json'] as String)))
          .toList(),
    );
  }

  Future<bool> hasCachedData() async {
    final db = await DBHelper.db;
    final rows = await db.query('global_summary_cache', limit: 1);
    return rows.isNotEmpty;
  }
}

/// Lightweight container for locally cached summary data
class GlobalSummaryLocalData {
  final DateTime syncedAt;
  final List<SummarySchool> schools;
  final List<SummaryStudent> students;
  final List<SummaryOrder> orders;
  final List<SummaryStaffOrder> staffOrders;
  final List<SummaryStudentCorrection> studentCorrections;
  final List<SummaryStaffCorrection> staffCorrections;

  GlobalSummaryLocalData({
    required this.syncedAt,
    required this.schools,
    required this.students,
    required this.orders,
    required this.staffOrders,
    required this.studentCorrections,
    required this.staffCorrections,
  });
}
