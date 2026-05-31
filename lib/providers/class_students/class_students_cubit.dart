import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:idmitra/models/add_student/StudentFormDataModel.dart' as model;
import 'class_students_state.dart';

class ClassStudentsCubit extends Cubit<ClassStudentsState> {
  ClassStudentsCubit() : super(ClassStudentsState());

  final ApiManager apiManager = ApiManager();
  final StudentLocalDS _studentLocalDS = StudentLocalDS();

  Future<bool> _hasInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> fetchClasses(String schoolId) async {
    if (schoolId.isEmpty) {
      emit(state.copyWith(error: "School ID is missing"));
      return;
    }
    
    emit(state.copyWith(classesLoading: true, error: null));

    final bool online = await _hasInternet();

    if (online) {
      try {
        final String url = "${Config.baseUrl}auth/school/$schoolId/students/form-data";
        debugPrint("Fetching classes from API: $url");
        
        final response = await apiManager.getRequest(url);

        if (response != null && response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          debugPrint("Classes API Response: ${response.body}");
          
          final formData = model.StudentFormDataModel.fromJson(jsonData);
          
          if (formData.classes.isNotEmpty) {
            // Save to LocalDB
            await _saveClassesToLocal(schoolId, jsonData);

            final List<ClassOption> classes = formData.classes
                .map((e) => ClassOption(
                      value: e.id.toString(),
                      label: e.nameWithPrefix,
                    ))
                .toList();

            emit(state.copyWith(
              classesLoading: false,
              classes: classes,
            ));

            // Auto-select first class if none selected
            if (classes.isNotEmpty && state.selectedClassId == null) {
              fetchClassStudents(schoolId: schoolId, classId: classes.first.value!);
            }
            return;
          } else {
            debugPrint("API returned empty classes for school $schoolId, checking alternate keys...");
            // Try fallback keys if the model didn't find them
            final rawData = jsonData['data'] ?? jsonData;
            final List? altClasses = rawData['classes'] ?? rawData['school_classes'];
            
            if (altClasses != null && altClasses.isNotEmpty) {
              final List<ClassOption> classes = altClasses.map((e) {
                return ClassOption(
                  value: e['id']?.toString() ?? '',
                  label: e['name_withprefix']?.toString() ?? e['name']?.toString() ?? '',
                );
              }).toList();
              
              await _saveClassesToLocal(schoolId, jsonData);
              
              emit(state.copyWith(
                classesLoading: false,
                classes: classes,
              ));
              
              if (classes.isNotEmpty && state.selectedClassId == null) {
                fetchClassStudents(schoolId: schoolId, classId: classes.first.value!);
              }
              return;
            }
          }
        } else {
          debugPrint("API error: ${response?.statusCode} - ${response?.body}");
        }
      } catch (e) {
        debugPrint("fetchClasses API exception: $e");
      }
    }

    // If offline or API fails, try LocalDB
    debugPrint("Fetching classes from LocalDB for schoolId: $schoolId");
    var localData = await _loadClassesFromLocal(schoolId);
    
    // Fallback: If not found, try to search for the schoolId as integer
    if (localData == null || localData.classes.isEmpty) {
      debugPrint("Not found in LocalDB with String ID, trying as integer...");
      localData = await _loadClassesFromLocal(int.tryParse(schoolId)?.toString() ?? schoolId);
    }

    if (localData != null && localData.classes.isNotEmpty) {
      debugPrint("Found ${localData.classes.length} classes in LocalDB");
      final List<ClassOption> classes = localData.classes
          .map((e) => ClassOption(
                value: e.id.toString(),
                label: e.nameWithPrefix,
              ))
          .toList();

      emit(state.copyWith(
        classesLoading: false,
        classes: classes,
      ));

      if (classes.isNotEmpty && state.selectedClassId == null) {
        fetchClassStudents(schoolId: schoolId, classId: classes.first.value!);
      }
    } else {
      emit(state.copyWith(
        classesLoading: false,
        error: online ? "No classes found" : "No internet connection and no offline data",
      ));
    }
  }

