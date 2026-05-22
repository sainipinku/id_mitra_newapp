import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';

class StudentsState {
  final bool loading;
  final bool isPaginationLoading;
  final List<StudentDetailsData> studentsList;
  final int page;
  final bool hasMore;
  final int total;
  final String? error;
  final bool isSyncing;

  // Extra (moved) students
  final bool extraLoading;
  final List<StudentDetailsData> extraStudentsList;

  /// 🔥 Filters
  final String selectedClassId;
  final List<int> selectedSectionIds;
  final String selectedGender;

  StudentsState({
    this.loading = false,
    this.isPaginationLoading = false,
    this.studentsList = const [],
    this.page = 1,
    this.hasMore = true,
    this.total = 0,
    this.error,
    this.isSyncing = false,
    this.extraLoading = false,
    this.extraStudentsList = const [],
    this.selectedClassId = "",
    this.selectedSectionIds = const [],
    this.selectedGender = "",
  });

  StudentsState copyWith({
    bool? loading,
    bool? isPaginationLoading,
    List<StudentDetailsData>? studentsList,
    int? page,
    bool? hasMore,
    int? total,
    String? error,
    bool? isSyncing,
    bool? extraLoading,
    List<StudentDetailsData>? extraStudentsList,
    String? selectedClassId,
    List<int>? selectedSectionIds,
    String? selectedGender,
  }) {
    return StudentsState(
      loading: loading ?? this.loading,
      isPaginationLoading: isPaginationLoading ?? this.isPaginationLoading,
      studentsList: studentsList ?? this.studentsList,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      total: total ?? this.total,
      error: error ?? this.error,
      isSyncing: isSyncing ?? this.isSyncing,
      extraLoading: extraLoading ?? this.extraLoading,
      extraStudentsList: extraStudentsList ?? this.extraStudentsList,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      selectedSectionIds: selectedSectionIds ?? this.selectedSectionIds,
      selectedGender: selectedGender ?? this.selectedGender,
    );
  }
}