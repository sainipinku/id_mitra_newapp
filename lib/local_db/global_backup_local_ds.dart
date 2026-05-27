import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:idmitra/db_helper.dart';

class GlobalBackupLocalDS {

  Future<void> saveEntities(
    String entityType,
    List<dynamic> items, {
    required String schoolIdKey,
  }) async {
    if (items.isEmpty) return;
    final db = await DBHelper.db;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final raw in items) {
      final item = raw as Map<String, dynamic>;

      // ── global_backup (for reference) ──
      batch.insert(
        'global_backup',
        {
          'entity_type': entityType,
          'entity_id': item['id'].toString(),
          'school_id': item[schoolIdKey]?.toString(),
          'raw_json': jsonEncode(item),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // ── dedicated table (for offline use by screens) ──
      _insertToDedicated(batch, entityType, item, now);
    }

    await batch.commit(noResult: true);
  }

  void _insertToDedicated(
    Batch batch,
    String entityType,
    Map<String, dynamic> item,
    int now,
  ) {
    switch (entityType) {

      case 'school':
        // schools table — raw_json is all screens need
        batch.insert(
          'schools',
          {
            'id': item['id'],
            'raw_json': jsonEncode(item),
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // image_settings table — needed for card printing offline
        final imageSettings = item['image_settings'];
        if (imageSettings != null) {
          batch.insert(
            'image_settings',
            {
              'school_id': item['id'].toString(),
              'settings_json': jsonEncode(imageSettings),
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        // school_form_fields table — needed for student/staff add forms offline
        final studentFields = item['student_form_fields'];
        final staffFields = item['staff_form_fields'];
        if (studentFields != null || staffFields != null) {
          batch.insert(
            'school_form_fields',
            {
              'school_id': item['id'].toString(),
              'fields_json': jsonEncode(studentFields ?? []),
              'available_fields_json': jsonEncode(studentFields ?? []),
              'roles_json': jsonEncode(staffFields ?? []),
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        break;

      case 'student':
        batch.insert(
          'students',
          {
            'id': item['id'],
            'uuid': item['uuid'],
            'school_id': item['school_id'],
            'name': item['name'],
            'email': item['email'],
            'phone': item['phone'],
            'gender': item['gender'],
            'status': item['status'] ?? 1,
            'profile_photo_url': item['profile_photo_url'],
            'father_name': item['father_name'],
            'father_phone': item['father_phone'],
            'mother_name': item['mother_name'],
            'mother_phone': item['mother_phone'],
            'address': item['address'],
            'school_class_id': item['school_class_id'],
            'school_class_section_id': item['school_class_section_id'],
            'raw_data': jsonEncode(item),
            // all offline flags 0 — this is server data
            'is_offline': 0,
            'is_extra': 0,
            'is_offline_update': 0,
            'is_extra_pending_sync': 0,
            'is_delete_pending_sync': 0,
            'is_status_pending_sync': 0,
            'is_photo_pending_sync': 0,
            'created_at': item['created_at'],
            'updated_at': item['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        break;

      case 'order':
        batch.insert(
          'orders',
          {
            'id': item['id'],
            'uuid': item['uuid'],
            'school_id': item['school_id'],
            'status': item['status'],
            'type': item['type'],
            'school_json': jsonEncode({
              'id': item['school_id'],
              'name': item['school_name'],
              'prefix': item['school_prefix'],
            }),
            'student_json': jsonEncode({
              'id': item['student_id'],
              'name': item['student_name'],
            }),
            'raw_data': jsonEncode(item),
            'is_offline': 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        break;

      case 'staff_order':
        batch.insert(
          'orders',
          {
            'id': item['id'],
            'uuid': item['uuid'],
            'school_id': item['school_id'],
            'status': item['status'],
            'type': item['type'],
            'school_json': jsonEncode({
              'id': item['school_id'],
              'name': item['school_name'],
            }),
            'staff_json': jsonEncode({
              'id': item['school_staff_id'],
              'name': item['staff_name'],
            }),
            'raw_data': jsonEncode(item),
            'is_offline': 0,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        break;

      case 'staff':
        batch.insert(
          'staff',
          {
            'id': item['id'],
            'uuid': item['uuid'],
            'school_id': item['school_id'],
            'name': item['name'],
            'designation': item['designation'],
            'department': item['department'],
            'email': item['email'],
            'phone': item['phone'],
            'status': item['status'] ?? 1,
            'profile_photo_url': item['profile_photo_url'],
            'raw_data': jsonEncode(item),
            'is_offline': 0,
            'is_extra': 0,
            'is_offline_update': 0,
            'is_extra_pending_sync': 0,
            'is_delete_pending_sync': 0,
            'is_status_pending_sync': 0,
            'is_photo_pending_sync': 0,
            'created_at': item['created_at'],
            'updated_at': item['updated_at'],
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        break;

      // student_correction, staff_correction → global_backup me hi rahega
      // dedicated correction tables ka schema alag hai
      default:
        break;
    }
  }

  // ── home_cache populate — screens jo home_cache se padhti hain unke liye ──

  /// Backup ke baad schools ko home_cache me SchoolCubit format me save karo
  Future<void> populateSchoolsHomeCache() async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query('schools', orderBy: 'updated_at DESC');
      if (rows.isEmpty) return;

      final schoolsList = rows.map((row) {
        return jsonDecode(row['raw_json'] as String) as Map<String, dynamic>;
      }).toList();

      // SchoolCubit jo format expect karta hai
      final cacheJson = {
        'data': {
          'schools': {
            'data': schoolsList,
            'total': schoolsList.length,
            'current_page': 1,
            'last_page': 1,
          }
        }
      };

      await db.insert(
        'home_cache',
        {
          'key': 'schools_list_page_1_search_',
          'json_data': jsonEncode(cacheJson),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      print('GlobalBackupLocalDS: home_cache me ${schoolsList.length} schools save kiye');
    } catch (e) {
      print('GlobalBackupLocalDS populateSchoolsHomeCache error: $e');
    }
  }

  // ── Offline stats readers ──────────────────────────────────────────────────

  Future<int> getTotalBackupCount() async {
    try {
      final db = await DBHelper.db;
      final result =
          await db.rawQuery('SELECT COUNT(*) as total FROM global_backup');
      return (result.first['total'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<DateTime?> getLastSyncedAt() async {
    try {
      final db = await DBHelper.db;
      final result = await db
          .rawQuery('SELECT MAX(synced_at) as last_sync FROM global_backup');
      final ms = result.first['last_sync'] as int?;
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  // ── Old summary-based save (kept for reference) ──
  Future<void> saveGlobalSummary(Map<String, dynamic> data) async {
    final db = await DBHelper.db;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    final partner = data['panel']['partner'] as Map<String, dynamic>;
    batch.insert('global_backup', {
      'entity_type': 'partner',
      'entity_id': partner['id'].toString(),
      'school_id': null,
      'raw_json': jsonEncode(partner),
      'synced_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('global_backup', {
      'entity_type': 'global_counts',
      'entity_id': '1',
      'school_id': null,
      'raw_json': jsonEncode(data['counts']),
      'synced_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }

  int countEntities(Map<String, dynamic> data) {
    final latest = data['latest'] as Map<String, dynamic>;
    return 2 +
        (latest['schools'] as List).length +
        (latest['students'] as List).length +
        (latest['orders'] as List).length +
        (latest['staff_orders'] as List).length +
        (latest['student_corrections'] as List).length +
        (latest['staff_corrections'] as List).length;
  }
}
