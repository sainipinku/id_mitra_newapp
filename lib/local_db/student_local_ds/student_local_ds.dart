import 'dart:convert';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:sqflite/sqflite.dart';

class StudentLocalDS {

  ///INSERT BATCH
  Future<void> insertStudents(List<StudentDetailsData> list) async {
    final db = await DBHelper.db;
    final batch = db.batch();

    for (var e in list) {
      if (e.uuid != null && e.uuid!.isNotEmpty) {
        batch.delete('students', where: 'uuid = ?', whereArgs: [e.uuid]);
      }

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
          "school_class_section_id": e.schoolClassSectionId,

          "father_name": e.fatherName ?? "",
          "father_phone": e.fatherPhone,
          "mother_name": e.motherName,
          "mother_phone": e.motherPhone,

          "profile_photo_url": e.profilePhotoUrl,
          "address": e.address,
          "status": e.status ?? 0,
          "is_offline": e.isOffline ? 1 : 0,
          "is_extra": e.isExtra ? 1 : 0,

          /// Nested JSON
          "missing_fields": jsonEncode(e.missingFields ?? []),
          "session_json": jsonEncode(e.session?.toJson() ?? {}),
          "class_json": jsonEncode(e.datumClass?.toJson() ?? {}),
          "section_json": jsonEncode(e.section?.toJson() ?? {}),
          "house_json": jsonEncode(e.house ?? {}),

          /// Full Raw JSON
          "raw_data": jsonEncode(e.toJson()),
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
    List<int> sectionIds = const [],
  }) async {
    final db = await DBHelper.db;

    String where = "is_extra = 0";
    List<dynamic> args = [];

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
      "students",
      where: where,
      whereArgs: args,
      orderBy: "name COLLATE NOCASE ASC",
    );

    print("Fetched Students: ${data.length}");

    return data.map((e) {
      final map = Map<String, dynamic>.from(e);

      /// Decode JSON Fields
      map["missing_fields"] =
          jsonDecode(map["missing_fields"] ?? "[]");

      map["session"] =
          jsonDecode(map["session_json"] ?? "{}");

      map["class"] =
          jsonDecode(map["class_json"] ?? "{}");

      map["section"] =
          jsonDecode(map["section_json"] ?? "{}");

      map["house"] =
          jsonDecode(map["house_json"] ?? "{}");

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

    String where = includeExtra ? "1=1" : "is_extra = 0";
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
      where += " AND school_class_id = ?";
      args.add(int.parse(classId));
    }

    if (sectionIds.isNotEmpty) {
      where +=
      " AND school_class_section_id IN (${sectionIds.map((e) => '?').join(',')})";

      args.addAll(sectionIds);
    }

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM students WHERE $where',
      args,
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// FETCH OFFLINE STUDENTS
  Future<List<StudentDetailsData>> getOfflineStudents() async {
    final db = await DBHelper.db;
    final data = await db.query(
      "students",
      where: "is_offline = 1",
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

  ///  FETCH EXTRA STUDENTS
  Future<List<StudentDetailsData>> getExtraStudents() async {
    final db = await DBHelper.db;
    final data = await db.query(
      "students",
      where: "is_extra = 1",
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

  ///  CLEAR TABLE (Only synced ones)
  Future<void> clearStudents() async {
    final db = await DBHelper.db;
    await db.delete('students', where: 'is_offline = 0 AND is_extra = 0');
  }

  /// DELETE SINGLE STUDENT
  Future<void> deleteStudent(String uuid) async {
    final db = await DBHelper.db;
    await db.delete('students', where: 'uuid = ?', whereArgs: [uuid]);
    print("Deleted Student from local DB: $uuid");
  }

  ///  FETCH SINGLE STUDENT BY UUID
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

    /// Decode JSON Fields
    map["missing_fields"] = jsonDecode(map["missing_fields"] ?? "[]");
    map["session"] = jsonDecode(map["session_json"] ?? "{}");
    map["class"] = jsonDecode(map["class_json"] ?? "{}");
    map["section"] = jsonDecode(map["section_json"] ?? "{}");
    map["house"] = jsonDecode(map["house_json"] ?? "{}");

    return StudentDetailsData.fromJson(map);
  }
}