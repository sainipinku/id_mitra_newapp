import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/local_db/correction_local_ds/correction_local_ds.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/correction/CorrectionListModel.dart';
import 'package:idmitra/providers/correction/correction_state.dart';
import 'package:idmitra/utils/pdf_helper.dart';
import 'package:path_provider/path_provider.dart';

class CorrectionCubit extends Cubit<CorrectionState> {
  StreamSubscription? _connectivitySubscription;

  CorrectionCubit() : super(const CorrectionState()) {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (hasInternet) {
        syncPendingChecklists();
        syncPendingOrders();
        syncPendingDownloads();
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  final ApiManager _api = ApiManager();
  final CorrectionLocalDS _localDS = CorrectionLocalDS();
  final StudentLocalDS _studentLocalDS = StudentLocalDS();

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

  Future<void> fetchCorrectionList({
    required String schoolId,
    bool isSchool = false,
    bool isLoadMore = false,
    String search = '',
    String classId = '',
    String gender = '',
  }) async {
    if (isLoadMore && (state.loading || !state.hasMore)) return;

    final currentPage = isLoadMore ? state.page : 1;

    if (!isLoadMore) {
      emit(state.copyWith(
        loading: true,
        items: [],
        page: 1,
        hasMore: true,
        clearError: true,
      ));
    }

    try {
      String url =
          '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists?page=$currentPage&per_page=50';

      if (search.isNotEmpty) url += '&search=$search';
      if (classId.isNotEmpty) url += '&class_id=$classId';
      if (gender.isNotEmpty) url += '&gender=$gender';

      var response = await _api.getRequest(url);

      if (response != null && response.statusCode == 403) {
        final partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/orders/correction-lists?page=$currentPage&per_page=50'
            '${search.isNotEmpty ? '&search=$search' : ''}'
            '${classId.isNotEmpty ? '&class_id=$classId' : ''}'
            '${gender.isNotEmpty ? '&gender=$gender' : ''}';

        response = await _api.getRequest(partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(
          loading: false,
          error: 'Failed to load correction list',
        ));
        return;
      }

      final json = jsonDecode(response.body);

      if (json['success'] != true) {
        emit(state.copyWith(
          loading: false,
          error: json['message'] ?? 'Something went wrong',
        ));
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      final checklists = data?['checklists'] as Map<String, dynamic>?;

      final List rawList = checklists?['data'] ?? [];

      final int lastPage = checklists?['last_page'] ?? 1;
      final int respPage = checklists?['current_page'] ?? 1;

      final newItems = rawList
          .map(
            (e) => CorrectionItem.fromJson(
          e as Map<String, dynamic>,
        ),
      )
          .toList();

      final updatedList =
      isLoadMore ? [...state.items, ...newItems] : newItems;

      emit(state.copyWith(
        loading: false,
        items: updatedList,
        page: respPage + 1,
        hasMore: respPage < lastPage,
      ));
    } catch (e) {
      emit(state.copyWith(
        loading: false,
        error: e.toString(),
      ));
    }
  }

  void toggleSelection(int id) {
    final current = Set<int>.from(state.selectedIds);

    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }

    emit(state.copyWith(selectedIds: current));
  }

  void selectAll() {
    final allIds = state.items.map((e) => e.id).toSet();

    emit(state.copyWith(selectedIds: allIds));
  }

  void clearSelection() {
    emit(state.copyWith(selectedIds: {}));
  }

  void toggleStudentSelection(int id) {
    final current = Set<int>.from(state.selectedStudentIds);

    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }

    emit(state.copyWith(selectedStudentIds: current));
  }

  void selectAllStudents() {
    final allIds = state.students.map((e) => e.id).toSet();

    emit(state.copyWith(selectedStudentIds: allIds));
  }

  void clearStudentSelection() {
    emit(state.copyWith(selectedStudentIds: {}));
  }

  void setSelectedClassIds(List<String> classIds) {
    emit(state.copyWith(selectedClassIds: classIds));
  }

  Future<void> processOrder({
    required String schoolId,
    String processType = 'create',
    String listType = 'class_wise',
    String cardType = '',
    List<String> cardFor = const [],
    List<String>? studentUuids,
  }) async {
    List<String> selectedUuids;

    if (studentUuids != null && studentUuids.isNotEmpty) {
      selectedUuids = studentUuids;
    } else {
      if (state.selectedStudentIds.isEmpty) return;
      selectedUuids = state.students
          .where((s) =>
      state.selectedStudentIds.contains(s.id) &&
          s.student?.uuid != null &&
          s.student!.uuid!.isNotEmpty)
          .map((s) => s.student!.uuid!)
          .toList();
    }

    if (selectedUuids.isEmpty) {
      emit(state.copyWith(
          sendOrderError: 'No valid items found for selected entries'));
      return;
    }

    emit(state.copyWith(
        sendOrderLoading: true,
        clearSendOrderError: true,
        clearSendOrderMessage: true,
        sendOrderSuccess: false));
    try {
      if (!await _hasInternet()) {
        await _localDS.savePendingChecklist(
          schoolId: schoolId,
          processType: processType,
          listType: listType,
          cardType: cardType,
          cardFor: cardFor,
          studentUuids: selectedUuids,
        );

        //  Move students to Correction List locally
        final studentDetails = await _studentLocalDS.getStudentsByUuids(selectedUuids);
        final correctionItems = studentDetails.map((s) {
          return CorrectionStudentItem(
            id: s.id ?? 0,
            uuid: s.uuid,
            status: 'pending',
            remark: 'Offline Processed',
            student: CorrectionStudentData(
              id: s.id ?? 0,
              uuid: s.uuid,
              schoolId: s.schoolId,
              name: s.name,
              email: s.email?.toString(),
              phone: s.phone?.toString(),
              regNo: s.regNo,
              rollNo: s.rollNo,
              admissionNo: s.admissionNo,
              dob: s.dob,
              address: s.address,
              fatherName: s.fatherName,
              fatherPhone: s.fatherPhone,
              motherName: s.motherName,
              motherPhone: s.motherPhone,
              schoolClassId: s.schoolClassId,
              schoolClassSectionId: s.schoolClassSectionId,
              profilePhotoUrl: s.profilePhotoUrl,
              studentClass: s.datumClass != null
                  ? CorrectionStudentClass(
                      id: s.datumClass!.id ?? 0,
                      nameWithPrefix: s.datumClass!.nameWithprefix,
                    )
                  : null,
              section: s.section != null
                  ? CorrectionStudentSection(
                      id: s.section!.id ?? 0,
                      name: s.section!.name,
                    )
                  : null,
            ),
          );
        }).toList();

        await _localDS.insertCorrectionStudents(correctionItems, schoolId);

        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          sendOrderMessage: 'Saved offline. Students added to Correction List locally.',
          selectedStudentIds: {},
        ));

        // Refresh correction list state
        fetchCorrectionStudents(schoolId: schoolId);
        return;
      }

      final url =
          '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists/process';
      final body = <String, dynamic>{
        'processType': processType,
        'listType': listType,
        'students': selectedUuids,
        if (cardType.isNotEmpty) 'card_type': cardType,
        if (cardFor.isNotEmpty) 'card_for': cardFor,
      };
      final response = await _api.postRequest(body, url);
      print("=== processOrder RESPONSE ===");
      print("URL: $url");
      print("BODY: ${jsonEncode(body)}");
      print("STATUS: ${response?.statusCode}");
      print("BODY: ${response?.body}");
      if (response == null) {
        emit(state.copyWith(
            sendOrderLoading: false,
            sendOrderError: 'Failed to process order'));
        return;
      }
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          sendOrderMessage: json['message'] ?? 'Correction list created successfully!',
          selectedStudentIds: {},
        ));
      } else {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderError: json['message'] ?? 'Failed to process order',
        ));
      }
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        await _localDS.savePendingChecklist(
          schoolId: schoolId,
          processType: processType,
          listType: listType,
          cardType: cardType,
          cardFor: cardFor,
          studentUuids: selectedUuids,
        );

        //  Move students to Correction List locally
        final studentDetails = await _studentLocalDS.getStudentsByUuids(selectedUuids);
        final correctionItems = studentDetails.map((s) {
          return CorrectionStudentItem(
            id: s.id ?? 0,
            uuid: s.uuid,
            status: 'pending',
            remark: 'Offline Processed',
            student: CorrectionStudentData(
              id: s.id ?? 0,
              uuid: s.uuid,
              schoolId: s.schoolId,
              name: s.name,
              email: s.email?.toString(),
              phone: s.phone?.toString(),
              regNo: s.regNo,
              rollNo: s.rollNo,
              admissionNo: s.admissionNo,
              dob: s.dob,
              address: s.address,
              fatherName: s.fatherName,
              fatherPhone: s.fatherPhone,
              motherName: s.motherName,
              motherPhone: s.motherPhone,
              schoolClassId: s.schoolClassId,
              schoolClassSectionId: s.schoolClassSectionId,
              profilePhotoUrl: s.profilePhotoUrl,
              studentClass: s.datumClass != null
                  ? CorrectionStudentClass(
                      id: s.datumClass!.id ?? 0,
                      nameWithPrefix: s.datumClass!.nameWithprefix,
                    )
                  : null,
              section: s.section != null
                  ? CorrectionStudentSection(
                      id: s.section!.id ?? 0,
                      name: s.section!.name,
                    )
                  : null,
            ),
          );
        }).toList();

        await _localDS.insertCorrectionStudents(correctionItems, schoolId);

        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          sendOrderMessage: 'Saved offline. Students added to Correction List locally.',
          selectedStudentIds: {},
        ));

        // Refresh correction list state
        fetchCorrectionStudents(schoolId: schoolId);
      } else {
        emit(state.copyWith(
            sendOrderLoading: false, sendOrderError: e.toString()));
      }
    }
  }

  Future<void> syncPendingChecklists() async {
    if (!await _hasInternet()) return;

    final pending = await _localDS.getAllPendingChecklists();
    if (pending.isEmpty) return;

    print("Syncing ${pending.length} pending checklists...");

    bool anySynced = false;
    for (var item in pending) {
      try {
        final schoolId = item['school_id'];
        final processType = item['process_type'];
        final listType = item['list_type'];
        final cardType = item['card_type'];
        final cardFor = List<String>.from(jsonDecode(item['card_for'] ?? '[]'));
        final studentUuids = List<String>.from(jsonDecode(item['students_json'] ?? '[]'));

        final url = '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists/process';
        final body = <String, dynamic>{
          'processType': processType,
          'listType': listType,
          'students': studentUuids,
          if (cardType != null && cardType.isNotEmpty) 'card_type': cardType,
          if (cardFor.isNotEmpty) 'card_for': cardFor,
        };

        final response = await _api.postRequest(body, url);
        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _localDS.deletePendingChecklist(item['id']);
            print("Successfully synced pending checklist ID: ${item['id']}");
            anySynced = true;
          }
        }
      } catch (e) {
        print("Error syncing pending checklist: $e");
      }
    }

    if (anySynced) {
      final school = await UserLocal.getSchool();
      final schoolId = school['schoolId'];
      if (schoolId != null && schoolId.isNotEmpty) {
        fetchCorrectionStudents(schoolId: schoolId);
        emit(state.copyWith(syncSuccess: true));
        Future.delayed(const Duration(seconds: 2), () {
          if (!isClosed) emit(state.copyWith(syncSuccess: false));
        });
      }
    }
  }

  Future<void> createOrder({
    required String schoolId,
    String cardType = 'new',
    List<String> cardFor = const [],
    List<String>? studentUuids,
  }) async {
    List<String> selectedUuids = [];

    try {
      if (studentUuids != null && studentUuids.isNotEmpty) {
        selectedUuids = studentUuids.where((e) => e.trim().isNotEmpty).toList();
      } else {
        if (state.selectedStudentIds.isEmpty) {
          emit(state.copyWith(
            createOrderLoading: false,
            createOrderError: 'Please select students',
          ));
          return;
        }
        selectedUuids = state.students
            .where((s) =>
        state.selectedStudentIds.contains(s.id) &&
            s.student?.uuid != null &&
            s.student!.uuid!.trim().isNotEmpty)
            .map((s) => s.student!.uuid!.trim())
            .toList();
      }

      selectedUuids = selectedUuids.toSet().toList();

      if (selectedUuids.isEmpty) {
        emit(state.copyWith(
          createOrderLoading: false,
          createOrderError: 'No valid students found for selected entries',
        ));
        return;
      }

      emit(state.copyWith(
        createOrderLoading: true,
        clearCreateOrderError: true,
        createOrderSuccess: false,
      ));

      if (!await _hasInternet()) {
        final now = DateTime.now();

        final studentDetails = await _studentLocalDS.getStudentsByUuids(selectedUuids);
        final schoolInfo = await UserLocal.getSchool();

        Map<String, dynamic>? studentData;
        if (studentDetails.isNotEmpty) {
          final firstStudent = studentDetails.first;
          studentData = {
            'id': firstStudent.id,
            'name': firstStudent.name ?? 'Unknown',
            'profile_photo_url': firstStudent.profilePhotoUrl,
            'class': firstStudent.datumClass != null ? {
              'id': firstStudent.datumClass!.id,
              'name': firstStudent.datumClass!.name,
              'name_withprefix': firstStudent.datumClass!.nameWithprefix,
            } : null,
            'section': firstStudent.section != null ? {
              'id': firstStudent.section!.id,
              'name': firstStudent.section!.name,
            } : null,
            'gender': firstStudent.gender,
            'dob': firstStudent.dob,
            'father_name': firstStudent.fatherName,
            'father_phone': firstStudent.fatherPhone,
            'mother_name': firstStudent.motherName,
            'address': firstStudent.address,
            'pincode': firstStudent.pincode,
            'login_id': firstStudent.loginId,
          };
        }

        final schoolData = {
          'id': int.tryParse(schoolInfo['schoolId'] ?? '0') ?? 0,
          'name': schoolInfo['schoolName'] ?? 'Unknown School',
        };

        final dateOnly = '${now.day.toString().padLeft(2, '0')} '
            '${_monthName(now.month)} ${now.year}';

        final mockOrderJson = {
          "id": 0,
          "uuid": "offline_${now.millisecondsSinceEpoch}",
          "status": "order_created",
          "type": cardType,
          "orderd_at": dateOnly,
          "received_at_short": "Pending Sync",
          "student_card": cardFor.contains('student_card') ? 1 : 0,
          "parent_card": cardFor.contains('parent_card') ? 1 : 0,
          "admit_card": cardFor.contains('admit_card') ? 1 : 0,
          "student_card_qty": selectedUuids.length,
          "school": schoolData,
          "student": studentData,
        };

        await _localDS.savePendingOrder(
          schoolId: schoolId,
          cardType: cardType,
          cardFor: cardFor,
          cardUsers: selectedUuids,
          orderJson: mockOrderJson,
        );

        emit(state.copyWith(
          createOrderLoading: false,
          createOrderSuccess: true,
          selectedStudentIds: {},
        ));
        return;
      }

      // POST auth/school/{schoolId}/orders
      final String url = '${Config.baseUrl}auth/school/$schoolId/orders';

      final Map<String, dynamic> body = {
        "card_users": selectedUuids,
        "card_type": cardType.trim().isNotEmpty ? cardType.trim() : 'new',
        "student_card": cardFor.contains('student_card') ? 1 : 0,
        "parent_card": cardFor.contains('parent_card') ? 1 : 0,
        "admit_card": cardFor.contains('admit_card') ? 1 : 0,
      };

      var response = await _api.postRequest(body, url);

      if (response != null && response.statusCode == 403) {
        final String partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/orders';
        response = await _api.postRequest(body, partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(
          createOrderLoading: false,
          createOrderError: 'Failed to create order',
        ));
        return;
      }

      final dynamic jsonResponse = jsonDecode(response.body);

      if (jsonResponse['success'] == true) {
        emit(state.copyWith(
          createOrderLoading: false,
          createOrderSuccess: true,
          selectedStudentIds: {},
        ));
      } else {
        emit(state.copyWith(
          createOrderLoading: false,
          createOrderError: jsonResponse['message'] ?? 'Failed to create order',
        ));
      }
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        final now = DateTime.now();

        final studentDetails = await _studentLocalDS.getStudentsByUuids(selectedUuids);
        final schoolInfo = await UserLocal.getSchool();

        Map<String, dynamic>? studentData;
        if (studentDetails.isNotEmpty) {
          final firstStudent = studentDetails.first;
          studentData = {
            'id': firstStudent.id,
            'name': firstStudent.name ?? 'Unknown',
            'profile_photo_url': firstStudent.profilePhotoUrl,
            'class': firstStudent.datumClass != null ? {
              'id': firstStudent.datumClass!.id,
              'name': firstStudent.datumClass!.name,
              'name_withprefix': firstStudent.datumClass!.nameWithprefix,
            } : null,
            'section': firstStudent.section != null ? {
              'id': firstStudent.section!.id,
              'name': firstStudent.section!.name,
            } : null,
            'gender': firstStudent.gender,
            'dob': firstStudent.dob,
            'father_name': firstStudent.fatherName,
            'father_phone': firstStudent.fatherPhone,
            'mother_name': firstStudent.motherName,
            'address': firstStudent.address,
            'pincode': firstStudent.pincode,
            'login_id': firstStudent.loginId,
          };
        }

        final schoolData = {
          'id': int.tryParse(schoolInfo['schoolId'] ?? '0') ?? 0,
          'name': schoolInfo['schoolName'] ?? 'Unknown School',
        };

        final dateOnly = '${now.day.toString().padLeft(2, '0')} '
            '${_monthName(now.month)} ${now.year}';

        final mockOrderJson = {
          "id": 0,
          "uuid": "offline_${now.millisecondsSinceEpoch}",
          "status": "order_created",
          "type": cardType,
          "orderd_at": dateOnly,
          "received_at_short": "Pending Sync",
          "student_card": cardFor.contains('student_card') ? 1 : 0,
          "parent_card": cardFor.contains('parent_card') ? 1 : 0,
          "admit_card": cardFor.contains('admit_card') ? 1 : 0,
          "student_card_qty": selectedUuids.length,
          "school": schoolData,
          "student": studentData,
        };

        await _localDS.savePendingOrder(
          schoolId: schoolId,
          cardType: cardType,
          cardFor: cardFor,
          cardUsers: selectedUuids,
          orderJson: mockOrderJson,
        );

        emit(state.copyWith(
          createOrderLoading: false,
          createOrderSuccess: true,
          selectedStudentIds: {},
        ));
      } else {
        emit(state.copyWith(
          createOrderLoading: false,
          createOrderError: e.toString(),
        ));
      }
    }
  }

  Future<void> syncPendingOrders() async {
    if (!await _hasInternet()) return;

    final pending = await _localDS.getAllPendingOrders();
    if (pending.isEmpty) return;

    print("Syncing ${pending.length} pending orders...");

    for (var item in pending) {
      try {
        final schoolId = item['school_id'];
        final cardType = item['card_type'];
        final cardFor = List<String>.from(jsonDecode(item['card_for_json'] ?? '[]'));
        final cardUsers = List<String>.from(jsonDecode(item['card_users_json'] ?? '[]'));

        final String url = '${Config.baseUrl}auth/school/$schoolId/orders';
        final Map<String, dynamic> body = {
          "card_users": cardUsers,
          "card_type": cardType,
          "student_card": cardFor.contains('student_card') ? 1 : 0,
          "parent_card": cardFor.contains('parent_card') ? 1 : 0,
          "admit_card": cardFor.contains('admit_card') ? 1 : 0,
        };

        final response = await _api.postRequest(body, url);
        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _localDS.deletePendingOrder(item['id']);
            print("Successfully synced pending order ID: ${item['id']}");
          }
        }
      } catch (e) {
        print("Error syncing pending order: $e");
      }
    }
  }

  Future<void> syncPendingDownloads() async {
    if (!await _hasInternet()) return;

    final pending = await _localDS.getAllPendingDownloads();
    if (pending.isEmpty) return;

    print("Syncing ${pending.length} pending downloads...");

    for (var item in pending) {
      try {
        final schoolId = item['school_id'];
        final listType = item['list_type'];
        final selected = List<String>.from(jsonDecode(item['selected_columns_json'] ?? '[]'));

        final url = '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists/download';
        final body = {
          'list_type': listType,
          'selected': selected,
        };

        final response = await _api.postRequest(body, url);
        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          await _localDS.deletePendingDownload(item['id']);
          print("Successfully synced pending download ID: ${item['id']}");
        }
      } catch (e) {
        print("Error syncing pending download: $e");
      }
    }
  }

  Future<void> fetchCorrectionStudents({
    required String schoolId,
    bool isLoadMore = false,
    String search = '',
    String classFilter = '',
    List<String> classIds = const [],
    List<int> sectionIds = const [],
  }) async {
    if (isLoadMore &&
        (state.studentsLoading || !state.studentsHasMore)) {
      return;
    }

    const int perPage = 50;
    final currentPage = isLoadMore ? state.studentsPage : 1;
    final int offset = (currentPage - 1) * perPage;

    final effectiveClassFilter =
    classIds.isNotEmpty ? classIds.join(',') : classFilter;

    if (!isLoadMore) {
      emit(state.copyWith(
        studentsLoading: true,
        students: [],
        studentsPage: 1,
        studentsHasMore: true,
        clearStudentsError: true,
        selectedClassIds: classIds.isNotEmpty
            ? classIds
            : (classFilter.isNotEmpty
            ? classFilter.split(',')
            : state.selectedClassIds),
      ));
    } else {
      emit(state.copyWith(studentsLoading: true));
    }

    try {
      // ── Try local DB first ──────────────────────────────────
      final localList = await _localDS.getCorrectionStudents(
        schoolId: schoolId,
        search: search,
        classId: effectiveClassFilter,
        sectionIds: sectionIds,
        limit: perPage,
        offset: offset,
      );

      final int totalLocalCount = await _localDS.getCount(
        schoolId: schoolId,
        search: search,
        classId: effectiveClassFilter,
        sectionIds: sectionIds,
      );

      if (localList.isNotEmpty) {
        final updated =
            isLoadMore ? [...state.students, ...localList] : localList;

        bool hasMoreLocal = updated.length < totalLocalCount;

        emit(state.copyWith(
          studentsLoading: false,
          students: updated,
          studentsPage: currentPage + 1,
          studentsHasMore: hasMoreLocal || await _hasInternet(),
          studentsTotal: totalLocalCount > state.studentsTotal ? totalLocalCount : state.studentsTotal,
        ));

        // If we have internet, we continue to fetch from server to sync/update local cache
        // If it's load more and we have full page from local, we can stop here.
        if (isLoadMore && localList.length == perPage) return;
        if (!await _hasInternet()) return;
      }

      if (!await _hasInternet()) {
        emit(state.copyWith(studentsLoading: false));
        return;
      }

      String url =
          '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists/students?page=$currentPage&per_page=$perPage';

      if (search.isNotEmpty) url += '&search=$search';

      if (effectiveClassFilter.isNotEmpty) {
        url += '&class_filters=$effectiveClassFilter';
      }

      for (int i = 0; i < sectionIds.length; i++) {
        url += '&sectionsIds[$i]=${sectionIds[i]}';
      }

      var response = await _api.getRequest(url);

      if (response != null && response.statusCode == 403) {
        String partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/orders/correction-lists/students?page=$currentPage&per_page=50';

        if (search.isNotEmpty) partnerUrl += '&search=$search';
        if (effectiveClassFilter.isNotEmpty) {
          partnerUrl += '&class_filters=$effectiveClassFilter';
        }
        for (int i = 0; i < sectionIds.length; i++) {
          partnerUrl += '&sectionsIds[$i]=${sectionIds[i]}';
        }

        response = await _api.getRequest(partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(
          studentsLoading: false,
          studentsError: 'Failed to load students',
        ));
        return;
      }

      final json = jsonDecode(response.body);

      if (json['success'] != true) {
        emit(state.copyWith(
          studentsLoading: false,
          studentsError: json['message'] ?? 'Something went wrong',
        ));
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;

      final listPage =
      (data?['list'] ?? data?['students']) as Map<String, dynamic>?;

      final List rawList = listPage?['data'] ?? [];

      final int lastPage = listPage?['last_page'] ?? 1;
      final int respPage = listPage?['current_page'] ?? 1;

      final newItems = rawList
          .map(
            (e) => CorrectionStudentItem.fromJson(
          e as Map<String, dynamic>,
        ),
      )
          .toList();

      // Update Local Cache
      if (!isLoadMore &&
          search.isEmpty &&
          effectiveClassFilter.isEmpty &&
          sectionIds.isEmpty) {
        await _localDS.clearForSchool(schoolId);
      }
      await _localDS.insertCorrectionStudents(newItems, schoolId);

      final updated =
      isLoadMore ? [...state.students, ...newItems] : newItems;

      final int total = listPage?['total'] ??
          (isLoadMore ? state.studentsTotal : updated.length);

      emit(state.copyWith(
        studentsLoading: false,
        students: updated,
        studentsPage: respPage + 1,
        studentsHasMore: respPage < lastPage,
        studentsTotal: total,
      ));
    } catch (e) {
      // Fallback to local on error if not already loaded
      if (state.students.isEmpty) {
        final localList = await _localDS.getCorrectionStudents(
          schoolId: schoolId,
          search: search,
          classId: effectiveClassFilter,
          sectionIds: sectionIds,
        );
        if (localList.isNotEmpty) {
          emit(state.copyWith(
            studentsLoading: false,
            students: localList,
            studentsHasMore: false,
            studentsTotal: localList.length,
          ));
          return;
        }
      }

      emit(state.copyWith(
        studentsLoading: false,
        studentsError: e.toString(),
      ));
    }
  }

  Future<void> fetchDownloadColumns({
    required String schoolId,
    bool isSchool = false,
  }) async {
    emit(state.copyWith(columnsLoading: true));

    try {
      // 1. Try to load from Local DB first
      final localColumns = await _localDS.getDownloadColumns(schoolId);
      if (localColumns.isNotEmpty) {
        emit(state.copyWith(
          columnsLoading: false,
          downloadColumns: localColumns,
        ));
        // If we have internet, we continue to fetch from server to update cache
        if (!await _hasInternet()) return;
      }

      if (!await _hasInternet()) {
        emit(state.copyWith(columnsLoading: false));
        return;
      }

      String url = '${Config.baseUrl}auth/school/$schoolId/form-fields';

      var response = await _api.getRequest(url);

      if (response != null && response.statusCode == 403) {
        url =
        '${Config.baseUrl}auth/partner/school/$schoolId/student-form-fields';
        response = await _api.getRequest(url);
      }

      if (response == null) {
        emit(state.copyWith(columnsLoading: false));
        return;
      }

      final json = jsonDecode(response.body);

      final data = json['data'] ?? json['props']?['school'] ?? {};

      List rawFields = [];

      if (data['student_form_fields'] is List) {
        rawFields = data['student_form_fields'] as List;
      } else if (data['available_student_form_fields'] is List) {
        rawFields = data['available_student_form_fields'] as List;
      } else if (json['data'] is List) {
        rawFields = json['data'] as List;
      }

      final columns = rawFields
          .where((e) => e['name'] != null && e['label'] != null)
          .map(
            (e) => DownloadColumn(
          key: e['name'].toString(),
          label: e['label'].toString(),
        ),
      )
          .toList();

      // 2. Save to Local DB
      if (columns.isNotEmpty) {
        await _localDS.saveDownloadColumns(schoolId, columns);
      }

      emit(state.copyWith(
        columnsLoading: false,
        downloadColumns: columns,
      ));
    } catch (e) {
      emit(state.copyWith(columnsLoading: false));
    }
  }

  Future<Uint8List?> downloadCorrectionList({
    required String schoolId,
    required List<String> selected,
    required String listType,
  }) async {
    emit(state.copyWith(
      downloadLoading: true,
      clearDownloadError: true,
      clearDownloadUrl: true,
    ));

    try {
      if (!await _hasInternet()) {
        await _localDS.savePendingDownload(
          schoolId: schoolId,
          listType: listType,
          selectedColumns: selected,
        );

        final school = await UserLocal.getSchool();
        final schoolName = school['schoolName'] ?? 'School';

        final pdfBytes = await PdfHelper.generateCorrectionChecklist(
          schoolName: schoolName,
          students: state.students,
          selectedColumnKeys: selected,
          allColumns: state.downloadColumns,
          listType: listType,
        );

        emit(state.copyWith(
          downloadLoading: false,
          sendOrderMessage: 'Generated offline. Sync pending.',
        ));
        return pdfBytes;
      }

      String url =
          '${Config.baseUrl}auth/school/$schoolId/orders/correction-lists/download';

      final body = {
        'list_type': listType,
        'selected': selected,
      };

      var response = await _api.postRequest(body, url);

      if (response != null && response.statusCode == 403) {
        final partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/orders/correction-lists/download';
        response = await _api.postRequest(body, partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(
          downloadLoading: false,
          downloadError: 'Failed to load PDF',
        ));
        return null;
      }

      final contentType =
          response.headers['content-type']?.toLowerCase() ?? '';

      if (contentType.contains('application/pdf') ||
          contentType.contains('application/octet-stream') ||
          (response.bodyBytes.isNotEmpty &&
              response.bodyBytes.first == 0x25)) {
        emit(state.copyWith(downloadLoading: false));
        return Uint8List.fromList(response.bodyBytes);
      }

      try {
        final json = jsonDecode(response.body);

        if (json['success'] == true) {
          final fileUrl =
              json['data']?['url'] ?? json['data']?['file_url'] ?? '';

          if (fileUrl.toString().isNotEmpty) {
            final res = await _api.getRequest(fileUrl);

            if (res != null && res.bodyBytes.isNotEmpty) {
              emit(state.copyWith(downloadLoading: false));
              return Uint8List.fromList(res.bodyBytes);
            }
          }
        } else {
          emit(state.copyWith(
            downloadLoading: false,
            downloadError: json['message'] ?? 'Download failed',
          ));
          return null;
        }
      } catch (e) {
        emit(state.copyWith(
          downloadLoading: false,
          downloadError: 'Invalid PDF format',
        ));
        return null;
      }

      emit(state.copyWith(
        downloadLoading: false,
        downloadError: 'Invalid PDF format',
      ));
      return null;
    } catch (e) {
      emit(state.copyWith(
        downloadLoading: false,
        downloadError: e.toString(),
      ));
      return null;
    }
  }

  Future<String?> savePdfFile(
      Uint8List pdfBytes,
      String fileName,
      ) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(pdfBytes);
      return file.path;
    } catch (e) {
      return null;
    }
  }

  String _monthName(int month) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month];
  }
}