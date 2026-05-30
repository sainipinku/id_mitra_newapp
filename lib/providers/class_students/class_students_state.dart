import 'package:idmitra/models/students/StudentsListModel.dart';

class ClassStudentsState {
  final bool loading;
  final bool classesLoading;
  final List<StudentDetailsData> studentsList;
  final List<ClassOption> classes;
  final String? selectedClassId;
  final String? error;

  ClassStudentsState({
    this.loading = false,
    this.classesLoading = false,
    this.studentsList = const [],
    this.classes = const [],
    this.selectedClassId,
    this.error,
  });

  ClassStudentsState copyWith({
    bool? loading,
    bool? classesLoading,
    List<StudentDetailsData>? studentsList,
    List<ClassOption>? classes,
    String? selectedClassId,
    String? error,
  }) {
    return ClassStudentsState(
      loading: loading ?? this.loading,
      classesLoading: classesLoading ?? this.classesLoading,
      studentsList: studentsList ?? this.studentsList,
      classes: classes ?? this.classes,
      selectedClassId: selectedClassId ?? this.selectedClassId,
      error: error ?? this.error,
    );
  }
}
