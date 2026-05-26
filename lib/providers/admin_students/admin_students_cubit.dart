import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/admin_students/admin_students_state.dart';

class AdminStudentsCubit extends Cubit<AdminStudentsState> {
  AdminStudentsCubit() : super(AdminStudentsState());

  final ApiManager _api = ApiManager();

  Future<void> fetchStudents({
    bool isLoadMore = false,
    String schoolId = "",
    String search = "",
    String classId = "",
    String gender = "",
  }) async {
    if (state.isPaginationLoading || (!state.hasMore && isLoadMore)) return;

    final int currentPage = isLoadMore ? state.page : 1;

    if (!isLoadMore) {
      emit(state.copyWith(loading: true, page: 1, studentsList: [], hasMore: true));
    } else {
      emit(state.copyWith(isPaginationLoading: true));
    }

    final url =
        "${Config.baseUrl}auth/school/$schoolId/students?search=$search&page=$currentPage&gender=$gender&class_filters=$classId";

    final response = await _api.getRequest(url);

    if (response == null || response.statusCode != 200) {
      emit(state.copyWith(
        loading: false,
        isPaginationLoading: false,
        error: 'Failed to load students (${response?.statusCode})',
      ));
      return;
    }

    final jsonData = jsonDecode(response.body);
    final List list = jsonData["data"]?["data"] ?? [];
    final newList = list.map((e) => StudentDetailsData.fromJson(e)).toList();
    final total = jsonData["data"]?["total"] ?? 0;

    final updatedList = isLoadMore
        ? [...state.studentsList, ...newList]
        : List<StudentDetailsData>.from(newList);

    emit(state.copyWith(
      loading: false,
      isPaginationLoading: false,
      studentsList: updatedList,
      page: currentPage + 1,
      hasMore: updatedList.length < total,
    ));
  }

  void prependStudent(StudentDetailsData student) {
    emit(state.copyWith(studentsList: [student, ...state.studentsList]));
  }
}
