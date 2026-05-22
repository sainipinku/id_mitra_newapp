// ==================== ORDER MODEL ====================

class OrderModel {
  final int id;
  final String uuid;
  final String status;
  final String type;
  final String orderedAt;        // API mein "orderd_at"
  final String receivedAtShort;
  final int studentCard;
  final int studentCardQty;
  final int parentCard;
  final int admitCard;
  final String? printingIssue;
  final String? deliveredAt;
  final String? cancelledAt;

  final OrderSchool? school;
  final OrderStudent? student;
  final OrderStaff? staff;

  const OrderModel({
    required this.id,
    required this.uuid,
    required this.status,
    required this.type,
    required this.orderedAt,
    required this.receivedAtShort,
    this.studentCard = 0,
    this.studentCardQty = 1,
    this.parentCard = 0,
    this.admitCard = 0,
    this.printingIssue,
    this.deliveredAt,
    this.cancelledAt,
    this.school,
    this.student,
    this.staff,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? 0,
      uuid: json['uuid'] ?? '',
      status: json['status'] ?? '',
      type: json['type'] ?? '',
      orderedAt: json['orderd_at'] ?? json['ordered_at'] ?? '',
      receivedAtShort: json['received_at_short'] ?? '',
      studentCard: json['student_card'] ?? 0,
      studentCardQty: json['student_card_qty'] ?? 1,
      parentCard: json['parent_card'] ?? 0,
      admitCard: json['admit_card'] ?? 0,
      printingIssue: json['printing_issue'],
      deliveredAt: json['deliverd_at'],      // API spelling
      cancelledAt: json['cancelled_at'],
      school: json['school'] != null ? OrderSchool.fromJson(json['school']) : null,
      student: json['student'] != null ? OrderStudent.fromJson(json['student']) : null,
      staff: json['staff'] != null ? OrderStaff.fromJson(json['staff']) : null,
    );
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String get formattedOrderedAt {
    if (orderedAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(orderedAt).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = _months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return orderedAt;
    }
  }

  String get statusLabel {
    return kOrderStatuses
        .firstWhere(
          (s) => s.value == status,
      orElse: () => OrderStatusOption(status, status.replaceAll('_', ' ')),
    )
        .label;
  }

  String get typeLabel {
    switch (type.toLowerCase()) {
      case 'rfid_card':
        return 'RFID Card';
      case 'pvc_card':
        return 'PVC Card';
      case 'pasting_card':
        return 'Pasting Card';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }
}

// ==================== SUB MODELS ====================

class OrderSchool {
  final int id;
  final String name;
  final String? logoUrl;
  final String? address;
  final String? pincode;
  final String? prefix;

  const OrderSchool({
    required this.id,
    required this.name,
    this.logoUrl,
    this.address,
    this.pincode,
    this.prefix,
  });

  factory OrderSchool.fromJson(Map<String, dynamic> json) => OrderSchool(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    logoUrl: json['logo_url'],
    address: json['address'],
    pincode: json['pincode']?.toString(),
    prefix: json['school_prefix'] ?? json['prefix'],
  );
}

class OrderStudent {
  final int id;
  final String name;
  final String? profilePhotoUrl;
  final String? className;
  final int? classId;
  final String? sectionName;
  final String? gender;
  final String? dob;
  final String? fatherName;
  final String? fatherPhone;
  final String? motherName;
  final String? address;
  final String? pincode;
  final String? loginId;

  const OrderStudent({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    this.className,
    this.classId,
    this.sectionName,
    this.gender,
    this.dob,
    this.fatherName,
    this.fatherPhone,
    this.motherName,
    this.address,
    this.pincode,
    this.loginId,
  });

  factory OrderStudent.fromJson(Map<String, dynamic> json) {
    final classData = json['class'] as Map<String, dynamic>?;
    final sectionData = json['section'] as Map<String, dynamic>?;

    return OrderStudent(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      profilePhotoUrl: json['profile_photo_url'],
      className: classData?['name_withprefix'] ?? classData?['name'],
      classId: classData?['id'],
      sectionName: sectionData?['name'],
      gender: json['gender'],
      dob: json['dob'],
      fatherName: json['father_name'],
      fatherPhone: json['father_phone'],
      motherName: json['mother_name'],
      address: json['address'],
      pincode: json['pincode']?.toString(),
      loginId: json['login_id'],
    );
  }
}

class OrderStaff {
  final int id;
  final String name;
  final String? profilePhotoUrl;
  final String? designation;
  final String? phone;
  final String? email;
  final String? employeeId;

  const OrderStaff({
    required this.id,
    required this.name,
    this.profilePhotoUrl,
    this.designation,
    this.phone,
    this.email,
    this.employeeId,
  });

  factory OrderStaff.fromJson(Map<String, dynamic> json) => OrderStaff(
    id: json['id'] ?? 0,
    name: json['name'] ?? '',
    profilePhotoUrl: json['profile_photo_url'],
    designation: json['designation'],
    phone: json['phone'],
    email: json['email'],
    employeeId: json['employee_id']?.toString(),
  );
}

// ==================== STATUS ====================

class OrderStatusOption {
  final String value;
  final String label;
  const OrderStatusOption(this.value, this.label);
}

const kOrderStatuses = [
  OrderStatusOption('order_created', 'Order Created'),
  OrderStatusOption('re_order', 'Re-Order'),
  OrderStatusOption('work_in_process', 'Work In Process'),
  OrderStatusOption('completed', 'Completed'),
  OrderStatusOption('cancelled', 'Cancelled'),
  OrderStatusOption('printing_issue', 'Printing Issue'),
  OrderStatusOption('delivery_verified', 'Delivery Verified'),
];

const kOrderFilterStatuses = [
  OrderStatusOption('', 'All Status'),
  OrderStatusOption('order_created', 'Order Created'),
  OrderStatusOption('re_order', 'Re-Order'),
  OrderStatusOption('work_in_process', 'Work In Process'),
  OrderStatusOption('completed', 'Completed'),
  OrderStatusOption('cancelled', 'Cancelled'),
  OrderStatusOption('printing_issue', 'Printing Issue'),
  OrderStatusOption('delivery_verified', 'Delivery Verified'),
];