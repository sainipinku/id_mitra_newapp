import 'dart:convert';

class GlobalSummaryModel {
  final bool success;
  final String message;
  final GlobalSummaryData data;

  GlobalSummaryModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory GlobalSummaryModel.fromJson(Map<String, dynamic> json) =>
      GlobalSummaryModel(
        success: json['success'] ?? false,
        message: json['message'] ?? '',
        data: GlobalSummaryData.fromJson(json['data'] ?? {}),
      );
}

class GlobalSummaryData {
  final SummaryPanel panel;
  final SummaryCounts counts;
  final SummaryLatest latest;

  GlobalSummaryData({
    required this.panel,
    required this.counts,
    required this.latest,
  });

  factory GlobalSummaryData.fromJson(Map<String, dynamic> json) =>
      GlobalSummaryData(
        panel: SummaryPanel.fromJson(json['panel'] ?? {}),
        counts: SummaryCounts.fromJson(json['counts'] ?? {}),
        latest: SummaryLatest.fromJson(json['latest'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'panel': panel.toJson(),
        'counts': counts.toJson(),
        'latest': latest.toJson(),
      };
}

// ─── Panel ───────────────────────────────────────────────────────────────────

class SummaryPanel {
  final SummaryPartner partner;

  SummaryPanel({required this.partner});

  factory SummaryPanel.fromJson(Map<String, dynamic> json) =>
      SummaryPanel(partner: SummaryPartner.fromJson(json['partner'] ?? {}));

  Map<String, dynamic> toJson() => {'partner': partner.toJson()};
}

class SummaryPartner {
  final int? id;
  final String? uuid;
  final String? name;
  final String? email;
  final String? phone;
  final int? status;
  final String? accountType;
  final String? profilePhotoUrl;
  final String? lastLogin;

  SummaryPartner({
    this.id,
    this.uuid,
    this.name,
    this.email,
    this.phone,
    this.status,
    this.accountType,
    this.profilePhotoUrl,
    this.lastLogin,
  });

  factory SummaryPartner.fromJson(Map<String, dynamic> json) => SummaryPartner(
        id: json['id'],
        uuid: json['uuid'],
        name: json['name'],
        email: json['email'],
        phone: json['phone'],
        status: json['status'],
        accountType: json['account_type'],
        profilePhotoUrl: json['profile_photo_url'],
        lastLogin: json['last_login'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'email': email,
        'phone': phone,
        'status': status,
        'account_type': accountType,
        'profile_photo_url': profilePhotoUrl,
        'last_login': lastLogin,
      };
}

// ─── Counts ──────────────────────────────────────────────────────────────────

class SummaryCounts {
  final SchoolCounts schools;
  final StudentCounts students;
  final OrderCounts orders;
  final OrderCounts staffOrders;
  final CorrectionCounts corrections;

  SummaryCounts({
    required this.schools,
    required this.students,
    required this.orders,
    required this.staffOrders,
    required this.corrections,
  });

  factory SummaryCounts.fromJson(Map<String, dynamic> json) => SummaryCounts(
        schools: SchoolCounts.fromJson(json['schools'] ?? {}),
        students: StudentCounts.fromJson(json['students'] ?? {}),
        orders: OrderCounts.fromJson(json['orders'] ?? {}),
        staffOrders: OrderCounts.fromJson(json['staff_orders'] ?? {}),
        corrections: CorrectionCounts.fromJson(json['corrections'] ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'schools': schools.toJson(),
        'students': students.toJson(),
        'orders': orders.toJson(),
        'staff_orders': staffOrders.toJson(),
        'corrections': corrections.toJson(),
      };
}

class SchoolCounts {
  final int total;
  final String active;
  final String inactive;

  SchoolCounts({required this.total, required this.active, required this.inactive});

  factory SchoolCounts.fromJson(Map<String, dynamic> json) => SchoolCounts(
        total: json['total'] ?? 0,
        active: json['active']?.toString() ?? '0',
        inactive: json['inactive']?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {'total': total, 'active': active, 'inactive': inactive};
}

class StudentCounts {
  final int total;
  final String active;
  final String inactive;

  StudentCounts({required this.total, required this.active, required this.inactive});

  factory StudentCounts.fromJson(Map<String, dynamic> json) => StudentCounts(
        total: json['total'] ?? 0,
        active: json['active']?.toString() ?? '0',
        inactive: json['inactive']?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {'total': total, 'active': active, 'inactive': inactive};
}

class OrderCounts {
  final int total;
  final String newOrders;
  final String completeOrders;
  final String pendingOrders;

  OrderCounts({
    required this.total,
    required this.newOrders,
    required this.completeOrders,
    required this.pendingOrders,
  });

  factory OrderCounts.fromJson(Map<String, dynamic> json) => OrderCounts(
        total: json['total'] ?? 0,
        newOrders: json['new']?.toString() ?? '0',
        completeOrders: json['complete_orders']?.toString() ?? '0',
        pendingOrders: json['pending_orders']?.toString() ?? '0',
      );

  Map<String, dynamic> toJson() => {
        'total': total,
        'new': newOrders,
        'complete_orders': completeOrders,
        'pending_orders': pendingOrders,
      };
}

class CorrectionCounts {
  final int checklists;
  final int checklistStudents;
  final int staffCorrectionLists;

  CorrectionCounts({
    required this.checklists,
    required this.checklistStudents,
    required this.staffCorrectionLists,
  });

  factory CorrectionCounts.fromJson(Map<String, dynamic> json) => CorrectionCounts(
        checklists: json['checklists'] ?? 0,
        checklistStudents: json['checklist_students'] ?? 0,
        staffCorrectionLists: json['staff_correction_lists'] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'checklists': checklists,
        'checklist_students': checklistStudents,
        'staff_correction_lists': staffCorrectionLists,
      };
}

// ─── Latest ──────────────────────────────────────────────────────────────────

class SummaryLatest {
  final List<SummarySchool> schools;
  final List<SummaryStudent> students;
  final List<SummaryOrder> orders;
  final List<SummaryStaffOrder> staffOrders;
  final List<SummaryStudentCorrection> studentCorrections;
  final List<SummaryStaffCorrection> staffCorrections;

  SummaryLatest({
    required this.schools,
    required this.students,
    required this.orders,
    required this.staffOrders,
    required this.studentCorrections,
    required this.staffCorrections,
  });

  factory SummaryLatest.fromJson(Map<String, dynamic> json) => SummaryLatest(
        schools: (json['schools'] as List? ?? [])
            .map((e) => SummarySchool.fromJson(e))
            .toList(),
        students: (json['students'] as List? ?? [])
            .map((e) => SummaryStudent.fromJson(e))
            .toList(),
        orders: (json['orders'] as List? ?? [])
            .map((e) => SummaryOrder.fromJson(e))
            .toList(),
        staffOrders: (json['staff_orders'] as List? ?? [])
            .map((e) => SummaryStaffOrder.fromJson(e))
            .toList(),
        studentCorrections: (json['student_corrections'] as List? ?? [])
            .map((e) => SummaryStudentCorrection.fromJson(e))
            .toList(),
        staffCorrections: (json['staff_corrections'] as List? ?? [])
            .map((e) => SummaryStaffCorrection.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'schools': schools.map((e) => e.toJson()).toList(),
        'students': students.map((e) => e.toJson()).toList(),
        'orders': orders.map((e) => e.toJson()).toList(),
        'staff_orders': staffOrders.map((e) => e.toJson()).toList(),
        'student_corrections': studentCorrections.map((e) => e.toJson()).toList(),
        'staff_corrections': staffCorrections.map((e) => e.toJson()).toList(),
      };
}

class SummarySchool {
  final int id;
  final String uuid;
  final String name;
  final String schoolPrefix;
  final int status;
  final String createdAt;

  SummarySchool({
    required this.id,
    required this.uuid,
    required this.name,
    required this.schoolPrefix,
    required this.status,
    required this.createdAt,
  });

  factory SummarySchool.fromJson(Map<String, dynamic> json) => SummarySchool(
        id: json['id'] ?? 0,
        uuid: json['uuid'] ?? '',
        name: json['name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        status: json['status'] ?? 1,
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'name': name,
        'school_prefix': schoolPrefix,
        'status': status,
        'created_at': createdAt,
      };
}

class SummaryStudent {
  final int id;
  final String uuid;
  final int schoolId;
  final String schoolName;
  final String schoolPrefix;
  final String name;
  final dynamic admissionNo;
  final dynamic phone;
  final int status;
  final String createdAt;

  SummaryStudent({
    required this.id,
    required this.uuid,
    required this.schoolId,
    required this.schoolName,
    required this.schoolPrefix,
    required this.name,
    this.admissionNo,
    this.phone,
    required this.status,
    required this.createdAt,
  });

  factory SummaryStudent.fromJson(Map<String, dynamic> json) => SummaryStudent(
        id: json['id'] ?? 0,
        uuid: json['uuid'] ?? '',
        schoolId: json['school_id'] ?? 0,
        schoolName: json['school_name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        name: json['name'] ?? '',
        admissionNo: json['admission_no'],
        phone: json['phone'],
        status: json['status'] ?? 1,
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'school_id': schoolId,
        'school_name': schoolName,
        'school_prefix': schoolPrefix,
        'name': name,
        'admission_no': admissionNo,
        'phone': phone,
        'status': status,
        'created_at': createdAt,
      };
}

class SummaryOrder {
  final int id;
  final String uuid;
  final int schoolId;
  final String schoolName;
  final String schoolPrefix;
  final int studentId;
  final String studentName;
  final String type;
  final String status;
  final String createdAt;

  SummaryOrder({
    required this.id,
    required this.uuid,
    required this.schoolId,
    required this.schoolName,
    required this.schoolPrefix,
    required this.studentId,
    required this.studentName,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  factory SummaryOrder.fromJson(Map<String, dynamic> json) => SummaryOrder(
        id: json['id'] ?? 0,
        uuid: json['uuid'] ?? '',
        schoolId: json['school_id'] ?? 0,
        schoolName: json['school_name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        studentId: json['student_id'] ?? 0,
        studentName: json['student_name'] ?? '',
        type: json['type'] ?? '',
        status: json['status'] ?? '',
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'school_id': schoolId,
        'school_name': schoolName,
        'school_prefix': schoolPrefix,
        'student_id': studentId,
        'student_name': studentName,
        'type': type,
        'status': status,
        'created_at': createdAt,
      };
}

class SummaryStaffOrder {
  final int id;
  final String uuid;
  final int schoolId;
  final String schoolName;
  final String schoolPrefix;
  final int schoolStaffId;
  final String staffName;
  final String type;
  final String quantity;
  final String status;
  final String createdAt;

  SummaryStaffOrder({
    required this.id,
    required this.uuid,
    required this.schoolId,
    required this.schoolName,
    required this.schoolPrefix,
    required this.schoolStaffId,
    required this.staffName,
    required this.type,
    required this.quantity,
    required this.status,
    required this.createdAt,
  });

  factory SummaryStaffOrder.fromJson(Map<String, dynamic> json) => SummaryStaffOrder(
        id: json['id'] ?? 0,
        uuid: json['uuid'] ?? '',
        schoolId: json['school_id'] ?? 0,
        schoolName: json['school_name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        schoolStaffId: json['school_staff_id'] ?? 0,
        staffName: json['staff_name'] ?? '',
        type: json['type'] ?? '',
        quantity: json['quantity']?.toString() ?? '0',
        status: json['status'] ?? '',
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'school_id': schoolId,
        'school_name': schoolName,
        'school_prefix': schoolPrefix,
        'school_staff_id': schoolStaffId,
        'staff_name': staffName,
        'type': type,
        'quantity': quantity,
        'status': status,
        'created_at': createdAt,
      };
}

class SummaryStudentCorrection {
  final int id;
  final String uuid;
  final int schoolId;
  final String schoolName;
  final String schoolPrefix;
  final String listType;
  final String status;
  final String? className;
  final dynamic sectionName;
  final String createdAt;

  SummaryStudentCorrection({
    required this.id,
    required this.uuid,
    required this.schoolId,
    required this.schoolName,
    required this.schoolPrefix,
    required this.listType,
    required this.status,
    this.className,
    this.sectionName,
    required this.createdAt,
  });

  factory SummaryStudentCorrection.fromJson(Map<String, dynamic> json) =>
      SummaryStudentCorrection(
        id: json['id'] ?? 0,
        uuid: json['uuid'] ?? '',
        schoolId: json['school_id'] ?? 0,
        schoolName: json['school_name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        listType: json['list_type'] ?? '',
        status: json['status'] ?? '',
        className: json['class_name'],
        sectionName: json['section_name'],
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'uuid': uuid,
        'school_id': schoolId,
        'school_name': schoolName,
        'school_prefix': schoolPrefix,
        'list_type': listType,
        'status': status,
        'class_name': className,
        'section_name': sectionName,
        'created_at': createdAt,
      };
}

class SummaryStaffCorrection {
  final int id;
  final int schoolId;
  final String schoolName;
  final String schoolPrefix;
  final int schoolStaffId;
  final String staffName;
  final String createdAt;

  SummaryStaffCorrection({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.schoolPrefix,
    required this.schoolStaffId,
    required this.staffName,
    required this.createdAt,
  });

  factory SummaryStaffCorrection.fromJson(Map<String, dynamic> json) =>
      SummaryStaffCorrection(
        id: json['id'] ?? 0,
        schoolId: json['school_id'] ?? 0,
        schoolName: json['school_name'] ?? '',
        schoolPrefix: json['school_prefix'] ?? '',
        schoolStaffId: json['school_staff_id'] ?? 0,
        staffName: json['staff_name'] ?? '',
        createdAt: json['created_at'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'school_id': schoolId,
        'school_name': schoolName,
        'school_prefix': schoolPrefix,
        'school_staff_id': schoolStaffId,
        'staff_name': staffName,
        'created_at': createdAt,
      };
}
