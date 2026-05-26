import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:sqflite/sqflite.dart';

class ImageSettingsLocalDS {
  /// 📥 SAVE IMAGE SETTINGS (CACHE)
  Future<void> saveImageSettings(String schoolId, Map<String, dynamic> data) async {
    final db = await DBHelper.db;
    await db.insert(
      'image_settings',
      {
        'school_id': schoolId,
        'settings_json': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 🔍 GET IMAGE SETTINGS (CACHE)
  Future<Map<String, dynamic>?> getImageSettings(String schoolId) async {
    try {
      final db = await DBHelper.db;
      final List<Map<String, dynamic>> maps = await db.query(
        'image_settings',
        where: 'school_id = ?',
        whereArgs: [schoolId],
      );

      if (maps.isNotEmpty) {
        return jsonDecode(maps.first['settings_json'] as String? ?? '{}') as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      // Corrupted cache — delete so fresh fetch works next time
      try {
        final db = await DBHelper.db;
        await db.delete('image_settings', where: 'school_id = ?', whereArgs: [schoolId]);
      } catch (_) {}
      return null;
    }
  }

  Future<void> savePendingImageSettings(String schoolId, Map<String, dynamic> body) async {
    final db = await DBHelper.db;
    await db.insert(
      'pending_image_settings',
      {
        'school_id': schoolId,
        'body_json': jsonEncode(body),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<List<Map<String, dynamic>>> getAllPendingSync() async {
    final db = await DBHelper.db;
    return await db.query('pending_image_settings', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingSync(int id) async {
    final db = await DBHelper.db;
    await db.delete(
      'pending_image_settings',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
