import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class StaffRole {
  final int id;
  final String uuid;
  final String name;

  const StaffRole({required this.id, required this.uuid, required this.name});

  factory StaffRole.fromJson(Map<String, dynamic> json) => StaffRole(
    id: json['id'] ?? 0,
    uuid: json['uuid'] ?? '',
    name: json['name'] ?? '',
  );
}

class StaffFormState {
  final bool loading;
  final bool saving;
  final List<StudentFormField> fields;
  final List<StudentFormField> availableFields;
  final List<StaffRole> roles;
  final String? error;
  final String? successMessage;
  final String schoolName;

  const StaffFormState({
    this.loading = false,
    this.saving = false,
    this.fields = const [],
    this.availableFields = const [],
    this.roles = const [],
    this.error,
    this.successMessage,
    this.schoolName = '',
  });

  StaffFormState copyWith({
    bool? loading,
    bool? saving,
    List<StudentFormField>? fields,
    List<StudentFormField>? availableFields,
    List<StaffRole>? roles,
    String? error,
    String? successMessage,
    String? schoolName,
    bool clearError = false,
    bool clearSuccess = false,
  }) => StaffFormState(
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    fields: fields ?? this.fields,
    availableFields: availableFields ?? this.availableFields,
    roles: roles ?? this.roles,
    error: clearError ? null : (error ?? this.error),
    successMessage: clearSuccess
        ? null
        : (successMessage ?? this.successMessage),
    schoolName: schoolName ?? this.schoolName,
  );
}

class StaffFormCubit extends Cubit<StaffFormState> {
  StaffFormCubit() : super(const StaffFormState());

  String _schoolId = '';

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

  void clearMessages() {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }

  Future<void> loadFields(String schoolId, {String schoolName = ''}) async {
    _schoolId = schoolId;
    emit(
      state.copyWith(loading: true, clearError: true, schoolName: schoolName),
    );

    // Step 1: Try local DB first (instant)
    final local = await _loadFromLocal(schoolId);
    if (local != null && local.$1.isNotEmpty) {
      emit(
        state.copyWith(
          loading: false,
          fields: local.$1,
          availableFields: local.$2,
          roles: local.$3,
          schoolName: schoolName,
        ),
      );
      // Background sync
      _syncFromApi(schoolId, schoolName: schoolName);
      return;
    }

    // Step 2: No local data — check internet
    if (!await _hasInternet()) {
      emit(
        state.copyWith(
          loading: false,
          fields: _partnerDefaultFields(),
          availableFields: _staffAllAvailableFields(),
          schoolName: schoolName,
        ),
      );
      return;
    }

    // Step 3: Fetch from API
    await _syncFromApi(schoolId, emitStates: true, schoolName: schoolName);
  }

