import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:idmitra/db_helper.dart';

class GlobalBackupLocalDS {
  Future<void> saveGlobalSummary(Map<String, dynamic> data) async {
    final db = await DBHelper.db;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    final partner = data['panel']['partner'] as Map<String, dynamic>;
    batch.insert(
      'global_backup',
      {
        'entity_type': 'partner',
        'entity_id': partner['id'].toString(),
        'school_id': null,
        'raw_json': jsonEncode(partner),
        'synced_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    batch.insert(
      'global_backup',
      {
        'entity_type': 'global_counts',
        'entity_id': '1',
        'school_id': null,
        'raw_json': jsonEncode(data['counts']),
        'synced_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final latest = data['latest'] as Map<String, dynamic>;

    for (final school in (latest['schools'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_school',
          'entity_id': school['id'].toString(),
          'school_id': school['id'].toString(),
          'raw_json': jsonEncode(school),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final student in (latest['students'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_student',
          'entity_id': student['id'].toString(),
          'school_id': student['school_id'].toString(),
          'raw_json': jsonEncode(student),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final order in (latest['orders'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_order',
          'entity_id': order['id'].toString(),
          'school_id': order['school_id'].toString(),
          'raw_json': jsonEncode(order),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final order in (latest['staff_orders'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_staff_order',
          'entity_id': order['id'].toString(),
          'school_id': order['school_id'].toString(),
          'raw_json': jsonEncode(order),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final c in (latest['student_corrections'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_student_correction',
          'entity_id': c['id'].toString(),
          'school_id': c['school_id'].toString(),
          'raw_json': jsonEncode(c),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    for (final c in (latest['staff_corrections'] as List)) {
      batch.insert(
        'global_backup',
        {
          'entity_type': 'latest_staff_correction',
          'entity_id': c['id'].toString(),
          'school_id': c['school_id'].toString(),
          'raw_json': jsonEncode(c),
          'synced_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

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
    }

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
