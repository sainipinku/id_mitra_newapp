import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/face_capture/screens/camera_screen.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:idmitra/providers/students/students_state.dart';
import 'package:idmitra/providers/class_students/class_students_cubit.dart';
import 'package:idmitra/providers/class_students/class_students_state.dart';
import 'package:idmitra/screens/home/StudentCard.dart';

class ClassStudentsListPage extends StatefulWidget {
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;
  final String? initialClassId;

  const ClassStudentsListPage({
    super.key,
    required this.schoolId,
    this.schoolDetailsModel,
    this.initialClassId,
  });

  @override
  State<ClassStudentsListPage> createState() => _ClassStudentsListPageState();
}

class _ClassStudentsListPageState extends State<ClassStudentsListPage> {
  final Set<String> _selectedUuids = {};
  final ScrollController _scrollCtrl = ScrollController();

  void _selectAll(List<StudentDetailsData> students) {
    setState(() {
      final allUuids = students
          .where((s) => s.uuid != null)
          .map((s) => s.uuid!)
          .toSet();

      if (_selectedUuids.containsAll(allUuids) && allUuids.isNotEmpty) {
        _selectedUuids.clear();
      } else {
        _selectedUuids.addAll(allUuids);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedUuids.clear();
    });
  }

  @override
  void initState() {
    super.initState();

    // Load all students immediately (no class filter)
    context.read<StudentsCubit>().fetchStudents(
      schoolId: widget.schoolId,
      search: '',
    );

    // Load classes for dropdown
    context.read<ClassStudentsCubit>().fetchClasses(
      widget.schoolId,
      initialClassId: widget.initialClassId,
    );

    // Pagination scroll
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        final state = context.read<StudentsCubit>().state;
        final classState = context.read<ClassStudentsCubit>().state;
        if (state.loading || state.isPaginationLoading || !state.hasMore) return;
        context.read<StudentsCubit>().fetchStudents(
          isLoadMore: true,
          schoolId: widget.schoolId,
          classId: classState.selectedClassId ?? '',
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: 'Class Student List',
        showText: true,
      ),
      body: BlocBuilder<ClassStudentsCubit, ClassStudentsState>(
        builder: (context, classState) {
          final students = context.watch<StudentsCubit>().state.studentsList;

          final allUuids = students
              .where((s) => s.uuid != null)
              .map((s) => s.uuid!)
              .toSet();

          final bool isAllSelected = allUuids.isNotEmpty && 
              allUuids.every((id) => _selectedUuids.contains(id));

          return Column(
            children: [
              // Selection Actions Toolbar (Visible only when students are selected)
              if (_selectedUuids.isNotEmpty)
                _SelectionToolbar(
                  selectedCount: _selectedUuids.length,
                  onClear: _clearSelection,
                  onBulkAction: () {
                    final studentsList =
                        context.read<StudentsCubit>().state.studentsList;

                    final List<StudentDetailsData> selectedWithPhotos = [];
                    final List<StudentDetailsData> selectedWithoutPhotos = [];

                    for (var s in studentsList) {
                      if (s.uuid != null && _selectedUuids.contains(s.uuid)) {
                        final url = s.profilePhotoUrl?.trim();
                        final bool hasOnlinePhoto = url != null &&
                            url.isNotEmpty &&
                            !url.contains('ui-avatars.com');

                        final bool hasOfflinePhoto =
                            s.offlinePhotoPath != null &&
                                s.offlinePhotoPath!.isNotEmpty;

                        if (hasOnlinePhoto || hasOfflinePhoto) {
                          selectedWithPhotos.add(s);
                        } else {
                          selectedWithoutPhotos.add(s);
                        }
                      }
                    }

                    // Show message for skipped students
                    if (selectedWithPhotos.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${selectedWithPhotos.length} students skipped because they already have photos.',
                            style: MyStyles.mediumText(
                                size: 14, color: Colors.white),
                          ),
                          backgroundColor: AppTheme.btnColor,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }

                    if (selectedWithoutPhotos.isEmpty) {
                      _clearSelection();
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CameraScreen(
                          bulkStudents: selectedWithoutPhotos,
                          schoolId: widget.schoolId,
                          onUploaded: (url) {},
                        ),
                      ),
                    ).then((_) {
                      _clearSelection();
                      context.read<StudentsCubit>().fetchStudents(
                            schoolId: widget.schoolId,
                            classId: classState.selectedClassId ?? '',
                          );
                    });
                  },
              ),

              // Selection & Class filter row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Select All Section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Select",
                          style: MyStyles.mediumText(
                            size: 12,
                            color: AppTheme.graySubTitleColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _selectAll(students),
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppTheme.whiteColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.backBtnBgColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: isAllSelected,
                                    onChanged: (_) => _selectAll(students),
                                    activeColor: AppTheme.btnColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    side: const BorderSide(
                                        color: AppTheme.btnColor, width: 1.5),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'All',
                                  style: MyStyles.mediumText(
                                      size: 14, color: AppTheme.btnColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Class Dropdown Section
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Filter by Class",
                            style: MyStyles.mediumText(
                              size: 12,
                              color: AppTheme.graySubTitleColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.whiteColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.backBtnBgColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                menuMaxHeight: 350,
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppTheme.btnColor,
                                ),
                                hint: Text(
                                  classState.classesLoading
                                      ? "Loading Classes..."
                                      : "All Classes",
                                  style: MyStyles.regularText(
                                    size: 14,
                                    color: AppTheme.graySubTitleColor,
                                  ),
                                ),
                                value: classState.selectedClassId,
                                dropdownColor: AppTheme.whiteColor,
                                borderRadius: BorderRadius.circular(12),
                                items: [
                                  DropdownMenuItem<String>(
                                    value: null,
                                    child: Text(
                                      'All Classes',
                                      style: MyStyles.mediumText(
                                        size: 15,
                                        color: AppTheme.black_Color,
                                      ),
                                    ),
                                  ),
                                  ...classState.classes
                                      .map((ClassOption classOpt) {
                                    return DropdownMenuItem<String>(
                                      value: classOpt.value,
                                      child: Text(
                                        classOpt.label ?? '',
                                        style: MyStyles.mediumText(
                                          size: 15,
                                          color: AppTheme.black_Color,
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                onChanged: (String? newValue) {
                                  _clearSelection();
                                  // Update selected class in ClassStudentsCubit
                                  context
                                      .read<ClassStudentsCubit>()
                                      .setSelectedClass(newValue);
                                  // Fetch students with class filter via StudentsCubit
                                  context.read<StudentsCubit>().applyFilters(
                                        schoolId: widget.schoolId,
                                        classId: newValue ?? '',
                                        gender: '',
                                        sectionIds: [],
                                      );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Student list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    final selectedClassId = classState.selectedClassId;
                    await context.read<StudentsCubit>().fetchStudents(
                      schoolId: widget.schoolId,
                      classId: selectedClassId ?? '',
                    );
                  },
                  child: BlocBuilder<StudentsCubit, StudentsState>(
                    builder: (context, state) {
                      if (state.loading && state.studentsList.isEmpty) {
                        return const ShimmerList(expanded: false);
                      }

                      if (state.studentsList.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset("assets/images/no_data.png", height: 150),
                              const SizedBox(height: 10),
                              const Text("No students found"),
                            ],
                          ),
                        );
                      }

                      final itemCount = state.studentsList.length + (state.hasMore ? 1 : 0);

                      return ListView.builder(
                        controller: _scrollCtrl,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= state.studentsList.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final student = state.studentsList[index];
                          final isSelected = student.uuid != null &&
                              _selectedUuids.contains(student.uuid);

                          final void Function() toggleSelection = () {
                            if (student.uuid == null) return;
                            setState(() {
                              if (_selectedUuids.contains(student.uuid)) {
                                _selectedUuids.remove(student.uuid);
                              } else {
                                _selectedUuids.add(student.uuid!);
                              }
                            });
                          };

                          return StudentCard(
                            studentData: student,
                            schoolId: widget.schoolId,
                            schoolIntId: widget.schoolDetailsModel?.id,
                            imageShape: widget.schoolDetailsModel?.imageShape,
                            showExtraOption: false,
                            showActivateOption: false,
                            isSelected: isSelected,
                            onToggle: _selectedUuids.isNotEmpty ? toggleSelection : null,
                            onLongPress: toggleSelection,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onBulkAction;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.onClear,
    required this.onBulkAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.btnColor.withOpacity(0.07),
        border: const Border(
          left: BorderSide(color: AppTheme.btnColor, width: 3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.btnColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$selectedCount',
              style: MyStyles.boldText(size: 11, color: Colors.white),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'selected',
            style: MyStyles.regularText(size: 12, color: AppTheme.btnColor),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onClear,
            child: Text(
              'Clear',
              style: MyStyles.mediumText(
                  size: 12, color: AppTheme.graySubTitleColor),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onBulkAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.btnColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.btnColor.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    'Bulk Action',
                    style: MyStyles.mediumText(size: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
