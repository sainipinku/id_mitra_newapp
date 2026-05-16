import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';
import 'package:sqflite/sqflite.dart';

part 'student_form_state.dart';

const List<Map<String, dynamic>> _kAllAvailableFields = [
  {
    'name': 'student_phone',
    'label': 'Student Phone',
    'type': 'phone',
    'group': 'student',
    'group_label': 'Personal Details',
    'required': false,
    'order': 1,
  },
  {
    'name': 'aadhar_card_number',
    'label': 'Aadhar Card Number',
    'type': 'digits',
    'group': 'student',
    'group_label': 'Personal Details',
    'required': false,
    'order': 2,
  },
  {
    'name': 'is_rte_student',
    'label': 'Is RTE Student',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 3,
  },
  {
    'name': 'religion',
    'label': 'Religion',
    'type': 'text',
    'group': 'student',
    'group_label': 'Personal Details',
    'required': false,
    'order': 4,
  },
  {
    'name': 'father_email',
    'label': 'Father Email',
    'type': 'email',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 5,
  },
  {
    'name': 'father_whatsapp',
    'label': 'Father WhatsApp',
    'type': 'phone',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 6,
  },
  {
    'name': 'father_photo',
    'label': 'Father Photo',
    'type': 'file',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 7,
  },
  {
    'name': 'father_signature',
    'label': 'Father Signature',
    'type': 'file',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 8,
  },
  {
    'name': 'mother_email',
    'label': 'Mother Email',
    'type': 'email',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 9,
  },
  {
    'name': 'mother_phone',
    'label': 'Mother Phone',
    'type': 'phone',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 10,
  },
  {
    'name': 'mother_whatsapp',
    'label': 'Mother WhatsApp',
    'type': 'phone',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 11,
  },
  {
    'name': 'mother_photo',
    'label': 'Mother Photo',
    'type': 'file',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 12,
  },
  {
    'name': 'mother_signature',
    'label': 'Mother Signature',
    'type': 'file',
    'group': 'parent',
    'group_label': 'Parent Details',
    'required': false,
    'order': 13,
  },
  {
    'name': 'pincode',
    'label': 'Pincode',
    'type': 'digits',
    'group': 'address',
    'group_label': 'Address Details',
    'required': false,
    'order': 14,
  },
  {
    'name': 'house',
    'label': 'House',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 15,
  },
  {
    'name': 'registration_number',
    'label': 'Registration Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 16,
  },
  {
    'name': 'roll_number',
    'label': 'Roll Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 17,
  },
  {
    'name': 'pen_number',
    'label': 'PEN Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 18,
  },
  {
    'name': 'sr_number',
    'label': 'Sr. Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 19,
  },
  {
    'name': 'admission_number',
    'label': 'Admission Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 20,
  },
  {
    'name': 'transport_mode',
    'label': 'Transport Mode',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 21,
  },
  {
    'name': 'rfid_number',
    'label': 'RFID Number',
    'type': 'text',
    'group': 'school',
    'group_label': 'School',
    'required': false,
    'order': 22,
  },
];

List<StudentFormField> get _masterAvailableFields => _kAllAvailableFields
    .map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e)))
    .toList();

const List<Map<String, dynamic>> _kCoreFields = [
  {
    'name': 'student_name',
    'label': 'Student Name',
    'type': 'text',
    'group': 'student',
    'group_label': 'Personal Details',
    'required': true,
    'order': 0,
  },
  {
    'name': 'session',
    'label': 'Session',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 1,
  },
  {
    'name': 'class',
    'label': 'Class',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 2,
  },
  {
    'name': 'class_section',
    'label': 'Class Section',
    'type': 'select',
    'group': 'school',
    'group_label': 'Academic Details',
    'required': false,
    'order': 3,
  },
];

