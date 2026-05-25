import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/local_db/staff_correction_local_ds.dart';
import 'package:idmitra/local_db/correction_local_ds/correction_local_ds.dart';
import 'package:idmitra/local_db/staff_local_ds/staff_local_ds.dart';
import 'package:idmitra/local_db/order_local_ds/order_local_ds.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/providers/correction/correction_state.dart';
import 'package:idmitra/utils/pdf_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'staff_correction_state.dart';

export 'staff_correction_state.dart';

class StaffCorrectionCubit extends Cubit<StaffCorrectionState> {
  StreamSubscription? _connectivitySubscription;
  String? _lastSchoolId;

  StaffCorrectionCubit() : super(const StaffCorrectionState()) {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) return;

      if (_lastSchoolId != null) {
        syncOfflinePhotos(schoolId: _lastSchoolId!);
        syncPendingStaffChecklists(schoolId: _lastSchoolId!);
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }

  final ApiManager _api = ApiManager();
  final _localDS = StaffCorrectionLocalDS();
  final _correctionLocalDS = CorrectionLocalDS();
  final _staffLocalDS = StaffLocalDS();
  final _orderLocalDS = OrderLocalDS();

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

  Future<void> syncOfflinePhotos({required String schoolId}) async {
    if (!await _hasInternet()) return;

    final offlineItems = state.items.where((item) {
      final staff = item.effectiveStaff;
      return staff?.isPhotoPendingSync == true && staff?.offlinePhotoPath != null;
    }).toList();

    if (offlineItems.isEmpty) return;

    debugPrint("Syncing ${offlineItems.length} offline staff correction photos...");

    for (var item in offlineItems) {
      final staff = item.effectiveStaff!;
      final newUrl = await uploadStaffPhoto(
        schoolId: schoolId,
        uuid: staff.uuid!,
        imagePath: staff.offlinePhotoPath!,
      );
      if (newUrl != null) {
        debugPrint("Synced photo for staff correction: ${staff.name}");
      }
    }
  }

  Future<void> fetchStaffCorrection({
    required String schoolId,
    bool isLoadMore = false,
    String search = '',
  }) async {
    _lastSchoolId = schoolId;
    if (isLoadMore && (state.loading || !state.hasMore)) return;

    final currentPage = isLoadMore ? state.page : 1;
    const int perPage = 50;
    int offset = (currentPage - 1) * perPage;

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
      // 1. Try local DB first
      final localItems = await _localDS.getStaffCorrections(
        schoolId: schoolId,
        search: search,
        limit: perPage,
        offset: offset,
      );

      final int totalLocalCount = await _localDS.getCount(
        schoolId: schoolId,
        search: search,
      );

      if (localItems.isNotEmpty) {
        List<StaffCorrectionItem> updated;
        if (isLoadMore) {
          final existingIds = state.items.map((e) => e.id).toSet();
          final newOnly = localItems.where((e) => !existingIds.contains(e.id)).toList();
          updated = [...state.items, ...newOnly];
        } else {
          updated = localItems;
        }
        emit(state.copyWith(
          loading: false,
          items: updated,
          hasMore: updated.length < totalLocalCount,
          total: totalLocalCount,
        ));
      }

      // 2. Fetch from API (Only if online)
      if (!await _hasInternet()) {
        emit(state.copyWith(loading: false));
        return;
      }

      String url =
          '${Config.baseUrl}auth/school/$schoolId/staff/correction-lists?page=$currentPage&per_page=$perPage';
      if (search.isNotEmpty) url += '&search=$search';

      var response = await _api.getRequest(url);

      if (response != null && response.statusCode == 403) {
        String partnerUrl =
            '${Config.baseUrl}auth/partner/school/$schoolId/staff/correction-lists?page=$currentPage&per_page=$perPage';
        if (search.isNotEmpty) partnerUrl += '&search=$search';
        response = await _api.getRequest(partnerUrl);
      }

      if (response == null) {
        emit(state.copyWith(loading: false));
        return;
      }

      final json = jsonDecode(response.body);
      if (json['success'] != true) {
        if (state.items.isEmpty) {
          emit(state.copyWith(
            loading: false,
            error: json['message'] ?? 'Something went wrong',
          ));
        } else {
          emit(state.copyWith(loading: false));
        }
        return;
      }

      final data = json['data'] as Map<String, dynamic>?;
      final listPage = (data?['list'] ?? data?['data']) as Map<String, dynamic>?;
      final List rawList = listPage?['data'] ?? (data?['data'] is List ? data!['data'] : []);
      final int lastPage = listPage?['last_page'] ?? 1;
      final int respPage = listPage?['current_page'] ?? 1;
      final int total = listPage?['total'] ?? rawList.length;

      final newItems = rawList
          .map((e) => StaffCorrectionItem.fromJson(e as Map<String, dynamic>))
          .toList();

      // Sync to local DB — fromApi:true + page clears stale data on first page
      await _localDS.insertStaffCorrections(newItems, schoolId, fromApi: true, page: currentPage);

      // Fetch latest from local DB to ensure consistency
      final latestLocal = await _localDS.getStaffCorrections(
        schoolId: schoolId,
        search: search,
        limit: perPage,
        offset: offset,
      );

      List<StaffCorrectionItem> updated;
      if (isLoadMore) {
        // Deduplicate by id to avoid showing same item twice
        final existingIds = state.items.map((e) => e.id).toSet();
        final newOnly = latestLocal.where((e) => !existingIds.contains(e.id)).toList();
        updated = [...state.items, ...newOnly];
      } else {
        updated = latestLocal;
      }

      emit(state.copyWith(
        loading: false,
        items: updated,
        page: respPage + 1,
        hasMore: respPage < lastPage,
        total: total,
      ));
    } catch (e) {
      if (state.items.isEmpty) {
        final hasNet = await _hasInternet();
        if (hasNet) {
          emit(state.copyWith(loading: false, error: e.toString()));
        } else {
          emit(state.copyWith(loading: false));
        }
      } else {
        emit(state.copyWith(loading: false));
      }
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
    emit(state.copyWith(selectedIds: state.items.map((e) => e.id).toSet()));
  }

