import 'dart:convert';

class StaffListModel {
  final int id;
  final String uuid;
  final String name;
  final String designation;
  final String department;
  final String email;
  final String phone;
  final String? whatsappPhone;
  final String? address;
  final String? profilePhotoUrl;
  final String roleName;
  final int? roleId;
  final int status;
  final List<String> assignedClasses;
  final String? dob;
  final String? fatherName;
  final String? motherName;
  final String? husbandName;
  final String? gender;
  final String? bloodGroup;
  final String? pincode;
  final String? employeeId;
  final String? nationalCode;
  final String? loginId;
  final String? dateOfJoining;

  // Offline support flags
  final bool isOffline;
  final bool isExtra;
  final bool isOfflineUpdate;
  final bool isExtraPendingSync;
  final bool isDeletePendingSync;
  final bool isStatusPendingSync;
  final bool isPhotoPendingSync;
  final String? offlinePhotoPath;
  final String? offlineFieldsJson;
  final int? schoolId;

  const StaffListModel({
    required this.id,
    required this.uuid,
    required this.name,
    required this.designation,
    required this.department,
    required this.email,
    required this.phone,
    this.whatsappPhone,
    this.address,
    this.profilePhotoUrl,
    required this.roleName,
    this.roleId,
    required this.status,
    required this.assignedClasses,
    this.dob,
    this.fatherName,
    this.motherName,
    this.husbandName,
    this.gender,
    this.bloodGroup,
    this.pincode,
    this.employeeId,
    this.nationalCode,
    this.loginId,
    this.dateOfJoining,
    this.isOffline = false,
    this.isExtra = false,
    this.isOfflineUpdate = false,
    this.isExtraPendingSync = false,
    this.isDeletePendingSync = false,
    this.isStatusPendingSync = false,
    this.isPhotoPendingSync = false,
    this.offlinePhotoPath,
    this.offlineFieldsJson,
    this.schoolId,
  });

  /// Fix malformed URL like "https://server/.../https://cdn/.../file.jpg"
  /// Also replaces localhost URLs with production domain
  static String? _fixUrl(dynamic raw) {
    if (raw == null) return null;
    String url = raw.toString().trim();
    if (url.isEmpty) return null;
    // If multiple http(s):// found, take from the last one
    final regex = RegExp(r'https?://');
    final matches = regex.allMatches(url).toList();
    if (matches.length > 1) {
      url = url.substring(matches.last.start);
    }
    // Replace localhost/127.0.0.1 with production domain
    url = url
        .replaceAll('http://127.0.0.1:8000', 'https://idmitra.com')
        .replaceAll('http://localhost:8000', 'https://idmitra.com')
        .replaceAll('http://localhost', 'https://idmitra.com');
    return url;
  }

  StaffListModel copyWith({
    int? id,
    String? uuid,
    String? name,
    String? designation,
    String? department,
    String? email,
    String? phone,
    String? whatsappPhone,
    String? address,
    String? profilePhotoUrl,
    String? roleName,
    int? roleId,
    int? status,
    List<String>? assignedClasses,
    String? dob,
    String? fatherName,
    String? motherName,
    String? husbandName,
    String? gender,
    String? bloodGroup,
    String? pincode,
    String? employeeId,
    String? nationalCode,
    String? loginId,
    String? dateOfJoining,
    bool? isOffline,
    bool? isExtra,
    bool? isOfflineUpdate,
    bool? isExtraPendingSync,
    bool? isDeletePendingSync,
    bool? isStatusPendingSync,
    bool? isPhotoPendingSync,
    String? offlinePhotoPath,
    String? offlineFieldsJson,
    int? schoolId,
  }) =>
      StaffListModel(
        id: id ?? this.id,
        uuid: uuid ?? this.uuid,
        name: name ?? this.name,
        designation: designation ?? this.designation,
        department: department ?? this.department,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        whatsappPhone: whatsappPhone ?? this.whatsappPhone,
        address: address ?? this.address,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
        roleName: roleName ?? this.roleName,
        roleId: roleId ?? this.roleId,
        status: status ?? this.status,
        assignedClasses: assignedClasses ?? this.assignedClasses,
        dob: dob ?? this.dob,
        fatherName: fatherName ?? this.fatherName,
        motherName: motherName ?? this.motherName,
        husbandName: husbandName ?? this.husbandName,
        gender: gender ?? this.gender,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        pincode: pincode ?? this.pincode,
        employeeId: employeeId ?? this.employeeId,
        nationalCode: nationalCode ?? this.nationalCode,
        loginId: loginId ?? this.loginId,
        dateOfJoining: dateOfJoining ?? this.dateOfJoining,
        isOffline: isOffline ?? this.isOffline,
        isExtra: isExtra ?? this.isExtra,
        isOfflineUpdate: isOfflineUpdate ?? this.isOfflineUpdate,
        isExtraPendingSync: isExtraPendingSync ?? this.isExtraPendingSync,
        isDeletePendingSync: isDeletePendingSync ?? this.isDeletePendingSync,
        isStatusPendingSync: isStatusPendingSync ?? this.isStatusPendingSync,
        isPhotoPendingSync: isPhotoPendingSync ?? this.isPhotoPendingSync,
        offlinePhotoPath: offlinePhotoPath ?? this.offlinePhotoPath,
        offlineFieldsJson: offlineFieldsJson ?? this.offlineFieldsJson,
        schoolId: schoolId ?? this.schoolId,
      );

