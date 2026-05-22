import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/providers/staff_correction/staff_correction_cubit.dart';
import 'package:sqflite/sqflite.dart';

class StaffCorrectionLocalDS {

  Future<void> insertStaffCorrections(
    List<StaffCorrectionItem> list,
    String schoolId, {
    bool fromApi = false,
    int page = 1,
  }) async {
    final db = await DBHelper.db;
    final schoolIdInt = int.tryParse(schoolId) ?? 0;

    if (fromApi && page == 1) {
      // Full replace: delete all local corrections for this school on first page
      // so stale/offline data doesn't linger after a fresh API fetch.
      await db.delete(
        'staff_corrections',
        where: 'school_id = ?',
        whereArgs: [schoolIdInt],
      );
    } else if (fromApi && page > 1) {
      // Subsequent pages: only remove rows whose uuid or staff_uuid matches
      // incoming items to avoid duplicates without wiping earlier pages.
      final correctionUuids = list
          .where((item) => item.uuid != null && item.uuid!.isNotEmpty)
          .map((item) => item.uuid!)
          .toList();
      final staffUuids = list
          .where((item) =>
              item.effectiveStaff?.uuid != null &&
              item.effectiveStaff!.uuid.isNotEmpty)
          .map((item) => item.effectiveStaff!.uuid)
          .toList();

      if (correctionUuids.isNotEmpty) {
        await db.delete(
          'staff_corrections',
          where:
              'school_id = ? AND uuid IN (${correctionUuids.map((_) => '?').join(',')})',
          whereArgs: [schoolIdInt, ...correctionUuids],
        );
      }
      if (staffUuids.isNotEmpty) {
        await db.delete(
          'staff_corrections',
          where:
              'school_id = ? AND staff_uuid IN (${staffUuids.map((_) => '?').join(',')})',
          whereArgs: [schoolIdInt, ...staffUuids],
        );
      }
    }

    final batch = db.batch();

    for (var item in list) {
      if (item.id == 0) continue; // skip truly invalid items

      final staff = item.effectiveStaff;

      batch.insert(
        'staff_corrections',
        {
          "id": item.id,
          "uuid": item.uuid ?? "",
          // store staff uuid separately for offline deduplication
          "staff_uuid": staff?.uuid ?? "",
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
    print("Inserted Staff Corrections: ${list.length} (fromApi: $fromApi)");
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