  // Load staff form fields + roles from local DB
  Future<(List<StudentFormField>, List<StudentFormField>, List<StaffRole>)?>
  _loadFromLocal(String schoolId) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_fields',
        where: 'school_id = ?',
        whereArgs: ['staff_$schoolId'],
        limit: 1,
      ); 
      if (rows.isEmpty) return null;

      final row = rows.first;
      final rawFields =
          jsonDecode(row['fields_json'] as String? ?? '[]') as List;
      final rawAvailable =
          jsonDecode(row['available_fields_json'] as String? ?? '[]') as List;
      final rawRoles = jsonDecode(row['roles_json'] as String? ?? '[]') as List;

      final fields = rawFields
          .map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final available = _staffAllAvailableFields();
      final roles = rawRoles
          .map((e) => StaffRole.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      print(
        '[StaffForm] Loaded from local DB — fields: ${fields.length}, roles: ${roles.length}',
      );
      return (fields, available, roles);
    } catch (e) {
      print('[StaffForm] Local load error: $e');
      return null;
    }
  }

  Future<void> _syncFromApi(
    String schoolId, {
    bool emitStates = false,
    String schoolName = '',
  }) async {
    try {
      final token = await UserSecureStorage.fetchToken();
      final role = await UserSecureStorage.fetchRole();
      final isPartner = role == 'partner';

      print(
        '[StaffForm] Syncing from API — schoolId: $schoolId, isPartner: $isPartner',
      );

      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      };

      List<StudentFormField> fields = [];
      List<StudentFormField> availableFields = [];
      List<StaffRole> roles = [];

      // Fetch staff form fields
      final fieldsUrl = Config.url(
        Routes.getStaffFormFields(schoolId, isPartner: isPartner),
      );
      print('[StaffForm] Fields URL: $fieldsUrl');

      try {
        final fieldsResp = await http.get(
          Uri.parse(fieldsUrl),
          headers: headers,
        );
        print('[StaffForm] Fields status: ${fieldsResp.statusCode}');

        if (fieldsResp.statusCode == 200) {
          final fJson = jsonDecode(fieldsResp.body);
          final formData = _extractFormFieldsData(fJson);

          if (formData != null) {
            final List currentFields = formData['staff_form_fields'] ?? [];
            final List availableFieldsList =
                formData['available_staff_form_fields'] ?? [];

            fields = currentFields
                .map(
                  (e) =>
                      StudentFormField.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
            availableFields = availableFieldsList
                .map(
                  (e) =>
                      StudentFormField.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
          }
        }
      } catch (e) {
        print('[StaffForm] Fields API error: $e');
        if (isPartner && emitStates) {
          fields = _partnerDefaultFields();
          availableFields = _staffAllAvailableFields();
        }
      }

      // Fetch roles
      final rolesUrls = [
        Config.url(Routes.getStaffRoles(schoolId, isPartner: isPartner)),
        Config.url(Routes.getStaffRoles(schoolId, isPartner: !isPartner)),
      ];

      for (final rolesUrl in rolesUrls) {
        try {
          final rolesResp = await http.get(
            Uri.parse(rolesUrl),
            headers: headers,
          );
          if (rolesResp.statusCode == 200) {
            final rJson = jsonDecode(rolesResp.body);
            List rawRoles = _extractRolesList(rJson);
            roles = rawRoles
                .map((e) => StaffRole.fromJson(Map<String, dynamic>.from(e)))
                .toList();
            if (roles.isNotEmpty) break;
          }
        } catch (e) {
          print('[StaffForm] Roles API error: $e');
        }
      }

      // Save to local DB only if we got data
      if (fields.isNotEmpty || roles.isNotEmpty) {
        await _saveToLocal(schoolId, fields, availableFields, roles);
      }

      if (emitStates || fields.isNotEmpty) {
        emit(
          state.copyWith(
            loading: false,
            fields: fields,
            availableFields: _staffAllAvailableFields(),
            roles: roles,
            schoolName: schoolName,
          ),
        );
      }
    } catch (e) {
      print('[StaffForm] Sync error: $e');
      if (emitStates) {
        emit(
          state.copyWith(loading: false, error: 'Failed to sync staff fields'),
        );
      }
    }
  }

  // Save staff form fields + roles to local DB
  Future<void> _saveToLocal(
    String schoolId,
    List<StudentFormField> fields,
    List<StudentFormField> availableFields,
    List<StaffRole> roles,
  ) async {
    try {
      final db = await DBHelper.db;

      final fieldsJson = jsonEncode(
        fields
            .map(
              (f) => {
                'name': f.name,
                'label': f.label,
                'type': f.type,
                'group': f.group,
                'group_label': f.groupLabel,
                'required': f.required,
                'order': f.order,
              },
            )
            .toList(),
      );

      final availableJson = jsonEncode(
        availableFields
            .map(
              (f) => {
                'name': f.name,
                'label': f.label,
                'type': f.type,
                'group': f.group,
                'group_label': f.groupLabel,
                'required': f.required,
                'order': f.order,
              },
            )
            .toList(),
      );

      final rolesJson = jsonEncode(
        roles.map((r) => {'id': r.id, 'uuid': r.uuid, 'name': r.name}).toList(),
      );

      await db.insert('school_form_fields', {
        'school_id': 'staff_$schoolId',
        'fields_json': fieldsJson,
        'available_fields_json': availableJson,
        'roles_json': rolesJson,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      print('[StaffForm] Saved to local DB — school: $schoolId');
    } catch (e) {
      print('[StaffForm] Local save error: $e');
    }
  }

  Future<void> updateStaffFormFields(
    List<StudentFormField> updatedFields,
  ) async {
    emit(state.copyWith(saving: true, clearError: true, clearSuccess: true));

    final token = await UserSecureStorage.fetchToken();
    final url = Config.url('auth/school/$_schoolId/form-fields/staff');
    print('Update Staff URL: $url');

    final response = await http.put(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'fields': updatedFields
            .map(
              (f) => {
                'name': f.name,
                'label': f.label,
                'group': f.group,
                'group_label': f.groupLabel,
                'type': f.type,
                'required': f.required,
                'order': f.order,
              },
            )
            .toList(),
      }),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      emit(
        state.copyWith(
          saving: false,
          successMessage:
              json['message'] ?? 'Staff form fields updated successfully',
          fields: updatedFields,
        ),
      );
    } else {
      emit(
        state.copyWith(
          saving: false,
          error: 'Update failed: ${response.statusCode}',
        ),
      );
    }
  }

  List _extractRolesList(dynamic json) {
    if (json == null) return [];
    if (json is List) return json;
    if (json is! Map) return [];
    for (final key in ['data', 'roles', 'items', 'result', 'results']) {
      final val = json[key];
      if (val is List && val.isNotEmpty) return val;
      if (val is Map) {
        for (final innerKey in [
          'data',
          'roles',
          'items',
          'result',
          'results',
          'list',
        ]) {
          final inner = val[innerKey];
          if (inner is List && inner.isNotEmpty) return inner;
        }
      }
    }
    return [];
  }

  Map<String, dynamic>? _extractFormFieldsData(dynamic json) {
    if (json == null) return null;
    if (json is! Map) return null;

    // Check for nested data structures
    if (json.containsKey('props')) {
      final props = json['props'];
      if (props is Map && props.containsKey('school')) {
        return Map<String, dynamic>.from(props['school']);
      }
    }

    if (json.containsKey('data')) {
      final data = json['data'];
      if (data is Map) {
        // API returns "fields" key, we need to map it to expected structure
        if (data.containsKey('fields')) {
          return {
            'staff_form_fields': data['fields'],
            'available_staff_form_fields':
                data['fields'], // Same fields for available
          };
        }
        return Map<String, dynamic>.from(data);
      }
    }

    // Return the json itself if it contains the expected fields
    if (json.containsKey('staff_form_fields') ||
        json.containsKey('available_staff_form_fields')) {
      return Map<String, dynamic>.from(json);
    }

    return null;
  }

  List<StudentFormField> _partnerDefaultFields() {
    return [
      StudentFormField(
        name: 'designation',
        label: 'Designation',
        type: 'text',
        required: false,
        order: 1,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'department',
        label: 'Department',
        type: 'text',
        required: false,
        order: 2,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'name',
        label: 'Name',
        type: 'text',
        required: true,
        order: 3,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'phone',
        label: 'Phone',
        type: 'phone',
        required: true,
        order: 4,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'email',
        label: 'Email',
        type: 'email',
        required: false,
        order: 5,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'role',
        label: 'Role',
        type: 'select',
        required: true,
        order: 6,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'password',
        label: 'Password',
        type: 'password',
        required: false,
        order: 7,
        group: 'login_details',
        groupLabel: 'Login Details',
      ),
      StudentFormField(
        name: 'password_confirmation',
        label: 'Confirm Password',
        type: 'password',
        required: false,
        order: 8,
        group: 'login_details',
        groupLabel: 'Login Details',
      ),
    ];
  }

  List<StudentFormField> _staffAllAvailableFields() {
    return [
      // ── Staff Details ──────────────────────────────────────
      StudentFormField(
        name: 'designation',
        label: 'Designation',
        type: 'text',
        required: false,
        order: 1,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'department',
        label: 'Department',
        type: 'text',
        required: false,
        order: 2,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'name',
        label: 'Name',
        type: 'text',
        required: true,
        order: 3,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'phone',
        label: 'Phone',
        type: 'phone',
        required: true,
        order: 4,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'email',
        label: 'Email',
        type: 'email',
        required: false,
        order: 5,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'role',
        label: 'Role',
        type: 'select',
        required: true,
        order: 6,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'employee_id',
        label: 'Employee Id',
        type: 'text',
        required: false,
        order: 7,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'gender',
        label: 'Gender',
        type: 'select',
        required: false,
        order: 8,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'date_of_birth',
        label: 'Date of Birth',
        type: 'date',
        required: false,
        order: 9,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'date_of_joining',
        label: 'Date Of Joining',
        type: 'date',
        required: false,
        order: 10,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'blood_group',
        label: 'Blood Group',
        type: 'select',
        required: false,
        order: 11,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'whatsapp_number',
        label: 'Whatsapp Number',
        type: 'phone',
        required: false,
        order: 12,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'father_name',
        label: 'Father Name',
        type: 'text',
        required: false,
        order: 13,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'mother_name',
        label: 'Mother Name',
        type: 'text',
        required: false,
        order: 14,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'husband_name',
        label: 'Husband Name',
        type: 'text',
        required: false,
        order: 15,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'national_code',
        label: 'National Code',
        type: 'text',
        required: false,
        order: 16,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'address',
        label: 'Address',
        type: 'textarea',
        required: false,
        order: 17,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      StudentFormField(
        name: 'pincode',
        label: 'Pincode',
        type: 'digits',
        required: false,
        order: 18,
        group: 'staff_details',
        groupLabel: 'Staff Details',
      ),
      // ── Login Details ──────────────────────────────────────
      StudentFormField(
        name: 'password',
        label: 'Password',
        type: 'password',
        required: false,
        order: 19,
        group: 'login_details',
        groupLabel: 'Login Details',
      ),
      StudentFormField(
        name: 'password_confirmation',
        label: 'Confirm Password',
        type: 'password',
        required: false,
        order: 20,
        group: 'login_details',
        groupLabel: 'Login Details',
      ),
    ];
  }
}
