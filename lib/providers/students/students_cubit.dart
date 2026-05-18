import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/LoginModel.dart';
import 'package:idmitra/models/LogoutModel.dart';
import 'package:idmitra/models/home/PartnerDashboardModel.dart';
import 'package:idmitra/models/home/UserDetailsModel.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/school/school_state.dart';
import 'package:idmitra/providers/students/students_state.dart';
import 'package:connectivity_plus/connectivity_plus.dart';


class StudentsCubit extends Cubit<StudentsState> {
  StudentsCubit() : super(StudentsState());

  ApiManager apiManager = ApiManager();
  final localDS = StudentLocalDS();

  void applyFilters({
    String classId = "",
    List<int> sectionIds = const [],
    String gender = "",
    required String schoolId,
  }) {
    emit(state.copyWith(
      selectedClassId: classId,
      selectedSectionIds: sectionIds,
      selectedGender: gender,
      page: 1,
      hasMore: true,
    ));

    fetchStudents(
      classId: classId,
      sectionIds: sectionIds,
      gender: gender,
    );
  }

  void updateStudentInState(StudentDetailsData updated) {
    final updatedList = state.studentsList.map((s) {
      return s.uuid == updated.uuid ? updated : s;
    }).toList();
    emit(state.copyWith(studentsList: updatedList));
  }

