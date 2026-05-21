// ─── Correction List Students (from /orders/correction-lists/students) ────────

class CorrectionStudentClass {
  final int id;
  final int? schoolId;
  final String? nameWithPrefix;

  const CorrectionStudentClass({required this.id, this.schoolId, this.nameWithPrefix});

  factory CorrectionStudentClass.fromJson(Map<String, dynamic> json) {
    return CorrectionStudentClass(
      id: json['id'] ?? 0,
      schoolId: json['school_id'],
      nameWithPrefix: json['name_withprefix'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'name_withprefix': nameWithPrefix,
    };
  }
}

class CorrectionStudentSection {
  final int id;
  final int? schoolId;
  final String? name;

  const CorrectionStudentSection({required this.id, this.schoolId, this.name});

  factory CorrectionStudentSection.fromJson(Map<String, dynamic> json) {
    return CorrectionStudentSection(
      id: json['id'] ?? 0,
      schoolId: json['school_id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'school_id': schoolId,
      'name': name,
    };
  }
}

class CorrectionStudentData {
  final int id;
  final String? uuid;
  final int? schoolId;
  final String? name;
  final String? email;
  final String? phone;
  final String? regNo;
  final String? rollNo;
  final String? admissionNo;
  final String? dob;
  final String? address;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? motherPhone;
  final int? schoolClassId;
  final int? schoolClassSectionId;
  final String? photo;
  final String? photoUrl;
  final String? profilePhotoUrl;
  final CorrectionStudentClass? studentClass;
  final CorrectionStudentSection? section;

  const CorrectionStudentData({
    required this.id,
    this.uuid,
    this.schoolId,
    this.name,
    this.email,
    this.phone,
    this.regNo,
    this.rollNo,
    this.admissionNo,
    this.dob,
    this.address,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.motherPhone,
    this.schoolClassId,
    this.schoolClassSectionId,
    this.photo,
    this.photoUrl,
    this.profilePhotoUrl,
    this.studentClass,
    this.section,
  });

  factory CorrectionStudentData.fromJson(Map<String, dynamic> json) {
    return CorrectionStudentData(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      schoolId: json['school_id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      regNo: json['reg_no'],
      rollNo: json['roll_no'],
      admissionNo: json['admission_no'],
      dob: json['dob'],
      address: json['address'],
      fatherName: json['father_name'],
      fatherPhone: json['father_phone'],
      motherName: json['mother_name'],
      motherPhone: json['mother_phone'],
      schoolClassId: json['school_class_id'],
      schoolClassSectionId: json['school_class_section_id'],
      photo: json['photo'],
      photoUrl: json['photo_url'],
      profilePhotoUrl: json['profile_photo_url'],
      studentClass: json['class'] != null
          ? CorrectionStudentClass.fromJson(json['class'] as Map<String, dynamic>)
          : null,
      section: json['section'] != null
          ? CorrectionStudentSection.fromJson(json['section'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'school_id': schoolId,
      'name': name,
      'email': email,
      'phone': phone,
      'reg_no': regNo,
      'roll_no': rollNo,
      'admission_no': admissionNo,
      'dob': dob,
      'address': address,
      'father_name': fatherName,
      'father_phone': fatherPhone,
      'mother_name': motherName,
      'mother_phone': motherPhone,
      'school_class_id': schoolClassId,
      'school_class_section_id': schoolClassSectionId,
      'photo': photo,
      'photo_url': photoUrl,
      'profile_photo_url': profilePhotoUrl,
      'class': studentClass?.toJson(),
      'section': section?.toJson(),
    };
  }
}

class CorrectionStudentItem {
  final int id;
  final String? uuid;
  final String? status;
  final String? remark;
  final CorrectionStudentData? student;

  const CorrectionStudentItem({
    required this.id,
    this.uuid,
    this.status,
    this.remark,
    this.student,
  });

  factory CorrectionStudentItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? studentJson = json['student'] as Map<String, dynamic>?;
    return CorrectionStudentItem(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      status: json['status'],
      remark: json['remark'],
      student: studentJson != null ? CorrectionStudentData.fromJson(studentJson) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'uuid': uuid,
      'status': status,
      'remark': remark,
      'student': student?.toJson(),
    };
  }
}


class CorrectionSection {
  final int id;
  final String? uuid;
  final String? name;

  const CorrectionSection({required this.id, this.uuid, this.name});

  factory CorrectionSection.fromJson(Map<String, dynamic> json) {
    return CorrectionSection(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      name: json['name'],
    );
  }
}

class CorrectionClass {
  final int id;
  final String? uuid;
  final String? name;
  final String? nameWithPrefix;
  final List<CorrectionSection> sections;

  const CorrectionClass({
    required this.id,
    this.uuid,
    this.name,
    this.nameWithPrefix,
    this.sections = const [],
  });

  factory CorrectionClass.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List? ?? [];
    return CorrectionClass(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      name: json['name'],
      nameWithPrefix: json['name_withprefix'],
      sections: rawSections
          .map((s) => CorrectionSection.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CorrectionItem {
  final int id;
  final String? uuid;
  final String? status;
  final String? listType;
  final String? createdAt;
  final int studentCount;
  final CorrectionClass? classData;
  final int? sectionId;

  String? get studentUuid => uuid;

  const CorrectionItem({
    required this.id,
    this.uuid,
    this.status,
    this.listType,
    this.createdAt,
    this.studentCount = 0,
    this.classData,
    this.sectionId,
  });

  String get displayLabel {
    if (classData != null) {
      final cls = classData!.nameWithPrefix ?? classData!.name ?? '';
      if (classData!.sections.isNotEmpty) {
        final secs = classData!.sections.map((s) => s.name ?? '').join(', ');
        return '$cls ($secs)';
      }
      return cls;
    }
    return 'Section #${sectionId ?? id}';
  }

  factory CorrectionItem.fromJson(Map<String, dynamic> json) {
    final classJson = json['class'] as Map<String, dynamic>?;
    return CorrectionItem(
      id: json['id'] ?? 0,
      uuid: json['uuid'],
      status: json['status'],
      listType: json['list_type'],
      createdAt: json['created_at'],
      studentCount: json['checklist_students_count'] ?? 0,
      classData: classJson != null ? CorrectionClass.fromJson(classJson) : null,
      sectionId: json['school_class_section_id'],
    );
  }
}
