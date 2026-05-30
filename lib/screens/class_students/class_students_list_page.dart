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
import 'package:idmitra/providers/class_students/class_students_cubit.dart';
import 'package:idmitra/providers/class_students/class_students_state.dart';
import 'package:idmitra/screens/home/StudentCard.dart';

class ClassStudentsListPage extends StatefulWidget {
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;

  const ClassStudentsListPage({
    super.key,
    required this.schoolId,
    this.schoolDetailsModel,
  });

  @override
  State<ClassStudentsListPage> createState() => _ClassStudentsListPageState();
}

class _ClassStudentsListPageState extends State<ClassStudentsListPage> {
  final Set<String> _selectedUuids = {};

  void _toggleSelect(String uuid) {
    setState(() {
      if (_selectedUuids.contains(uuid)) {
        _selectedUuids.remove(uuid);
      } else {
        _selectedUuids.add(uuid);
      }
    });
  }

  void _selectAll(List<StudentDetailsData> students) {
    setState(() {
      for (var s in students) {
        if (s.uuid != null) _selectedUuids.add(s.uuid!);
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
    context.read<ClassStudentsCubit>().fetchClasses(widget.schoolId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CommonAppBar(
        title: 'Class Student List',
        showText: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final cubit = context.read<ClassStudentsCubit>();
          final currentClassId = cubit.state.selectedClassId;
          
          await cubit.fetchClasses(widget.schoolId);
          
          if (currentClassId != null) {
            await cubit.fetchClassStudents(
              schoolId: widget.schoolId,
              classId: currentClassId,
            );
          }
        },
        child: BlocBuilder<ClassStudentsCubit, ClassStudentsState>(
          builder: (context, state) {
            return Column(
              children: [
                if (_selectedUuids.isNotEmpty)
                  _SelectionToolbar(
                    selectedCount: _selectedUuids.length,
                    onSelectAll: () => _selectAll(state.studentsList),
                    onClear: _clearSelection,
                    onBulkAction: () {
                      final selectedStudents = state.studentsList
                          .where((s) => s.uuid != null && _selectedUuids.contains(s.uuid))
                          .toList();

                      if (selectedStudents.isEmpty) return;

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CameraScreen(
                            bulkStudents: selectedStudents,
                            schoolId: widget.schoolId,
                            onUploaded: (url) {
                              // Optional: handle something when each student is uploaded
                            },
                          ),
                        ),
                      ).then((_) {
                        // Refresh list or clear selection when back
                        _clearSelection();
                        context.read<ClassStudentsCubit>().selectClass(
                          widget.schoolId, 
                          state.selectedClassId!,
                        );
                      });
                    },
                  ),
                Expanded(
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Select Class",
                                style: MyStyles.mediumText(
                                  size: 12,
                                  color: AppTheme.graySubTitleColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
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
                                      state.classesLoading
                                          ? "Loading Classes..."
                                          : "Choose a class",
                                      style: MyStyles.regularText(
                                        size: 14,
                                        color: AppTheme.graySubTitleColor,
                                      ),
                                    ),
                                    value: state.selectedClassId,
                                    dropdownColor: AppTheme.whiteColor,
                                    borderRadius: BorderRadius.circular(12),
                                    items: state.classes.map((ClassOption classOpt) {
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
                                    }).toList(),
                                    onChanged: (String? newValue) {
                                      if (newValue != null) {
                                        _clearSelection();
                                        context
                                            .read<ClassStudentsCubit>()
                                            .selectClass(widget.schoolId, newValue);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (state.classesLoading && state.classes.isEmpty)
                  const SliverFillRemaining(
                      child: ShimmerList(expanded: false))
                else if (state.error != null && state.classes.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(
                          state.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  )
                else if (state.loading ||
                    (state.classesLoading && state.selectedClassId == null))
                  const SliverFillRemaining(
                      child: ShimmerList(expanded: false))
                else if (state.selectedClassId == null && !state.classesLoading)
                        const SliverFillRemaining(
                          child: Center(
                            child: Text("No classes available"),
                          ),
                        )
                      else if (state.studentsList.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.asset("assets/images/no_data.png", height: 150),
                                const SizedBox(height: 10),
                                const Text("No students found for this class"),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final student = state.studentsList[index];
                                return StudentCard(
                                  studentData: student,
                                  schoolId: widget.schoolId,
                                  schoolIntId: widget.schoolDetailsModel?.id,
                                  imageShape: widget.schoolDetailsModel?.imageShape,
                                  showExtraOption: false,
                                  showActivateOption: false,
                                  isSelected: student.uuid != null && _selectedUuids.contains(student.uuid),
                                  onToggle: student.uuid != null ? () => _toggleSelect(student.uuid!) : null,
                                );
                              },
                              childCount: state.studentsList.length,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final VoidCallback onBulkAction;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.onSelectAll,
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
          const SizedBox(width: 8),
          Container(width: 1, height: 14, color: Colors.grey.shade300),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onSelectAll,
            child: Text(
              'Select All',
              style: MyStyles.mediumText(size: 12, color: AppTheme.btnColor),
            ),
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
