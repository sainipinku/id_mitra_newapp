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
import 'package:path_provider/path_provider.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';

class StudentsCubit extends Cubit<StudentsState> {
  StreamSubscription? _connectivitySubscription;
  String? _lastSchoolId;

  StudentsCubit() : super(StudentsState()) {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      // Jab bhi internet aaye, offline students sync karo
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;

      if (_lastSchoolId != null) {
        syncOfflineStudents(schoolId: _lastSchoolId!);
      } else {
        final school = await UserLocal.getSchool();
        final schoolId = school['schoolId'];
        if (schoolId != null && schoolId.isNotEmpty) {
          syncOfflineStudents(schoolId: schoolId);
        }
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  ApiManager apiManager = ApiManager();
  final localDS = StudentLocalDS();

  // ─────────────────────────────────────────────────────────────
  // INTERNET CHECK
  // ─────────────────────────────────────────────────────────────

  Future<bool> _hasInternet() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none) &&
          connectivity.length == 1) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }


  void updateStudentInState(StudentDetailsData updated) {
    final updatedList = state.studentsList.map((s) {
      return s.uuid == updated.uuid ? updated : s;
    }).toList();
    emit(state.copyWith(studentsList: updatedList));
  }

  void replaceStudentInState(String oldUuid, StudentDetailsData newStudent) {
    final updatedList = state.studentsList.map((s) {
      return s.uuid == oldUuid ? newStudent : s;
    }).toList();
    emit(state.copyWith(studentsList: updatedList));
  }

  void prependStudent(StudentDetailsData student) {
    emit(state.copyWith(
      studentsList: [student, ...state.studentsList],
    ));
  }


  void applyFilters({
    String classId = "",
    List<int> sectionIds = const [],
    String gender = "",
    required String schoolId,
  }) {
    _lastSchoolId = schoolId;
    emit(state.copyWith(
      selectedClassId: classId,
      selectedSectionIds: sectionIds,
      selectedGender: gender,
      page: 1,
      hasMore: true,
    ));

    fetchStudents(
      schoolId: schoolId,
      classId: classId,
      sectionIds: sectionIds,
      gender: gender,
    );
  }

  Future<void> fetchStudents({
    bool isLoadMore = false,
    String search = "",
    String schoolId = "",
    String gender = "",
    String classId = "",
    List<int> sectionIds = const [],
  }) async {
    // Agar pagination chal rahi hai ya aur data nahi hai toh return
    if (state.isPaginationLoading || (!state.hasMore && isLoadMore)) return;

    if (schoolId.isNotEmpty) {
      _lastSchoolId = schoolId;
    }

    const int perPage = 50;
    int currentPage = isLoadMore ? state.page : 1;
    int offset = (currentPage - 1) * perPage;

    if (!isLoadMore) {
      emit(state.copyWith(loading: true, page: 1, hasMore: true, studentsList: []));
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    try {
      // State ke filters use karo agar function mein nahi diye
      final usedClassId = classId.isEmpty ? state.selectedClassId : classId;
      final usedSectionIds = sectionIds.isEmpty ? state.selectedSectionIds : sectionIds;
      final usedGender = gender.isEmpty ? state.selectedGender : gender;

      // ── STEP 1: Local DB se data lo ─────────────────────────
      final effectiveSchoolId = schoolId.isEmpty ? _lastSchoolId : schoolId;

      final localList = await localDS.getStudents(
        schoolId: effectiveSchoolId ?? "",
        search: search,
        gender: usedGender,
        classId: usedClassId,
        sectionIds: usedSectionIds,
        limit: perPage,
        offset: offset,
      );

      // Pending/offline students hamesha fetch karo taaki wo kabhi disappear na ho
      final pendingStudents = await localDS.getOfflineStudents(
        schoolId: effectiveSchoolId ?? "",
      );

      final int totalLocalCount = await localDS.getCount(
        search: search,
        gender: usedGender,
        classId: usedClassId,
        sectionIds: usedSectionIds,
        schoolId: effectiveSchoolId ?? "",
      );

      debugPrint("LOCAL DATA: Page=${localList.length}, Pending=${pendingStudents.length}");

      if (localList.isNotEmpty || pendingStudents.isNotEmpty) {
        final Set<String> seenUuids = {};
        final List<StudentDetailsData> mergedLocal = [];

        for (var s in pendingStudents) {
          if (s.uuid != null && !seenUuids.contains(s.uuid)) {
            bool matchesSearch = search.isEmpty ||
                (s.name ?? "").toLowerCase().contains(search.toLowerCase());
            if (matchesSearch) {
              mergedLocal.add(s);
              seenUuids.add(s.uuid!);
            }
          }
        }

        // Phir page ke results
        for (var s in localList) {
          if (s.uuid != null && !seenUuids.contains(s.uuid)) {
            mergedLocal.add(s);
            seenUuids.add(s.uuid!);
          }
        }

        final updatedList = isLoadMore ? [...state.studentsList, ...mergedLocal] : mergedLocal;

        bool hasMoreLocal = (offset + perPage) < totalLocalCount;

        emit(state.copyWith(
          loading: false,
          isPaginationLoading: false,
          studentsList: updatedList,
          page: currentPage + 1,
          hasMore: hasMoreLocal || await _hasInternet(),
          total: totalLocalCount > state.total ? totalLocalCount : state.total,
        ));

        if (isLoadMore && localList.length == perPage) return;

        if (!await _hasInternet()) return;
      }

      // Server se data fetch karo
      if (effectiveSchoolId == null || effectiveSchoolId.isEmpty) {
        emit(state.copyWith(loading: false, isPaginationLoading: false));
        return;
      }

      if (!await _hasInternet()) {
        emit(state.copyWith(loading: false, isPaginationLoading: false));
        return;
      }

      String url = "${Config.baseUrl}auth/school/$effectiveSchoolId"
          "?perPage=$perPage"
          "&search=$search"
          "&page=$currentPage"
          "&gender=$usedGender"
          "&class_filters=$usedClassId";

      if (usedSectionIds.isNotEmpty) {
        url += "&" +
            usedSectionIds
                .asMap()
                .entries
                .map((e) => "sectionsIds[${e.key}]=${e.value}")
                .join("&");
      }

      final response = await apiManager.getRequest(url);
      if (response == null) {
        emit(state.copyWith(loading: false, isPaginationLoading: false));
        return;
      }

      final jsonData = jsonDecode(response.body);
      List list = jsonData["data"]?["data"] ?? [];
      final total = jsonData["data"]?["total"] ?? 0;

      List<StudentDetailsData> newList = list.map((e) => StudentDetailsData.fromJson(e)).toList();

      // Page-1 unfiltered fresh fetch: stale (server-deleted) records clean karo
      if (!isLoadMore && currentPage == 1 && search.isEmpty && usedClassId.isEmpty && usedGender.isEmpty && usedSectionIds.isEmpty) {
        await localDS.clearStudents(schoolId: effectiveSchoolId ?? "");
      }

      // API data local DB mein save karo
      await localDS.insertStudents(newList);

      final latestLocalList = await localDS.getStudents(
        schoolId: effectiveSchoolId ?? "",
        search: search,
        gender: usedGender,
        classId: usedClassId,
        sectionIds: usedSectionIds,
        limit: perPage,
        offset: offset,
      );

      final latestPending = await localDS.getOfflineStudents(
        schoolId: effectiveSchoolId ?? "",
      );

      final Set<String> seenUuids = {};
      final List<StudentDetailsData> finalMerged = [];

      // Pending students pehle (upar rahenge)
      for (var s in latestPending) {
        if (s.uuid != null && !seenUuids.contains(s.uuid)) {
          bool matchesSearch = search.isEmpty ||
              (s.name ?? "").toLowerCase().contains(search.toLowerCase());
          if (matchesSearch) {
            finalMerged.add(s);
            seenUuids.add(s.uuid!);
          }
        }
      }

      // Phir API/Local students
      for (var s in latestLocalList) {
        if (s.uuid != null && !seenUuids.contains(s.uuid)) {
          finalMerged.add(s);
          seenUuids.add(s.uuid!);
        }
      }

      List<StudentDetailsData> updatedList;
      if (isLoadMore) {
        final existingUuids = state.studentsList.map((e) => e.uuid).toSet();
        final trulyNew = finalMerged.where((e) => !existingUuids.contains(e.uuid)).toList();
        updatedList = [...state.studentsList, ...trulyNew];
      } else {
        updatedList = finalMerged;
      }

      emit(state.copyWith(
        loading: false,
        isPaginationLoading: false,
        studentsList: updatedList,
        page: currentPage + 1,
        hasMore: updatedList.length < (total as int),
        total: total,
      ));
    } catch (e) {
      emit(state.copyWith(loading: false, isPaginationLoading: false, error: e.toString()));
      debugPrint("fetchStudents error: $e");
    }
  }

  Future<void> syncAllStudents({
    required String schoolId,
    String search = "",
    String gender = "",
    String classId = "",
    List<int> sectionIds = const [],
  }) async {
    _lastSchoolId = schoolId;

    if (!await _hasInternet()) {
      debugPrint("Sync skipped: No internet");
      return;
    }

    emit(state.copyWith(isSyncing: true));

    try {
      await localDS.clearStudents(schoolId: schoolId);
      int page = 1;
      bool hasMore = true;

      while (hasMore) {
        String url = "${Config.baseUrl}auth/school/$schoolId"
            "?perPage=50"
            "&search=$search"
            "&page=$page"
            "&gender=$gender"
            "&class_filters=$classId";

        if (sectionIds.isNotEmpty) {
          url += "&" +
              sectionIds
                  .asMap()
                  .entries
                  .map((e) => "sectionsIds[${e.key}]=${e.value}")
                  .join("&");
        }

        final response = await apiManager.getRequest(url);
        if (response == null) break;

        final jsonData = jsonDecode(response.body);
        List list = jsonData["data"]?["data"] ?? [];
        int total = jsonData["data"]["total"] ?? 0;

        List<StudentDetailsData> newList = list.map((e) => StudentDetailsData.fromJson(e)).toList();

        await localDS.insertStudents(newList);

        int count = await localDS.getCount(schoolId: schoolId);
        hasMore = count < total;
        page++;

        emit(state.copyWith(total: total));

        if (page == 2) {
          await fetchStudents(schoolId: schoolId);
        }
      }
    } catch (e) {
      debugPrint("Sync stopped: $e");
    } finally {
      emit(state.copyWith(isSyncing: false));
      await fetchStudents(schoolId: schoolId);
      debugPrint("FULL DATA SYNC DONE");
    }
  }

  Future<void> syncOfflineStudents({required String schoolId}) async {
    _lastSchoolId = schoolId;
    if (!await _hasInternet()) return;

    final offlineStudents = await localDS.getOfflineStudents(schoolId: schoolId);
    if (offlineStudents.isEmpty) return;

    debugPrint("Syncing ${offlineStudents.length} offline students...");
    emit(state.copyWith(isSyncing: true));

    try {
      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}auth/school/$schoolId/students';

      for (var student in offlineStudents) {
        try {
          StudentDetailsData currentStudent = student;

          // ── CASE A: Delete sync (sabse pehle check karo) ────
          if (currentStudent.isDeletePendingSync) {
            final success = await _syncDelete(
              token: token,
              schoolId: schoolId,
              student: currentStudent,
            );
            if (success) {
              await localDS.deleteStudent(currentStudent.uuid!);
              debugPrint("Synced delete for: ${currentStudent.name}");
            } else {
              debugPrint("Delete sync failed for: ${currentStudent.name}, will retry later.");
            }
            continue; // Is student ke baaki cases skip karo
          }

          // ── CASE B: Extra-pending sync ───────────────────────
          if (currentStudent.isExtraPendingSync) {
            final success = await _syncMoveToExtra(
              token: token,
              schoolId: schoolId,
              student: currentStudent,
            );
            if (success) {
              currentStudent = currentStudent.copyWith(
                isOffline: false,
                isExtraPendingSync: false,
              );
              await localDS.insertStudents([currentStudent], forceUpdate: true);
              updateStudentInState(currentStudent);
              debugPrint("Synced extra move for: ${currentStudent.name}");
            }
          }
          // ── CASE C: Naya offline student ─────────────────────
          else if (currentStudent.uuid != null &&
              currentStudent.uuid!.startsWith('offline_')) {
            Map<String, dynamic> body;
            if (currentStudent.offlineFieldsJson != null &&
                currentStudent.offlineFieldsJson!.isNotEmpty) {
              final originalFields = jsonDecode(currentStudent.offlineFieldsJson!)
              as Map<String, dynamic>;
              body = _buildSyncBody(schoolId, originalFields);
            } else {
              body = _buildBodyFromStudent(schoolId, currentStudent);
            }

            final request = http.MultipartRequest('POST', Uri.parse(url));
            request.headers['Authorization'] = 'Bearer $token';
            request.headers['Accept'] = 'application/json';
            body.forEach((k, v) {
              if (v != null && v.toString().isNotEmpty) {
                request.fields[k] = v.toString();
              }
            });

            final streamed = await request.send();
            final response = await http.Response.fromStream(streamed);

            if (response.statusCode == 200 || response.statusCode == 201) {
              final json = jsonDecode(response.body);
              final data = json['data'];
              if (data != null && data is Map<String, dynamic>) {
                final oldUuid = currentStudent.uuid!;
                await localDS.deleteStudent(oldUuid);
                var newStudent = StudentDetailsData.fromJson(data);
                if (currentStudent.isPhotoPendingSync) {
                  newStudent = newStudent.copyWith(
                    isPhotoPendingSync: true,
                    offlinePhotoPath: currentStudent.offlinePhotoPath,
                  );
                }
                currentStudent = newStudent;
                await localDS.insertStudents([currentStudent], forceUpdate: true);
                replaceStudentInState(oldUuid, currentStudent);
                debugPrint("Synced new student: ${currentStudent.name}");
              }
            }
          }
          // ── CASE D: Offline update ───────────────────────────
          else if (currentStudent.isOfflineUpdate) {
            Map<String, dynamic> body;
            if (currentStudent.offlineFieldsJson != null &&
                currentStudent.offlineFieldsJson!.isNotEmpty) {
              final originalFields = jsonDecode(currentStudent.offlineFieldsJson!)
              as Map<String, dynamic>;
              body = _buildSyncBody(schoolId, originalFields);
            } else {
              body = _buildBodyFromStudent(schoolId, currentStudent);
            }

            final putUrl = '${Config.baseUrl}auth/school/$schoolId/students/${currentStudent.uuid}';
            final putRequest = http.MultipartRequest('PUT', Uri.parse(putUrl));
            putRequest.headers['Authorization'] = 'Bearer $token';
            putRequest.headers['Accept'] = 'application/json';
            body.forEach((k, v) {
              if (v != null && v.toString().isNotEmpty) {
                putRequest.fields[k] = v.toString();
              }
            });

            final putStreamed = await putRequest.send();
            final putResponse = await http.Response.fromStream(putStreamed);

            if (putResponse.statusCode == 200 || putResponse.statusCode == 201) {
              final json = jsonDecode(putResponse.body);
              final data = json['data'];
              if (data != null && data is Map<String, dynamic>) {
                final oldUuid = currentStudent.uuid!;
                await localDS.deleteStudent(oldUuid);
                var updatedFromServer = StudentDetailsData.fromJson(data);
                if (currentStudent.isPhotoPendingSync) {
                  updatedFromServer = updatedFromServer.copyWith(
                    isPhotoPendingSync: true,
                    offlinePhotoPath: currentStudent.offlinePhotoPath,
                  );
                }
                currentStudent = updatedFromServer;
                await localDS.insertStudents([currentStudent], forceUpdate: true);
                updateStudentInState(currentStudent);
                debugPrint("Synced offline update for: ${currentStudent.name}");
              }
            }
          }
          // ── CASE E: Assignment-only ──────────────────────────
          else if (currentStudent.isOffline &&
              currentStudent.uuid != null &&
              !currentStudent.uuid!.startsWith('offline_') &&
              currentStudent.uuid!.contains('-') &&
              currentStudent.schoolClassId != null) {
            final assignUrl = '${Config.baseUrl}auth/school/$schoolId/students/${currentStudent.uuid}/assign';
            final assignResponse = await http.post(
              Uri.parse(assignUrl),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'school_class_id': currentStudent.schoolClassId,
                if (currentStudent.schoolClassSectionId != null)
                  'school_class_section_id': currentStudent.schoolClassSectionId,
              }),
            );

            if (assignResponse.statusCode == 200 || assignResponse.statusCode == 201) {
              currentStudent = currentStudent.copyWith(isOffline: false);
              await localDS.insertStudents([currentStudent], forceUpdate: true);
              updateStudentInState(currentStudent);
              debugPrint("Synced class assignment for: ${currentStudent.name}");
            }
          }
          // ── CASE F: Status toggle sync ───────────────────────
          else if (currentStudent.isStatusPendingSync) {
            final success = await _syncStatusToggle(
              token: token,
              schoolId: schoolId,
              student: currentStudent,
            );
            if (success) {
              currentStudent = currentStudent.copyWith(isStatusPendingSync: false);
              await localDS.insertStudents([currentStudent], forceUpdate: true);
              updateStudentInState(currentStudent);
              debugPrint("Synced status toggle for: ${currentStudent.name}");
            }
          }
          // ── CASE G: Photo-only pending sync ─────────────────
          else if (currentStudent.isPhotoPendingSync) {
            debugPrint("Photo-only pending for: ${currentStudent.name}");
          }

          // ── Photo sync (sab cases ke baad) ──────────────────
          if (currentStudent.isPhotoPendingSync &&
              currentStudent.offlinePhotoPath != null) {
            await _syncStudentPhoto(currentStudent);
          } else if (currentStudent.isPhotoPendingSync &&
              currentStudent.offlinePhotoPath == null) {
            debugPrint("Photo pending but no local path for: ${currentStudent.name}, clearing flag");
            final cleared = currentStudent.copyWith(isPhotoPendingSync: false);
            await localDS.insertStudents([cleared], forceUpdate: true);
            updateStudentInState(cleared);
          }
        } catch (e) {
          debugPrint("Error syncing student ${student.name}: $e");
        }
      }
    } catch (e) {
      debugPrint("syncOfflineStudents main error: $e");
    } finally {
      emit(state.copyWith(isSyncing: false));
      await fetchStudents(schoolId: schoolId);
      final extraList = await localDS.getExtraStudents();
      emit(state.copyWith(extraStudentsList: extraList));
    }
  }

  Future<bool> deleteStudent(String studentUuid, String schoolId) async {
    try {
      final student = state.studentsList.firstWhere(
            (s) => s.uuid == studentUuid,
        orElse: () => StudentDetailsData(uuid: studentUuid),
      );

      if (!await _hasInternet()) {
        debugPrint("Deleting student locally (offline): $studentUuid");
        if (studentUuid.startsWith('offline_')) {
          await localDS.deleteStudent(studentUuid);
        } else {
          final updatedStudent = student.copyWith(isDeletePendingSync: true);
          await localDS.insertStudents([updatedStudent]);
        }
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      }

      final result = await apiManager.deleteRequest(
        "${Config.baseUrl}${Routes.deleteStudent(schoolId, studentUuid)}",
      );
      if (result.statusCode == 200 || result.statusCode == 204 || result.statusCode == 404) {
        await localDS.deleteStudent(studentUuid);
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      return false;
    }
  }

  Future<void> fetchExtraStudents({String schoolId = ''}) async {
    emit(state.copyWith(extraLoading: true));
    try {
      // Pehle local data dikhao
      final localExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraStudentsList: localExtra));

      if (!await _hasInternet()) {
        emit(state.copyWith(extraLoading: false));
        return;
      }

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

        final validNewList = newList.where((s) => s.name != null && s.name!.isNotEmpty).toList();
        await localDS.insertStudents(validNewList);
      }

      final finalExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraLoading: false, extraStudentsList: finalExtra));
    } catch (e) {
      final localExtra = await localDS.getExtraStudents();
      emit(state.copyWith(extraLoading: false, extraStudentsList: localExtra));
      debugPrint("Fetch extra students error: $e");
    }
  }

  Future<bool> moveStudentToExtra(String studentUuid, String schoolId) async {
    StudentDetailsData? student;
    try {
      student = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
    } catch (_) {
      try {
        student = await localDS.getStudentByUuid(studentUuid);
      } catch (_) {}
    }

    if (student == null) {
      debugPrint("Move to extra failed: Student not found locally");
      return false;
    }

    try {
      if (!await _hasInternet()) {
        return _performMoveToExtraOffline(student, studentUuid);
      }

      final response = await apiManager.postWithoutRequest(
        "${Config.baseUrl}${Routes.moveStudentToExtra(schoolId, studentUuid)}",
      );

      if (response != null &&
          (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 404)) {
        final updatedStudent = student.copyWith(isExtra: true, isOffline: false);
        await localDS.insertStudents([updatedStudent]);
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else {
        return _performMoveToExtraOffline(student, studentUuid);
      }
    } catch (e) {
      debugPrint("Move to extra error: $e");
      return _performMoveToExtraOffline(student, studentUuid);
    }
  }

  Future<bool> _performMoveToExtraOffline(StudentDetailsData student, String studentUuid) async {
    final updatedStudent = student.copyWith(
      isExtra: true,
      isExtraPendingSync: true,
      isOffline: true,
      isOfflineUpdate: false,
    );
    await localDS.insertStudents([updatedStudent]);
    final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
    emit(state.copyWith(studentsList: updated));
    debugPrint("Student moved to extra offline: $studentUuid");
    return true;
  }

  Future<bool> assignClass({
    required String studentUuid,
    required String schoolId,
    required int classId,
    int? sectionId,
  }) async {
    try {
      StudentDetailsData? student;
      try {
        student = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
      } catch (_) {
        try {
          student = state.extraStudentsList.firstWhere((s) => s.uuid == studentUuid);
        } catch (_) {
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
        isExtra: false,
        isOffline: true,
        isOfflineUpdate: false,
      );

      StudentDetailsData fullyUpdatedStudent = updatedStudent;
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
          final classData = classesList.firstWhere(
                (c) => c['id'] == classId,
            orElse: () => null,
          );
          if (classData != null) {
            final datumClass = Class.fromJson(classData);
            Section? section;
            if (sectionId != null) {
              final sectionsList = classData['sections'] as List? ?? [];
              final sectionData = sectionsList.firstWhere(
                    (s) => s['id'] == sectionId,
                orElse: () => null,
              );
              if (sectionData != null) {
                section = Section.fromJson(sectionData);
              }
            }
            fullyUpdatedStudent = updatedStudent.copyWith(
              datumClass: datumClass,
              section: section,
            );
          }
        }
      } catch (e) {
        debugPrint("Error fetching class details from cache: $e");
      }

      await localDS.insertStudents([fullyUpdatedStudent]);

      final updatedExtra = state.extraStudentsList.where((s) => s.uuid != studentUuid).toList();
      final updatedStudents = [
        fullyUpdatedStudent,
        ...state.studentsList.where((s) => s.uuid != studentUuid),
      ];
      emit(state.copyWith(
        extraStudentsList: updatedExtra,
        studentsList: updatedStudents,
      ));

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
          final syncedStudent = fullyUpdatedStudent.copyWith(isOffline: false);
          await localDS.insertStudents([syncedStudent]);
          debugPrint("Student class assigned and synced online: $studentUuid");
        } else {
          debugPrint("Server assign failed (${response.statusCode}): ${response.body}");
        }
      } else {
        debugPrint("Device offline — assignment queued for sync: $studentUuid");
      }

      return true;
    } catch (e) {
      debugPrint("Assign class error: $e");
      return false;
    }
  }

  Future<bool> toggleStudentStatus(
      String studentUuid,
      String schoolId,
      int currentStatus,
      ) async {
    try {
      final student = state.studentsList.firstWhere(
            (s) => s.uuid == studentUuid,
        orElse: () => StudentDetailsData(uuid: studentUuid),
      );

      if (!await _hasInternet()) {
        final newStatus = currentStatus == 1 ? 0 : 1;
        final updatedStudent = student.copyWith(
          status: newStatus,
          isStatusPendingSync: true,
        );
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

      debugPrint('Toggle status: ${result.statusCode} - ${result.body}');

      if (result.statusCode == 200 || result.statusCode == 201) {
        final json = jsonDecode(result.body);
        final newStatus = (json['data']['status'] as int?) ?? (currentStatus == 1 ? 0 : 1);

        try {
          final studentToUpdate = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
          final updatedStudent = studentToUpdate.copyWith(status: newStatus);
          await localDS.insertStudents([updatedStudent]);
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
        await localDS.deleteStudent(studentUuid);
        final updated = state.studentsList.where((s) => s.uuid != studentUuid).toList();
        emit(state.copyWith(studentsList: updated));
        return true;
      } else {
        return false;
      }
    } catch (e) {
      debugPrint("Toggle status error: $e");
      return false;
    }
  }

  Future<void> uploadStudentImage({
    required String path,
    required StudentDetailsData student,
  }) async {
    final hasInternet = await _hasInternet();

    if (hasInternet) {
      // Online: Direct upload
      try {
        File fixedImage = await FlutterExifRotation.rotateImage(path: path);
        print("=== IMAGE UPLOAD URL: $fixedImage ===");

        var response = await apiManager.multiRequestRoute(
          fixedImage.path,
          Config.baseUrl + Routes.updateStudentProfile(student.uuid ?? ''),
        );
        print("IMAGE UPLOAD RESPONSE STATUS: ${response.statusCode} ===");
        print("IMAGE UPLOAD RESPONSE BODY: ${response.body} ===");
        debugPrint("uploadStudentImage status: ${response.statusCode}, body: ${response.body}");

        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          final updated = student.copyWith(
            profilePhotoUrl: jsonData['data']['profile_photo_url'],
            isPhotoPendingSync: false,
            clearOfflinePhotoPath: true,
          );
          await localDS.insertStudents([updated], forceUpdate: true);
          updateStudentInState(updated);
        }
      } catch (e) {
        debugPrint("Online upload error: $e");
      }
    } else {
      // Offline: Save locally
      try {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'student_photo_${student.uuid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedPath = '${directory.path}/$fileName';

        await File(path).copy(savedPath);

        final updated = student.copyWith(
          isPhotoPendingSync: true,
          offlinePhotoPath: savedPath,
        );

        await localDS.insertStudents([updated], forceUpdate: true);
        updateStudentInState(updated);
        debugPrint("Offline photo saved: $savedPath");
      } catch (e) {
        debugPrint("Offline photo save error: $e");
      }
    }
  }

  Future<void> _syncStudentPhoto(StudentDetailsData student) async {
    if (!student.isPhotoPendingSync || student.offlinePhotoPath == null) return;

    final file = File(student.offlinePhotoPath!);
    final exists = await file.exists();

    if (!exists) {
      // File missing — flag clear karo taaki dobara retry na ho
      debugPrint("Offline photo file not found for: ${student.name} at ${student.offlinePhotoPath}");
      final cleared = student.copyWith(isPhotoPendingSync: false, clearOfflinePhotoPath: true);
      await localDS.insertStudents([cleared], forceUpdate: true);
      updateStudentInState(cleared);
      return;
    }

    try {
      debugPrint("Uploading offline photo for: ${student.name}");
      final photoResponse = await apiManager.multiRequestRoute(
        file.path,
        Config.baseUrl + Routes.updateStudentProfile(student.uuid ?? ''),
      );
      debugPrint("Photo sync response: ${photoResponse.statusCode} for ${student.name}");
      if (photoResponse.statusCode == 200) {
        final photoJson = jsonDecode(photoResponse.body);
        final newUrl = photoJson['data']?['profile_photo_url'] as String?;
        final updatedWithPhoto = student.copyWith(
          profilePhotoUrl: newUrl,
          isPhotoPendingSync: false,
          clearOfflinePhotoPath: true,
        );
        await localDS.insertStudents([updatedWithPhoto], forceUpdate: true);
        updateStudentInState(updatedWithPhoto);
        debugPrint("Synced offline photo for: ${student.name}, url: $newUrl");
        try {
          await file.delete();
        } catch (_) {}
      } else {
        debugPrint("Photo sync failed (${photoResponse.statusCode}): ${photoResponse.body}");
      }
    } catch (e) {
      debugPrint("Error syncing photo for ${student.name}: $e");
    }
  }

  Future<bool> _syncMoveToExtra({
    required String? token,
    required String schoolId,
    required StudentDetailsData student,
  }) async {
    try {
      final url = '${Config.baseUrl}${Routes.moveStudentToExtra(schoolId, student.uuid ?? '')}';
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 404;
    } catch (e) {
      debugPrint("_syncMoveToExtra error: $e");
      return false;
    }
  }

  Future<bool> _syncStatusToggle({
    required String? token,
    required String schoolId,
    required StudentDetailsData student,
  }) async {
    try {
      final url = "${Config.baseUrl}${Routes.toggleStudentStatus(schoolId, student.uuid ?? '')}";
      final response = await http.patch(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'status': student.status == 1}),
      );
      return response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 404;
    } catch (e) {
      debugPrint("_syncStatusToggle error: $e");
      return false;
    }
  }

  Future<bool> _syncDelete({
    required String? token,
    required String schoolId,
    required StudentDetailsData student,
  }) async {
    try {
      final url = "${Config.baseUrl}${Routes.deleteStudent(schoolId, student.uuid ?? '')}";
      final response = await http.delete(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      return response.statusCode == 200 || response.statusCode == 204 || response.statusCode == 404;
    } catch (e) {
      debugPrint("_syncDelete error: $e");
      return false;
    }
  }

  Map<String, dynamic> _buildBodyFromStudent(String schoolId, StudentDetailsData student) {
    return {
      'school_id': schoolId,
      'student_name': student.name,
      'name': student.name,
      'gender': student.gender?.toString().toLowerCase(),
      'date_of_birth': student.dob,
      'dob': student.dob,
      'student_email': student.email?.toString(),
      'email': student.email?.toString(),
      'student_phone': student.phone?.toString(),
      'phone': student.phone?.toString(),
      'whatsapp_phone': student.whatsappPhone?.toString(),
      'land_line_no': student.landLineNo?.toString(),
      'aadhar_no': student.aadharNo?.toString(),
      'aadhar_card_number': student.aadharNo?.toString(),
      'uid_no': student.uidNo?.toString(),
      'pan_no': student.panNo?.toString(),
      'caste': student.caste?.toString(),
      'religion': student.religion?.toString(),
      'is_rte_student': student.isRteStudent?.toString(),
      'address': student.address,
      'pincode': student.pincode?.toString(),
      'reg_no': student.regNo?.toString(),
      'registration_number': student.regNo?.toString(),
      'roll_no': student.rollNo?.toString(),
      'roll_number': student.rollNo?.toString(),
      'admission_no': student.admissionNo?.toString(),
      'admission_number': student.admissionNo?.toString(),
      'sr_no': student.srNo,
      'rfid_no': student.rfidNo?.toString(),
      'blood_group': student.bloodGroup?.toString(),
      'transport_mode': student.transportMode?.toString(),
      'father_name': student.fatherName,
      'father_email': student.fatherEmail?.toString(),
      'father_phone': student.fatherPhone,
      'father_wphone': student.fatherWphone?.toString(),
      'mother_name': student.motherName,
      'mother_email': student.motherEmail?.toString(),
      'mother_phone': student.motherPhone?.toString(),
      'mother_wphone': student.motherWphone?.toString(),
      'school_session_id': student.schoolSessionId?.toString(),
      'session': student.schoolSessionId?.toString(),
      'school_class_id': student.schoolClassId?.toString(),
      'class': student.schoolClassId?.toString(),
      'school_class_section_id': student.schoolClassSectionId?.toString(),
      'school_house_id': student.schoolHouseId?.toString(),
      'password': 'Student@123',
      'password_confirmation': 'Student@123',
      'is_moved': student.isExtra ? '1' : '0',
      'status': student.status?.toString() ?? '1',
    };
  }

  Map<String, dynamic> _buildSyncBody(String schoolId, Map<String, dynamic> fields) {
    final gender = fields['gender']?.toString().toLowerCase();
    final cleanGender = (gender == null || gender == '-select gender-') ? null : gender;

    String? dob;
    final dobRaw = fields['date_of_birth']?.toString();
    if (dobRaw != null && dobRaw.isNotEmpty) {
      final parts = dobRaw.split(RegExp(r'[./\-]'));
      if (parts.length == 3) {
        final day = parts[0].padLeft(2, '0');
        final month = parts[1].padLeft(2, '0');
        final year = parts[2];
        dob = '$year-$month-$day';
      } else {
        dob = dobRaw;
      }
    }

    String? f(List<String> keys) {
      for (final k in keys) {
        final v = fields[k]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
      return null;
    }

    final password = f(['password']);
    final passwordConfirmation = f(['password_confirmation']);
    final finalPassword = (password != null && password.isNotEmpty) ? password : 'Student@123';
    final finalPasswordConfirmation = (password != null && password.isNotEmpty)
        ? (passwordConfirmation ?? password)
        : 'Student@123';

    return {
      'school_id': schoolId,
      'student_name': f(['student_name']),
      'name': f(['student_name']),
      'dob': dob,
      'date_of_birth': dob,
      'gender': cleanGender,
      'blood_group': f(['blood_group']),
      'email': f(['student_email']),
      'student_email': f(['student_email']),
      'phone': f(['student_phone']),
      'student_phone': f(['student_phone']),
      'whatsapp_phone': f([
        'student_whatsapp_number',
        'student_whatsapp',
        'whatsapp_number',
      ]),
      'student_whatsapp_number': f([
        'student_whatsapp_number',
        'student_whatsapp',
      ]),
      'land_line_no': f(['landline_contact_number', 'landline_number', 'land_line_no']),
      'landline_contact_number': f(['landline_contact_number', 'landline_number']),
      'aadhar_no': f(['aadhar_card_number', 'aadhar_no']),
      'aadhar_card_number': f(['aadhar_card_number', 'aadhar_no']),
      'uid_no': f(['uid_number', 'uid_no']),
      'uid_number': f(['uid_number', 'uid_no']),
      'student_nic_id': f(['student_nic_id', 'nic_id']),
      'pan_no': f(['pen_number', 'pan_number', 'pan_no']),
      'pen_number': f(['pen_number', 'pan_number', 'pan_no']),
      'caste': f(['caste']),
      'religion': f(['religion']),
      'is_rte_student': f(['is_rte_student']),
      'address': f(['address']),
      'pincode': f(['pincode']),
      'school_session_id': fields['session']?.toString(),
      'session': fields['session']?.toString(),
      'school_class_id': f(['class', 'school_class_id']),
      'class': f(['class', 'school_class_id']),
      'school_class_section_id': f(['class_section', 'school_class_section_id', 'section']),
      'class_section': f(['class_section', 'school_class_section_id', 'section']),
      'school_house_id': f(['house', 'school_house_id']),
      'house': f(['house', 'school_house_id']),
      'reg_no': f(['registration_number', 'reg_no']),
      'registration_number': f(['registration_number', 'reg_no']),
      'roll_no': f(['roll_number', 'roll_no']),
      'roll_number': f(['roll_number', 'roll_no']),
      'admission_no': f(['admission_number', 'admission_no']),
      'admission_number': f(['admission_number', 'admission_no']),
      'sr_no': f(['sr_number', 'sr_no']),
      'sr_number': f(['sr_number', 'sr_no']),
      'rfid_no': f(['rfid_number', 'rfid_no']),
      'rfid_number': f(['rfid_number', 'rfid_no']),
      'transport_mode': f(['transport_mode']),
      'father_name': f(['father_name']),
      'father_email': f(['father_email']),
      'father_phone': f(['father_phone']),
      'father_wphone': f(['father_whatsapp_number', 'father_whatsapp']),
      'mother_name': f(['mother_name']),
      'mother_email': f(['mother_email']),
      'mother_phone': f(['mother_phone']),
      'mother_wphone': f(['mother_whatsapp_number', 'mother_whatsapp']),
      'password': finalPassword,
      'password_confirmation': finalPasswordConfirmation,
    };
  }
}