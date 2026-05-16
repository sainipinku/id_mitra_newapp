

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

        final method = student.uuid != null && !student.uuid!.contains('-') 
            ? 'POST' // If it's a real UUID from server, it might need PUT/POST for update
            : 'POST'; // For new offline students
        
        // Note: If we had a separate Update API, we'd check if student.id != null
        // But for now, we treat all offline-created/updated students as POST to the main endpoint
        // or a specific update endpoint if available.

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
    /// 🔥 START LOADING
    emit(state.copyWith(isSyncing: true));
    await localDS.clearStudents(); // 🔥 MUST
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
        /// 🔥 STOP LOADING


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
        // 🔥 Remove from Local DB (even if 404, we want it gone from UI)
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
      final jsonData = jsonDecode(response.body);
      List list = jsonData["data"]?["data"] ?? [];
      final newList = list.map((e) {
        final s = StudentDetailsData.fromJson(e);
        return s.copyWith(isExtra: true);
      }).toList();
      
      // Save synced extra students to local DB
      await localDS.insertStudents(newList);
      
      emit(state.copyWith(extraLoading: false, extraStudentsList: newList));
    } catch (e) {
      emit(state.copyWith(extraLoading: false));
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
        // 🔥 Mark as extra in Local DB
        final updatedStudent = student.copyWith(isExtra: true);
        await localDS.insertStudents([updatedStudent]);
        
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else if (response?.statusCode == 404) {
        // 🔥 Student not found on server, just mark as extra locally or remove? 
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

        // 🔥 Update in Local DB
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
        // 🔥 Student not found on server, remove locally
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