  Future<void> fetchClassStudents({
    required String schoolId,
    required String classId,
  }) async {
    if (schoolId.isEmpty || classId.isEmpty) return;

    emit(state.copyWith(loading: true, error: null, selectedClassId: classId));

    final bool online = await _hasInternet();

    if (online) {
      try {
        final String url = "${Config.baseUrl}auth/school/$schoolId/classes/$classId/students";
        debugPrint("Fetching students from API: $url");
        
        final response = await apiManager.getRequest(url);
        
        if (response != null && response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          if (jsonData['success'] == true || jsonData['data'] != null) {
            final List data = jsonData['data'] ?? [];
            final List<StudentDetailsData> students = data.map((e) {
              final map = Map<String, dynamic>.from(e as Map);
              // Ensure school_id is present for LocalDB filtering
              if (map['school_id'] == null && schoolId.isNotEmpty) {
                map['school_id'] = int.tryParse(schoolId);
              }
              return StudentDetailsData.fromJson(map);
            }).toList();
            
            // Save to LocalDB
            await _studentLocalDS.insertStudents(students);

            emit(state.copyWith(
              loading: false,
              studentsList: students,
            ));
            return;
          }
        }
      } catch (e) {
        debugPrint("fetchClassStudents API error: $e");
      }
    }

    // If offline or API fails, try LocalDB
    debugPrint("Fetching students from LocalDB for class $classId, school $schoolId");
    try {
      var localStudents = await _studentLocalDS.getStudents(
        schoolId: schoolId,
        classId: classId,
      );

      // Fallback: If not found, try searching without schoolId or with int
      if (localStudents.isEmpty) {
        debugPrint("No students found with schoolId string, trying without schoolId filter...");
        localStudents = await _studentLocalDS.getStudents(
          classId: classId,
        );
      }

      emit(state.copyWith(
        loading: false,
        studentsList: localStudents,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: "Failed to load offline data: $e",
      ));
    }
  }

  Future<void> _saveClassesToLocal(String schoolId, Map<String, dynamic> jsonData) async {
    try {
      final db = await DBHelper.db;
      final data = jsonData['data'] ?? jsonData;
      final List sessions = data['sessions'] ?? [];
      final List classes = data['classes'] ?? [];
      final List houses = data['houses'] ?? [];

      // Map sessions to match StudentFormDataModel.fromJson expectation (int for value)
      final sessionsJson = jsonEncode(sessions.map((s) => {
        'value': int.tryParse(s['value']?.toString() ?? s['id']?.toString() ?? '0') ?? 0,
        'label': s['label']?.toString() ?? s['name']?.toString() ?? ''
      }).toList());

      // Map classes to match StudentFormDataModel.fromJson expectation (int for id)
      final classesJson = jsonEncode(classes.map((c) => {
        'id': int.tryParse(c['id']?.toString() ?? '0') ?? 0,
        'name': c['name']?.toString() ?? '',
        'name_withprefix': c['name_withprefix']?.toString() ?? c['name']?.toString() ?? '',
        'sections': (c['sections'] as List? ?? []).map((s) => {
          'id': int.tryParse(s['id']?.toString() ?? '0') ?? 0,
          'name': s['name']?.toString() ?? ''
        }).toList(),
        'sections_ids': (c['sections_ids'] as List? ?? (c['sections'] as List? ?? []).map((s) => s['id']).toList())
            .map((id) => int.tryParse(id.toString()) ?? 0).toList(),
      }).toList());

      final housesJson = jsonEncode(houses.map((h) => {
        'id': int.tryParse(h['id']?.toString() ?? '0') ?? 0,
        'name': h['name']?.toString() ?? ''
      }).toList());

      await db.insert(
        'school_form_data',
        {
          'school_id': schoolId,
          'sessions_json': sessionsJson,
          'classes_json': classesJson,
          'houses_json': housesJson,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint("Classes saved to LocalDB for school: $schoolId");
    } catch (e) {
      debugPrint("Error saving classes to local: $e");
    }
  }

  Future<model.StudentFormDataModel?> _loadClassesFromLocal(String schoolId) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_data',
        where: 'school_id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      return model.StudentFormDataModel.fromJson({
        'sessions': jsonDecode(row['sessions_json'] as String? ?? '[]'),
        'classes': jsonDecode(row['classes_json'] as String? ?? '[]'),
        'houses': jsonDecode(row['houses_json'] as String? ?? '[]'),
      });
    } catch (e) {
      debugPrint("Error loading classes from local: $e");
      return null;
    }
  }

  void selectClass(String schoolId, String classId) {
    fetchClassStudents(schoolId: schoolId, classId: classId);
  }
}
