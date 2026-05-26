import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/holidays/HolidayModel.dart';
import 'package:sqflite/sqflite.dart';

class HolidayLocalDS {
  // ── CACHE ────────────────────────────────────────────────────────────────

  Future<void> saveHolidays(
      String schoolId, int year, List<HolidayModel> holidays) async {
    final db = await DBHelper.db;
    final json = jsonEncode(holidays.map(_holidayToMap).toList());
    await db.insert(
      'holidays_cache',
      {
        'school_id': schoolId,
        'year': year,
        'holidays_json': json,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<HolidayModel>> getHolidays(
      String schoolId, int year, String search) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'holidays_cache',
        where: 'school_id = ? AND year = ?',
        whereArgs: [schoolId, year],
      );
      if (rows.isEmpty) return [];
      final list =
          jsonDecode(rows.first['holidays_json'] as String? ?? '[]') as List;
      var result = list
          .map((e) => HolidayModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (search.isNotEmpty) {
        final q = search.toLowerCase();
        result = result
            .where((h) => (h.name ?? '').toLowerCase().contains(q))
            .toList();
      }
      return result;
    } catch (e) {
      // Corrupted cache — wipe it so next online fetch rebuilds it cleanly
      try {
        final db = await DBHelper.db;
        await db.delete('holidays_cache',
            where: 'school_id = ? AND year = ?',
            whereArgs: [schoolId, year]);
      } catch (_) {}
      return [];
    }
  }

  /// Updates the cached holiday list for (schoolId, year) by replacing
  /// the entry that matches [holiday.id] with the provided [holiday].
  Future<void> upsertHolidayInCache(
      String schoolId, int year, HolidayModel holiday) async {
    final all = await getHolidays(schoolId, year, '');
    final idx = all.indexWhere((h) => h.id == holiday.id);
    if (idx == -1) {
      all.add(holiday);
    } else {
      all[idx] = holiday;
    }
    await saveHolidays(schoolId, year, all);
  }

  Future<void> removeHolidayFromCache(
      String schoolId, int year, int holidayId) async {
    final all = await getHolidays(schoolId, year, '');
    final updated = all.where((h) => h.id != holidayId).toList();
    await saveHolidays(schoolId, year, updated);
  }

  // ── PENDING ADD ──────────────────────────────────────────────────────────

  /// Inserts a pending add and returns the auto-increment ID.
  /// Use the negative of this ID as the temp holiday ID in state.
  Future<int> savePendingAdd({
    required String schoolId,
    required String name,
    required List<String> dates,
    required String type,
    String? description,
  }) async {
    final db = await DBHelper.db;
    return await db.insert('pending_add_holidays', {
      'school_id': schoolId,
      'name': name,
      'dates_json': jsonEncode(dates),
      'type': type,
      'description': description ?? '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deletePendingAdd(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_add_holidays',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllPendingAdds() async {
    final db = await DBHelper.db;
    return await db.query('pending_add_holidays',
        orderBy: 'created_at ASC');
  }

  // ── PENDING DELETE ───────────────────────────────────────────────────────

  Future<void> savePendingDelete(
      {required String schoolId, required int holidayId}) async {
    final db = await DBHelper.db;
    await db.insert('pending_delete_holidays', {
      'school_id': schoolId,
      'holiday_id': holidayId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deletePendingDelete(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_delete_holidays',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllPendingDeletes() async {
    final db = await DBHelper.db;
    return await db.query('pending_delete_holidays',
        orderBy: 'created_at ASC');
  }

  // ── PENDING UPDATE ───────────────────────────────────────────────────────

  Future<void> savePendingUpdate({
    required String schoolId,
    required int holidayId,
    required String name,
    required List<String> dates,
    required String type,
    String? description,
  }) async {
    final db = await DBHelper.db;
    // Replace previous pending update for same holiday (last one wins)
    await db.delete('pending_update_holidays',
        where: 'school_id = ? AND holiday_id = ?',
        whereArgs: [schoolId, holidayId]);
    await db.insert('pending_update_holidays', {
      'school_id': schoolId,
      'holiday_id': holidayId,
      'name': name,
      'dates_json': jsonEncode(dates),
      'type': type,
      'description': description ?? '',
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> deletePendingUpdate(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_update_holidays',
        where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getAllPendingUpdates() async {
    final db = await DBHelper.db;
    return await db.query('pending_update_holidays',
        orderBy: 'created_at ASC');
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────

  Map<String, dynamic> _holidayToMap(HolidayModel h) => {
        'id': h.id,
        'name': h.name,
        'date': h.dates,
        'type': h.type,
        'year': h.year,
        'description': h.description,
        'is_active': h.isActive == true ? 1 : 0,
        'extra': {'type': h.type},
      };
}
