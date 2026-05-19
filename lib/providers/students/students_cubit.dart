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
            if (_lastSchoolId != null) {
              syncOfflineStudents(schoolId: _lastSchoolId!);
            } else {
              // Try to get schoolId from local storage if not set in memory
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

        void applyFilters({
          String classId = "",
          List<int> sectionIds = const [],
          String gender = "",
          required String schoolId,
        }) {
          _lastSchoolId = schoolId;
          emit(
            state.copyWith(
              selectedClassId: classId,
              selectedSectionIds: sectionIds,
              selectedGender: gender,
              page: 1,
              hasMore: true,
            ),
          );

          fetchStudents(classId: classId, sectionIds: sectionIds, gender: gender);
        }

        void updateStudentInState(StudentDetailsData updated) {
          final updatedList = state.studentsList.map((s) {
            return s.uuid == updated.uuid ? updated : s;
          }).toList();
          emit(state.copyWith(studentsList: updatedList));
        }

        Future<void> syncOfflineStudents({required String schoolId}) async {
          _lastSchoolId = schoolId;
          final connectivity = await Connectivity().checkConnectivity();
          if (connectivity.contains(ConnectivityResult.none) &&
              connectivity.length == 1) return;

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
          final url  = '${Config.baseUrl}auth/school/$schoolId/students';

          for (var student in offlineStudents) {
            try {
              StudentDetailsData currentStudent = student;

              // ── CASE A: Extra-pending sync (move-to-extra offline) ─────────────
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
                  await localDS.insertStudents([currentStudent]);
                  debugPrint("Synced extra move for: ${currentStudent.name}");
                }
              }
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
                    await localDS.deleteStudent(currentStudent.uuid!);
                    var newStudent = StudentDetailsData.fromJson(data);

                    // Carry over photo flags if any
                    if (currentStudent.isPhotoPendingSync) {
                      newStudent = newStudent.copyWith(
                        isPhotoPendingSync: true,
                        offlinePhotoPath: currentStudent.offlinePhotoPath,
                      );
                    }

                    currentStudent = newStudent;
                    await localDS.insertStudents([currentStudent]);
                    debugPrint("Synced new student: ${currentStudent.name}");
                  }
                }
              }
              // ──  Offline update (existing student edited offline)
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

                final putUrl =
                    '${Config.baseUrl}auth/school/$schoolId/students/${currentStudent.uuid}';
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
                    await localDS.deleteStudent(currentStudent.uuid!);
                    var updatedFromServer = StudentDetailsData.fromJson(data);

                    // Carry over photo flags if any
                    if (currentStudent.isPhotoPendingSync) {
                      updatedFromServer = updatedFromServer.copyWith(
                        isPhotoPendingSync: true,
                        offlinePhotoPath: currentStudent.offlinePhotoPath,
                      );
                    }

                    currentStudent = updatedFromServer;
                    await localDS.insertStudents([currentStudent]);
                    debugPrint("Synced offline update for: ${currentStudent.name}");
                  }
                }
              }
              // ──  Assignment-only
              else if (currentStudent.uuid != null &&
                  !currentStudent.uuid!.startsWith('offline_') &&
                  currentStudent.uuid!.contains('-') &&
                  currentStudent.schoolClassId != null) {
                final assignUrl =
                    '${Config.baseUrl}auth/school/$schoolId/students/${currentStudent.uuid}/assign';
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

                if (assignResponse.statusCode == 200 ||
                    assignResponse.statusCode == 201) {
                  currentStudent = currentStudent.copyWith(isOffline: false);
                  await localDS.insertStudents([currentStudent]);
                  debugPrint("Synced class assignment for: ${currentStudent.name}");
                }
              }
              // ──  Status toggle sync
              else if (currentStudent.isStatusPendingSync) {
                final success = await _syncStatusToggle(
                  token: token,
                  schoolId: schoolId,
                  student: currentStudent,
                );
                if (success) {
                  currentStudent = currentStudent.copyWith(isStatusPendingSync: false);
                  await localDS.insertStudents([currentStudent]);
                  debugPrint("Synced status toggle for: ${currentStudent.name}");
                }
              }
              // ──  Delete sync
              else if (currentStudent.isDeletePendingSync) {
                final success = await _syncDelete(
                  token: token,
                  schoolId: schoolId,
                  student: currentStudent,
                );
                if (success) {
                  await localDS.deleteStudent(currentStudent.uuid!);
                  debugPrint("Synced delete for: ${currentStudent.name}");
                  continue; // Student deleted, move to next
                }
              }

              //  Pending photo sync
              if (currentStudent.isPhotoPendingSync &&
                  currentStudent.offlinePhotoPath != null) {
                await _syncStudentPhoto(currentStudent);
              }
            } catch (e) {
              debugPrint("Error syncing student ${student.name}: $e");
            }
          }

          emit(state.copyWith(isSyncing: false));
          await fetchStudents();
          final extraList = await localDS.getExtraStudents();
          emit(state.copyWith(extraStudentsList: extraList));
        }

        Future<void> _syncStudentPhoto(StudentDetailsData student) async {
          if (student.isPhotoPendingSync && student.offlinePhotoPath != null) {
            final file = File(student.offlinePhotoPath!);
            if (await file.exists()) {
              try {
                final photoResponse = await apiManager.multiRequestRoute(
                  file.path,
                  Config.baseUrl + Routes.updateStudentProfile(student.uuid ?? ''),
                );
                if (photoResponse.statusCode == 200) {
                  final photoJson = jsonDecode(photoResponse.body);
                  final updatedWithPhoto = student.copyWith(
                    profilePhotoUrl: photoJson['data']['profile_photo_url'],
                    isPhotoPendingSync: false,
                    offlinePhotoPath: null,
                  );
                  await localDS.insertStudents([updatedWithPhoto]);
                  updateStudentInState(updatedWithPhoto);
                  debugPrint("Synced offline photo for: ${student.name}");
                  try {
                    await file.delete();
                  } catch (_) {}
                }
              } catch (e) {
                debugPrint("Error syncing photo for ${student.name}: $e");
              }
            }
          }
        }

        Future<bool> _syncMoveToExtra({
          required String? token,
          required String schoolId,
          required StudentDetailsData student,
        }) async {
          try {
            final url =
                '${Config.baseUrl}${Routes.moveStudentToExtra(schoolId, student.uuid ?? '')}';
            final response = await http.post(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
                'Content-Type': 'application/json',
              },
            );
            return response.statusCode == 200 ||
                response.statusCode == 201 ||
                response.statusCode == 404;
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
            final url =
                "${Config.baseUrl}${Routes.toggleStudentStatus(schoolId, student.uuid ?? '')}";
            final response = await http.patch(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({'status': student.status == 1}),
            );
            return response.statusCode == 200 ||
                response.statusCode == 201 ||
                response.statusCode == 404;
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
            final url =
                "${Config.baseUrl}${Routes.deleteStudent(schoolId, student.uuid ?? '')}";
            final response = await http.delete(
              Uri.parse(url),
              headers: {
                'Authorization': 'Bearer $token',
                'Accept': 'application/json',
              },
            );
            return response.statusCode == 200 ||
                response.statusCode == 204 ||
                response.statusCode == 404;
          } catch (e) {
            debugPrint("_syncDelete error: $e");
            return false;
          }
        }

        Map<String, dynamic> _buildBodyFromStudent(
            String schoolId, StudentDetailsData student) {
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

        Future<void> uploadStudentImage({
          required String path,
          required StudentDetailsData student,
        }) async {
          // 1. Check internet
          final connectivity = await Connectivity().checkConnectivity();
          bool hasInternet = !connectivity.contains(ConnectivityResult.none);

          if (hasInternet) {
            try {
              final result = await InternetAddress.lookup('google.com');
              hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
            } catch (_) {
              hasInternet = false;
            }
          }

          if (hasInternet) {
            // 2. Online: Direct upload
            try {
              File fixedImage = await FlutterExifRotation.rotateImage(path: path);
              var response = await apiManager.multiRequestRoute(
                fixedImage.path,
                Config.baseUrl + Routes.updateStudentProfile(student.uuid ?? ''),
              );

              if (response.statusCode == 200) {
                final jsonData = jsonDecode(response.body);
                final updated = student.copyWith(
                  profilePhotoUrl: jsonData['data']['profile_photo_url'],
                  isPhotoPendingSync: false,
                  offlinePhotoPath: null,
                );
                await localDS.insertStudents([updated]);
                updateStudentInState(updated);
              }
            } catch (e) {
              debugPrint("Online upload error: $e");
            }
          } else {
            // 3. Offline: Save locally
            try {
              final directory = await getApplicationDocumentsDirectory();
              final fileName =
                  'student_photo_${student.uuid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final savedPath = '${directory.path}/$fileName';

              await File(path).copy(savedPath);

              final updated = student.copyWith(
                isPhotoPendingSync: true,
                offlinePhotoPath: savedPath,
              );

              await localDS.insertStudents([updated]);
              updateStudentInState(updated);
              debugPrint("Offline photo saved: $savedPath");
            } catch (e) {
              debugPrint("Offline photo save error: $e");
            }
          }
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

            emit(
              state.copyWith(
                loading: false,
                studentsList: localList,
                hasMore: false,
                page: 1,
              ),
            );
          } catch (e) {
            emit(state.copyWith(loading: false, error: e.toString()));
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
          emit(state.copyWith(isSyncing: true));
          await localDS.clearStudents();
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
              url +=
                  "&" +
                      sectionIds
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

              List<StudentDetailsData> newList = list
                  .map((e) => StudentDetailsData.fromJson(e))
                  .toList();

              await localDS.insertStudents(newList);

              int count = await localDS.getCount();

              hasMore = count < total;
              page++;

              if (page == 2) {
                await fetchStudents();
              }
              emit(state.copyWith(isSyncing: false));
            } catch (e) {
              print("Sync stopped: $e");
              break;
            }
          }

          print("FULL DATA SYNC DONE");
        }

        void prependStudent(StudentDetailsData student) {
          emit(state.copyWith(studentsList: [student, ...state.studentsList]));
        }

        Future<bool> deleteStudent(String studentUuid, String schoolId) async {
          try {
            final student = state.studentsList.firstWhere(
                  (s) => s.uuid == studentUuid,
              orElse: () => StudentDetailsData(uuid: studentUuid),
            );

            final connectivity = await Connectivity().checkConnectivity();
            final isDeviceOffline = connectivity.contains(ConnectivityResult.none) &&
                connectivity.length == 1;

            if (student.isOffline || isDeviceOffline) {
              debugPrint("Deleting student locally (offline): $studentUuid");
              if (studentUuid.startsWith('offline_')) {
                await localDS.deleteStudent(studentUuid);
              } else {
                // If it's a server student, mark for deletion sync
                final updatedStudent = student.copyWith(isDeletePendingSync: true);
                await localDS.insertStudents([updatedStudent]);
              }
              final updated =
              state.studentsList.where((s) => s.uuid != studentUuid).toList();
              emit(state.copyWith(studentsList: updated));
              return true;
            }

            final result = await apiManager.deleteRequest(
              "${Config.baseUrl}${Routes.deleteStudent(schoolId, studentUuid)}",
            );
            if (result.statusCode == 200 ||
                result.statusCode == 204 ||
                result.statusCode == 404) {
              await localDS.deleteStudent(studentUuid);
              final updated =
              state.studentsList.where((s) => s.uuid != studentUuid).toList();
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
            final localExtra = await localDS.getExtraStudents();
            emit(state.copyWith(extraStudentsList: localExtra));

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

              final validNewList =
              newList.where((s) => s.name != null && s.name!.isNotEmpty).toList();
              await localDS.insertStudents(validNewList);
            }

            final finalExtra = await localDS.getExtraStudents();
            emit(state.copyWith(extraLoading: false, extraStudentsList: finalExtra));
          } catch (e) {
            final localExtra = await localDS.getExtraStudents();
            emit(state.copyWith(extraLoading: false, extraStudentsList: localExtra));
            print("Fetch extra students error: $e");
          }
        }

        Future<bool> moveStudentToExtra(String studentUuid, String schoolId) async {
          try {
            final student = state.studentsList.firstWhere(
                  (s) => s.uuid == studentUuid,
              orElse: () => StudentDetailsData(uuid: studentUuid),
            );

            final connectivity = await Connectivity().checkConnectivity();
            final isDeviceOffline = connectivity.contains(ConnectivityResult.none) &&
                connectivity.length == 1;

            if (student.isOffline || isDeviceOffline) {
              // ✅ FIX: isOffline = true taaki syncOfflineStudents isse pick kare
              //         isExtraPendingSync = true taaki CASE A mein handle ho
              final updatedStudent = student.copyWith(
                isExtra: true,
                isExtraPendingSync: true,
                isOffline: true,           // ← yahi key flag hai sync ke liye
                isOfflineUpdate: false,    // ← naya student nahi, sirf move hai
              );
              await localDS.insertStudents([updatedStudent]);

              final updated =
              state.studentsList.where((s) => s.uuid != studentUuid).toList();
              emit(state.copyWith(studentsList: updated));
              return true;
            }

            // Online: directly server pe bhejo
            final response = await apiManager.postWithoutRequest(
              "${Config.baseUrl}${Routes.moveStudentToExtra(schoolId, studentUuid)}",
            );
            if (response != null &&
                (response.statusCode == 200 ||
                    response.statusCode == 201 ||
                    response.statusCode == 404)) {
              final updatedStudent = student.copyWith(isExtra: true);
              await localDS.insertStudents([updatedStudent]);

              final updated =
              state.studentsList.where((s) => s.uuid != studentUuid).toList();
              emit(state.copyWith(studentsList: updated));
              return true;
            } else {
              return false;
            }
          } catch (e) {
            debugPrint("Move to extra error: $e");
            return false;
          }
        }

        Future<bool> assignClass({
          required String studentUuid,
          required String schoolId,
          required int classId,
          int? sectionId,
        }) async {
          try {
            // ── Student dhundho
            StudentDetailsData? student;
            try {
              student = state.studentsList.firstWhere((s) => s.uuid == studentUuid);
            } catch (_) {
              try {
                student =
                    state.extraStudentsList.firstWhere((s) => s.uuid == studentUuid);
              } catch (_) {
                student = await localDS.getStudentByUuid(studentUuid);
              }
            }

            if (student == null) {
              debugPrint("Student not found for assignment: $studentUuid");
              return false;
            }

            // ── Local DB update ────────────────────────────────────────────────
            // isOffline = true  → syncOfflineStudents CASE B mein pick hoga
            // isOfflineUpdate = false → ye edit nahi, sirf assignment hai
            final updatedStudent = student.copyWith(
              schoolClassId: classId,
              schoolClassSectionId: sectionId,
              isExtra: false,
              isOffline: true,
              isOfflineUpdate: false,
            );

            // Class/Section naam bhi local cache se fill karo
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
                final classesList =
                jsonDecode(row['classes_json'] as String? ?? '[]') as List;
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

            // State update karo
            final updatedExtra =
            state.extraStudentsList.where((s) => s.uuid != studentUuid).toList();
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
              final url =
                  '${Config.baseUrl}auth/school/$schoolId/students/$studentUuid/assign';

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
                debugPrint(
                    "Server assign failed (${response.statusCode}): ${response.body}");
              }
            } else {
              debugPrint(
                  "Device offline — assignment queued for sync: $studentUuid");
            }

            return true;
          } catch (e) {
            debugPrint("Assign class error: $e");
            return false;
          }
        }

        Map<String, dynamic> _buildSyncBody(
            String schoolId,
            Map<String, dynamic> fields,
            ) {
          final gender = fields['gender']?.toString().toLowerCase();
          final cleanGender =
          (gender == null || gender == '-select gender-') ? null : gender;

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
          final finalPassword =
          (password != null && password.isNotEmpty) ? password : 'Student@123';
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
            'land_line_no': f([
              'landline_contact_number',
              'landline_number',
              'land_line_no',
            ]),
            'landline_contact_number': f([
              'landline_contact_number',
              'landline_number',
            ]),
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
            'school_class_id': fields['class']?.toString(),
            'class': fields['class']?.toString(),
            'school_class_section_id': fields['class_section']?.toString(),
            'school_house_id': fields['house']?.toString(),
            'house': fields['house']?.toString(),
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

            final connectivity = await Connectivity().checkConnectivity();
            final isDeviceOffline = connectivity.contains(ConnectivityResult.none) &&
                connectivity.length == 1;

            if (student.isOffline || isDeviceOffline) {
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
            final url =
                "${Config.baseUrl}${Routes.toggleStudentStatus(schoolId, studentUuid)}";
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

            if (result.statusCode == 200 || result.statusCode == 201) {
              final json = jsonDecode(result.body);
              final newStatus =
                  (json['data']['status'] as int?) ?? (currentStatus == 1 ? 0 : 1);

              try {
                final studentToUpdate =
                state.studentsList.firstWhere((s) => s.uuid == studentUuid);
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
              final updated =
              state.studentsList.where((s) => s.uuid != studentUuid).toList();
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
      }