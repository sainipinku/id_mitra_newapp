import 'package:idmitra/models/attendance/AttendanceModel.dart';

class AttendanceState {
  final bool loading;
  final String? error;
  final List<AttendanceClassItem> classes;
  final AttendanceClassItem? selectedClass;
  final String selectedDate;
  final List<AttendanceStudent> students;
  final AttendanceStats stats;
  final bool bulkMode;
  final Set<int> selectedStudentIds;
  final bool bulkSubmitting;

  const AttendanceState({
    this.loading = false,
    this.error,
    this.classes = const [],
    this.selectedClass,
    this.selectedDate = '',
    this.students = const [],
    this.stats = const AttendanceStats(),
    this.bulkMode = false,
    this.selectedStudentIds = const {},
    this.bulkSubmitting = false,
  });

  AttendanceState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<AttendanceClassItem>? classes,
    AttendanceClassItem? selectedClass,
    String? selectedDate,
    List<AttendanceStudent>? students,
    AttendanceStats? stats,
    bool? bulkMode,
    Set<int>? selectedStudentIds,
    bool? bulkSubmitting,
  }) {
    return AttendanceState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      classes: classes ?? this.classes,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedDate: selectedDate ?? this.selectedDate,
      students: students ?? this.students,
      stats: stats ?? this.stats,
      bulkMode: bulkMode ?? this.bulkMode,
      selectedStudentIds: selectedStudentIds ?? this.selectedStudentIds,
      bulkSubmitting: bulkSubmitting ?? this.bulkSubmitting,
    );
  }
}
