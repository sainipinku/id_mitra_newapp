import 'package:sqflite/sqflite.dart';
import 'package:idmitra/db_helper.dart';

class MaintenanceLocalDS {
  static const _key = 'server_maintenance';

  Future<void> saveStatus(bool isMaintenance) async {
    final db = await DBHelper.db;
    await db.insert(
      'server_status',
      {
        'key': _key,
        'is_maintenance': isMaintenance ? 1 : 0,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool?> getLastKnownMaintenance() async {
    final db = await DBHelper.db;
    final rows = await db.query(
      'server_status',
      where: 'key = ?',
      whereArgs: [_key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['is_maintenance'] as int) == 1;
  }
}
