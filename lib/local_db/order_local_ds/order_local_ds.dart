import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:sqflite/sqflite.dart';

import '../../providers/orders/orders_state.dart';

class OrderLocalDS {
  /// 📥 INSERT BATCH
  /// When [fromApi] is true and [page] is 1, ALL existing rows for this school
  /// are deleted first so local DB mirrors the server exactly.
  Future<void> insertOrders(List<OrderModel> orders, String schoolId, {bool fromApi = false, int page = 1}) async {
    final db = await DBHelper.db;
    final schoolIdInt = int.tryParse(schoolId) ?? 0;

    if (fromApi && page == 1) {
      // Full replace on first page: wipe all local orders for this school
      // so stale/offline data doesn't linger after a fresh API fetch.
      await db.delete(
        'orders',
        where: 'school_id = ?',
        whereArgs: [schoolIdInt],
      );
    } else if (fromApi && page > 1) {
      // Subsequent pages: only remove rows whose uuid matches incoming items
      final apiUuids = orders.map((o) => o.uuid).where((u) => u.isNotEmpty).toList();
      if (apiUuids.isNotEmpty) {
        await db.delete(
          'orders',
          where:
              'school_id = ? AND uuid IN (${apiUuids.map((_) => '?').join(',')})',
          whereArgs: [schoolIdInt, ...apiUuids],
        );
      }
      // Also remove offline placeholders on any page
      await db.delete(
        'orders',
        where: 'school_id = ? AND is_offline = 1',
        whereArgs: [schoolIdInt],
      );
    }

    final batch = db.batch();

    for (var order in orders) {
      batch.insert(
        'orders',
        {
          "id": order.id,
          "uuid": order.uuid,
          "school_id": int.tryParse(schoolId) ?? 0,
          "status": order.status,
          "type": order.type,
          "ordered_at": order.orderedAt,
          "received_at_short": order.receivedAtShort,
          "student_card": order.studentCard,
          "student_card_qty": order.studentCardQty,
          "parent_card": order.parentCard,
          "admit_card": order.admitCard,
          "printing_issue": order.printingIssue,
          "delivered_at": order.deliveredAt,
          "cancelled_at": order.cancelledAt,
          "school_json": jsonEncode(order.school?.id != null ? {
            'id': order.school!.id,
            'name': order.school!.name,
            'logo_url': order.school!.logoUrl,
            'address': order.school!.address,
            'pincode': order.school!.pincode,
            'prefix': order.school!.prefix,
          } : {}),
          "student_json": jsonEncode(order.student?.id != null ? {
            'id': order.student!.id,
            'name': order.student!.name,
            'profile_photo_url': order.student!.profilePhotoUrl,
            'className': order.student!.className,
            'classId': order.student!.classId,
            'sectionName': order.student!.sectionName,
            'gender': order.student!.gender,
            'dob': order.student!.dob,
            'fatherName': order.student!.fatherName,
            'fatherPhone': order.student!.fatherPhone,
            'motherName': order.student!.motherName,
            'address': order.student!.address,
            'pincode': order.student!.pincode,
            'loginId': order.student!.loginId,
          } : {}),
          "staff_json": jsonEncode(order.staff?.id != null ? {
            'id': order.staff!.id,
            'name': order.staff!.name,
            'profile_photo_url': order.staff!.profilePhotoUrl,
            'designation': order.staff!.designation,
            'phone': order.staff!.phone,
            'email': order.staff!.email,
            'employeeId': order.staff!.employeeId,
          } : {}),
          "raw_data": jsonEncode(order.id != 0 ? {} : {}), // For future raw use
          "updated_at": DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("Inserted Orders: ${orders.length}");
  }

  /// Convert dd-mm-yyyy or dd.mm.yyyy or dd/mm/yyyy → yyyy-mm-dd for SQLite date()
  String _toSqliteDate(String input) {
    if (input.isEmpty) return '';
    // Already in yyyy-mm-dd format
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(input)) return input;
    // dd-mm-yyyy / dd.mm.yyyy / dd/mm/yyyy
    final parts = input.split(RegExp(r'[-./]'));
    if (parts.length == 3 && parts[2].length == 4) {
      return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return input;
  }

  /// 🔍 FETCH ORDERS
  Future<List<OrderModel>> getOrders({
    required String schoolId,
    String search = "",
    String status = "",
    String classFilter = "",
    String startDate = "",
    String endDate = "",
    int? limit,
    int? offset,
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    if (search.isNotEmpty) {
      where += " AND (uuid LIKE ? OR status LIKE ?)";
      args.addAll(["%$search%", "%$search%"]);
    }

    if (status.isNotEmpty) {
      where += " AND status = ?";
      args.add(status);
    }

    if (classFilter.isNotEmpty) {
      // classFilter is often "classId-sectionId"
      final parts = classFilter.split('-');
      final classId = parts[0];
      where += " AND student_json LIKE ?";
      args.add('%"classId":$classId%');
      
      if (parts.length > 1) {
        final sectionId = parts[1];
        where += " AND student_json LIKE ?";
        args.add('%"sectionId":$sectionId%');
      }
    }

    final sqlStart = _toSqliteDate(startDate);
    final sqlEnd = _toSqliteDate(endDate);

    if (sqlStart.isNotEmpty) {
      where += " AND date(ordered_at) >= date(?)";
      args.add(sqlStart);
    }

    if (sqlEnd.isNotEmpty) {
      where += " AND date(ordered_at) <= date(?)";
      args.add(sqlEnd);
    }

    final data = await db.query(
      "orders",
      where: where,
      whereArgs: args,
      orderBy: "ordered_at DESC",
      limit: limit,
      offset: offset,
    );

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      
      // Reconstruct the JSON structure for OrderModel.fromJson
      final finalMap = {
        ...map,
        'orderd_at': map['ordered_at'],
        'school': jsonDecode(map['school_json'] ?? '{}'),
        'student': jsonDecode(map['student_json'] ?? '{}'),
        'staff': jsonDecode(map['staff_json'] ?? '{}'),
      };
      
      // Clean up empty objects
      if ((finalMap['school'] as Map).isEmpty) finalMap['school'] = null;
      if ((finalMap['student'] as Map).isEmpty) finalMap['student'] = null;
      if ((finalMap['staff'] as Map).isEmpty) finalMap['staff'] = null;

      return OrderModel.fromJson(finalMap);
    }).toList();
  }

  /// 🔢 COUNT
  Future<int> getCount({
    required String schoolId,
    String search = "",
    String status = "",
    String classFilter = "",
    String startDate = "",
    String endDate = "",
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    if (search.isNotEmpty) {
      where += " AND (uuid LIKE ? OR status LIKE ?)";
      args.addAll(["%$search%", "%$search%"]);
    }

    if (status.isNotEmpty) {
      where += " AND status = ?";
      args.add(status);
    }

    if (classFilter.isNotEmpty) {
      final parts = classFilter.split('-');
      final classId = parts[0];
      where += " AND student_json LIKE ?";
      args.add('%"classId":$classId%');
      
      if (parts.length > 1) {
        final sectionId = parts[1];
        where += " AND student_json LIKE ?";
        args.add('%"sectionId":$sectionId%');
      }
    }

    final sqlStart = _toSqliteDate(startDate);
    final sqlEnd = _toSqliteDate(endDate);

    if (sqlStart.isNotEmpty) {
      where += " AND date(ordered_at) >= date(?)";
      args.add(sqlStart);
    }

    if (sqlEnd.isNotEmpty) {
      where += " AND date(ordered_at) <= date(?)";
      args.add(sqlEnd);
    }

    final result = await db.rawQuery('SELECT COUNT(*) FROM orders WHERE $where', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearForSchool(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete('orders', where: 'school_id = ?', whereArgs: [int.tryParse(schoolId) ?? 0]);
  }

  /// 📥 INSERT OFFLINE STAFF ORDER — saves directly to orders table with is_offline=1
  Future<int> insertOfflineStaffOrder({
    required String schoolId,
    required String cardType,
    required List<String> cardUsers, // correction item uuids
    required String staffName,
    required String? staffPhoto,
  }) async {
    final db = await DBHelper.db;
    final now = DateTime.now();
    // Use negative timestamp as a temporary local id to avoid collision with server ids
    final tempId = -(now.millisecondsSinceEpoch ~/ 1000);
    final tempUuid = 'offline_${now.millisecondsSinceEpoch}';

    await db.insert(
      'orders',
      {
        'id': tempId,
        'uuid': tempUuid,
        'school_id': int.tryParse(schoolId) ?? 0,
        'status': 'order_created',
        'type': cardType,
        'ordered_at': now.toIso8601String(),
        'received_at_short': '',
        'student_card': 0,
        'student_card_qty': 1,
        'parent_card': 0,
        'admit_card': 0,
        'printing_issue': null,
        'delivered_at': null,
        'cancelled_at': null,
        'school_json': '{}',
        'student_json': '{}',
        'staff_json': jsonEncode({
          'id': 0,
          'name': staffName,
          'profile_photo_url': staffPhoto,
          'designation': null,
          'phone': null,
          'email': null,
          'employeeId': null,
        }),
        'raw_data': '{}',
        'is_offline': 1,
        'updated_at': now.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Also save to pending_orders for sync
    await db.insert('pending_orders', {
      'school_id': schoolId,
      'card_type': cardType,
      'card_for_json': jsonEncode([]),
      'card_users_json': jsonEncode(cardUsers),
      'order_json': jsonEncode({
        'temp_uuid': tempUuid,
        'staff_name': staffName,
        'staff_photo': staffPhoto,
      }),
      'created_at': now.millisecondsSinceEpoch,
    });

    print("Saved offline staff order locally: $tempUuid");
    return tempId;
  }

  /// 🔍 FETCH OFFLINE ORDERS (is_offline = 1)
  Future<List<Map<String, dynamic>>> getOfflineOrders({String? schoolId}) async {
    final db = await DBHelper.db;
    String where = 'is_offline = 1';
    List<dynamic> args = [];
    if (schoolId != null && schoolId.isNotEmpty) {
      where += ' AND school_id = ?';
      args.add(int.tryParse(schoolId) ?? 0);
    }
    return await db.query('orders', where: where, whereArgs: args, orderBy: 'updated_at DESC');
  }

  /// 🗑️ DELETE ORDER BY UUID (used after successful sync)
  Future<void> deleteOrderByUuid(String uuid) async {
    final db = await DBHelper.db;
    await db.delete('orders', where: 'uuid = ?', whereArgs: [uuid]);
  }

  Future<void> savePendingStatusUpdate({
    required String schoolId,
    required List<String> uuids,
    required String status,
    String issueNote = '',
  }) async {
    final db = await DBHelper.db;
    await db.insert('pending_status_updates', {
      'school_id': schoolId,
      'uuids_json': jsonEncode(uuids),
      'status': status,
      'issue_note': issueNote,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    // Also update local orders table immediately for UI consistency
    await db.update(
      'orders',
      {'status': status},
      where: "uuid IN (${uuids.map((_) => '?').join(',')})",
      whereArgs: uuids,
    );

    print("Saved pending status update locally and updated local orders table.");
  }

  Future<List<Map<String, dynamic>>> getAllPendingStatusUpdates() async {
    final db = await DBHelper.db;
    return await db.query('pending_status_updates', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingStatusUpdate(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_status_updates', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveSchoolClasses(String schoolId, List<SchoolOrderClass> classes) async {
    final db = await DBHelper.db;
    final jsonList = classes.map((e) => {'value': e.value, 'label': e.label}).toList();
    await db.insert(
      'school_classes',
      {
        'school_id': schoolId,
        'classes_json': jsonEncode(jsonList),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<SchoolOrderClass>> getSchoolClasses(String schoolId) async {
    final db = await DBHelper.db;
    final data = await db.query('school_classes', where: 'school_id = ?', whereArgs: [schoolId]);
    if (data.isNotEmpty) {
      final jsonList = jsonDecode(data.first['classes_json'] as String) as List;
      return jsonList.map((e) => SchoolOrderClass(value: e['value'], label: e['label'])).toList();
    }
    return [];
  }
}