  void clearSelection() {
    emit(state.copyWith(selectedIds: {}));
  }

  Future<void> createStaffOrder({
    required String schoolId,
    required String cardType,
    required List<String> cardUsers,
  }) async {
    if (cardUsers.isEmpty) {
      emit(state.copyWith(sendOrderError: 'No staff selected'));
      return;
    }

    emit(state.copyWith(
      sendOrderLoading: true,
      clearSendOrderError: true,
      sendOrderSuccess: false,
    ));

    try {
      // ── OFFLINE: save locally ──
      if (!await _hasInternet()) {
        // Collect staff names/photos from selected correction items for display
        final selectedItems = state.items
            .where((item) => cardUsers.contains(item.uuid))
            .toList();

        // Save one offline order per selected staff item for proper display
        for (final item in selectedItems) {
          final staff = item.effectiveStaff;
          await _orderLocalDS.insertOfflineStaffOrder(
            schoolId: schoolId,
            cardType: cardType,
            cardUsers: [item.uuid ?? ''],
            staffName: staff?.name ?? 'Unknown',
            staffPhoto: staff?.profilePhotoUrl,
          );
        }

        // If no items matched (edge case), save one combined entry
        if (selectedItems.isEmpty) {
          await _orderLocalDS.insertOfflineStaffOrder(
            schoolId: schoolId,
            cardType: cardType,
            cardUsers: cardUsers,
            staffName: 'Staff Order',
            staffPhoto: null,
          );
        }

        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          sendOrderError: null,
          selectedIds: {},
        ));

        // Remove ordered correction items from local staff_corrections immediately
        // so they don't show in correction list while pending sync
        final uuidsToRemove = cardUsers.where((u) => u.isNotEmpty).toList();
        if (uuidsToRemove.isNotEmpty) {
          final db = await DBHelper.db;
          await db.delete(
            'staff_corrections',
            where: 'uuid IN (${uuidsToRemove.map((_) => '?').join(',')})',
            whereArgs: uuidsToRemove,
          );
          // Also update state to remove these items from the correction list UI
          final updatedItems = state.items
              .where((item) => !uuidsToRemove.contains(item.uuid))
              .toList();
          emit(state.copyWith(items: updatedItems));
        }
        return;
      }

      // ── ONLINE: send to API ──
      final url = '${Config.baseUrl}auth/school/$schoolId/staff/orders';
      final body = <String, dynamic>{
        'card_type': cardType,
        'card_users': cardUsers,
      };

      print("=== createStaffOrder REQUEST ===");
      print("URL: $url");
      print("BODY: ${jsonEncode(body)}");

