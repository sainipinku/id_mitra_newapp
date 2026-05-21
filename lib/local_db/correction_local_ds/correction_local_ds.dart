import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/correction/CorrectionListModel.dart';
import 'package:idmitra/providers/correction/correction_state.dart';
import 'package:sqflite/sqflite.dart';

class CorrectionLocalDS {
  ///  INSERT BATCH
  Future<void> insertCorrectionStudents(List<CorrectionStudentItem> list, String schoolId) async {
    final db = await DBHelper.db;
    final batch = db.batch();

    for (var item in list) {
      if (item.id == 0) continue;

      final student = item.student;
      
      batch.insert(
        'correction_students',
        {
          "id": item.id,
          "uuid": item.uuid ?? "",
          "status": item.status ?? "",
          "remark": item.remark ?? "",
          "student_id": student?.id,
          "school_id": int.tryParse(schoolId) ?? student?.schoolId,
          "name": student?.name ?? "",
          "email": student?.email,
          "phone": student?.phone,
          "reg_no": student?.regNo,
          "roll_no": student?.rollNo,
          "admission_no": student?.admissionNo,
          "dob": student?.dob,
          "address": student?.address,
          "father_name": student?.fatherName,
          "father_phone": student?.fatherPhone,
          "mother_name": student?.motherName,
          "mother_phone": student?.motherPhone,
          "school_class_id": student?.schoolClassId,
          "school_class_section_id": student?.schoolClassSectionId,
          "profile_photo_url": student?.profilePhotoUrl,
          "class_json": jsonEncode(student?.studentClass?.toJson() ?? {}),
          "section_json": jsonEncode(student?.section?.toJson() ?? {}),
          "raw_data": jsonEncode(item.toJson()),
          "updated_at": DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("Inserted Correction Students: ${list.length}");
  }

  /// 🔍 FETCH CORRECTION STUDENTS
  Future<List<CorrectionStudentItem>> getCorrectionStudents({
    required String schoolId,
    String search = "",
    String classId = "",
    List<int> sectionIds = const [],
    int? limit,
    int? offset,
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    /// Search
    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add("%$search%");
    }

    /// Class Filter
    if (classId.isNotEmpty) {
      where += " AND school_class_id = ?";
      args.add(int.parse(classId));
    }

    /// Section Filter
    if (sectionIds.isNotEmpty) {
      where +=
      " AND school_class_section_id IN (${sectionIds.map((e) => '?').join(',')})";
      args.addAll(sectionIds);
    }

    final data = await db.query(
      "correction_students",
      where: where,
      whereArgs: args,
      orderBy: "name COLLATE NOCASE ASC",
      limit: limit,
      offset: offset,
    );

    print("Fetched Local Correction Students: ${data.length}");

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      
      // We stored the full CorrectionStudentItem in raw_data
      if (map["raw_data"] != null) {
        try {
           final raw = jsonDecode(map["raw_data"]);
           return CorrectionStudentItem.fromJson(raw);
        } catch (_) {}
      }
      
      // Fallback: reconstruction if raw_data is missing (though it shouldn't be)
      final studentMap = {
        "id": map["student_id"],
        "uuid": map["uuid"],
        "school_id": map["school_id"],
        "name": map["name"],
        "email": map["email"],
        "phone": map["phone"],
        "reg_no": map["reg_no"],
        "roll_no": map["roll_no"],
        "admission_no": map["admission_no"],
        "dob": map["dob"],
        "address": map["address"],
        "father_name": map["father_name"],
        "father_phone": map["father_phone"],
        "mother_name": map["mother_name"],
        "mother_phone": map["mother_phone"],
        "school_class_id": map["school_class_id"],
        "school_class_section_id": map["school_class_section_id"],
        "profile_photo_url": map["profile_photo_url"],
        "class": jsonDecode(map["class_json"] ?? "{}"),
        "section": jsonDecode(map["section_json"] ?? "{}"),
      };

      return CorrectionStudentItem.fromJson({
        "id": map["id"],
        "uuid": map["uuid"],
        "status": map["status"],
        "remark": map["remark"],
        "student": studentMap,
      });
    }).toList();
  }

  ///  COUNT
  Future<int> getCount({
    required String schoolId,
    String search = "",
    String classId = "",
    List<int> sectionIds = const [],
  }) async {
    final db = await DBHelper.db;

    String where = "school_id = ?";
    List<dynamic> args = [int.tryParse(schoolId) ?? 0];

    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add('%$search%');
    }

    if (classId.isNotEmpty) {
      where += " AND school_class_id = ?";
      args.add(int.parse(classId));
    }

    if (sectionIds.isNotEmpty) {
      where += " AND school_class_section_id IN (${sectionIds.map((e) => '?').join(',')})";
      args.addAll(sectionIds);
    }

    final result = await db.rawQuery('SELECT COUNT(*) FROM correction_students WHERE $where', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> clearForSchool(String schoolId) async {
    final db = await DBHelper.db;
    await db.delete('correction_students', where: 'school_id = ?', whereArgs: [int.tryParse(schoolId) ?? 0]);
  }

  Future<void> savePendingChecklist({
    required String schoolId,
    required String processType,
    required String listType,
    String cardType = '',
    List<String> cardFor = const [],
    required List<String> studentUuids,
  }) async {
    final db = await DBHelper.db;
    await db.insert('pending_checklists', {
      'school_id': schoolId,
      'process_type': processType,
      'list_type': listType,
      'card_type': cardType,
      'card_for': jsonEncode(cardFor),
      'students_json': jsonEncode(studentUuids),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    print("Saved pending checklist locally for school: $schoolId");
  }

  Future<List<Map<String, dynamic>>> getAllPendingChecklists() async {
    final db = await DBHelper.db;
    return await db.query('pending_checklists', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingChecklist(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_checklists', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> savePendingOrder({
    required String schoolId,
    required String cardType,
    required List<String> cardFor,
    required List<String> cardUsers,
    required Map<String, dynamic> orderJson,
  }) async {
    final db = await DBHelper.db;
    await db.insert('pending_orders', {
      'school_id': schoolId,
      'card_type': cardType,
      'card_for_json': jsonEncode(cardFor),
      'card_users_json': jsonEncode(cardUsers),
      'order_json': jsonEncode(orderJson),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    print("Saved pending order locally for school: $schoolId");
  }

  Future<List<Map<String, dynamic>>> getAllPendingOrders({String? schoolId}) async {
    final db = await DBHelper.db;
    if (schoolId != null) {
      return await db.query('pending_orders', where: 'school_id = ?', whereArgs: [schoolId], orderBy: 'created_at ASC');
    }
    return await db.query('pending_orders', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingOrder(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_orders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> savePendingDownload({
    required String schoolId,
    required String listType,
    required List<String> selectedColumns,
  }) async {
    final db = await DBHelper.db;
    await db.insert('pending_downloads', {
      'school_id': schoolId,
      'list_type': listType,
      'selected_columns_json': jsonEncode(selectedColumns),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    print("Saved pending download locally for school: $schoolId");
  }

  Future<List<Map<String, dynamic>>> getAllPendingDownloads() async {
    final db = await DBHelper.db;
    return await db.query('pending_downloads', orderBy: 'created_at ASC');
  }

  Future<void> deletePendingDownload(int id) async {
    final db = await DBHelper.db;
    await db.delete('pending_downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveDownloadColumns(String schoolId, List<DownloadColumn> columns) async {
    final db = await DBHelper.db;
    final jsonList = columns.map((e) => {'key': e.key, 'label': e.label}).toList();
    await db.insert(
      'download_columns',
      {
        'school_id': schoolId,
        'columns_json': jsonEncode(jsonList),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DownloadColumn>> getDownloadColumns(String schoolId) async {
    final db = await DBHelper.db;
    final data = await db.query('download_columns', where: 'school_id = ?', whereArgs: [schoolId]);
    if (data.isNotEmpty) {
      final jsonList = jsonDecode(data.first['columns_json'] as String) as List;
      return jsonList.map((e) => DownloadColumn(key: e['key'], label: e['label'])).toList();
    }
    return [];
  }
}
