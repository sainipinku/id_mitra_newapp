import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/admin_students/admin_students_cubit.dart';
import 'package:idmitra/providers/admin_students/admin_students_state.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/screens/add_student/add_student_form.dart';
import 'package:idmitra/screens/home/FilterBottomSheet.dart';
import 'package:idmitra/screens/home/StudentCard.dart';

class AdminStudentsScreen extends StatefulWidget {
  final String schoolId;
  const AdminStudentsScreen({super.key, required this.schoolId});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  void _load({String search = '', String classId = '', String gender = ''}) {
    context.read<AdminStudentsCubit>().fetchStudents(
          schoolId: widget.schoolId,
          search: search,
          classId: classId,
          gender: gender,
        );
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      context.read<AdminStudentsCubit>().fetchStudents(
            isLoadMore: true,
            schoolId: widget.schoolId,
            search: _searchController.text.trim(),
          );
    }
  }

  void _navigateToAddStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => StudentFormCubit()
                ..loadFromSchoolId(schoolId: widget.schoolId, schoolName: ''),
            ),
            BlocProvider(
              create: (_) => StudentFormDataCubit()..load(widget.schoolId),
            ),
            BlocProvider(create: (_) => AddStudentCubit()),
          ],
          child: AddStudentFormPage(schoolId: widget.schoolId),
        ),
      ),
    ).then((result) {
      if (result != null && result is StudentDetailsData) {
        context.read<AdminStudentsCubit>().prependStudent(result);
      } else {
        _load(search: _searchController.text.trim());
      }
    });
  }

  Future<void> _refresh() async {
    _load(search: _searchController.text.trim());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'Students'),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.btnColor,
        tooltip: 'Add Student',
        onPressed: _navigateToAddStudent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _searchBar()),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final result =
                          await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.whiteColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        builder: (_) => BlocProvider(
                          create: (_) => OrdersCubit()
                            ..fetchSchoolClasses(widget.schoolId),
                          child: FilterBottomSheet(schoolId: widget.schoolId),
                        ),
                      );

                      if (result != null) {
                        _debounce?.cancel();
                        _debounce =
                            Timer(const Duration(milliseconds: 300), () {
                          _load(
                            classId: result['class'] ?? '',
                            gender: result['gender']?.toString().toLowerCase() ?? '',
                          );
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: svgIcon(
                        icon: 'assets/icons/filtter.svg',
                        clr: AppTheme.black_Color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              BlocBuilder<AdminStudentsCubit, AdminStudentsState>(
                builder: (context, state) {
                  if (state.loading) {
                    return const StudentListShimmer();
                  }

                  if (state.studentsList.isEmpty) {
                    return Expanded(
                      child: Center(
                        child: Image.asset(
                          "assets/images/no_data.png",
                          height: 200,
                        ),
                      ),
                    );
                  }

                  return Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      itemCount: state.studentsList.length +
                          (state.hasMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < state.studentsList.length) {
                          return StudentCard(
                            studentData: state.studentsList[index],
                            schoolId: widget.schoolId,
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchController,
      style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          _load(search: value.trim());
        });
      },
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.whiteColor,
        contentPadding: const EdgeInsets.all(12),
        hintText: 'Search students...',
        prefixIcon: const Icon(Icons.search),
        enabledBorder: _border(AppTheme.backBtnBgColor),
        focusedBorder: _border(AppTheme.backBtnBgColor),
        errorBorder: _border(AppTheme.errorMessageBackgroundColor),
        focusedErrorBorder: _border(AppTheme.errorMessageBackgroundColor),
        hintStyle:
            MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderSide: BorderSide(color: color),
        borderRadius: BorderRadius.circular(15),
      );
}