  Future<void> syncOfflineStudents({required String schoolId}) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) && connectivity.length == 1) return;

    // Optional: Real internet check
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com');
      hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      hasInternet = false;
    }
    if (!hasInternet) return;

    final offlineStudents = await localDS.getOfflineStudents();
    if (offlineStudents.isEmpty) return;

    debugPrint("Syncing ${offlineStudents.length} offline students...");
    emit(state.copyWith(isSyncing: true));

    final token = await UserSecureStorage.fetchToken();
    final url = '${Config.baseUrl}auth/school/$schoolId/students';

    for (var student in offlineStudents) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(url));
        request.headers['Authorization'] = 'Bearer $token';
        request.headers['Accept'] = 'application/json';

        // Map student data to request fields
        final body = {
          'school_id': schoolId,
          'student_name': student.name,
          'name': student.name,
          'gender': student.gender?.toString().toLowerCase(),
          'date_of_birth': student.dob,
          'dob': student.dob,
          'student_email': student.email,
          'email': student.email,
          'student_phone': student.phone,
          'phone': student.phone,
          'father_name': student.fatherName,
          'father_phone': student.fatherPhone,
          'mother_name': student.motherName,
          'address': student.address,
          'school_session_id': student.schoolSessionId?.toString(),
          'school_class_id': student.schoolClassId?.toString(),
          'school_class_section_id': student.schoolClassSectionId?.toString(),
          'password': 'Student@123',
          'password_confirmation': 'Student@123',
          'is_moved': student.isExtra ? '1' : '0',
          'status': student.status?.toString() ?? '1',
        };

        body.forEach((k, v) {
          if (v != null && v.toString().isNotEmpty) {
            request.fields[k] = v.toString();
          }
        });

        // 🚀 Handle class assignment for existing students that are marked as is_offline = 1
        // (This happens when we assign a class to an extra student while offline)
        final isAssignmentOnly = student.uuid != null &&
            !student.uuid!.contains('-') &&
            student.schoolClassId != null;

        if (isAssignmentOnly) {
          final assignUrl = '${Config.baseUrl}auth/school/$schoolId/students/${student.uuid}/assign';
          final assignResponse = await http.post(
            Uri.parse(assignUrl),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'school_class_id': student.schoolClassId,
              if (student.schoolClassSectionId != null)
                'school_class_section_id': student.schoolClassSectionId,
            }),
          );

          if (assignResponse.statusCode == 200 || assignResponse.statusCode == 201) {
            // Mark as synced by updating is_offline = 0
            final syncedStudent = student.copyWith(isOffline: false);
            await localDS.insertStudents([syncedStudent]);
            debugPrint("Synced class assignment for: ${student.name}");
            continue; // Move to next student
          }
        }

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode == 200 || response.statusCode == 201) {
          final json = jsonDecode(response.body);
          final data = json['data'];
          if (data != null && data is Map<String, dynamic>) {
            // Delete offline temporary student
            await localDS.deleteStudent(student.uuid!);

            // Insert server student
            final newStudent = StudentDetailsData.fromJson(data);
            await localDS.insertStudents([newStudent]);
            debugPrint("Synced student: ${student.name}");
          }
        }
      } catch (e) {
        debugPrint("Error syncing student ${student.name}: $e");
      }
    }

    emit(state.copyWith(isSyncing: false));
    await fetchStudents();
  }

  Future<void> fetchStudents({
    String search = "",
    String gender = "",
    String classId = "",
    List<int> sectionIds = const [],
  }) async {

    emit(state.copyWith(loading: true));

    try {
      final localList = await localDS.getStudents(
        search: search,
        gender: gender,
        classId: classId,
        sectionIds: sectionIds,
      );

      print("FULL LOCAL DATA: ${localList.length}");

      emit(state.copyWith(
        loading: false,
        studentsList: localList,
        hasMore: false, // ❌ no pagination
        page: 1,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> syncAllStudents({
    required String schoolId,
    String search = "",
    String gender = "",
    String classId = "",
    List<int> sectionIds = const [],
  }) async {
    ///  START LOADING
    emit(state.copyWith(isSyncing: true));
    await localDS.clearStudents(); //  MUST
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      String url =
          "${Config.baseUrl}auth/school/$schoolId"
          "?perPage=50"
          "&search=$search"
          "&page=$page"
          "&gender=$gender"
          "&class_filters=$classId";

      if (sectionIds.isNotEmpty) {
        url += "&" + sectionIds
            .asMap()
            .entries
            .map((e) => "sectionsIds[${e.key}]=${e.value}")
            .join("&");
      }

      try {
        final response = await apiManager.getRequest(url);
        final jsonData = jsonDecode(response.body);

        List list = jsonData["data"]?["data"] ?? [];
        int total = jsonData["data"]["total"] ?? 0;

        List<StudentDetailsData> newList =
        list.map((e) => StudentDetailsData.fromJson(e)).toList();

        await localDS.insertStudents(newList);

        int count = await localDS.getCount();

        hasMore = count < total;
        page++;
        print("Sync count: $count");
        print("Sync total: $total");
        print("Sync stopped: $page");
        ///  STOP LOADING


        if(page == 2){
          await fetchStudents();
        }
        emit(state.copyWith(isSyncing: false));
      } catch (e) {
        print("Sync stopped: $e");
        break;
      }
    }

    print(" FULL DATA SYNC DONE");
  }

  void prependStudent(StudentDetailsData student) {
    emit(state.copyWith(
      studentsList: [student, ...state.studentsList],
    ));
  }

  Future<bool> deleteStudent(String studentUuid, String schoolId) async {
    try {
      // Check if student is offline
      final student = state.studentsList.firstWhere(
            (s) => s.uuid == studentUuid,
        orElse: () => StudentDetailsData(uuid: studentUuid),
      );

      if (student.isOffline) {
        debugPrint("Deleting offline student locally: $studentUuid");
        await localDS.deleteStudent(studentUuid);
        final updated = state.studentsList
            .where((s) => s.uuid != studentUuid)
            .toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }

      final result = await apiManager.deleteRequest(
        "${Config.baseUrl}${Routes.deleteStudent(schoolId, studentUuid)}",
      );
      if (result.statusCode == 200 || result.statusCode == 204 || result.statusCode == 404) {
        //  Remove from Local DB (even if 404, we want it gone from UI)
        await localDS.deleteStudent(studentUuid);

        final updated = state.studentsList
            .where((s) => s.uuid != studentUuid)
            .toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
    return false;
  }

  Future<void> fetchExtraStudents({String schoolId = ''}) async {
    emit(state.copyWith(extraLoading: true));
    try {
      // 1. Fetch from Local DB first
      final localExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraStudentsList: localExtra));

      // 2. Then try to sync from API if online
      final response = await apiManager.getRequest(
        "${Config.baseUrl}auth/school/$schoolId?is_moved=1",
      );

      if (response != null && response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        List list = jsonData["data"]?["data"] ?? [];
        final newList = list.map((e) {
          final s = StudentDetailsData.fromJson(e);
          return s.copyWith(isExtra: true);
        }).toList();

        // 🔥 FIX: Skip inserting students with null/empty names to avoid
        // overwriting valid local data with incomplete API responses
        final validNewList = newList
            .where((s) => s.name != null && s.name!.isNotEmpty)
            .toList();
        await localDS.insertStudents(validNewList);
      }

      // 3. Final fetch from Local DB to show merged results (local + synced)
      final finalExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraLoading: false, extraStudentsList: finalExtra));
    } catch (e) {
      // Still show local data even if API fails
      final localExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraLoading: false, extraStudentsList: localExtra));
      debugPrint("Fetch extra students error: $e");
    }
  }

  Future<bool> moveStudentToExtra(String studentUuid, String schoolId) async {
    try {
      final student = state.studentsList.firstWhere(
            (s) => s.uuid == studentUuid,
        orElse: () => StudentDetailsData(uuid: studentUuid),
      );

      if (student.isOffline) {
        // Mark as extra locally
        final updatedStudent = student.copyWith(isExtra: true);
        await localDS.insertStudents([updatedStudent]);

        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }

      final response = await apiManager.postWithoutRequest(
        "${Config.baseUrl}${Routes.moveStudentToExtra(schoolId, studentUuid)}",
      );
      if (response != null && (response.statusCode == 200 || response.statusCode == 201)) {
        //  Mark as extra in Local DB
        final updatedStudent = student.copyWith(isExtra: true);
        await localDS.insertStudents([updatedStudent]);

        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else if (response?.statusCode == 404) {
        //  Student not found on server, just mark as extra locally or remove?
        // User wants it in "Other Student" tab, so mark as extra locally
        final updatedStudent = student.copyWith(isExtra: true);
        await localDS.insertStudents([updatedStudent]);

        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }
    } catch (e) {
      debugPrint("Move to extra error: $e");
    }
    return false;
  }

  Future<bool> assignClass({
    required String studentUuid,
    required String schoolId,
    required int classId,
    int? sectionId,
  }) async {
    try {
      // 1. Get student from state (check both lists)
      StudentDetailsData? student;
      try {
        student = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
      } catch (_) {
        try {
          student = state.extraStudentsList.firstWhere((s) => s.uuid == studentUuid);
        } catch (_) {
          // 🚀 CRITICAL: Fetch from local DB to preserve name/fatherName if not in state
          student = await localDS.getStudentByUuid(studentUuid);
        }
      }

      if (student == null) {
        debugPrint("Student not found for assignment: $studentUuid");
        return false;
      }

      final updatedStudent = student.copyWith(
        schoolClassId: classId,
        schoolClassSectionId: sectionId,
        isExtra: false, // Move from extra to regular list
        isOffline: true, // Mark for syncing
      );

      // 2. Fetch class/section details from local cache to populate datumClass/section objects
      try {
        final db = await DBHelper.db;
        final rows = await db.query(
          'school_form_data',
          where: 'school_id = ?',
          whereArgs: [schoolId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          final classesList = jsonDecode(row['classes_json'] as String? ?? '[]') as List;
          final classData = classesList.firstWhere((c) => c['id'] == classId, orElse: () => null);
          if (classData != null) {
            final datumClass = Class.fromJson(classData);
            Section? section;
            if (sectionId != null) {
              final sectionsList = classData['sections'] as List? ?? [];
              final sectionData = sectionsList.firstWhere((s) => s['id'] == sectionId, orElse: () => null);
              if (sectionData != null) {
                section = Section.fromJson(sectionData);
              }
            }
            // Update the student model with full objects
            final fullyUpdatedStudent = updatedStudent.copyWith(
              datumClass: datumClass,
              section: section,
            );

            // 2. Always update locally first for offline support
            await localDS.insertStudents([fullyUpdatedStudent]);
                 final updatedExtra = state.extraStudentsList
                .where((s) => s.uuid != studentUuid)
                .toList();
            final updatedStudents = [
              fullyUpdatedStudent,
              ...state.studentsList.where((s) => s.uuid != studentUuid),
            ];

            emit(state.copyWith(
              extraStudentsList: updatedExtra,
              studentsList: updatedStudents,
            ));
          } else {
            // Fallback if class not found in cache
            await localDS.insertStudents([updatedStudent]);

            //  FIX: Remove existing entry by uuid before prepending
            final updatedExtra = state.extraStudentsList
                .where((s) => s.uuid != studentUuid)
                .toList();
            final updatedStudents = [
              updatedStudent,
              ...state.studentsList.where((s) => s.uuid != studentUuid),
            ];
            emit(state.copyWith(
                extraStudentsList: updatedExtra,
                studentsList: updatedStudents));
          }
        } else {
          // Fallback if no form data cached
          await localDS.insertStudents([updatedStudent]);

          //  FIX: Remove existing entry by uuid before prepending
          final updatedExtra = state.extraStudentsList
              .where((s) => s.uuid != studentUuid)
              .toList();
          final updatedStudents = [
            updatedStudent,
            ...state.studentsList.where((s) => s.uuid != studentUuid),
          ];
          emit(state.copyWith(
              extraStudentsList: updatedExtra,
              studentsList: updatedStudents));
        }
      } catch (e) {
        debugPrint("Error fetching class details from cache: $e");
        await localDS.insertStudents([updatedStudent]);

        //  FIX: Remove existing entry by uuid before prepending
        final updatedExtra = state.extraStudentsList
            .where((s) => s.uuid != studentUuid)
            .toList();
        final updatedStudents = [
          updatedStudent,
          ...state.studentsList.where((s) => s.uuid != studentUuid),
        ];
        emit(state.copyWith(
            extraStudentsList: updatedExtra,
            studentsList: updatedStudents));
      }

      // 4. Try to sync with server if online
      final connectivity = await Connectivity().checkConnectivity();
      if (!connectivity.contains(ConnectivityResult.none)) {
        final token = await UserSecureStorage.fetchToken();
        final url = '${Config.baseUrl}auth/school/$schoolId/students/$studentUuid/assign';

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'school_class_id': classId,
            if (sectionId != null) 'school_class_section_id': sectionId,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          debugPrint("Student class assigned and synced: $studentUuid");
          return true;
        } else {
          print("Server assign failed: ${response.body}");

        }
      }
      return true;
    } catch (e) {
      debugPrint("Assign class error: $e");
      return false;
    }
  }

  Future<bool> toggleStudentStatus(String studentUuid, String schoolId, int currentStatus) async {
    try {
      final student = state.studentsList.firstWhere(
            (s) => s.uuid == studentUuid,
        orElse: () => StudentDetailsData(uuid: studentUuid),
      );

      if (student.isOffline) {
        // Just update locally for offline students
        final newStatus = currentStatus == 1 ? 0 : 1;
        final updatedStudent = student.copyWith(status: newStatus);
        await localDS.insertStudents([updatedStudent]);

        final updated = state.studentsList.map((s) {
          if (s.uuid == studentUuid) return updatedStudent;
          return s;
        }).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }

      final token = await UserSecureStorage.fetchToken();
      final url = "${Config.baseUrl}${Routes.toggleStudentStatus(schoolId, studentUuid)}";
      final newStatusStr = currentStatus == 1 ? false : true;

      final result = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'status': newStatusStr}),
      );

      debugPrint('Student update status: ${result.statusCode} - ${result.body}');

      if (result.statusCode == 200 || result.statusCode == 201) {
        final json = jsonDecode(result.body);
        final newStatus = (json['data']['status'] as int?) ?? (currentStatus == 1 ? 0 : 1);

        //  Update in Local DB
        try {
          final studentToUpdate = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
          final updatedStudent = studentToUpdate.copyWith(status: newStatus);
          await localDS.insertStudents([updatedStudent]);
          debugPrint("Student status updated in local DB");
        } catch (e) {
          debugPrint("Error updating status in local DB: $e");
        }

        final updated = state.studentsList.map((s) {
          if (s.uuid == studentUuid) return s.copyWith(status: newStatus);
          return s;
        }).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else if (result.statusCode == 404) {
        //  Student not found on server, remove locally
        await localDS.deleteStudent(studentUuid);
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }
    } catch (e) {
      debugPrint("Toggle status error: $e");
    }
    return false;
  }
}