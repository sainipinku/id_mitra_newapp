import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/providers/staff_correction/staff_correction_cubit.dart';
import 'package:sqflite/sqflite.dart';

class StaffCorrectionLocalDS {
  /// 📥 INSERT BATCH
  Future<void> insertStaffCorrections(List<StaffCorrectionItem> list, String schoolId) async {
    final db = await DBHelper.db;
    final batch = db.batch();

    for (var item in list) {
      if (item.id == 0) continue;

      final staff = item.effectiveStaff;
      
      batch.insert(
        'staff_corrections',
        {
          "id": item.id,
          "uuid": item.uuid ?? "",
          "school_id": int.tryParse(schoolId) ?? 0,
          "status": item.status ?? "",
          "remark": item.remark ?? "",
          "staff_name": staff?.name ?? "",
          "raw_data": jsonEncode({
            "id": item.id,
            "uuid": item.uuid,
            "status": item.status,
            "remark": item.remark,
            "staff": item.staff?.toJson(),
            "old_data": item.oldData?.toJson(),
          }),
          "updated_at": DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("Inserted Staff Corrections: ${list.length}");
  }

  /// 🔍 FETCH STAFF CORRECTIONS
  Future<List<StaffCorrectionItem>> getStaffCorrections({
    required String schoolId,
    String search = "",
    int? limit,
    int? offset,
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    /// Search
    if (search.isNotEmpty) {
      where += " AND staff_name LIKE ?";
      args.add("%$search%");
    }

    final data = await db.query(
      "staff_corrections",
      where: where,
      whereArgs: args,
      orderBy: "staff_name COLLATE NOCASE ASC",
      limit: limit,
      offset: offset,
    );

    print("Fetched Local Staff Corrections: ${data.length}");

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      if (map["raw_data"] != null) {
        try {
           final raw = jsonDecode(map["raw_data"]);
           return StaffCorrectionItem.fromJson(raw);
        } catch (_) {}
      }
      return StaffCorrectionItem.fromJson({
        "id": map["id"],
        "uuid": map["uuid"],
        "status": map["status"],
        "remark": map["remark"],
      });
    }).toList();
  }

  /// 🔢 COUNT
  Future<int> getCount({
    required String schoolId,
    String search = "",
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    if (search.isNotEmpty) {
      where += " AND staff_name LIKE ?";
      args.add('%$search%');
    }

    final result = await db.rawQuery('SELECT COUNT(*) FROM staff_corrections WHERE $where', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearForSchool(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete('staff_corrections', where: 'school_id = ?', whereArgs: [int.tryParse(schoolId) ?? 0]);
  }
}
