import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:sqflite/sqflite.dart';

class StudentLocalDS {

  ///INSERT BATCH
  Future<void> insertStudents(List<StudentDetailsData> list, {bool forceUpdate = false}) async {
    final db = await DBHelper.db;

    final pendingSyncUuids = <String>{};
    final existingPhotoUrls = <String, String>{};
    final existingSectionJsons = <String, String>{};
    final existingClassJsons = <String, String>{};
    final existingSectionIds = <String, int>{};

    if (list.isNotEmpty) {
      final uuids = list.map((e) => e.uuid).where((u) => u != null && u!.isNotEmpty);
      if (uuids.isNotEmpty) {
        final result = await db.query(
          'students',
          columns: ['uuid', 'is_delete_pending_sync', 'is_offline_update', 'is_status_pending_sync', 'is_photo_pending_sync', 'is_extra_pending_sync', 'is_offline', 'profile_photo_url', 'section_json', 'class_json', 'school_class_section_id'],
          where: "uuid IN (${uuids.map((_) => '?').join(',')})",
          whereArgs: uuids.toList(),
        );
        for (var row in result) {
          final uuid = row['uuid'] as String;
          final isPending = (row['is_delete_pending_sync'] == 1 ||
              row['is_offline_update'] == 1 ||
              row['is_status_pending_sync'] == 1 ||
              row['is_photo_pending_sync'] == 1 ||
              row['is_extra_pending_sync'] == 1 ||
              row['is_offline'] == 1);

          if (isPending) {
            pendingSyncUuids.add(uuid);
          }

          final photoUrl = row['profile_photo_url'] as String?;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            existingPhotoUrls[uuid] = photoUrl;
          }

          final sectionJson = row['section_json'] as String?;
          if (sectionJson != null && sectionJson.isNotEmpty && sectionJson != '{}') {
            existingSectionJsons[uuid] = sectionJson;
          }

          final classJson = row['class_json'] as String?;
          if (classJson != null && classJson.isNotEmpty && classJson != '{}') {
            existingClassJsons[uuid] = classJson;
          }

          final sectionId = row['school_class_section_id'];
          if (sectionId != null) {
            existingSectionIds[uuid] = sectionId as int;
          }
        }
      }
    }

    final batch = db.batch();

