import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/add_student/StudentFormDataModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart' hide ClassOption;
import 'package:uuid/uuid.dart';

class AddStudentState {
  final bool loading;
  final bool success;
  final String? error;
  final String? message;
  final StudentDetailsData? newStudent;
  const AddStudentState({
    this.loading = false,
    this.success = false,
    this.error,
    this.message,
    this.newStudent,
  });
}

class AddStudentCubit extends Cubit<AddStudentState> {
  AddStudentCubit() : super(const AddStudentState());

  final _localDS = StudentLocalDS();

  Future<void> submit({
    required String schoolId,
    required Map<String, dynamic> fields,
    required Map<String, File?> files,
    List<String> formFieldNames = const [],
    StudentFormDataModel? formDataModel,
    List<String> allConfiguredFieldNames = const [],
  }) async {
    emit(const AddStudentState(loading: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}auth/school/$schoolId/students';

      final body = _buildBody(schoolId, fields);
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      body.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          request.fields[k] = v.toString();
        }
      });

      for (final key in [
        'student_photo',
        'student_signature',
        'father_photo',
        'father_signature',
        'mother_photo',
        'mother_signature'
      ]) {
        final file = files[key];
        if (file != null) {
          request.files.add(await http.MultipartFile.fromPath(key, file.path));
        }
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? {};
        StudentDetailsData? newStudent;
        try {
          if (data is Map<String, dynamic>) {
            if (data['school_id'] == null) {
              data['school_id'] = int.tryParse(schoolId);
            }

            final sectionId = fields['class_section'];
            if (sectionId != null && data['school_class_section_id'] == null) {
              data['school_class_section_id'] = sectionId is int
                  ? sectionId
                  : int.tryParse(sectionId.toString());
            }
            newStudent = StudentDetailsData.fromJson(data);

            //  Save to Local DB
            if (newStudent != null) {
              await _localDS.insertStudents([newStudent]);
              debugPrint("Student saved to local DB after successful add");
            }
          }
        } catch (e) {
          debugPrint("Error saving to local DB or parsing student: $e");
        }
        emit(AddStudentState(
          success: true,
          message: json['message'] ?? 'Student added successfully',
          newStudent: newStudent,
        ));
      } else {
        Map<String, dynamic> json = {};
        try {
          json = jsonDecode(response.body);
        } catch (_) {}
        String errorMsg = json['message'] ?? 'Failed: ${response.statusCode}';
        final errors = json['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final relevantErrors = formFieldNames.isEmpty
              ? errors
              : Map.fromEntries(
              errors.entries.where((e) => formFieldNames.contains(e.key)));
          if (relevantErrors.isNotEmpty) {
            errorMsg = relevantErrors.values
                .expand((v) => v is List ? v : [v])
                .take(3)
                .join('\n');
          } else {
            errorMsg = 'Failed to add student. Please try again.';
          }
        }
        emit(AddStudentState(error: errorMsg));
      }
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        //  OFFLINE MODE
        debugPrint("Network error detected, saving student offline: $e");
        final offlineStudent = _buildOfflineStudent(
          schoolId,
          fields,
          formDataModel,
          allConfiguredFieldNames,
          existingStudent: null,
        );

        // Handle offline photo if present
        final photoFile = files['student_photo'];
        final studentWithFields = offlineStudent.copyWith(
          offlineFieldsJson: jsonEncode(fields),
          isPhotoPendingSync: photoFile != null,
          offlinePhotoPath: photoFile?.path,
        );

        await _localDS.insertStudents([studentWithFields]);
        emit(AddStudentState(
          success: true,
          message: 'Saved offline. Student will be synced later.',
          newStudent: studentWithFields,
        ));
      } else {
        emit(AddStudentState(error: e.toString()));
      }
    }
  }

  StudentDetailsData _buildOfflineStudent(
      String schoolId,
      Map<String, dynamic> fields,
      StudentFormDataModel? formDataModel,
      List<String> allConfiguredFieldNames, {
        StudentDetailsData? existingStudent,
      }) {
    final uuid = existingStudent?.uuid ?? 'offline_${const Uuid().v4()}';
    final now = DateTime.now();

    final classId = int.tryParse(fields['class']?.toString() ?? '') ??
        existingStudent?.schoolClassId;
    final sectionId = int.tryParse(fields['class_section']?.toString() ?? '') ??
        existingStudent?.schoolClassSectionId;
    final sessionId = int.tryParse(fields['session']?.toString() ?? '') ??
        existingStudent?.schoolSessionId;

    Class? datumClass = existingStudent?.datumClass;
    Section? section = existingStudent?.section;
    Session? session = existingStudent?.session;

    if (formDataModel != null) {
      if (classId != null) {
        final c = formDataModel.classes.firstWhere(
              (element) => element.id == classId,
          orElse: () => ClassOption(id: -1, name: '', nameWithPrefix: ''),
        );
        if (c.id != -1) {
          datumClass = Class(
            id: c.id,
            name: c.name,
            nameWithprefix: c.nameWithPrefix,
          );

          if (sectionId != null) {
            final s = c.sections.firstWhere(
                  (element) => element.id == sectionId,
              orElse: () => SectionOption(id: -1, name: ''),
            );
            if (s.id != -1) {
              section = Section(id: s.id, name: s.name);
            }
          }
        }
      }

      if (sessionId != null) {
        final s = formDataModel.sessions.firstWhere(
              (element) => element.value == sessionId,
          orElse: () => SessionOption(value: -1, label: ''),
        );
        if (s.value != -1) {
          session = Session(id: s.value, name: s.label);
        }
      }
    }

    final missingFields = <String>[];

    final fieldMapping = {
      'student_name': 'student_name',
      'date_of_birth': 'date_of_birth',
      'gender': 'gender',
      'class': 'class',
      'class_section': 'class_section',
      'father_name': 'father_name',
      'mother_name': 'mother_name',
      'student_phone': 'student_phone',
      'address': 'address',
    };

    for (var apiFieldName in allConfiguredFieldNames) {
      final logicalName = fieldMapping[apiFieldName] ?? apiFieldName;
      final value = fields[logicalName];
      if (value == null || value.toString().trim().isEmpty) {
        missingFields.add(apiFieldName);
      }
    }

    String? _pick(List<String> formKeys, String? existingValue) {
      for (final k in formKeys) {
        final v = fields[k]?.toString();
        if (v != null && v.isNotEmpty) return v;
      }
      return existingValue;
    }

    return StudentDetailsData(
      id: existingStudent?.id,
      uuid: uuid,
      schoolId: int.tryParse(schoolId) ?? existingStudent?.schoolId,
      name: _pick(['student_name', 'name'], existingStudent?.name),
      email: _pick(['student_email', 'email'], existingStudent?.email?.toString()),
      phone: _pick(['student_phone', 'phone'], existingStudent?.phone?.toString()),
      gender: _pick(['gender'], existingStudent?.gender?.toString()),
      dob: _pick(['date_of_birth', 'dob'], existingStudent?.dob),
      fatherName: _pick(['father_name'], existingStudent?.fatherName),
      fatherPhone: _pick(['father_phone'], existingStudent?.fatherPhone),
      fatherEmail: _pick(['father_email'], existingStudent?.fatherEmail?.toString()),
      fatherWphone: _pick(['father_whatsapp_number', 'father_whatsapp'], existingStudent?.fatherWphone?.toString()),
      motherName: _pick(['mother_name'], existingStudent?.motherName),
      motherPhone: _pick(['mother_phone'], existingStudent?.motherPhone?.toString()),
      motherEmail: _pick(['mother_email'], existingStudent?.motherEmail?.toString()),
      motherWphone: _pick(['mother_whatsapp_number', 'mother_whatsapp'], existingStudent?.motherWphone?.toString()),
      address: _pick(['address'], existingStudent?.address),
      pincode: _pick(['pincode'], existingStudent?.pincode?.toString()),
      whatsappPhone: _pick(['student_whatsapp_number', 'student_whatsapp'], existingStudent?.whatsappPhone?.toString()),
      landLineNo: _pick(['landline_contact_number', 'landline_number'], existingStudent?.landLineNo?.toString()),
      aadharNo: _pick(['aadhar_card_number', 'aadhar_no'], existingStudent?.aadharNo?.toString()),
      uidNo: _pick(['uid_number', 'uid_no'], existingStudent?.uidNo?.toString()),
      studentNicId: _pick(['student_nic_id', 'nic_id'], existingStudent?.studentNicId?.toString()),
      caste: _pick(['caste'], existingStudent?.caste?.toString()),
      religion: _pick(['religion'], existingStudent?.religion?.toString()),
      isRteStudent: _pick(['is_rte_student'], existingStudent?.isRteStudent?.toString()),
      regNo: _pick(['registration_number', 'reg_no'], existingStudent?.regNo?.toString()),
      rollNo: _pick(['roll_number', 'roll_no'], existingStudent?.rollNo?.toString()),
      admissionNo: _pick(['admission_number', 'admission_no'], existingStudent?.admissionNo?.toString()),
      srNo: _pick(['sr_number', 'sr_no'], existingStudent?.srNo),
      rfidNo: _pick(['rfid_number', 'rfid_no'], existingStudent?.rfidNo?.toString()),
      panNo: _pick(['pen_number', 'pan_number', 'pan_no'], existingStudent?.panNo?.toString()),
      bloodGroup: _pick(['blood_group'], existingStudent?.bloodGroup?.toString()),
      transportMode: _pick(['transport_mode'], existingStudent?.transportMode?.toString()),
      schoolClassId: classId,
      schoolClassSectionId: sectionId,
      schoolSessionId: sessionId,
      schoolHouseId: int.tryParse(fields['house']?.toString() ?? '') ??
          existingStudent?.schoolHouseId,
      profilePhotoUrl: existingStudent?.profilePhotoUrl,
      signatureUrl: existingStudent?.signatureUrl,
      fatherPhotoUrl: existingStudent?.fatherPhotoUrl,
      fatherSignatureUrl: existingStudent?.fatherSignatureUrl,
      motherPhotoUrl: existingStudent?.motherPhotoUrl,
      motherSignatureUrl: existingStudent?.motherSignatureUrl,
      status: existingStudent?.status ?? 1,
      isOffline: true,
      createdAt: existingStudent?.createdAt ?? now,
      updatedAt: now,
      missingFields: missingFields,
      datumClass: datumClass,
      section: section,
      session: session,
    );
  }

  Future<void> updateStudent({
    required String studentUuid,
    required String schoolId,
    required Map<String, dynamic> fields,
    required Map<String, File?> files,
    List<String> formFieldNames = const [],
    StudentFormDataModel? formDataModel,
    List<String> allConfiguredFieldNames = const [],
    StudentDetailsData? existingStudent, // NEW: pass existing student for offline fallback
  }) async {
    emit(const AddStudentState(loading: true));
    try {
      final token = await UserSecureStorage.fetchToken();
      final url = '${Config.baseUrl}${Routes.updateStudent(schoolId, studentUuid)}';

      final body = _buildBody(schoolId, fields);
      final request = http.MultipartRequest('PUT', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      body.forEach((k, v) {
        if (v != null && v.toString().isNotEmpty) {
          request.fields[k] = v.toString();
        }
      });

      for (final key in [
        'student_photo',
        'student_signature',
        'father_photo',
        'father_signature',
        'mother_photo',
        'mother_signature'
      ]) {
        final file = files[key];
        if (file != null) {
          request.files.add(await http.MultipartFile.fromPath(key, file.path));
        }
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body.trim().startsWith('<')) {
          emit(const AddStudentState(
              success: true, message: 'Student updated successfully'));
          return;
        }
        final json = jsonDecode(response.body);
        StudentDetailsData? updatedStudent;
        try {
          final data = json['data'];
          if (data is Map<String, dynamic>) {
            // Patch school_id from request if API response omits it
            if (data['school_id'] == null) {
              data['school_id'] = int.tryParse(schoolId);
            }

            updatedStudent = StudentDetailsData.fromJson(data);

            //  Update in Local DB
            if (updatedStudent != null) {
              await _localDS.insertStudents([updatedStudent]);
              print("Student updated in local DB after successful update");
            }
          }
        } catch (e) {
          debugPrint("Error updating local DB or parsing student: $e");
        }
        emit(AddStudentState(
          success: true,
          message: json['message'] ?? 'Student updated successfully',
          newStudent: updatedStudent,
        ));
      } else {
        Map<String, dynamic> json = {};
        try {
          json = jsonDecode(response.body);
        } catch (_) {}
        String errorMsg = json['message'] ?? 'Failed: ${response.statusCode}';
        final errors = json['errors'] as Map<String, dynamic>?;
        if (errors != null && errors.isNotEmpty) {
          final relevantErrors = formFieldNames.isEmpty
              ? errors
              : Map.fromEntries(
              errors.entries.where((e) => formFieldNames.contains(e.key)));
          if (relevantErrors.isNotEmpty) {
            errorMsg = relevantErrors.values
                .expand((v) => v is List ? v : [v])
                .take(3)
                .join('\n');
          } else {
            errorMsg = 'Failed to update student. Please try again.';
          }
        }
        emit(AddStudentState(error: errorMsg));
      }
    } catch (e) {
      if (e is SocketException || e is http.ClientException) {
        //  OFFLINE UPDATE MODE — existingStudent se data preserve karo
        debugPrint("Network error detected during update, saving locally: $e");

        final offlineStudent = _buildOfflineStudent(
          schoolId,
          fields,
          formDataModel,
          allConfiguredFieldNames,
          existingStudent: existingStudent, //  Pass existing student
        );

        // Handle offline photo if present
        final photoFile = files['student_photo'];
        final studentToSave = offlineStudent.copyWith(
          uuid: studentUuid,
          isOfflineUpdate: true,
          offlineFieldsJson: jsonEncode(fields),
          isPhotoPendingSync: photoFile != null,
          offlinePhotoPath: photoFile?.path,
        );

        await _localDS.insertStudents([studentToSave]);

        emit(AddStudentState(
          success: true,
          message: 'Updated offline. Changes will be synced later.',
          newStudent: studentToSave,
        ));
      } else {
        emit(AddStudentState(error: e.toString()));
      }
    }
  }

  Map<String, dynamic> _buildBody(String schoolId, Map<String, dynamic> fields) {
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

    final String? finalPassword;
    final String? finalPasswordConfirmation;

    if (password != null && password.isNotEmpty) {
      finalPassword = password;
      finalPasswordConfirmation = passwordConfirmation ?? password;
    } else {
      finalPassword = 'Student@123';
      finalPasswordConfirmation = 'Student@123';
    }

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
      'whatsapp_phone': f(['student_whatsapp_number', 'student_whatsapp', 'whatsapp_number']),
      'student_whatsapp_number': f(['student_whatsapp_number', 'student_whatsapp']),
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
}