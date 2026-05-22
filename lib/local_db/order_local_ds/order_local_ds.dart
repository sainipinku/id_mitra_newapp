import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:sqflite/sqflite.dart';

import '../../providers/orders/orders_state.dart';

class OrderLocalDS {
  /// 📥 INSERT BATCH
  Future<void> insertOrders(List<OrderModel> orders, String schoolId) async {
    final db = await DBHelper.db;
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

    if (startDate.isNotEmpty) {
      where += " AND date(ordered_at) >= date(?)";
      args.add(startDate);
    }

    if (endDate.isNotEmpty) {
      where += " AND date(ordered_at) <= date(?)";
      args.add(endDate);
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

    if (startDate.isNotEmpty) {
      where += " AND date(ordered_at) >= date(?)";
      args.add(startDate);
    }

    if (endDate.isNotEmpty) {
      where += " AND date(ordered_at) <= date(?)";
      args.add(endDate);
    }

    final result = await db.rawQuery('SELECT COUNT(*) FROM orders WHERE $where', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearForSchool(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete('orders', where: 'school_id = ?', whereArgs: [int.tryParse(schoolId) ?? 0]);
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