    for (var e in list) {
      if (e.uuid == null || e.uuid!.isEmpty) continue;

      // forceUpdate=true hone par skip logic bypass karo (internal sync updates ke liye)
      if (!forceUpdate) {
        final hasPendingLocal = pendingSyncUuids.contains(e.uuid);
        final isNewPendingData = e.isOffline ||
            e.isOfflineUpdate ||
            e.isDeletePendingSync ||
            e.isStatusPendingSync ||
            e.isPhotoPendingSync ||
            e.isExtraPendingSync;

        if (hasPendingLocal && !isNewPendingData) {
          continue;
        }
      }

      // profilePhotoUrl is from local DB column; photo field comes from server API response
      String? finalPhotoUrl = e.profilePhotoUrl;
      if ((finalPhotoUrl == null || finalPhotoUrl.isEmpty) && e.photo is String) {
        final photoStr = e.photo as String;
        if (photoStr.isNotEmpty) finalPhotoUrl = photoStr;
      }
      final isNewPlaceholder = finalPhotoUrl == null ||
          finalPhotoUrl.isEmpty ||
          finalPhotoUrl.contains('ui-avatars.com');

      if (isNewPlaceholder && existingPhotoUrls.containsKey(e.uuid)) {
        final existingUrl = existingPhotoUrls[e.uuid]!;
        final isExistingReal = existingUrl.isNotEmpty &&
            !existingUrl.contains('ui-avatars.com');

        if (isExistingReal) {
          finalPhotoUrl = existingUrl;
        }
      }

      // Preserve section_json from local DB if incoming data has no section
      String finalSectionJson = jsonEncode(e.section?.toJson() ?? {});
      if ((e.section == null || e.section!.id == null) &&
          existingSectionJsons.containsKey(e.uuid)) {
        finalSectionJson = existingSectionJsons[e.uuid]!;
      }

      // Preserve class_json from local DB if incoming data has no class
      String finalClassJson = jsonEncode(e.datumClass?.toJson() ?? {});
      if ((e.datumClass == null || e.datumClass!.id == null) &&
          existingClassJsons.containsKey(e.uuid)) {
        finalClassJson = existingClassJsons[e.uuid]!;
      }

      batch.delete('students', where: 'uuid = ?', whereArgs: [e.uuid]);

      batch.insert(
        'students',
        {
          "id": e.id,
          "uuid": e.uuid ?? "",
          "school_id": e.schoolId,
          "name": e.name ?? "",
          "email": e.email?.toString(),
          "phone": e.phone?.toString(),
          "gender": e.gender?.toString(),
          "school_class_id": e.schoolClassId,
          "school_class_section_id": e.schoolClassSectionId ?? existingSectionIds[e.uuid],
          "father_name": e.fatherName ?? "",
          "father_phone": e.fatherPhone,
          "mother_name": e.motherName,
          "mother_phone": e.motherPhone,
          "profile_photo_url": finalPhotoUrl,
          "address": e.address,
          "status": e.status ?? 0,
          "is_offline": e.isOffline ? 1 : 0,
          "is_extra": e.isExtra ? 1 : 0,
          "is_offline_update": e.isOfflineUpdate ? 1 : 0,
          "is_extra_pending_sync": e.isExtraPendingSync ? 1 : 0,
          "is_delete_pending_sync": e.isDeletePendingSync ? 1 : 0,
          "is_status_pending_sync": e.isStatusPendingSync ? 1 : 0,
          "is_photo_pending_sync": e.isPhotoPendingSync ? 1 : 0,
          "offline_photo_path": e.offlinePhotoPath,

          /// Nested JSON
          "missing_fields": jsonEncode(e.missingFields ?? []),
          "session_json": jsonEncode(e.session?.toJson() ?? {}),
          "class_json": finalClassJson,
          "section_json": finalSectionJson,
          "house_json": jsonEncode(e.house ?? {}),

          /// Full Raw JSON
          "raw_data": jsonEncode(e.toJson()),
          "offline_fields_json": e.offlineFieldsJson,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    print("Inserted Students: ${list.length}");
  }

  /// 🔍 FETCH STUDENTS
  Future<List<StudentDetailsData>> getStudents({
    String search = "",
    String gender = "",
    String classId = "",
    String schoolId = "",
    List<int> sectionIds = const [],
    int? limit,
    int? offset,
  }) async {
    final db = await DBHelper.db;

    String where = "is_extra = 0 AND is_delete_pending_sync = 0 AND is_offline = 0 AND is_offline_update = 0";
    List<dynamic> args = [];

    /// School Filter
    if (schoolId.isNotEmpty) {
      where += " AND school_id = ?";
      args.add(int.tryParse(schoolId) ?? 0);
    }

    /// Search
    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add("%$search%");
    }

    /// Gender
    if (gender.isNotEmpty) {
      where += " AND gender = ?";
      args.add(gender);
    }

    /// Class Filter
    if (classId.isNotEmpty) {
      final classIds = classId
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (classIds.length == 1) {
        where += " AND school_class_id = ?";
        args.add(classIds.first);
      } else if (classIds.length > 1) {
        where += " AND school_class_id IN (${classIds.map((_) => '?').join(',')})";
        args.addAll(classIds);
      }
    }

    /// Section Filter
    if (sectionIds.isNotEmpty) {
      where += " AND school_class_section_id IN (${sectionIds.map((e) => '?').join(',')})";
      args.addAll(sectionIds);
    }

    final data = await db.query(
      "students",
      where: where,
      whereArgs: args,
      orderBy: "name COLLATE NOCASE ASC",
      limit: limit,
      offset: offset,
    );

    print("Fetched Students: ${data.length}");

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);

      dynamic _decodeOrNull(String? jsonStr) {
        if (jsonStr == null || jsonStr.isEmpty) return null;
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map && (decoded.isEmpty || decoded['id'] == null)) return null;
        return decoded;
      }

      /// Decode JSON Fields
      map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
      map["session"] = _decodeOrNull(map["session_json"] as String?);
      map["class"] = _decodeOrNull(map["class_json"] as String?);
      map["section"] = _decodeOrNull(map["section_json"] as String?);
      map["house"] = _decodeOrNull(map["house_json"] as String?);