List<StudentFormField> _ensureCoreFields(List<StudentFormField> fields) {
  // If fields are empty, return all available fields as a fallback
  if (fields.isEmpty) {
    final allFields = <StudentFormField>[];
    allFields.addAll(_kCoreFields.map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e))));
    allFields.addAll(_kAllAvailableFields.map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e))));
    return allFields;
  }

  final result = List<StudentFormField>.from(fields);

  if (!result.any((f) => f.name == 'class_section')) {
    final classIndex = result.indexWhere((f) => f.name == 'class');
    final sectionField = StudentFormField.fromJson(
      Map<String, dynamic>.from(
        _kCoreFields.firstWhere((c) => c['name'] == 'class_section'),
      ),
    );
    if (classIndex >= 0) {
      result.insert(classIndex + 1, sectionField);
    } else {
      result.add(sectionField);
    }
  }

  for (final core in _kCoreFields.where((c) => c['name'] != 'class_section')) {
    final name = core['name'] as String;
    if (!result.any((f) => f.name == name)) {
      result.insert(
        0,
        StudentFormField.fromJson(Map<String, dynamic>.from(core)),
      );
    }
  }

  return result;
}

class StudentFormCubit extends Cubit<StudentFormState> {
  StudentFormCubit() : super(StudentFormState());

  String _sig = '';
  String _schoolId = '';

  void clearMessages() {
    emit(
      StudentFormState(
        loading: state.loading,
        saving: state.saving,
        fields: state.fields,
        availableFields: state.availableFields,
        schoolName: state.schoolName,
        error: null,
        successMessage: null,
      ),
    );
  }

