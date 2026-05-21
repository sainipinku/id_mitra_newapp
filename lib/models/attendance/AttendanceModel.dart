class AttendanceClassItem {
  final int id;
  final String name;
  final String? nameWithprefix;

  const AttendanceClassItem({
    required this.id,
    required this.name,
    this.nameWithprefix,
  });

  String get displayName => nameWithprefix ?? name;

  @override
  bool operator ==(Object other) =>
      other is AttendanceClassItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  factory AttendanceClassItem.fromJson(Map<String, dynamic> json) =>
      AttendanceClassItem(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id'].toString()) ?? 0,
        name: json['name']?.toString() ?? '',
        nameWithprefix: json['name_withprefix']?.toString(),
      );
}

class AttendanceStudent {
  final int id;
  final String name;
  final String? rollNo;
  final String? fatherName;
  final String? motherName;
  final String? photo;
  final String? section;
  final String? className;
  final String status;

  const AttendanceStudent({
    required this.id,
    required this.name,
    this.rollNo,
    this.fatherName,
    this.motherName,
    this.photo,
    this.section,
    this.className,
    required this.status,
  });

  bool get isPresent => status == 'present';
  bool get isAbsent => status == 'absent';
  bool get isLate => status == 'late';
  bool get isLeave => status == 'leave';
  bool get isUnmarked => status.isEmpty || status == 'unmarked';

  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  String? get fixedPhoto {
    if (photo == null || photo!.isEmpty) return null;
    if (!photo!.contains('ui-avatars.com')) return photo;

    String url = photo!;

    url = url.replaceFirstMapped(
      RegExp(r'background=([0-9a-fA-F]{5,6})(size=)'),
          (m) => 'background=%23${m[1]}&${m[2]}',
    );

    url = url.replaceFirstMapped(
      RegExp(r'background=([0-9a-fA-F]{5,6})(?=&|$)'),
          (m) => 'background=%23${m[1]}',
    );

    return url;
  }

  factory AttendanceStudent.fromJson(Map<String, dynamic> json) =>
      AttendanceStudent(
        id: json['id'] is int
            ? json['id']
            : int.tryParse(json['id'].toString()) ?? 0,
        name: json['name']?.toString() ?? '',
        rollNo: json['roll_no']?.toString() ?? json['rollNo']?.toString(),
        fatherName:
        json['father_name']?.toString() ?? json['fatherName']?.toString(),
        motherName:
        json['mother_name']?.toString() ?? json['motherName']?.toString(),
        photo: json['photo']?.toString(),
        section: json['section']?.toString(),
        className: json['class_name']?.toString() ??
            json['className']?.toString() ??
            json['class']?.toString(),
        status: (json['status']?.toString() ?? '').toLowerCase().trim(),
      );
}

class AttendanceStats {
  final int present;
  final int absent;
  final int late;
  final int leave;
  final int total;

  const AttendanceStats({
    this.present = 0,
    this.absent = 0,
    this.late = 0,
    this.leave = 0,
    this.total = 0,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    final present = _int(json['present']);
    final absent = _int(json['absent']);
    final late = _int(json['late']);
    final leave = _int(json['leave']);
    final apiTotal = _int(json['total']);
    final computed = present + absent + late + leave;
    return AttendanceStats(
      present: present,
      absent: absent,
      late: late,
      leave: leave,
      total: apiTotal > 0 ? apiTotal : computed,
    );
  }

  static int _int(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;
}

class AttendanceResponse {
  final List<AttendanceClassItem> classes;
  final int selectedClassId;
  final String selectedDate;
  final List<AttendanceStudent> students;
  final AttendanceStats stats;

  const AttendanceResponse({
    required this.classes,
    required this.selectedClassId,
    required this.selectedDate,
    required this.students,
    required this.stats,
  });

  factory AttendanceResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final rawClasses = data['classes'] as List? ?? [];
    final rawStudents = data['attendanceData'] as List? ?? [];

    return AttendanceResponse(
      classes: rawClasses
          .map((e) => AttendanceClassItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      selectedClassId: data['selectedClass'] is int
          ? data['selectedClass']
          : int.tryParse(data['selectedClass']?.toString() ?? '') ?? 0,
      selectedDate: data['selectedDate']?.toString() ?? '',
      students: rawStudents
          .map((e) => AttendanceStudent.fromJson(e as Map<String, dynamic>))
          .toList(),
      stats: AttendanceStats.fromJson(
        (data['stats'] as Map<String, dynamic>?) ?? {},
      ),
    );
  }
}