      return StudentDetailsData.fromJson(map);
    }).toList();
  }

  /// 🔢 COUNT
  Future<int> getCount({
    String search = "",
    String gender = "",
    String classId = "",
    String schoolId = "",
    List<int> sectionIds = const [],
    bool includeExtra = true,
  }) async {
    final db = await DBHelper.db;

    String where = includeExtra
        ? "is_delete_pending_sync = 0"
        : "is_extra = 0 AND is_delete_pending_sync = 0 AND is_offline = 0 AND is_offline_update = 0";
    List<dynamic> args = [];

    if (schoolId.isNotEmpty) {
      where += " AND school_id = ?";
      args.add(int.tryParse(schoolId) ?? 0);
    }

    if (search.isNotEmpty) {
      where += " AND name LIKE ?";
      args.add('%$search%');
    }

    if (gender.isNotEmpty) {
      where += " AND gender = ?";
      args.add(gender);
    }

    if (classId.isNotEmpty) {
      final classIds = classId
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .where((e) => e != null)
          .toList();
      if (classIds.length == 1) {
        where += " AND school_class_id = ?";
        args.add(classIds.first);
      } else if (classIds.length > 1) {
        where += " AND school_class_id IN (${classIds.map((_) => '?').join(',')})";
        args.addAll(classIds);
      }
    }

    if (sectionIds.isNotEmpty) {
      where += " AND school_class_section_id IN (${sectionIds.map((e) => '?').join(',')})";
      args.addAll(sectionIds);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE $where',
      args,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<StudentDetailsData>> getOfflineStudents({String? schoolId}) async {
    final db = await DBHelper.db;
    String where = "is_offline = 1 OR is_offline_update = 1 OR is_extra_pending_sync = 1 OR is_delete_pending_sync = 1 OR is_status_pending_sync = 1 OR is_photo_pending_sync = 1";
    List<dynamic>? whereArgs;

    if (schoolId != null && schoolId.isNotEmpty) {
      where = "($where) AND school_id = ?";
      whereArgs = [int.tryParse(schoolId) ?? 0];
    }

    final data = await db.query(
      "students",
      where: where,
      whereArgs: whereArgs,
      orderBy: "name COLLATE NOCASE ASC",
    );
    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
      map["session"] = jsonDecode(map["session_json"] ?? "{}");
      map["class"] = jsonDecode(map["class_json"] ?? "{}");
      map["section"] = jsonDecode(map["section_json"] ?? "{}");
      map["house"] = jsonDecode(map["house_json"] ?? "{}");
      final student = StudentDetailsData.fromJson(map);
      student.offlineFieldsJson = map["offline_fields_json"] as String?;
      return student;
    }).toList();
  }

  Future<List<StudentDetailsData>> getExtraStudents() async {
    final db = await DBHelper.db;
    final data = await db.query(
      "students",
      where: "is_extra = 1 AND is_delete_pending_sync = 0",
      orderBy: "name COLLATE NOCASE ASC",
    );
    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
      map["session"] = jsonDecode(map["session_json"] ?? "{}");
      map["class"] = jsonDecode(map["class_json"] ?? "{}");
      map["section"] = jsonDecode(map["section_json"] ?? "{}");
      map["house"] = jsonDecode(map["house_json"] ?? "{}");
      return StudentDetailsData.fromJson(map);
    }).toList();
  }

  Future<void> clearStudents({String? schoolId}) async {
    final db = await DBHelper.db;
    String where = 'is_offline = 0 AND is_offline_update = 0 AND is_extra_pending_sync = 0 AND is_delete_pending_sync = 0 AND is_status_pending_sync = 0 AND is_photo_pending_sync = 0 AND is_extra = 0';
    List<dynamic>? whereArgs;

    if (schoolId != null && schoolId.isNotEmpty) {
      where = '($where) AND school_id = ?';
      whereArgs = [int.tryParse(schoolId) ?? 0];
    }

    await db.delete('students', where: where, whereArgs: whereArgs);
  }

  Future<void> deleteStudent(String uuid) async {
    final db = await DBHelper.db;
    await db.delete('students', where: 'uuid = ?', whereArgs: [uuid]);
    print("Deleted Student from local DB: $uuid");
  }

  Future<StudentDetailsData?> getStudentByUuid(String uuid) async {
    final db = await DBHelper.db;
    final data = await db.query(
      "students",
      where: "uuid = ?",
      whereArgs: [uuid],
      limit: 1,
    );

    if (data.isEmpty) return null;

    final e = data.first;
    final map = Map<String, dynamic>.from(e);

    map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
    map["session"] = jsonDecode(map["session_json"] ?? "{}");
    map["class"] = jsonDecode(map["class_json"] ?? "{}");
    map["section"] = jsonDecode(map["section_json"] ?? "{}");
    map["house"] = jsonDecode(map["house_json"] ?? "{}");

    return StudentDetailsData.fromJson(map);
  }

  /// 🔍 FETCH BY UUIDS
  Future<List<StudentDetailsData>> getStudentsByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return [];
    final db = await DBHelper.db;
    final data = await db.query(
      "students",
      where: "uuid IN (${uuids.map((_) => '?').join(',')})",
      whereArgs: uuids,
    );

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);
      map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
      map["session"] = jsonDecode(map["session_json"] ?? "{}");
      map["class"] = jsonDecode(map["class_json"] ?? "{}");
      map["section"] = jsonDecode(map["section_json"] ?? "{}");
      map["house"] = jsonDecode(map["house_json"] ?? "{}");
      return StudentDetailsData.fromJson(map);
    }).toList();
  }
}