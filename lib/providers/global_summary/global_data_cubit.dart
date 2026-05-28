import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/local_db/global_summary_local_ds/global_summary_local_ds.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/global_summary/global_summary_model.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/global_summary/global_summary_state.dart';
import 'package:sqflite/sqflite.dart';

class GlobalDataCubit extends Cubit<GlobalSummaryState> {
  final _api = ApiManager();
  final _studentDS = StudentLocalDS();
  final _summaryDS = GlobalSummaryLocalDS();
  StreamSubscription? _connectivitySub;

  GlobalDataCubit() : super(const GlobalSummaryState()) {
    _init();
  }

  Future<void> _init() async {
    final cached = await _summaryDS.loadCachedSummary();
    if (cached != null) {
      emit(state.copyWith(
        localData: cached,
        status: GlobalSyncStatus.idle,
        statusText: 'Last synced: ${_formatDate(cached.syncedAt)}',
        progress: 1.0,
      ));
    }
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (hasInternet && state.status != GlobalSyncStatus.syncing) {
        await syncAll();
      }
    });
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }

  // ─── 429-aware GET ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> _getJson(String url) async {
    var response = await _api.getRequest(url);
    if (response != null && response.statusCode == 429) {
      print('[GlobalSync] ⚠ 429 rate limit hit — waiting 5s before retry. URL: $url');
      _updateProgress(state.progress, ' Rate limited — waiting 5s...');
      await Future.delayed(const Duration(seconds: 5));
      response = await _api.getRequest(url);
    }
    if (response == null || response.statusCode != 200) return null;
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ─── Main sync ────────────────────────────────────────────────────────────

  Future<void> syncAll() async {
    if (state.isSyncing) return;

    final hasInternet = await _hasInternet();
    if (!hasInternet) {
      final cached = await _summaryDS.loadCachedSummary();
      emit(state.copyWith(
        status: GlobalSyncStatus.noInternet,
        localData: cached,
        progress: cached != null ? 1.0 : 0.0,
        statusText: cached != null
            ? 'Offline — showing data from ${_formatDate(cached.syncedAt)}'
            : 'No internet connection',
      ));
      return;
    }

    emit(state.copyWith(
      status: GlobalSyncStatus.syncing,
      progress: 0.02,
      statusText: 'Starting sync...',
    ));
    print('[GlobalSync]  Sync started');

    try {
      // Step 1: Summary API (fast single call) — also returns server-side totals
      final serverTotals = await _syncSummary();

      // Step 2: Full paginated data — single combined strategy
      final savedCounts = await _syncAllEntities(serverTotals: serverTotals);

      final cached = await _summaryDS.loadCachedSummary();
      final sc = savedCounts['schools'] ?? 0;
      final st = savedCounts['students'] ?? 0;
      final or_ = savedCounts['orders'] ?? 0;
      final so = savedCounts['staffOrders'] ?? 0;
      final tSc = serverTotals['schools'] ?? 0;
      final tSt = serverTotals['students'] ?? 0;
      final tOr = serverTotals['orders'] ?? 0;
      final tSo = serverTotals['staffOrders'] ?? 0;
      emit(state.copyWith(
        status: GlobalSyncStatus.success,
        localData: cached,
        progress: 1.0,
        statusText: 'Synced at ${_formatDate(DateTime.now())}'
            '\nSchools: $sc/$tSc | Students: $st/$tSt'
            '\nOrders: $or_/$tOr | Staff Orders: $so/$tSo',
        errorMessage: null,
      ));
    } catch (e) {
      _emitError('Sync failed: $e');
    }
  }

  // ─── Summary ─────────────────────────────────────────────────────────────

  Future<Map<String, int>> _syncSummary() async {
    _updateProgress(0.03, 'Fetching summary...');
    final json = await _getJson(Config.url(Routes.getGlobalSummary()));
    if (json == null || json['success'] != true) return {};
    final model = GlobalSummaryModel.fromJson(json);
    await _summaryDS.saveSummary(model);
    _updateProgress(0.06, 'Summary saved');
    return {
      'schools': model.data.counts.schools.total,
      'students': model.data.counts.students.total,
      'orders': model.data.counts.orders.total,
      'staffOrders': model.data.counts.staffOrders.total,
    };
  }

  Future<Map<String, int>> _syncAllEntities({Map<String, int> serverTotals = const {}}) async {
    final db = await DBHelper.db;

    await db.delete('schools');
    await db.delete('orders', where: 'is_offline = 0');
    await db.delete('gs_staff_orders');
    await db.delete('gs_student_corrections');
    await db.delete('gs_staff_corrections');

    // Per-entity page tracking
    int schoolsPage = 1, schoolsLastPage = 1;
    int studentsPage = 1, studentsLastPage = 1;
    int ordersPage = 1, ordersLastPage = 1;
    int staffOrdersPage = 1, staffOrdersLastPage = 1;
    int studentCorrectionsPage = 1, studentCorrectionsLastPage = 1;
    int staffCorrectionsPage = 1, staffCorrectionsLastPage = 1;

    // Counters for status text
    int savedStudents = 0, savedOrders = 0, savedSchools = 0;
    int savedStaffOrders = 0, savedStudentCorrections = 0, savedStaffCorrections = 0;

    // First request to discover last_page for all entities
    bool firstRequest = true;

    while (true) {
      // Check if all entities are done
      final schoolsDone = schoolsPage > schoolsLastPage;
      final studentsDone = studentsPage > studentsLastPage;
      final ordersDone = ordersPage > ordersLastPage;
      final staffOrdersDone = staffOrdersPage > staffOrdersLastPage;
      final studentCorrectionsDone = studentCorrectionsPage > studentCorrectionsLastPage;
      final staffCorrectionsDone = staffCorrectionsPage > staffCorrectionsLastPage;

      if (!firstRequest &&
          schoolsDone &&
          studentsDone &&
          ordersDone &&
          staffOrdersDone &&
          studentCorrectionsDone &&
          staffCorrectionsDone) {
        break;
      }

      // Build URL with current page for each entity (only include if not done)
      final url = _buildUrl(
        schoolsPage: schoolsDone ? null : schoolsPage,
        studentsPage: studentsDone ? null : studentsPage,
        ordersPage: ordersDone ? null : ordersPage,
        staffOrdersPage: staffOrdersDone ? null : staffOrdersPage,
        studentCorrectionsPage: studentCorrectionsDone ? null : studentCorrectionsPage,
        staffCorrectionsPage: staffCorrectionsDone ? null : staffCorrectionsPage,
      );

      final json = await _getJson(url);
      if (json == null || json['success'] != true) {
        // Skip this page on error, advance all pending pages to avoid infinite loop
        if (!schoolsDone) schoolsPage++;
        if (!studentsDone) studentsPage++;
        if (!ordersDone) ordersPage++;
        if (!staffOrdersDone) staffOrdersPage++;
        if (!studentCorrectionsDone) studentCorrectionsPage++;
        if (!staffCorrectionsDone) staffCorrectionsPage++;
        continue;
      }

      final data = json['data'] as Map<String, dynamic>? ?? {};
      firstRequest = false;

      // ── Schools ──
      if (!schoolsDone) {
        final sd = data['schools'] as Map<String, dynamic>?;
        if (sd != null) {
          schoolsLastPage = (sd['last_page'] as int?) ?? 1;
          final items = sd['data'] as List? ?? [];
          final now = DateTime.now().millisecondsSinceEpoch;
          final batch = db.batch();
          for (final s in items) {
            final school = s as Map<String, dynamic>;
            final schoolIdStr = school['id'].toString();

            // Save school raw JSON
            batch.insert('schools', {
              'id': school['id'],
              'raw_json': jsonEncode(school),
              'updated_at': now,
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            // Save student_form_fields → school_form_fields (key: schoolId)
            final studentFields = school['student_form_fields'];
            if (studentFields != null) {
              batch.insert('school_form_fields', {
                'school_id': schoolIdStr,
                'fields_json': jsonEncode(studentFields),
                'updated_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }

            // Save staff_form_fields → school_form_fields (key: 'staff_schoolId')
            final staffFields = school['staff_form_fields'];
            if (staffFields != null) {
              batch.insert('school_form_fields', {
                'school_id': 'staff_$schoolIdStr',
                'fields_json': jsonEncode(staffFields),
                'updated_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }

            // Save image_settings → image_settings table
            final imageSettings = school['image_settings'];
            if (imageSettings != null) {
              batch.insert('image_settings', {
                'school_id': schoolIdStr,
                'settings_json': jsonEncode(imageSettings),
                'updated_at': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
          await batch.commit(noResult: true);
          savedSchools += items.length;
          print('[GlobalSync] Schools page $schoolsPage/$schoolsLastPage — saved ${items.length} (total: $savedSchools)');

          // Sync sessions/classes/houses and staff roles for each school
          for (final s in items) {
            final school = s as Map<String, dynamic>;
            final schoolIdStr = school['id'].toString();
            await _syncSchoolFormData(db, schoolIdStr);
            await _syncStaffRoles(db, schoolIdStr);
          }

          schoolsPage++;
        }
      }

      // ── Students ──
      if (!studentsDone) {
        final sd = data['students'] as Map<String, dynamic>?;
        if (sd != null) {
          studentsLastPage = (sd['last_page'] as int?) ?? 1;
          final items = sd['data'] as List? ?? [];
          final students = items
              .map((s) => StudentDetailsData.fromJson(s as Map<String, dynamic>))
              .toList();
          await _studentDS.insertStudents(students);
          savedStudents += students.length;
          print('[GlobalSync] Students page $studentsPage/$studentsLastPage — saved ${students.length} (total: $savedStudents)');
          studentsPage++;
        }
      }

      // ── Orders ──
      if (!ordersDone) {
        final od = data['orders'] as Map<String, dynamic>?;
        if (od != null) {
          ordersLastPage = (od['last_page'] as int?) ?? 1;
          final items = od['data'] as List? ?? [];
          final batch = db.batch();
          for (final o in items) {
            final map = o as Map<String, dynamic>;
            final order = OrderModel.fromJson({
              ...map,
              'orderd_at': map['created_at'],
              'ordered_at': map['created_at'],
              'received_at_short': '',
              'student_card': 0,
              'student_card_qty': map['student_card_qty'] ?? 1,
              'parent_card': 0,
              'admit_card': 0,
            });
            batch.insert('orders', {
              'id': order.id,
              'uuid': order.uuid,
              'school_id': order.school?.id ?? 0,
              'status': order.status,
              'type': order.type,
              'ordered_at': order.orderedAt,
              'received_at_short': '',
              'student_card': 0,
              'student_card_qty': order.studentCardQty,
              'parent_card': 0,
              'admit_card': 0,
              'printing_issue': order.printingIssue,
              'delivered_at': order.deliveredAt,
              'cancelled_at': order.cancelledAt,
              'school_json': jsonEncode(order.school != null ? {
                'id': order.school!.id,
                'name': order.school!.name,
                'logo_url': order.school!.logoUrl,
                'address': order.school!.address,
                'pincode': order.school!.pincode,
                'prefix': order.school!.prefix,
              } : {}),
              'student_json': jsonEncode(order.student != null ? {
                'id': order.student!.id,
                'name': order.student!.name,
                'profile_photo_url': order.student!.profilePhotoUrl,
                'className': order.student!.className,
                'classId': order.student!.classId,
                'sectionName': order.student!.sectionName,
                'gender': order.student!.gender,
                'dob': order.student!.dob,
                'fatherName': order.student!.fatherName,
                'fatherPhone': order.student!.fatherPhone,
                'motherName': order.student!.motherName,
                'address': order.student!.address,
                'pincode': order.student!.pincode,
                'loginId': order.student!.loginId,
              } : {}),
              'staff_json': '{}',
              'raw_data': '{}',
              'is_offline': 0,
              'updated_at': DateTime.now().millisecondsSinceEpoch,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          savedOrders += items.length;
          print('[GlobalSync] Orders page $ordersPage/$ordersLastPage — saved ${items.length} (total: $savedOrders)');
          ordersPage++;
        }
      }

      // ── Staff Orders ──
      if (!staffOrdersDone) {
        final sod = data['staff_orders'] as Map<String, dynamic>?;
        if (sod != null) {
          staffOrdersLastPage = (sod['last_page'] as int?) ?? 1;
          final items = sod['data'] as List? ?? [];
          final batch = db.batch();
          for (final so in items) {
            final map = so as Map<String, dynamic>;
            final staff = map['staff'] as Map<String, dynamic>?;
            batch.insert('gs_staff_orders', {
              'id': map['id'],
              'uuid': map['uuid'] ?? '',
              'school_id': map['school_id'],
              'school_name': (map['school'] as Map<String, dynamic>?)?['name'] ?? '',
              'school_prefix': (map['school'] as Map<String, dynamic>?)?['school_prefix'] ?? '',
              'school_staff_id': map['school_staff_id'],
              'staff_name': staff?['name'] ?? '',
              'type': map['type'] ?? '',
              'quantity': map['quantity']?.toString() ?? '1',
              'status': map['status'] ?? '',
              'created_at': map['created_at'] ?? '',
              'raw_json': jsonEncode(map),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          savedStaffOrders += items.length;
          print('[GlobalSync] Staff orders page $staffOrdersPage/$staffOrdersLastPage — saved ${items.length} (total: $savedStaffOrders)');
          staffOrdersPage++;
        }
      }

      // ── Student Corrections ──
      if (!studentCorrectionsDone) {
        final scd = data['student_corrections'] as Map<String, dynamic>?;
        if (scd != null) {
          studentCorrectionsLastPage = (scd['last_page'] as int?) ?? 1;
          final items = scd['data'] as List? ?? [];
          final batch = db.batch();
          for (final sc in items) {
            final map = sc as Map<String, dynamic>;
            batch.insert('gs_student_corrections', {
              'id': map['id'],
              'uuid': map['uuid'] ?? '',
              'school_id': map['school_id'],
              'school_name': map['school_name'] ?? '',
              'school_prefix': map['school_prefix'] ?? '',
              'list_type': map['list_type'] ?? '',
              'status': map['status'] ?? '',
              'class_name': map['class_name'],
              'section_name': map['section_name']?.toString(),
              'created_at': map['created_at'] ?? '',
              'raw_json': jsonEncode(map),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          savedStudentCorrections += items.length;
          print('[GlobalSync] Student corrections page $studentCorrectionsPage/$studentCorrectionsLastPage — saved ${items.length} (total: $savedStudentCorrections)');
          studentCorrectionsPage++;
        }
      }

      // ── Staff Corrections ──
      if (!staffCorrectionsDone) {
        final scd = data['staff_corrections'] as Map<String, dynamic>?;
        if (scd != null) {
          staffCorrectionsLastPage = (scd['last_page'] as int?) ?? 1;
          final items = scd['data'] as List? ?? [];
          final batch = db.batch();
          for (final sc in items) {
            final map = sc as Map<String, dynamic>;
            batch.insert('gs_staff_corrections', {
              'id': map['id'],
              'school_id': map['school_id'],
              'school_name': map['school_name'] ?? '',
              'school_prefix': map['school_prefix'] ?? '',
              'school_staff_id': map['school_staff_id'],
              'staff_name': map['staff_name'] ?? '',
              'created_at': map['created_at'] ?? '',
              'raw_json': jsonEncode(map),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
          savedStaffCorrections += items.length;
          print('[GlobalSync] Staff corrections page $staffCorrectionsPage/$staffCorrectionsLastPage — saved ${items.length} (total: $savedStaffCorrections)');
          staffCorrectionsPage++;
        }
      }

      // ── Progress update ──
      // Use students as the primary progress driver (most pages)
      final totalPages = studentsLastPage > 0 ? studentsLastPage : 1;
      final currentPage = studentsPage - 1;
      final progress = 0.06 + 0.92 * (currentPage / totalPages);
      final tSt = serverTotals['students'] ?? 0;
      final tOr = serverTotals['orders'] ?? 0;
      final tSo = serverTotals['staffOrders'] ?? 0;
      _updateProgress(
        progress.clamp(0.06, 0.98),
        'Schools: $savedSchools | Students: $savedStudents${tSt > 0 ? "/$tSt" : ""}'
        ' | Orders: $savedOrders${tOr > 0 ? "/$tOr" : ""}'
        '\nStaff Orders: $savedStaffOrders${tSo > 0 ? "/$tSo" : ""}'
        ' | Corrections: $savedStudentCorrections | Staff Corr: $savedStaffCorrections',
      );
    }

    print('[GlobalSync]  SYNC COMPLETE — Schools: $savedSchools | Students: $savedStudents | Orders: $savedOrders | Staff Orders: $savedStaffOrders | Student Corrections: $savedStudentCorrections | Staff Corrections: $savedStaffCorrections');
    return {
      'schools': savedSchools,
      'students': savedStudents,
      'orders': savedOrders,
      'staffOrders': savedStaffOrders,
      'studentCorrections': savedStudentCorrections,
      'staffCorrections': savedStaffCorrections,
    };
  }

  // ─── Per-school form data sync ────────────────────────────────────────────

  Future<void> _syncSchoolFormData(Database db, String schoolId) async {
    try {
      final json = await _getJson(Config.url('auth/school/$schoolId/students/form-data'));
      if (json == null) return;

      final data = (json['data'] ?? json) as Map<String, dynamic>? ?? {};

      final sessions = jsonEncode((data['sessions'] as List? ?? []).map((s) {
        final m = s as Map<String, dynamic>;
        return {'value': m['value'], 'label': m['label'] ?? ''};
      }).toList());

      final classes = jsonEncode((data['classes'] as List? ?? []).map((c) {
        final m = c as Map<String, dynamic>;
        final sections = (m['sections'] as List? ?? []).map((sec) {
          final sm = sec as Map<String, dynamic>;
          return {'id': sm['id'], 'name': sm['name'] ?? ''};
        }).toList();
        final sectionsIds = (m['sections_ids'] as List? ?? [])
            .map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
            .toList();
        return {
          'id': m['id'],
          'name': m['name'] ?? '',
          'name_withprefix': m['name_withprefix'] ?? m['name'] ?? '',
          'sections': sections,
          'sections_ids': sectionsIds,
        };
      }).toList());

      final houses = jsonEncode((data['houses'] as List? ?? []).map((h) {
        final m = h as Map<String, dynamic>;
        return {'id': m['id'], 'name': m['name'] ?? ''};
      }).toList());

      await db.insert('school_form_data', {
        'school_id': schoolId,
        'sessions_json': sessions,
        'classes_json': classes,
        'houses_json': houses,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      print('[GlobalSync] School form data saved — schoolId: $schoolId');
    } catch (e) {
      print('[GlobalSync] School form data sync error — schoolId: $schoolId, error: $e');
    }
  }

  Future<void> _syncStaffRoles(Database db, String schoolId) async {
    try {
      // Only update if staff_form_fields row exists (i.e. school has staff fields configured)
      final existing = await db.query(
        'school_form_fields',
        where: 'school_id = ?',
        whereArgs: ['staff_$schoolId'],
        limit: 1,
      );
      if (existing.isEmpty) return;

      final json = await _getJson(Config.url('auth/partner/school/$schoolId/staff/roles/list'));
      if (json == null) return;

      // Extract roles list from various response shapes
      List rawRoles = [];
      final d = json['data'];
      if (d is List) {
        rawRoles = d;
      } else if (d is Map) {
        final inner = d['data'];
        if (inner is List) rawRoles = inner;
      }
      if (rawRoles.isEmpty) return;

      final rolesJson = jsonEncode(rawRoles.map((r) {
        final m = r as Map<String, dynamic>;
        return {'id': m['id'], 'uuid': m['uuid'] ?? '', 'name': m['name'] ?? ''};
      }).toList());

      await db.update(
        'school_form_fields',
        {'roles_json': rolesJson, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'school_id = ?',
        whereArgs: ['staff_$schoolId'],
      );

      print('[GlobalSync] Staff roles saved — schoolId: $schoolId, count: ${rawRoles.length}');
    } catch (e) {
      print('[GlobalSync] Staff roles sync error — schoolId: $schoolId, error: $e');
    }
  }

  // ─── Build combined URL ───────────────────────────────────────────────────

  String _buildUrl({
    int? schoolsPage,
    int? studentsPage,
    int? ordersPage,
    int? staffOrdersPage,
    int? studentCorrectionsPage,
    int? staffCorrectionsPage,
  }) {
    final includes = <String>[];
    final params = <String>[];

    if (schoolsPage != null) {
      includes.add('schools');
      params.add('schools_page=$schoolsPage');
      params.add('schools_per_page=25');
    }
    if (studentsPage != null) {
      includes.add('students');
      params.add('students_page=$studentsPage');
      params.add('students_per_page=25');
    }
    if (ordersPage != null) {
      includes.add('orders');
      params.add('orders_page=$ordersPage');
      params.add('orders_per_page=25');
    }
    if (staffOrdersPage != null) {
      includes.add('staff_orders');
      params.add('staff_orders_page=$staffOrdersPage');
      params.add('staff_orders_per_page=100');
    }
    if (studentCorrectionsPage != null) {
      includes.add('student_corrections');
      params.add('student_corrections_page=$studentCorrectionsPage');
      params.add('student_corrections_per_page=100');
    }
    if (staffCorrectionsPage != null) {
      includes.add('staff_corrections');
      params.add('staff_corrections_page=$staffCorrectionsPage');
      params.add('staff_corrections_per_page=100');
    }

    final includeStr = includes.join(',');
    final paramStr = params.join('&');
    return Config.url('auth/partner/global/data?include=$includeStr&$paramStr');
  }

  // ─── Load from local ──────────────────────────────────────────────────────

  Future<void> loadFromLocal() async {
    final cached = await _summaryDS.loadCachedSummary();
    if (cached != null) {
      emit(state.copyWith(
        localData: cached,
        status: GlobalSyncStatus.idle,
        progress: 1.0,
        statusText: 'Last synced: ${_formatDate(cached.syncedAt)}',
      ));
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  void _updateProgress(double progress, String text) {
    if (!isClosed) {
      emit(state.copyWith(
        status: GlobalSyncStatus.syncing,
        progress: progress,
        statusText: text,
      ));
    }
  }

  void _emitError(String msg) {
    if (!isClosed) {
      emit(state.copyWith(
        status: GlobalSyncStatus.error,
        errorMessage: msg,
        statusText: msg,
        progress: 0.0,
      ));
    }
  }

  Future<bool> _hasInternet() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none) && connectivity.length == 1) {
        return false;
      }
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  String _formatDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day}/${dt.month}/${dt.year} $h:$m';
  }
}
