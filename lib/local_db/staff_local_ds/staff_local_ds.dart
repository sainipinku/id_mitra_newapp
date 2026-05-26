import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/staff/StaffListModel.dart';
import 'package:sqflite/sqflite.dart';

class StaffLocalDS {
  /// INSERT BATCH
  Future<void> insertStaff(List<StaffListModel> list) async {
    final db = await DBHelper.db;

    // ── STEP 1: Find UUIDs that are currently pending sync ──
    final pendingSyncUuids = <String>{};
    if (list.isNotEmpty) {
      final uuids = list.map((e) => e.uuid).where((u) => u.isNotEmpty);
      if (uuids.isNotEmpty) {
        final result = await db.query(
          'staff',
          columns: ['uuid'],
          where:
              "(is_delete_pending_sync = 1 OR is_offline_update = 1 OR is_status_pending_sync = 1 OR is_photo_pending_sync = 1 OR is_extra_pending_sync = 1 OR is_offline = 1) AND uuid IN (${uuids.map((_) => '?').join(',')})",
          whereArgs: uuids.toList(),
        );
        for (var row in result) {
          pendingSyncUuids.add(row['uuid'] as String);
        }
      }
    }

    final batch = db.batch();

    for (var e in list) {
      if (e.uuid.isEmpty) continue;

      final hasPendingLocal = pendingSyncUuids.contains(e.uuid);
      final isNewPendingData = e.isOffline ||
          e.isOfflineUpdate ||
          e.isDeletePendingSync ||
          e.isStatusPendingSync ||
          e.isPhotoPendingSync ||
          e.isExtraPendingSync;

      if (hasPendingLocal && !isNewPendingData) {
        continue;
      }

      batch.delete('staff', where: 'uuid = ?', whereArgs: [e.uuid]);

      batch.insert(
        'staff',
        {
          "id": e.id,
          "uuid": e.uuid,
          "school_id": e.schoolId,
          "name": e.name,
          "designation": e.designation,
          "department": e.department,
          "email": e.email,
          "phone": e.phone,
          "whatsapp_phone": e.whatsappPhone,
          "address": e.address,
          "profile_photo_url": e.profilePhotoUrl,
          "role_name": e.roleName,
          "role_id": e.roleId,
          "status": e.status,
          "assigned_classes_json": jsonEncode(e.assignedClasses),
          "dob": e.dob,
          "father_name": e.fatherName,
          "mother_name": e.motherName,
          "husband_name": e.husbandName,
          "gender": e.gender,
          "blood_group": e.bloodGroup,
          "pincode": e.pincode,
          "employee_id": e.employeeId,
          "national_code": e.nationalCode,
          "login_id": e.loginId,
          "date_of_joining": e.dateOfJoining,
          "is_offline": e.isOffline ? 1 : 0,
          "is_extra": e.isExtra ? 1 : 0,
          "is_offline_update": e.isOfflineUpdate ? 1 : 0,
          "is_extra_pending_sync": e.isExtraPendingSync ? 1 : 0,
          "is_delete_pending_sync": e.isDeletePendingSync ? 1 : 0,
          "is_status_pending_sync": e.isStatusPendingSync ? 1 : 0,
          "is_photo_pending_sync": e.isPhotoPendingSync ? 1 : 0,
          "offline_photo_path": e.offlinePhotoPath,
          "raw_data": jsonEncode(e.toJson()),
          "offline_fields_json": e.offlineFieldsJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("Inserted Staff: ${list.length}");
  }

  /// 🔍 FETCH STAFF
  Future<List<StaffListModel>> getStaff({
    String search = "",
    String schoolId = "",
    int? limit,
    int? offset,
  }) async {
    final db = await DBHelper.db;

    String where = "is_extra = 0 AND is_delete_pending_sync = 0";
    List<dynamic> args = [];

    /// School Filter
    if (schoolId.isNotEmpty) {
      where += " AND school_id = ?";
      args.add(int.tryParse(schoolId) ?? 0);
    }

    /// Search
    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add("%$search%");
    }

    final data = await db.query(
      "staff",
      where: where,
      whereArgs: args,
      orderBy: "name COLLATE NOCASE ASC",
      limit: limit,
      offset: offset,
    );

    print("Fetched Staff: ${data.length}");

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["assigned_classes"] = jsonDecode(map["assigned_classes_json"] ?? "[]");
      return StaffListModel.fromJson(map);
    }).toList();
  }

  /// 🔢 COUNT
  Future<int> getCount({
    String search = "",
    String schoolId = "",
    bool includeExtra = true,
  }) async {
    final db = await DBHelper.db;

    String where = includeExtra
        ? "is_delete_pending_sync = 0"
        : "is_extra = 0 AND is_delete_pending_sync = 0";
    List<dynamic> args = [];

    if (schoolId.isNotEmpty) {
      where += " AND school_id = ?";
      args.add(int.tryParse(schoolId) ?? 0);
    }

    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add('%$search%');
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM staff WHERE $where',
      args,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<StaffListModel>> getOfflineStaff({String? schoolId}) async {
    final db = await DBHelper.db;
    String where =
        "is_offline = 1 OR is_offline_update = 1 OR is_extra_pending_sync = 1 OR is_delete_pending_sync = 1 OR is_status_pending_sync = 1 OR is_photo_pending_sync = 1";
    List<dynamic>? whereArgs;

    if (schoolId != null && schoolId.isNotEmpty) {
      where = "($where) AND school_id = ?";
      whereArgs = [int.tryParse(schoolId) ?? 0];
    }

    final data = await db.query(
      "staff",
      where: where,
      whereArgs: whereArgs,
      orderBy: "name COLLATE NOCASE ASC",
    );
    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["assigned_classes"] = jsonDecode(map["assigned_classes_json"] ?? "[]");
      return StaffListModel.fromJson(map);
    }).toList();
  }

  Future<void> deleteStaffByUuid(String uuid) async {
    final db = await DBHelper.db;
    await db.delete('staff', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<void> clearStaff(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete('staff', where: 'school_id = ?', whereArgs: [schoolId]);
  }

  /// Sirf synced (non-pending) staff records delete karo — pending wale safe rehte hain
  Future<void> clearSyncedStaff(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete(
      'staff',
      where: 'school_id = ? AND is_offline = 0 AND is_offline_update = 0 AND is_extra_pending_sync = 0 AND is_delete_pending_sync = 0 AND is_status_pending_sync = 0 AND is_photo_pending_sync = 0 AND is_extra = 0',
      whereArgs: [int.tryParse(schoolId) ?? 0],
    );
  }

  Future<StaffListModel?> getStaffByUuid(String uuid) async {
    final db = await DBHelper.db;
    final data = await db.query(
      "staff",
      where: "uuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );
    if (data.isEmpty) return null;
    final map = Map<String, dynamic>.from(data.first);
    map["assigned_classes"] = jsonDecode(map["assigned_classes_json"] ?? "[]");
    return StaffListModel.fromJson(map);
  }

  /// 🔍 FETCH STAFF BY UUIDS
  Future<List<StaffListModel>> getStaffByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return [];
    final db = await DBHelper.db;
    final data = await db.query(
      "staff",
      where: "uuid IN (${uuids.map((_) => '?').join(',')})",
      whereArgs: uuids,
    );
    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["assigned_classes"] = jsonDecode(map["assigned_classes_json"] ?? "[]");
      return StaffListModel.fromJson(map);
    }).toList();
  }
}