  Future<void> loadFromSchoolId({
    required String schoolId,
    required String schoolName,
  }) async {
    _schoolId = schoolId;
    emit(state.copyWith(loading: true, error: null, successMessage: null));

    // Step 1: Try local DB first (instant load)
    final localFields = await _loadFieldsFromLocal(schoolId);
    if (localFields != null && localFields.$1.isNotEmpty) {
      emit(state.copyWith(
        loading: false,
        fields: _ensureCoreFields(localFields.$1),
        availableFields: localFields.$2,
        schoolName: schoolName,
      ));
      // Background sync
      _syncFieldsFromApi(schoolId, schoolName);
      return;
    }

    // Step 2: If no local data and no internet, provide core fields as fallback
    final hasInternet = await _checkInternet();
    if (!hasInternet) {
      emit(state.copyWith(
        loading: false,
        fields: _ensureCoreFields([]), // This will provide core fields (Name, Class, etc.)
        availableFields: _masterAvailableFields,
        schoolName: schoolName,
      ));
      return;
    }

    // Step 3: Fetch from API
    await _syncFieldsFromApi(schoolId, schoolName, emitStates: true);
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Load form fields from local DB
  Future<(List<StudentFormField>, List<StudentFormField>)?> _loadFieldsFromLocal(String schoolId) async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_fields',
        where: 'school_id = ?',
        whereArgs: [schoolId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      final rawFields = jsonDecode(row['fields_json'] as String? ?? '[]') as List;
      final rawAvailable = jsonDecode(row['available_fields_json'] as String? ?? '[]') as List;

      final fields = rawFields
          .map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      final available = rawAvailable.isNotEmpty
          ? rawAvailable.map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e))).toList()
          : _masterAvailableFields;

      print('[FormFields] Loaded from local DB — fields: ${fields.length}');
      return (fields, available);
    } catch (e) {
      print('[FormFields] Local load error: $e');
      return null;
    }
  }

  /// Fetch form fields from API and save to local DB
  Future<void> _syncFieldsFromApi(String schoolId, String schoolName, {bool emitStates = false}) async {
    try {
      final token = await UserSecureStorage.fetchToken();
      final formFieldsUrl = '${Config.baseUrl}auth/school/$schoolId/form-fields';
      print('[FormFields] API URL: $formFieldsUrl');

      final response = await http.get(
        Uri.parse(formFieldsUrl),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      print('[FormFields] API status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? {};
        final List rawFields = data['student_form_fields'] ?? [];
        final fields = rawFields
            .map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        final List rawAvailable = data['available_student_form_fields'] ?? [];
        final availableFields = rawAvailable.isNotEmpty
            ? rawAvailable.map((e) => StudentFormField.fromJson(Map<String, dynamic>.from(e))).toList()
            : _masterAvailableFields;

        // Save to local DB
        await _saveFieldsToLocal(schoolId, fields, availableFields);

        emit(state.copyWith(
          loading: false,
          fields: _ensureCoreFields(fields),
          availableFields: availableFields,
          schoolName: schoolName,
        ));
      } else {
        if (emitStates) {
          emit(state.copyWith(loading: false, error: 'Failed to load form fields'));
        }
      }
    } catch (e) {
      print('[FormFields] API sync error: $e');
      if (emitStates) {
        emit(state.copyWith(loading: false, error: e.toString()));
      }
    }
  }

  /// Save form fields to local DB
  Future<void> _saveFieldsToLocal(
    String schoolId,
    List<StudentFormField> fields,
    List<StudentFormField> availableFields,
  ) async {
    try {
      final db = await DBHelper.db;
      final fieldsJson = jsonEncode(fields.map((f) => {
        'name': f.name,
        'label': f.label,
        'type': f.type,
        'group': f.group,
        'group_label': f.groupLabel,
        'required': f.required,
        'order': f.order,
      }).toList());
      final availableJson = jsonEncode(availableFields.map((f) => {
        'name': f.name,
        'label': f.label,
        'type': f.type,
        'group': f.group,
        'group_label': f.groupLabel,
        'required': f.required,
        'order': f.order,
      }).toList());

      await db.insert(
        'school_form_fields',
        {
          'school_id': schoolId,
          'fields_json': fieldsJson,
          'available_fields_json': availableJson,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('[FormFields] Saved to local DB — school: $schoolId');
    } catch (e) {
      print('[FormFields] Local save error: $e');
    }
  }

  void loadFromModel({
    required List<StudentFormField> fields,
    required String schoolName,
    required String schoolId,
  }) {
    _schoolId = schoolId;
    emit(
      state.copyWith(
        fields: _ensureCoreFields(fields),
        availableFields: _masterAvailableFields,
        schoolName: schoolName,
        error: null,
        successMessage: null,
      ),
    );
    _fetchSig(schoolId);
  }

  void loadFromModelWithSig({
    required List<StudentFormField> fields,
    required String schoolName,
    required String sig,
    String schoolId = '',
  }) {
    _sig = sig;
    _schoolId = schoolId;
    emit(
      state.copyWith(
        fields: _ensureCoreFields(fields),
        availableFields: _masterAvailableFields,
        schoolName: schoolName,
        error: null,
        successMessage: null,
      ),
    );
  }

  Future<void> _fetchSig(String schoolId) async {
    final token = await UserSecureStorage.fetchToken();
    final response = await http.get(
      Uri.parse('${Config.baseUrl}auth/school/student-form-sig'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _sig = json['sig'] ?? json['data']?['sig'] ?? '';
    }
    print('Sig result: $_sig (status: ${response.statusCode})');
  }

  Future<void> updateStudentFormFields(
    List<StudentFormField> updatedFields,
  ) async {
    emit(state.copyWith(saving: true, error: null, successMessage: null));

    if (_schoolId.isEmpty) {
      final school = await UserLocal.getSchool();
      _schoolId = school['schoolId'] ?? '';
    }

    if (_schoolId.isEmpty) {
      emit(
        state.copyWith(
          saving: false,
          error: 'School ID not found. Please reopen this screen.',
        ),
      );
      return;
    }

    final token = await UserSecureStorage.fetchToken();
    final url = '${Config.baseUrl}auth/school/$_schoolId/form-fields/student';
    print('Update URL: $url');

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
          successMessage: json['message'] ?? 'Form fields updated successfully',
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
}