  factory StaffListModel.fromJson(Map<String, dynamic> json) {
    final role = json['role'] as Map<String, dynamic>?;
    final classes = json['assigned_classes'] is String 
        ? jsonDecode(json['assigned_classes']) as List 
        : (json['assigned_classes'] as List? ?? []);

    return StaffListModel(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      name: json['name'] ?? '',
      designation: json['designation'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      whatsappPhone: json['whatsapp_phone'],
      address: json['address'],
      profilePhotoUrl: _fixUrl(json['profile_photo_url']),
      roleName: role?['name'] ?? json['role_name'] ?? '',
      roleId: role?['id'] is int ? role!['id'] : (int.tryParse(role?['id']?.toString() ?? '') ?? (json['role_id'] is int ? json['role_id'] : int.tryParse(json['role_id']?.toString() ?? ''))),
      status: json['status'] ?? 1,
      assignedClasses: classes.map((c) {
        if (c is Map) return c['name_withprefix']?.toString() ?? c['class_name']?.toString() ?? c['name']?.toString() ?? '';
        return c.toString();
      }).where((s) => s.isNotEmpty).toList(),
      dob: json['dob'],
      fatherName: json['father_name'],
      motherName: json['mother_name'],
      husbandName: json['husband_name'],
      gender: json['gender'],
      bloodGroup: json['blood_group'],
      pincode: json['pincode']?.toString(),
      employeeId: json['employee_id']?.toString(),
      nationalCode: json['national_code']?.toString(),
      loginId: json['login_id'],
      dateOfJoining: json['date_of_joining'],
      isOffline: json['is_offline'] == 1 || (json['is_offline'] is bool && json['is_offline']),
      isExtra: json['is_extra'] == 1 || (json['is_extra'] is bool && json['is_extra']),
      isOfflineUpdate: json['is_offline_update'] == 1 || (json['is_offline_update'] is bool && json['is_offline_update']),
      isExtraPendingSync: json['is_extra_pending_sync'] == 1 || (json['is_extra_pending_sync'] is bool && json['is_extra_pending_sync']),
      isDeletePendingSync: json['is_delete_pending_sync'] == 1 || (json['is_delete_pending_sync'] is bool && json['is_delete_pending_sync']),
      isStatusPendingSync: json['is_status_pending_sync'] == 1 || (json['is_status_pending_sync'] is bool && json['is_status_pending_sync']),
      isPhotoPendingSync: json['is_photo_pending_sync'] == 1 || (json['is_photo_pending_sync'] is bool && json['is_photo_pending_sync']),
      offlinePhotoPath: json['offline_photo_path'],
      offlineFieldsJson: json['offline_fields_json'],
      schoolId: json['school_id'],
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "uuid": uuid,
        "name": name,
        "designation": designation,
        "department": department,
        "email": email,
        "phone": phone,
        "whatsapp_phone": whatsappPhone,
        "address": address,
        "profile_photo_url": profilePhotoUrl,
        "role_name": roleName,
        "role_id": roleId,
        "status": status,
        "assigned_classes": assignedClasses,
        "dob": dob,
        "father_name": fatherName,
        "mother_name": motherName,
        "husband_name": husbandName,
        "gender": gender,
        "blood_group": bloodGroup,
        "pincode": pincode,
        "employee_id": employeeId,
        "national_code": nationalCode,
        "login_id": loginId,
        "date_of_joining": dateOfJoining,
        "is_offline": isOffline ? 1 : 0,
        "is_extra": isExtra ? 1 : 0,
        "is_offline_update": isOfflineUpdate ? 1 : 0,
        "is_extra_pending_sync": isExtraPendingSync ? 1 : 0,
        "is_delete_pending_sync": isDeletePendingSync ? 1 : 0,
        "is_status_pending_sync": isStatusPendingSync ? 1 : 0,
        "is_photo_pending_sync": isPhotoPendingSync ? 1 : 0,
        "offline_photo_path": offlinePhotoPath,
        "offline_fields_json": offlineFieldsJson,
        "school_id": schoolId,
      };
}