      final response = await _api.postRequest(body, url);

      print("=== createStaffOrder RESPONSE ===");
      print("STATUS: ${response?.statusCode}");
      print("BODY: ${response?.body}");
      print("================================");

      if (response == null) {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderError: 'Failed to create order',
        ));
        return;
      }

      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        // Remove ordered correction items from local staff_corrections table
        final uuids = cardUsers.where((u) => u.isNotEmpty).toList();
        if (uuids.isNotEmpty) {
          final db = await DBHelper.db;
          await db.delete(
            'staff_corrections',
            where: 'uuid IN (${uuids.map((_) => '?').join(',')})',
            whereArgs: uuids,
          );
        }
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          selectedIds: {},
        ));
      } else {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderError: json['message'] ?? 'Failed to create order',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        sendOrderLoading: false,
        sendOrderError: e.toString(),
      ));
    }
  }



  Future<void> processOrder({
    required String schoolId,
    String cardType = '',
    List<String> cardFor = const [],
    List<String>? staffUuids, // optional: pass directly from Staff list tab
    String listType = '',
    String processType = 'create',
  }) async {
    List<String> selectedUuids;

    if (staffUuids != null && staffUuids.isNotEmpty) {
      selectedUuids = staffUuids;
    } else {
      if (state.selectedIds.isEmpty) return;
      selectedUuids = state.items
          .where((s) => state.selectedIds.contains(s.id) && s.uuid != null)
          .map((s) => s.uuid!)
          .toList();
    }

    if (selectedUuids.isEmpty) {
      emit(state.copyWith(sendOrderError: 'No valid items found for selected entries'));
      return;
    }

    emit(state.copyWith(sendOrderLoading: true, clearSendOrderError: true, sendOrderSuccess: false));
    try {
      // ── OFFLINE: save locally and add to staff_corrections ──
      if (!await _hasInternet()) {
        await _correctionLocalDS.savePendingStaffChecklist(
          schoolId: schoolId,
          processType: processType.isNotEmpty ? processType : 'create',
          listType: listType.isNotEmpty ? listType : 'selected',
          cardType: cardType,
          cardFor: cardFor,
          staffUuids: selectedUuids,
        );

        // Add staff to staff_corrections locally
        final staffDetails = await _staffLocalDS.getStaffByUuids(selectedUuids);
        final staffByUuid = {for (var s in staffDetails) s.uuid: s};

        // Build correction items — use staff from local DB if found,
        // otherwise create a minimal placeholder so the entry is still saved.
        final correctionItems = selectedUuids.asMap().entries.map((entry) {
          final uuid = entry.value;
          final s = staffByUuid[uuid];
          // Use a stable negative id derived from index to avoid id=0 skip
          final itemId = s != null && s.id != 0
              ? s.id
              : -(entry.key + 1); // negative placeholder id
          return StaffCorrectionItem(
            id: itemId,
            uuid: uuid,
            status: 'pending',
            remark: null, // no remark — avoids showing 'Offline Processed' text
            staff: s,
          );
        }).toList();

        await _localDS.insertStaffCorrections(correctionItems, schoolId);

        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          sendOrderError: null,
        ));
        return;
      }

      // ── ONLINE: send to API ──
      final url = '${Config.baseUrl}auth/school/$schoolId/staff/correction-lists/process';
      final body = <String, dynamic>{
        'processType': processType.isNotEmpty ? processType : 'create',
        'listType': listType.isNotEmpty ? listType : 'selected',
        'staff': selectedUuids,
        if (cardType.isNotEmpty) 'card_type': cardType,
        if (cardFor.isNotEmpty) 'card_for': cardFor,
      };
      final response = await _api.postRequest(body, url);
      if (response == null) {
        emit(state.copyWith(sendOrderLoading: false, sendOrderError: 'Failed to process order'));
        return;
      }
      final json = jsonDecode(response.body);
      if (json['success'] == true) {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderSuccess: true,
          selectedIds: {},
        ));
      } else {
        emit(state.copyWith(
          sendOrderLoading: false,
          sendOrderError: json['message'] ?? 'Failed to process order',
        ));
      }
    } catch (e) {
      emit(state.copyWith(sendOrderLoading: false, sendOrderError: e.toString()));
    }
  }

  /// Sync pending staff checklists when internet is restored
  Future<void> syncPendingStaffChecklists({required String schoolId}) async {
    if (!await _hasInternet()) return;

    final allPending = await _correctionLocalDS.getAllPendingChecklists();
    final staffPending = allPending.where((row) {
      final staffJson = row['staff_json'] as String?;
      return staffJson != null && staffJson.isNotEmpty && staffJson != 'null';
    }).toList();

    if (staffPending.isEmpty) return;

    debugPrint("Syncing ${staffPending.length} pending staff checklists...");

    for (final row in staffPending) {
      try {
        final rowId = row['id'] as int;
        final rowSchoolId = row['school_id'] as String? ?? schoolId;
        final processType = row['process_type'] as String? ?? 'create';
        final listType = row['list_type'] as String? ?? 'selected';
        final cardType = row['card_type'] as String? ?? '';
        final cardFor = jsonDecode(row['card_for'] as String? ?? '[]') as List;
        final staffUuids = jsonDecode(row['staff_json'] as String) as List;

        final url = '${Config.baseUrl}auth/school/$rowSchoolId/staff/correction-lists/process';
        final body = <String, dynamic>{
          'processType': processType,
          'listType': listType,
          'staff': staffUuids.cast<String>(),
          if (cardType.isNotEmpty) 'card_type': cardType,
          if (cardFor.isNotEmpty) 'card_for': cardFor.cast<String>(),
        };

        final response = await _api.postRequest(body, url);
        if (response != null) {
          final json = jsonDecode(response.body);
          if (json['success'] == true) {
            await _correctionLocalDS.deletePendingChecklist(rowId);
            debugPrint("Synced pending staff checklist id=$rowId");
          }
        }
      } catch (e) {
        debugPrint("Failed to sync pending staff checklist: $e");
      }
    }
  }

  /// Fetches staff form fields to use as download columns
  Future<void> fetchStaffDownloadColumns({required String schoolId}) async {
    emit(state.copyWith(columnsLoading: true));
    try {
      // Offline: load from local DB cache
      if (!await _hasInternet()) {
        final cached = await _correctionLocalDS.getDownloadColumns('staff_$schoolId');
        emit(state.copyWith(
          columnsLoading: false,
          downloadColumns: cached.isNotEmpty
              ? cached.map((e) => StaffDownloadColumn(key: e.key, label: e.label)).toList()
              : state.downloadColumns,
        ));
        return;
      }

      final url = '${Config.baseUrl}auth/school/$schoolId/form-fields/staff';
      var response = await _api.getRequest(url);

      if (response == null) {
        emit(state.copyWith(columnsLoading: false));
        return;
      }

      final json = jsonDecode(response.body);
      final data = json['data'] ?? {};

      List rawFields = [];
      if (data['staff_form_fields'] is List) {
        rawFields = data['staff_form_fields'] as List;
      } else if (data['available_staff_form_fields'] is List) {
        rawFields = data['available_staff_form_fields'] as List;
      } else if (json['data'] is List) {
        rawFields = json['data'] as List;
      }

      // Fallback: default staff fields if API returns nothing
      if (rawFields.isEmpty) {
        rawFields = [
          {'name': 'name', 'label': 'Name'},
          {'name': 'father_name', 'label': 'Father Name'},
          {'name': 'phone', 'label': 'Phone'},
          {'name': 'dob', 'label': 'DOB'},
          {'name': 'gender', 'label': 'Gender'},
          {'name': 'email', 'label': 'Email'},
          {'name': 'photo', 'label': 'Photo'},
          {'name': 'designation', 'label': 'Designation'},
          {'name': 'department', 'label': 'Department'},
          {'name': 'employee_id', 'label': 'Employee ID'},
          {'name': 'address', 'label': 'Address'},
        ];
      }

      final columns = rawFields
          .where((e) => e['name'] != null && e['label'] != null)
          .map((e) => StaffDownloadColumn(
        key: e['name'].toString(),
        label: e['label'].toString(),
      ))
          .toList();

      // Cache to local DB for offline use
      if (columns.isNotEmpty) {
        await _correctionLocalDS.saveDownloadColumns(
          'staff_$schoolId',
          columns.map((e) => DownloadColumn(key: e.key, label: e.label)).toList(),
        );
      }

      emit(state.copyWith(columnsLoading: false, downloadColumns: columns));
    } catch (e) {
      emit(state.copyWith(columnsLoading: false));
    }
  }

  Future<Uint8List?> downloadStaffCorrectionList({
    required String schoolId,
    required List<String> ids,
    required List<String> selected,
  }) async {
    try {
      // Offline: generate PDF locally from cached state
      if (!await _hasInternet()) {
        await _correctionLocalDS.savePendingDownload(
          schoolId: schoolId,
          listType: 'staff',
          selectedColumns: selected,
        );
        final school = await UserLocal.getSchool();
        final schoolName = school['schoolName'] ?? 'School';
        final pdfBytes = await PdfHelper.generateStaffCorrectionChecklist(
          schoolName: schoolName,
          items: state.items,
          selectedColumnKeys: selected,
          allColumns: state.downloadColumns,
        );
        return pdfBytes;
      }

      final url = '${Config.baseUrl}auth/school/$schoolId/staff/correction-lists/download';
      final body = <String, dynamic>{
        'ids': ids,
        'selected': selected,
      };

      print("=== downloadStaffCorrectionList REQUEST ===");
      print("URL: $url");
      print("BODY: ${jsonEncode(body)}");

      final response = await _api.postRequest(body, url);

      print("=== downloadStaffCorrectionList RESPONSE ===");
      print("STATUS: ${response?.statusCode}");
      print("CONTENT-TYPE: ${response?.headers['content-type']}");
      print("BODY LENGTH: ${response?.bodyBytes.length}");

      if (response == null) return null;

      // If response is PDF bytes directly
      final contentType = response.headers['content-type']?.toLowerCase() ?? '';
      if (contentType.contains('application/pdf') ||
          contentType.contains('application/octet-stream') ||
          (response.bodyBytes.isNotEmpty && response.bodyBytes.first == 0x25)) {
        return Uint8List.fromList(response.bodyBytes);
      }

      // If response is JSON with a file URL
      try {
        final json = jsonDecode(response.body);
        if (json['success'] == true) {
          final fileUrl = json['data']?['url'] ?? json['data']?['file_url'] ?? '';
          if (fileUrl.toString().isNotEmpty) {
            final res = await _api.getRequest(fileUrl.toString());
            if (res != null && res.bodyBytes.isNotEmpty) {
              return Uint8List.fromList(res.bodyBytes);
            }
          }
        }
      } catch (_) {}

      return null;
    } catch (e) {
      print('downloadStaffCorrectionList error: $e');
      return null;
    }
  }

  Future<String?> uploadStaffPhoto({
    required String schoolId,
    required String uuid,
    required String imagePath,
  }) async {
    try {
      if (!await _hasInternet()) {
        debugPrint("Uploading staff correction photo locally (offline): $uuid");
        // Find the item and update it locally
        final index = state.items.indexWhere((s) => s.uuid == uuid);
        if (index != -1) {
          final item = state.items[index];
          final staff = item.effectiveStaff;
          if (staff != null) {
            final updatedStaff = staff.copyWith(
              isPhotoPendingSync: true,
              offlinePhotoPath: imagePath,
            );
            final updatedItem = StaffCorrectionItem(
              id: item.id,
              uuid: item.uuid,
              status: item.status,
              remark: item.remark,
              staff: item.staff != null ? updatedStaff : null,
              oldData: item.oldData != null ? updatedStaff : null,
            );
            final newItems = List<StaffCorrectionItem>.from(state.items);
            newItems[index] = updatedItem;
            emit(state.copyWith(items: newItems));
            
            // Also save to local DB
            await _localDS.insertStaffCorrections([updatedItem], schoolId);
          }
        }
        return imagePath;
      }

      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}${Routes.uploadStaffPhoto(schoolId, uuid)}';
      print('uploadStaffPhoto URL: $url');
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', imagePath));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      print('uploadStaffPhoto status: ${response.statusCode}');
      print('uploadStaffPhoto body: ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        String? newUrl = json['data']?['profile_photo_url'] as String?;
        if (newUrl != null) {
          final regex = RegExp(r'https?://');
          final matches = regex.allMatches(newUrl).toList();
          if (matches.length > 1) newUrl = newUrl.substring(matches.last.start);
          newUrl = newUrl
              .replaceAll('http://127.0.0.1:8000', 'https://idmitra.com')
              .replaceAll('http://localhost:8000', 'https://idmitra.com')
              .replaceAll('http://localhost', 'https://idmitra.com');
        }
        return newUrl;
      }
    } catch (e) {
      print('uploadStaffPhoto error: $e');
    }
    return null;
  }
}
