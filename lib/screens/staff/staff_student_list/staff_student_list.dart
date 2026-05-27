import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/correction/CorrectionListModel.dart';
import 'package:idmitra/models/orders/OrderModel.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/correction/correction_cubit.dart';
import 'package:idmitra/providers/correction/correction_state.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/orders/orders_state.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:idmitra/providers/students/students_state.dart';
import 'package:idmitra/screens/home/FilterBottomSheet.dart';
import 'package:idmitra/screens/home/StudentCard.dart';
import 'package:idmitra/screens/home/StudentIdCardWidget.dart';
import 'package:idmitra/screens/staff/staff_add_student_form/staff_add_student_form.dart';
import 'package:idmitra/screens/staff/staff_order_page/staff_order_detail_page.dart';
import 'package:idmitra/providers/school/school_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

class StaffStudentsScreen extends StatefulWidget {
  final String? schoolId;
  final bool showAppBar;
  final SchoolDetailsModel? schoolDetailsModel;
  final List<int> assignedClassIds;
  final bool userLoaded;

  const StaffStudentsScreen({
    super.key,
    this.schoolId,
    this.showAppBar = false,
    this.schoolDetailsModel,
    this.assignedClassIds = const [],
    this.userLoaded = false,
  });

  @override
  State<StaffStudentsScreen> createState() => _StaffStudentsScreenState();
}

class _StaffStudentsScreenState extends State<StaffStudentsScreen>
    with SingleTickerProviderStateMixin {
  String _schoolId = '';
  bool _schoolLoaded = false;
  bool _initialFetchDone = false; // ← FIX: guard against double fetch
  late TabController _tabController;
  bool _correctionIsGridView = false;
  bool _studentsIsGridView = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    if (widget.schoolId != null && widget.schoolId!.isNotEmpty) {
      _schoolId = widget.schoolId!;
      _schoolLoaded = true;
      _initialFetchDone = true; // ← mark done so didUpdateWidget skips
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final classId = widget.assignedClassIds.isNotEmpty
              ? widget.assignedClassIds.first.toString()
              : '';
          context.read<StudentsCubit>().fetchStudents(
            search: '',
            schoolId: _schoolId,
            classId: classId,
          );
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StaffStudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.schoolId ?? '';
    final schoolIdChanged = newId.isNotEmpty && newId != _schoolId;
    final classIdsChanged = widget.assignedClassIds.toString() !=
        oldWidget.assignedClassIds.toString();
    final userJustLoaded = widget.userLoaded && !oldWidget.userLoaded;

    if (schoolIdChanged) {
      setState(() {
        _schoolId = newId;
        _schoolLoaded = true;
      });
    }

    // ← FIX: if initState already fetched and nothing changed, skip
    if (_initialFetchDone &&
        !schoolIdChanged &&
        !classIdsChanged &&
        !userJustLoaded) {
      return;
    }

    if ((schoolIdChanged || classIdsChanged || userJustLoaded) &&
        (newId.isNotEmpty || _schoolId.isNotEmpty)) {
      _initialFetchDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final classId = widget.assignedClassIds.isNotEmpty
              ? widget.assignedClassIds.first.toString()
              : '';
          final sid = _schoolId.isNotEmpty ? _schoolId : newId;
          context.read<StudentsCubit>().fetchStudents(
            search: '',
            schoolId: sid,
            classId: classId,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_schoolLoaded || _schoolId.isEmpty) {
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              shimmerBox(height: 48, radius: 12),
              const SizedBox(height: 15),
              const StudentListShimmer(),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.all(10.0),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                border: Border.all(color: AppTheme.titleHintColor),
                borderRadius:
                const BorderRadius.all(Radius.circular(8)),
              ),
              child: const Padding(
                padding: EdgeInsets.all(5.0),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: Text(
          'Student Listings',
          style: MyStyles.boldText(size: 20, color: Colors.black),
        ),
        actions: _tabController.index != 2
            ? [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                if (_tabController.index == 0) {
                  setState(() =>
                  _studentsIsGridView = !_studentsIsGridView);
                } else {
                  setState(() =>
                  _correctionIsGridView =
                  !_correctionIsGridView);
                }
              },
              child: Builder(builder: (context) {
                final isGrid = _tabController.index == 0
                    ? _studentsIsGridView
                    : _correctionIsGridView;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color:
                    isGrid ? AppTheme.btnColor : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isGrid
                          ? AppTheme.btnColor
                          : Colors.grey.shade300,
                    ),
                    boxShadow: isGrid
                        ? [
                      BoxShadow(
                          color: AppTheme.btnColor
                              .withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                        : [],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isGrid
                            ? Icons.view_list_rounded
                            : Icons.badge_outlined,
                        size: 18,
                        color: isGrid
                            ? Colors.white
                            : AppTheme.black_Color,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isGrid ? 'List' : 'ID Card',
                        style: MyStyles.mediumText(
                          size: 12,
                          color: isGrid
                              ? Colors.white
                              : AppTheme.black_Color,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.btnColor,
          unselectedLabelColor: AppTheme.graySubTitleColor,
          indicatorColor: AppTheme.btnColor,
          indicatorWeight: 2.5,
          labelStyle:
          MyStyles.mediumText(size: 13, color: Colors.white),
          unselectedLabelStyle: MyStyles.regularText(
            size: 13,
            color: Colors.white,
          ),
          tabs: const [
            Tab(text: 'Students List'),
            Tab(text: 'Correction List'),
            Tab(text: 'Orders List'),
          ],
        ),
      )
          : PreferredSize(
        preferredSize: const Size.fromHeight(kTextTabBarHeight),
        child: Material(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.btnColor,
            unselectedLabelColor: AppTheme.graySubTitleColor,
            indicatorColor: AppTheme.btnColor,
            indicatorWeight: 2.5,
            labelStyle: MyStyles.mediumText(
              size: 13,
              color: Colors.white,
            ),
            unselectedLabelStyle: MyStyles.regularText(
              size: 13,
              color: Colors.white,
            ),
            tabs: const [
              Tab(text: 'Students List'),
              Tab(text: 'Correction List'),
              Tab(text: 'Orders List'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Students
                _StaffStudentsTab(
                  schoolId: _schoolId,
                  schoolDetailsModel: widget.schoolDetailsModel,
                  isGridView: _studentsIsGridView,
                  assignedClassIds: widget.assignedClassIds,
                  userLoaded: widget.userLoaded,
                ),
                BlocProvider(
                  create: (_) => CorrectionCubit()
                    ..fetchCorrectionStudents(schoolId: _schoolId),
                  child: _StaffCorrectionTab(
                    schoolId: _schoolId,
                    isGridView: _correctionIsGridView,
                    schoolDetailsModel: widget.schoolDetailsModel,
                    assignedClassIds: widget.assignedClassIds,
                  ),
                ),
                // Tab 3: Orders
                BlocProvider(
                  create: (_) => OrdersCubit()
                    ..fetchSchoolOrders(schoolId: _schoolId),
                  child: _StaffOrdersTab(schoolId: _schoolId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Selection Toolbar
// ---------------------------------------------------------------------------

class _StaffSelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onSelectAll;
  final VoidCallback onClear;
  final String actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool actionLoading;

  const _StaffSelectionToolbar({
    required this.selectedCount,
    required this.onSelectAll,
    required this.onClear,
    required this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.actionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.btnColor.withOpacity(0.07),
        border: Border(
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
          actionLoading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.btnColor),
          )
              : GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.btnColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIcon != null) ...[
                    Icon(actionIcon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    actionLabel,
                    style: MyStyles.mediumText(
                        size: 11, color: Colors.white),
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

// ---------------------------------------------------------------------------
// Count row banner
// ---------------------------------------------------------------------------

class _StaffCountRow extends StatelessWidget {
  final int total;
  final String label;
  const _StaffCountRow({required this.total, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppTheme.btnColor.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '$label: $total',
        style: MyStyles.mediumText(size: 13, color: AppTheme.btnColor),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Students Tab
// ---------------------------------------------------------------------------

class _StaffStudentsTab extends StatefulWidget {
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;
  final bool isGridView;
  final List<int> assignedClassIds;
  final bool userLoaded;

  const _StaffStudentsTab({
    required this.schoolId,
    this.schoolDetailsModel,
    this.isGridView = false,
    this.assignedClassIds = const [],
    this.userLoaded = false,
  });

  @override
  State<_StaffStudentsTab> createState() => _StaffStudentsTabState();
}

class _StaffStudentsTabState extends State<_StaffStudentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _gridScrollCtrl = ScrollController();
  Timer? _debounce;

  final Set<int> _selectedIds = {};
  final Map<int, String> _idToUuid = {};

  // ← FIX: guard so initState and didUpdateWidget don't both fire a fetch
  bool _fetchDone = false;

  bool get _isGridView => widget.isGridView;

  void _toggleSelect(StudentDetailsData student) {
    if (student.id == null) return;
    setState(() {
      if (_selectedIds.contains(student.id)) {
        _selectedIds.remove(student.id);
      } else {
        _selectedIds.add(student.id!);
        if (student.uuid != null) _idToUuid[student.id!] = student.uuid!;
      }
    });
  }

  void _selectAll(List<StudentDetailsData> students) {
    setState(() {
      for (final s in students) {
        if (s.id != null) {
          _selectedIds.add(s.id!);
          if (s.uuid != null) _idToUuid[s.id!] = s.uuid!;
        }
      }
    });
  }

  void _clearSelection() => setState(() => _selectedIds.clear());

  void _showProcessChecklistDialog(BuildContext ctx) {
    final uuids = _selectedIds
        .where((id) => _idToUuid.containsKey(id))
        .map((id) => _idToUuid[id]!)
        .toList();
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider(
        create: (_) => CorrectionCubit(),
        child: _StaffStudentsProcessChecklistDialog(
          schoolId: widget.schoolId,
          studentUuids: uuids,
          onSuccess: () {
            _clearSelection();
            context.read<StudentsCubit>().fetchStudents(
              search: _searchCtrl.text.trim(),
              schoolId: widget.schoolId,
            );
          },
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels ==
          _scrollCtrl.position.maxScrollExtent) {
        context.read<StudentsCubit>().fetchStudents(
          isLoadMore: true,
          search: _searchCtrl.text.trim(),
          schoolId: widget.schoolId,
          gender: '',
          classId: '',
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _fetchDone) return;
      _fetchDone = true;

      final classId = widget.assignedClassIds.isNotEmpty
          ? widget.assignedClassIds.first.toString()
          : '';

      context.read<StudentsCubit>().fetchStudents(
        search: '',
        schoolId: widget.schoolId,
        classId: classId,
      );

      final schoolIntId = widget.schoolDetailsModel?.id;
      if (schoolIntId != null) {
        context.read<SchoolCubit>().fetchAndApplyImageShape(schoolIntId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _StaffStudentsTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    final classIdsChanged = widget.assignedClassIds.toString() !=
        oldWidget.assignedClassIds.toString();
    final schoolIdChanged = widget.schoolId != oldWidget.schoolId;
    final userJustLoaded = widget.userLoaded && !oldWidget.userLoaded;

    if ((classIdsChanged || schoolIdChanged || userJustLoaded) &&
        widget.schoolId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _fetchDone = true;
        final classId = widget.assignedClassIds.isNotEmpty
            ? widget.assignedClassIds.first.toString()
            : '';
        context.read<StudentsCubit>().fetchStudents(
          search: _searchCtrl.text.trim(),
          schoolId: widget.schoolId,
          classId: classId,
        );
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _gridScrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _navigateToAddStudent() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => StudentFormCubit()
                ..loadFromSchoolId(
                    schoolId: widget.schoolId, schoolName: ''),
            ),
            BlocProvider(
              create: (_) =>
              StudentFormDataCubit()..load(widget.schoolId),
            ),
            BlocProvider(create: (_) => AddStudentCubit()),
          ],
          child: StaffAddStudentFormPage(schoolId: widget.schoolId),
        ),
      ),
    ).then((_) {
      context.read<StudentsCubit>().fetchStudents(
        search: _searchCtrl.text.trim(),
        schoolId: widget.schoolId,
        gender: '',
        classId: '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.userLoaded) {
      return const Scaffold(
        body: Padding(
          padding: EdgeInsets.all(16),
          child: StudentListShimmer(),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _isGridView
          ? null
          : FloatingActionButton(
        backgroundColor: AppTheme.btnColor,
        tooltip: 'Add Student',
        onPressed: _navigateToAddStudent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          BlocBuilder<StudentsCubit, StudentsState>(
            buildWhen: (p, c) => p.total != c.total,
            builder: (_, s) =>
                _StaffCountRow(total: s.total, label: 'Total Students'),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  context.read<StudentsCubit>().fetchStudents(
                    search: _searchCtrl.text.trim(),
                    schoolId: widget.schoolId,
                    gender: '',
                    classId: widget.assignedClassIds.isNotEmpty
                        ? widget.assignedClassIds.first.toString()
                        : '',
                  ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_selectedIds.isNotEmpty)
                      BlocBuilder<StudentsCubit, StudentsState>(
                        builder: (_, studState) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _StaffSelectionToolbar(
                            selectedCount: _selectedIds.length,
                            onSelectAll: () => _selectAll(studState.studentsList),
                            onClear: _clearSelection,
                            actionLabel: 'Process Checklist',
                            onAction: () => _showProcessChecklistDialog(context),
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(child: _searchBar()),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () async {
                            final result = await showModalBottomSheet<
                                Map<String, dynamic>>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: AppTheme.whiteColor,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(25),
                                ),
                              ),
                              builder: (_) => BlocProvider(
                                create: (_) => OrdersCubit()
                                  ..fetchSchoolClasses(widget.schoolId),
                                child: FilterBottomSheet(
                                  schoolId: widget.schoolId,
                                  allowedClassIds: widget.assignedClassIds,
                                ),
                              ),
                            );
                            if (result != null) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 300),
                                    () {
                                  // If class filter is cleared (reset), fall back to assigned class
                                  final selectedClass = result['class'];
                                  final effectiveClassId = (selectedClass == null || selectedClass.toString().isEmpty)
                                      ? (widget.assignedClassIds.isNotEmpty
                                      ? widget.assignedClassIds.first.toString()
                                      : '')
                                      : selectedClass.toString();
                                  final List<int> sectionIds = result['section'] is List
                                      ? List<int>.from(
                                      (result['section'] as List)
                                          .map((e) => int.tryParse(e.toString()) ?? 0)
                                          .where((e) => e != 0))
                                      : [];
                                  context
                                      .read<StudentsCubit>()
                                      .applyFilters(
                                    schoolId: widget.schoolId,
                                    classId: effectiveClassId,
                                    gender: result['gender']
                                        ?.toString()
                                        .toLowerCase() ??
                                        '',
                                    sectionIds: sectionIds,
                                  );
                                },
                              );
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
                        const SizedBox(width: 8),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Expanded(
                      child: BlocBuilder<StudentsCubit, StudentsState>(
                        builder: (context, state) {
                          final schoolState =
                              context.watch<SchoolCubit>().state;
                          if (state.loading) {
                            return const ShimmerList(expanded: false);
                          }
                          if (state.studentsList.isEmpty) {
                            return Center(
                              child: Image.asset(
                                'assets/images/no_data.png',
                                height: 200,
                              ),
                            );
                          }
                          final itemCount = state.studentsList.length +
                              (state.hasMore ? 1 : 0);
                          if (_isGridView) {
                            return ListView.builder(
                              physics:
                              const AlwaysScrollableScrollPhysics(),
                              controller: _gridScrollCtrl,
                              itemCount: itemCount,
                              itemBuilder: (context, index) {
                                if (index < state.studentsList.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 300,
                                        child: Hero(
                                          tag:
                                          'student_card_${state.studentsList[index].uuid}',
                                          child: Material(
                                            color: Colors.transparent,
                                            child: StudentIdCardWidget(
                                              student: state
                                                  .studentsList[index],
                                              schoolId: widget.schoolId,
                                              schoolDetailsModel: widget
                                                  .schoolDetailsModel,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child:
                                      CircularProgressIndicator()),
                                );
                              },
                            );
                          }
                          return ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            controller: _scrollCtrl,
                            itemCount: itemCount,
                            itemBuilder: (context, index) {
                              if (index < state.studentsList.length) {
                                final student = state.studentsList[index];
                                final schoolIntId =
                                    widget.schoolDetailsModel?.id ??
                                        student.schoolId;
                                String? imageShape;
                                try {
                                  if (schoolIntId != null &&
                                      schoolState.imageShapeMap
                                          .containsKey(schoolIntId)) {
                                    imageShape = schoolState
                                        .imageShapeMap[schoolIntId];
                                  } else {
                                    if (schoolIntId != null) {
                                      final match = schoolState.students
                                          .firstWhere(
                                            (s) => s.id == schoolIntId,
                                        orElse: () => SchoolDetailsModel(),
                                      );
                                      if (match.imageShape != null &&
                                          match.imageShape!.isNotEmpty) {
                                        imageShape = match.imageShape;
                                      }
                                    }
                                    imageShape ??= widget
                                        .schoolDetailsModel?.imageShape;
                                  }
                                } catch (_) {}
                                final isSelected = student.id != null &&
                                    _selectedIds.contains(student.id);
                                return StudentCard(
                                  key: ValueKey(state.studentsList[index].uuid),
                                  studentData: student,
                                  schoolId: widget.schoolId,
                                  schoolIntId: schoolIntId,
                                  imageShape: imageShape,
                                  isSelected: isSelected,
                                  onToggle: () => _toggleSelect(student),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(
        size: 14, color: AppTheme.black_Color),
    onChanged: (value) {
      _debounce?.cancel();
      _debounce =
          Timer(const Duration(milliseconds: 500), () {
            context.read<StudentsCubit>().fetchStudents(
              search: value.trim(),
              schoolId: widget.schoolId,
              classId: widget.assignedClassIds.isNotEmpty
                  ? widget.assignedClassIds.first.toString()
                  : '',
            );
          });
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.whiteColor,
      contentPadding: const EdgeInsets.all(12),
      hintText: 'Search by name...',
      prefixIcon: const Icon(Icons.search),
      enabledBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      hintStyle: MyStyles.regularText(
        size: 14,
        color: AppTheme.graySubTitleColor,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Correction Tab
// ---------------------------------------------------------------------------

class _StaffCorrectionTab extends StatefulWidget {
  final String schoolId;
  final VoidCallback? onOrderSent;
  final bool isGridView;
  final SchoolDetailsModel? schoolDetailsModel;
  final List<int> assignedClassIds;

  const _StaffCorrectionTab({
    required this.schoolId,
    this.onOrderSent,
    this.isGridView = false,
    this.schoolDetailsModel,
    this.assignedClassIds = const [],
  });

  @override
  State<_StaffCorrectionTab> createState() => _StaffCorrectionTabState();
}

class _StaffCorrectionTabState extends State<_StaffCorrectionTab> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool get _isGridView => widget.isGridView;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<CorrectionCubit>().fetchCorrectionStudents(
          schoolId: widget.schoolId,
          isLoadMore: true,
        );
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final schoolIntId = widget.schoolDetailsModel?.id;
        if (schoolIntId != null) {
          context
              .read<SchoolCubit>()
              .fetchAndApplyImageShape(schoolIntId);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.btnColor,
        tooltip: 'Download',
        onPressed: () => _showDownloadDialog(context),
        child: const Icon(Icons.download_rounded, color: Colors.white),
      ),
      body: BlocListener<CorrectionCubit, CorrectionState>(
        listenWhen: (p, c) =>
        p.sendOrderSuccess != c.sendOrderSuccess ||
            p.sendOrderError != c.sendOrderError ||
            p.syncSuccess != c.syncSuccess,
        listener: (context, state) async {
          if (state.syncSuccess) {
            context.read<CorrectionCubit>().fetchCorrectionStudents(
              schoolId: widget.schoolId,
            );
          }
          if (state.sendOrderSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.sendOrderMessage ?? 'Order sent successfully!'),
                backgroundColor: AppTheme.btnColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
              ),
            );
          }
          if (state.sendOrderError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.sendOrderError!),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(12),
              ),
            );
          }
        },
        child: Column(
          children: [
            BlocBuilder<CorrectionCubit, CorrectionState>(
              buildWhen: (p, c) => p.studentsTotal != c.studentsTotal,
              builder: (_, s) => _StaffCountRow(
                  total: s.studentsTotal, label: 'Total Correction'),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _searchBar()),
                  const SizedBox(width: 8),
                  BlocBuilder<CorrectionCubit, CorrectionState>(
                    buildWhen: (p, c) =>
                    p.selectedClassIds != c.selectedClassIds,
                    builder: (context, filterState) {
                      final isFilterActive =
                          filterState.selectedClassIds.isNotEmpty;
                      return GestureDetector(
                        onTap: () async {
                          final result = await showModalBottomSheet<
                              Map<String, dynamic>>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: AppTheme.whiteColor,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(25),
                              ),
                            ),
                            builder: (_) => BlocProvider(
                              create: (_) => OrdersCubit()
                                ..fetchSchoolClasses(widget.schoolId),
                              child: FilterBottomSheet(
                                  schoolId: widget.schoolId,
                                  allowedClassIds: widget.assignedClassIds),
                            ),
                          );
                          if (result != null) {
                            _debounce?.cancel();
                            _debounce = Timer(
                                const Duration(milliseconds: 300), () {
                              final rawClass = result['class'];
                              final List<String> classIds = rawClass
                              is String &&
                                  rawClass.isNotEmpty
                                  ? rawClass
                                  .split(',')
                                  .map((e) => e.trim())
                                  .where((e) => e.isNotEmpty)
                                  .toList()
                                  : rawClass is List
                                  ? List<String>.from(rawClass
                                  .map((e) => e.toString()))
                                  : [];
                              final List<int> sectionIds =
                              result['section'] is List
                                  ? List<int>.from(
                                  (result['section'] as List)
                                      .map((e) =>
                                  int.tryParse(
                                      e.toString()) ??
                                      0)
                                      .where((e) => e != 0))
                                  : [];
                              context
                                  .read<CorrectionCubit>()
                                  .setSelectedClassIds(classIds);
                              context
                                  .read<CorrectionCubit>()
                                  .fetchCorrectionStudents(
                                schoolId: widget.schoolId,
                                classIds: classIds,
                                sectionIds: sectionIds,
                                search: _searchCtrl.text.trim(),
                              );
                            });
                          }
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isFilterActive
                                    ? AppTheme.btnColor.withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: isFilterActive
                                    ? Border.all(
                                    color: AppTheme.btnColor,
                                    width: 1.5)
                                    : null,
                              ),
                              child: svgIcon(
                                icon: 'assets/icons/filtter.svg',
                                clr: isFilterActive
                                    ? AppTheme.btnColor
                                    : AppTheme.black_Color,
                              ),
                            ),
                            if (isFilterActive)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: AppTheme.btnColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${filterState.selectedClassIds.length}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<CorrectionCubit, CorrectionState>(
                builder: (context, state) {
                  final schoolState = context.watch<SchoolCubit>().state;
                  final schoolId = widget.schoolDetailsModel?.id;
                  String? imageShape;
                  if (schoolId != null &&
                      schoolState.imageShapeMap.containsKey(schoolId)) {
                    imageShape = schoolState.imageShapeMap[schoolId];
                  } else {
                    try {
                      if (schoolId != null) {
                        final match = schoolState.students.firstWhere(
                              (s) => s.id == schoolId,
                          orElse: () => SchoolDetailsModel(),
                        );
                        if (match.imageShape != null &&
                            match.imageShape!.isNotEmpty) {
                          imageShape = match.imageShape;
                        }
                      }
                    } catch (_) {}
                    imageShape ??= widget.schoolDetailsModel?.imageShape;
                  }

                  if (state.studentsLoading && state.students.isEmpty) {
                    return const ShimmerList(expanded: false);
                  }
                  if (state.studentsError != null &&
                      state.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline,
                              size: 48, color: Colors.red.shade300),
                          const SizedBox(height: 12),
                          Text(state.studentsError!,
                              style: MyStyles.regularText(
                                  size: 14, color: Colors.red)),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context
                                .read<CorrectionCubit>()
                                .fetchCorrectionStudents(
                                schoolId: widget.schoolId),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.btnColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state.students.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset('assets/images/no_data.png',
                              height: 160),
                          const SizedBox(height: 12),
                          Text('No students found',
                              style: MyStyles.mediumText(
                                  size: 14,
                                  color: AppTheme.graySubTitleColor)),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.btnColor,
                    onRefresh: () async => context
                        .read<CorrectionCubit>()
                        .fetchCorrectionStudents(schoolId: widget.schoolId),
                    child: Column(
                      children: [
                        if (!_isGridView &&
                            state.selectedStudentIds.isNotEmpty)
                          _StaffSelectionToolbar(
                            selectedCount: state.selectedStudentIds.length,
                            onSelectAll: () => context
                                .read<CorrectionCubit>()
                                .selectAllStudents(),
                            onClear: () => context
                                .read<CorrectionCubit>()
                                .clearStudentSelection(),
                            actionLabel: 'Create Order',
                            actionIcon: Icons.send_rounded,
                            actionLoading: state.sendOrderLoading,
                            onAction: state.sendOrderLoading
                                ? null
                                : () => _showCreateOrderDialog(context),
                          ),
                        Expanded(
                          child: _isGridView
                              ? ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 20),
                            itemCount: state.students.length +
                                (state.studentsHasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i < state.students.length) {
                                final s = state.students[i].student;
                                if (s == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 20),
                                  child: Center(
                                    child: SizedBox(
                                      width: 300,
                                      child: StudentIdCardWidget(
                                        student:
                                        _correctionToStudentData(s),
                                        schoolId: widget.schoolId,
                                        schoolDetailsModel:
                                        widget.schoolDetailsModel,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.btnColor,
                                        strokeWidth: 2)),
                              );
                            },
                          )
                              : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.fromLTRB(
                                16, 4, 16, 20),
                            itemCount: state.students.length +
                                (state.studentsHasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i < state.students.length) {
                                final item = state.students[i];
                                final isSelected = state
                                    .selectedStudentIds
                                    .contains(item.id);
                                return _CorrectionStudentCard(
                                  key: ValueKey(item.id),
                                  item: item,
                                  isSelected: isSelected,
                                  imageShape: imageShape,
                                  onToggle: () => context
                                      .read<CorrectionCubit>()
                                      .toggleStudentSelection(
                                      item.id),
                                  onTapCard: () {
                                    final s = item.student;
                                    if (s == null) return;
                                    final studentData =
                                    _correctionToStudentData(s);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MultiBlocProvider(
                                              providers: [
                                                BlocProvider(
                                                  create: (_) =>
                                                  StudentFormCubit()
                                                    ..loadFromSchoolId(
                                                      schoolId: widget
                                                          .schoolId,
                                                      schoolName: '',
                                                    ),
                                                ),
                                                BlocProvider(
                                                  create: (_) =>
                                                  StudentFormDataCubit()
                                                    ..load(widget
                                                        .schoolId),
                                                ),
                                                BlocProvider(
                                                  create: (_) =>
                                                      AddStudentCubit(),
                                                ),
                                              ],
                                              child:
                                              StaffAddStudentFormPage(
                                                schoolId: widget.schoolId,
                                                editStudent: studentData,
                                              ),
                                            ),
                                      ),
                                    ).then((_) {
                                      context
                                          .read<CorrectionCubit>()
                                          .fetchCorrectionStudents(
                                          schoolId:
                                          widget.schoolId);
                                    });
                                  },
                                );
                              }
                              return const Padding(
                                padding: EdgeInsets.symmetric(
                                    vertical: 20),
                                child: Center(
                                    child: CircularProgressIndicator(
                                        color: AppTheme.btnColor,
                                        strokeWidth: 2)),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDownloadDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: ctx.read<CorrectionCubit>(),
        child: _DownloadChecklistDialog(schoolId: widget.schoolId),
      ),
    );
  }

  void _showCreateOrderDialog(BuildContext ctx) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: ctx.read<CorrectionCubit>(),
        child: _CreateOrderDialog(schoolId: widget.schoolId),
      ),
    );
  }

  StudentDetailsData _correctionToStudentData(CorrectionStudentData s) {
    return StudentDetailsData(
      id: s.id,
      uuid: s.uuid,
      schoolId: s.schoolId,
      name: s.name,
      photo: s.photo,
      profilePhotoUrl: s.photoUrl,
      fatherName: s.fatherName,
      fatherPhone: s.fatherPhone,
      motherName: s.motherName,
      motherPhone: s.motherPhone,
      address: s.address,
      dob: s.dob,
      regNo: s.regNo,
      rollNo: s.rollNo,
      admissionNo: s.admissionNo,
      schoolClassId: s.schoolClassId,
      schoolClassSectionId: s.schoolClassSectionId,
      datumClass: s.studentClass != null
          ? Class(
          id: s.studentClass!.id,
          nameWithprefix: s.studentClass!.nameWithPrefix)
          : null,
      section: s.section != null
          ? Section(id: s.section!.id, name: s.section!.name)
          : null,
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(
        size: 14, color: AppTheme.black_Color),
    onChanged: (value) {
      _debounce?.cancel();
      _debounce =
          Timer(const Duration(milliseconds: 500), () {
            final classIds = context
                .read<CorrectionCubit>()
                .state
                .selectedClassIds;
            context
                .read<CorrectionCubit>()
                .fetchCorrectionStudents(
              schoolId: widget.schoolId,
              search: value.trim(),
              classIds: classIds,
            );
          });
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.whiteColor,
      contentPadding: const EdgeInsets.all(12),
      hintText: 'Search by name...',
      prefixIcon: const Icon(Icons.search),
      enabledBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:
        BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      hintStyle: MyStyles.regularText(
        size: 14,
        color: AppTheme.graySubTitleColor,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Correction Student Card
// ---------------------------------------------------------------------------

class _CorrectionStudentCard extends StatefulWidget {
  final CorrectionStudentItem item;
  final bool isSelected;
  final VoidCallback onToggle;
  final VoidCallback? onTapCard;
  final String? imageShape;

  const _CorrectionStudentCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onToggle,
    this.onTapCard,
    this.imageShape,
  });

  @override
  State<_CorrectionStudentCard> createState() =>
      _CorrectionStudentCardState();
}

class _CorrectionStudentCardState
    extends State<_CorrectionStudentCard> {
  String? _currentPhotoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.item.student;
    _currentPhotoUrl = s?.photoUrl ?? s?.photo ?? '';
  }

  @override
  void didUpdateWidget(covariant _CorrectionStudentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      final s = widget.item.student;
      _currentPhotoUrl = s?.photoUrl ?? s?.photo ?? '';
    }
  }

  Future<void> _fromCamera() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (pickedFile != null) {
      File rotatedImage = await FlutterExifRotation.rotateImage(
          path: pickedFile.path);
      await _uploadImage(rotatedImage.path);
    }
  }

  Future<void> _fromGallery() async {
    final pickedFile =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
            title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );
    if (croppedFile != null) {
      await _uploadImage(croppedFile.path);
    }
  }

  Future<void> _uploadImage(String path) async {
    setState(() => _isUploading = true);
    try {
      File fixedImage =
      await FlutterExifRotation.rotateImage(path: path);
      final uuid = widget.item.student?.uuid ?? '';
      var response = await ApiManager().multiRequestRoute(
        fixedImage.path,
        Config.baseUrl + Routes.updateStudentProfile(uuid),
      );
      debugPrint("_uploadImage status: ${response.statusCode}, body: ${response.body}");
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        final newUrl = jsonData['data']?['profile_photo_url'] as String?;
        if (newUrl != null) {
          setState(() => _currentPhotoUrl = newUrl);
        }
      } else {
        debugPrint("Upload failed: ${response.statusCode} ${response.body}");
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    }
    setState(() => _isUploading = false);
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Choose Image",
                style:
                MyStyles.boldText(size: 14, color: Colors.black)),
            const SizedBox(height: 15),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _fromCamera();
              },
              child: Row(children: [
                SvgPicture.asset('assets/icons/camera_single.svg'),
                const SizedBox(width: 10),
                Text("Camera",
                    style: MyStyles.regularText(
                        size: 14, color: Colors.black)),
              ]),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              height: 1,
              color: Colors.grey.shade300,
            ),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                _fromGallery();
              },
              child: Row(children: [
                SvgPicture.asset(
                    'assets/icons/choose_from_gallery.svg'),
                const SizedBox(width: 10),
                Text("Gallery",
                    style: MyStyles.regularText(
                        size: 14, color: Colors.black)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePreview(String imageUrl) {
    final shape = widget.imageShape ?? 'rectangle';
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4,
                    child: _buildShapedPreview(imageUrl, shape),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromCamera();
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text("Camera"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _fromGallery();
                        },
                        icon: const Icon(Icons.photo_library,
                            size: 18),
                        label: const Text("Gallery"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() => _currentPhotoUrl = '');
                        },
                        icon:
                        const Icon(Icons.delete, size: 18),
                        label: const Text("Retake"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.item.student;
    final className = s?.studentClass?.nameWithPrefix ?? '';
    final sectionName = s?.section?.name ?? '';
    final fatherPhone = s?.fatherPhone ?? '';
    final photoUrl = _currentPhotoUrl ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: widget.isSelected,
                  onChanged: (_) => widget.onToggle(),
                  activeColor: AppTheme.btnColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                  side: BorderSide(
                      color: AppTheme.graySubTitleColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.onTapCard?.call(),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (photoUrl.isNotEmpty) {
                        _showImagePreview(photoUrl);
                      } else {
                        Future.delayed(Duration.zero, _fromCamera);
                      }
                    },
                    child: Stack(
                      children: [
                        _buildPhoto(photoUrl),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            height: 22,
                            width: 22,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s?.name ?? '',
                                style: MyStyles.boldText(
                                    size: 16,
                                    color: AppTheme.black_Color),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (className.isNotEmpty) ...[
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  '• $className${sectionName.isNotEmpty ? ' ($sectionName)' : ''}',
                                  style: MyStyles.boldText(
                                      size: 14,
                                      color: AppTheme.btnColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (fatherPhone.isNotEmpty)
                          Row(
                            children: [
                              const Icon(Icons.phone,
                                  size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(fatherPhone,
                                  style: MyStyles.regularText(
                                      size: 12,
                                      color:
                                      AppTheme.graySubTitleColor)),
                            ],
                          ),
                        const SizedBox(height: 2),
                        if ((s?.fatherName ?? '').isNotEmpty)
                          Text('F: ${s!.fatherName}',
                              style: MyStyles.regularText(
                                  size: 12,
                                  color: AppTheme.graySubTitleColor)),
                        if ((s?.motherName ?? '').isNotEmpty)
                          Text('M: ${s!.motherName}',
                              style: MyStyles.regularText(
                                  size: 12,
                                  color: AppTheme.graySubTitleColor)),
                        if ((s?.address ?? '').isNotEmpty)
                          Text(
                            s!.address!,
                            style: MyStyles.regularText(
                                size: 11,
                                color: AppTheme.graySubTitleColor),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapedPreview(String imageUrl, String shape) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: double.infinity,
      fit: BoxFit.contain,
      placeholder: (_, __) => const SizedBox(
          height: 300,
          child: Center(child: CircularProgressIndicator())),
      errorWidget: (_, __, ___) => Container(
        height: 300,
        width: double.infinity,
        color: Colors.grey.shade300,
        child: const Icon(Icons.person, size: 80, color: Colors.grey),
      ),
    );
    switch (shape) {
      case 'round':
      case 'oval':
        return ClipOval(child: imageWidget);
      case 'square':
        return ClipRRect(
            borderRadius: BorderRadius.zero, child: imageWidget);
      case 'rectangle':
      default:
        return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageWidget);
    }
  }

  Widget _placeholder() => Container(
    height: 60,
    width: 60,
    color: Colors.grey.shade200,
    child: const Icon(Icons.person, color: Colors.grey),
  );

  Widget _buildPhoto(String photoUrl) {
    const shape = 'rectangle';
    Widget content;
    if (_isUploading) {
      content = const SizedBox(
        height: 60,
        width: 60,
        child: Center(
            child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (photoUrl.isNotEmpty) {
      content = CachedNetworkImage(
        imageUrl: photoUrl,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      content = _placeholder();
    }

    switch (shape) {
      case 'round':
      case 'oval':
        return ClipOval(
            child: SizedBox(width: 60, height: 60, child: content));
      case 'square':
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: SizedBox(width: 60, height: 60, child: content),
        );
      case 'rectangle':
      default:
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(width: 60, height: 60, child: content),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Create Order Dialog
// ---------------------------------------------------------------------------

class _CreateOrderDialog extends StatefulWidget {
  final String schoolId;
  const _CreateOrderDialog({required this.schoolId});

  @override
  State<_CreateOrderDialog> createState() =>
      _CreateOrderDialogState();
}

class _CreateOrderDialogState extends State<_CreateOrderDialog> {
  static const _cardTypes = [
    {'value': '', 'label': '-Select card Type-'},
    {'value': 'pvc_card', 'label': 'Pvc Card'},
    {'value': 'rfid_card', 'label': 'RFID Card'},
    {'value': 'pasting_card', 'label': 'Pasting card'},
    {'value': 'acrylic_card', 'label': 'Acrylic Card'},
    {'value': 'nfc_card', 'label': 'NFC Card'},
    {'value': 'my_fair_card', 'label': 'My Fair Card'},
  ];

  static const _cardForOptions = [
    {'value': 'student_card', 'label': 'Student Card'},
    {'value': 'parent_card', 'label': 'Parent Card'},
    {'value': 'admit_card', 'label': 'Admit Card'},
  ];

  String _selectedCardType = '';
  final Set<String> _selectedCardFor = {'student_card', 'parent_card'};

  void _toggleCardFor(String value) {
    setState(() {
      if (_selectedCardFor.contains(value)) {
        _selectedCardFor.remove(value);
      } else {
        _selectedCardFor.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CorrectionCubit, CorrectionState>(
      listenWhen: (p, c) =>
      p.sendOrderLoading != c.sendOrderLoading ||
          p.sendOrderSuccess != c.sendOrderSuccess ||
          p.sendOrderError != c.sendOrderError,
      listener: (ctx, state) {
        if (!state.sendOrderLoading && state.sendOrderSuccess) {
          Navigator.of(context).pop();
        }
        if (!state.sendOrderLoading && state.sendOrderError != null) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Create Order',
                      style: MyStyles.boldText(
                          size: 18, color: AppTheme.black_Color)),
                  const Spacer(),
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53)
                        ]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Create Card Order For',
                  style: MyStyles.mediumText(
                      size: 13, color: AppTheme.black_Color)),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding:
                const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCardType,
                    isExpanded: true,
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor),
                    style: MyStyles.regularText(
                        size: 14, color: AppTheme.black_Color),
                    items: _cardTypes
                        .map((t) => DropdownMenuItem<String>(
                      value: t['value']!,
                      child: Text(t['label']!,
                          style: MyStyles.regularText(
                            size: 14,
                            color: t['value']!.isEmpty
                                ? AppTheme.graySubTitleColor
                                : AppTheme.black_Color,
                          )),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedCardType = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ..._cardForOptions.map((opt) {
                final isSelected =
                _selectedCardFor.contains(opt['value']);
                return GestureDetector(
                  onTap: () => _toggleCardFor(opt['value']!),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.btnColor
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.btnColor
                                  : Colors.grey.shade400,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Text(opt['label']!,
                            style: MyStyles.regularText(
                                size: 14,
                                color: AppTheme.black_Color)),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Cancel',
                              style: MyStyles.mediumText(
                                  size: 14, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: state.sendOrderLoading
                        ? null
                        : () {
                      if (_selectedCardType.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: const Text(
                              'Please select a card type'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(12),
                        ));
                        return;
                      }
                      if (_selectedCardFor.isEmpty) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(
                          content: const Text(
                              'Please select at least one card option'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(10)),
                          margin: const EdgeInsets.all(12),
                        ));
                        return;
                      }
                      context
                          .read<CorrectionCubit>()
                          .processOrder(
                        schoolId: widget.schoolId,
                        cardType: _selectedCardType,
                        cardFor: _selectedCardFor.toList(),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: state.sendOrderLoading
                            ? Colors.grey
                            : const Color(0xFF6C63FF),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: state.sendOrderLoading
                          ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                          : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.add_circle_outline,
                              size: 14, color: Colors.white),
                          const SizedBox(width: 6),
                          Text('Create',
                              style: MyStyles.mediumText(
                                  size: 14,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DownloadChecklistDialog extends StatefulWidget {
  final String schoolId;
  const _DownloadChecklistDialog({required this.schoolId});

  @override
  State<_DownloadChecklistDialog> createState() =>
      _DownloadChecklistDialogState();
}

class _DownloadChecklistDialogState
    extends State<_DownloadChecklistDialog> {
  Set<String> _selectedColumns = {};
  String _printType = '';

  List<Map<String, String>> _buildPrintTypes(List<CorrectionItem> items) {
    return [
      {'value': '', 'label': '-Select Print Type-'},
      {'value': 'class_wise', 'label': 'Class Wise'},
      {'value': 'section_wise', 'label': 'Section Wise'},
    ];
  }

  @override
  void initState() {
    super.initState();
    context
        .read<CorrectionCubit>()
        .fetchDownloadColumns(schoolId: widget.schoolId);
  }

  void _toggleColumn(String key) {
    setState(() {
      if (_selectedColumns.contains(key)) {
        _selectedColumns.remove(key);
      } else {
        _selectedColumns.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CorrectionCubit, CorrectionState>(
      listenWhen: (p, c) =>
      p.downloadLoading != c.downloadLoading ||
          p.downloadError != c.downloadError ||
          (p.columnsLoading && !c.columnsLoading),
      listener: (ctx, state) async {
        if (!state.columnsLoading &&
            state.downloadColumns.isNotEmpty &&
            _selectedColumns.isEmpty) {
          setState(() {
            _selectedColumns =
                state.downloadColumns.map((c) => c.key).toSet();
          });
        }

        if (!state.downloadLoading && state.downloadError != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.downloadError!),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(12),
          ));
        }
      },
      builder: (context, state) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Download Checklist',
                      style: MyStyles.boldText(
                          size: 18, color: AppTheme.black_Color)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFFF6B6B),
                          Color(0xFFFF8E53)
                        ]),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Select Data You Want to Display in Correction List',
                style: MyStyles.mediumText(
                    size: 13, color: AppTheme.graySubTitleColor),
              ),
              const SizedBox(height: 16),

              if (state.columnsLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(
                        color: AppTheme.btnColor, strokeWidth: 2),
                  ),
                )
              else if (state.downloadColumns.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('No columns available',
                      style: MyStyles.regularText(
                          size: 13,
                          color: AppTheme.graySubTitleColor)),
                )
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 3.2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 4,
                  children: state.downloadColumns.map((col) {
                    final isSelected =
                    _selectedColumns.contains(col.key);
                    return GestureDetector(
                      onTap: () => _toggleColumn(col.key),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.btnColor
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.btnColor
                                    : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check,
                                size: 13, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(col.label,
                                style: MyStyles.regularText(
                                    size: 12,
                                    color: AppTheme.black_Color),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),
              Text('Print List Type *',
                  style: MyStyles.mediumText(
                      size: 13, color: AppTheme.black_Color)),
              const SizedBox(height: 8),
              Container(
                height: 48,
                padding:
                const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _printType,
                    isExpanded: true,
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor),
                    style: MyStyles.regularText(
                        size: 14, color: AppTheme.black_Color),
                    items: _buildPrintTypes(state.items)
                        .map((t) => DropdownMenuItem<String>(
                      value: t['value']!,
                      child: Text(t['label']!),
                    ))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _printType = v ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              BlocBuilder<CorrectionCubit, CorrectionState>(
                buildWhen: (p, c) =>
                p.downloadLoading != c.downloadLoading,
                builder: (ctx, state) => Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: state.downloadLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Text('Cancel',
                            style: MyStyles.mediumText(
                                size: 14, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: state.downloadLoading
                          ? null
                          : () async {
                        if (_printType.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Please select a Print List Type'),
                            backgroundColor: Colors.orange,
                          ));
                          return;
                        }
                        if (_selectedColumns.isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Please select at least one column'),
                            backgroundColor: Colors.orange,
                          ));
                          return;
                        }

                        final pdfBytes = await context
                            .read<CorrectionCubit>()
                            .downloadCorrectionList(
                          schoolId: widget.schoolId,
                          selected: _selectedColumns.toList(),
                          listType: _printType,
                        );

                        if (pdfBytes != null && pdfBytes.isNotEmpty) {
                          await Printing.layoutPdf(
                            onLayout: (PdfPageFormat format) async => pdfBytes,
                            name: 'Correction_List_${DateTime.now().millisecondsSinceEpoch}',
                          );
                          if (mounted) Navigator.of(context).pop();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: state.downloadLoading
                              ? Colors.grey
                              : const Color(0xFF6C63FF),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: state.downloadLoading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white),
                        )
                            : Text('Print Now',
                            style: MyStyles.mediumText(
                                size: 14, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _StaffOrdersTab extends StatefulWidget {
  final String schoolId;
  const _StaffOrdersTab({required this.schoolId});

  @override
  State<_StaffOrdersTab> createState() => _StaffOrdersTabState();
}

class _StaffOrdersTabState extends State<_StaffOrdersTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _dateFromCtrl = TextEditingController();
  final TextEditingController _dateToCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  Timer? _debounce;

  String _selectedStatus = '';
  String _selectedClass = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<OrdersCubit>().fetchSchoolOrders(
          isLoadMore: true,
          search: _searchCtrl.text.trim(),
          status: _selectedStatus,
          classFilter: _selectedClass,
          schoolId: widget.schoolId,
          dateFrom: _dateFromCtrl.text,
          dateTo: _dateToCtrl.text,
        );
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _dateFromCtrl.dispose();
    _dateToCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _resetAndFetch() {
    context.read<OrdersCubit>().fetchSchoolOrders(
      search: _searchCtrl.text.trim(),
      status: _selectedStatus,
      classFilter: _selectedClass,
      schoolId: widget.schoolId,
      dateFrom: _dateFromCtrl.text,
      dateTo: _dateToCtrl.text,
    );
  }

  bool get _hasActiveFilters =>
      _selectedStatus.isNotEmpty ||
          _selectedClass.isNotEmpty ||
          _dateFromCtrl.text.isNotEmpty ||
          _dateToCtrl.text.isNotEmpty;

  void _clearFilters() {
    setState(() {
      _selectedStatus = '';
      _selectedClass = '';
      _dateFromCtrl.clear();
      _dateToCtrl.clear();
    });
    _resetAndFetch();
  }

  Future<void> _showChangeStatusDialog(
      BuildContext ctx,
      List<String> uuids,
      ) async {
    String? selectedStatus;
    String issueNote = '';
    bool confirming = false;

    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Change Order Status',
                        style: MyStyles.boldText(size: 18, color: AppTheme.black_Color),
                      ),
                    ),
                    GestureDetector(
                      onTap: confirming ? null : () => Navigator.pop(dialogCtx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Select new status',
                    style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedStatus != null ? AppTheme.btnColor : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      hint: Text('-- Select Status --',
                          style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppTheme.graySubTitleColor),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text('-- Select Status --',
                              style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor)),
                        ),
                        DropdownMenuItem<String>(
                          value: 'delivery_verified',
                          child: Text('Delivery Verified',
                              style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                        ),
                        DropdownMenuItem<String>(
                          value: 'printing_issue',
                          child: Text('Printing Issue',
                              style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                        ),
                      ],
                      onChanged: confirming
                          ? null
                          : (v) => setDialogState(() => selectedStatus = v),
                    ),
                  ),
                ),
                if (selectedStatus == 'printing_issue') ...[
                  const SizedBox(height: 12),
                  TextField(
                    style: MyStyles.regularText(size: 13, color: AppTheme.black_Color),
                    onChanged: (v) => issueNote = v,
                    decoration: InputDecoration(
                      hintText: 'Issue note (e.g. Card photo blur)',
                      hintStyle: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(color: AppTheme.btnColor),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: confirming ? null : () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        backgroundColor: AppTheme.lightRedColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: Text('Cancel',
                          style: MyStyles.mediumText(size: 13, color: AppTheme.cancelTextColor)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: (selectedStatus == null || confirming)
                          ? null
                          : () async {
                        setDialogState(() => confirming = true);
                        final success =
                        await ctx.read<OrdersCubit>().bulkUpdateOrderStatus(
                          schoolId: widget.schoolId,
                          uuids: uuids,
                          status: selectedStatus!,
                          issueNote: issueNote,
                        );
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (ctx.mounted) {
                          ctx.read<OrdersCubit>().clearOrderSelection();
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Status updated successfully'
                                  : 'Failed to update status'),
                              backgroundColor: success ? AppTheme.btnColor : Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(12),
                            ),
                          );
                          if (success) _resetAndFetch();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      ),
                      child: confirming
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                          : Text('Confirm',
                          style: MyStyles.mediumText(size: 13, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<OrdersCubit, OrdersState>(
          buildWhen: (p, c) => p.total != c.total,
          builder: (_, s) =>
              _StaffCountRow(total: s.total, label: 'Total Orders'),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: _searchBar(),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            children: [
              const Divider(height: 1, color: AppTheme.LineColor),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _classDropdown()),
                  const SizedBox(width: 8),
                  Expanded(child: _statusDropdown()),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                      child: _dateField(
                          _dateFromCtrl, 'From dd-mm-yyyy')),
                  const SizedBox(width: 8),
                  Expanded(
                      child:
                      _dateField(_dateToCtrl, 'To dd-mm-yyyy')),
                ],
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _clearFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.lightRedColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close,
                              size: 12,
                              color: AppTheme.cancelTextColor),
                          const SizedBox(width: 4),
                          Text('Clear Filters',
                              style: MyStyles.mediumText(
                                  size: 11,
                                  color: AppTheme.cancelTextColor)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<OrdersCubit, OrdersState>(
            builder: (_, state) {
              if (state.loading && state.ordersList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: OrderListShimmer(),
                );
              }
              if (state.error != null && state.ordersList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(state.error!,
                          style: MyStyles.regularText(
                              size: 14, color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _resetAndFetch,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (state.ordersList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/no_data.png',
                          height: 160),
                      const SizedBox(height: 12),
                      Text('No orders found',
                          style: MyStyles.mediumText(
                              size: 14,
                              color: AppTheme.graySubTitleColor)),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text('Clear filters',
                              style: MyStyles.mediumText(
                                  size: 13,
                                  color: AppTheme.btnColor)),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: AppTheme.btnColor,
                onRefresh: () async => _resetAndFetch(),
                child: Column(
                  children: [
                    if (state.selectedOrderUuids.isNotEmpty)
                      _StaffSelectionToolbar(
                        selectedCount: state.selectedOrderUuids.length,
                        onSelectAll: () => context
                            .read<OrdersCubit>()
                            .selectAllOrders(),
                        onClear: () => context
                            .read<OrdersCubit>()
                            .clearOrderSelection(),
                        actionLabel: 'Change Status',
                        onAction: () => _showChangeStatusDialog(
                          context,
                          state.selectedOrderUuids.toList(),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding:
                        const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: state.ordersList.length +
                            (state.hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i < state.ordersList.length) {
                            final order = state.ordersList[i];
                            final isSelected = state.selectedOrderUuids
                                .contains(order.uuid);
                            return _StaffOrderCard(
                              order: order,
                              schoolId: widget.schoolId,
                              isSelected: isSelected,
                              onToggle: () => context
                                  .read<OrdersCubit>()
                                  .toggleOrderSelection(order.uuid),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                                child: CircularProgressIndicator(
                                    color: AppTheme.btnColor,
                                    strokeWidth: 2)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(
        size: 14, color: AppTheme.black_Color),
    onChanged: (_) {
      _debounce?.cancel();
      _debounce = Timer(
          const Duration(milliseconds: 500), _resetAndFetch);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.appBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      hintText: 'Search by student name, order ID...',
      prefixIcon: const Icon(Icons.search_rounded,
          size: 20, color: AppTheme.graySubTitleColor),
      suffixIcon: _searchCtrl.text.isNotEmpty
          ? GestureDetector(
        onTap: () {
          _searchCtrl.clear();
          setState(() {});
          _resetAndFetch();
        },
        child: const Icon(Icons.close,
            size: 16,
            color: AppTheme.graySubTitleColor),
      )
          : null,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
            color: AppTheme.backBtnBgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide:
        const BorderSide(color: AppTheme.btnColor),
        borderRadius: BorderRadius.circular(12),
      ),
      hintStyle: MyStyles.regularText(
          size: 13, color: AppTheme.graySubTitleColor),
    ),
  );

  Widget _classDropdown() =>
      BlocBuilder<OrdersCubit, OrdersState>(
        buildWhen: (p, c) =>
        p.schoolClassesWithSections != c.schoolClassesWithSections ||
            p.loading != c.loading,
        builder: (_, state) => _dropdown(
          value: _selectedClass.isEmpty ? '' : _selectedClass,
          hint: 'All Classes',
          items: [
            const DropdownMenuItem(
                value: '', child: Text('All Classes')),
            ...state.schoolClassesWithSections.map(
                  (c) => DropdownMenuItem(
                value: c.value,
                child: Text(
                  c.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: (v) {
            setState(() => _selectedClass = v ?? '');
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _resetAndFetch());
          },
        ),
      );

  Widget _statusDropdown() => _dropdown(
    value: _selectedStatus,
    hint: 'All Status',
    items: kOrderFilterStatuses
        .map(
          (s) => DropdownMenuItem<String>(
        value: s.value,
        child: Text(s.label,
            overflow: TextOverflow.ellipsis),
      ),
    )
        .toList(),
    onChanged: (v) {
      setState(() => _selectedStatus = v ?? '');
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _resetAndFetch());
    },
  );

  Widget _dropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool loading = false,
  }) =>
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: AppTheme.appBackgroundColor,
          border: Border.all(
              color: AppTheme.backBtnBgColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            menuMaxHeight: 300,
            icon: loading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.btnColor),
            )
                : const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppTheme.graySubTitleColor),
            style: MyStyles.regularText(
                size: 13, color: AppTheme.black_Color),
            items: items,
            onChanged: onChanged,
          ),
        ),
      );

  Widget _dateField(
      TextEditingController ctrl, String hint) {
    return StatefulBuilder(
      builder: (context, setLocal) => AppTextField(
        controller: ctrl,
        hintText: hint,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(r'[\d.\-/]')),
          LengthLimitingTextInputFormatter(10),
          _StaffDotDateFormatter(),
        ],
        suffixIcon: ctrl.text.isNotEmpty
            ? GestureDetector(
          onTap: () {
            ctrl.clear();
            setLocal(() {});
            _debounce?.cancel();
            _debounce = Timer(
                const Duration(milliseconds: 200),
                _resetAndFetch);
          },
          child:
          const Icon(Icons.close, size: 16),
        )
            : null,
        onChanged: (_) {
          setLocal(() {});
          if (ctrl.text.length == 10 ||
              ctrl.text.isEmpty) {
            _debounce?.cancel();
            _debounce = Timer(
                const Duration(milliseconds: 400),
                _resetAndFetch);
          }
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Order Card
// ---------------------------------------------------------------------------

class _StaffOrderCard extends StatefulWidget {
  final OrderModel order;
  final String schoolId;
  final bool isSelected;
  final VoidCallback? onToggle;

  const _StaffOrderCard({
    required this.order,
    this.schoolId = '',
    this.isSelected = false,
    this.onToggle,
  });

  @override
  State<_StaffOrderCard> createState() =>
      _StaffOrderCardState();
}

class _StaffOrderCardState extends State<_StaffOrderCard> {
  late String _currentStatus;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.order.status;
  }

  Color get _statusColor {
    switch (_currentStatus) {
      case 'completed':
        return const Color(0xFF2DC24E);
      case 'cancelled':
        return AppTheme.cancelTextColor;
      case 'work_in_process':
        return AppTheme.btnColor;
      case 're_order':
        return AppTheme.PendingDotColor;
      default:
        return AppTheme.graySubTitleColor;
    }
  }

  Color get _statusBg {
    switch (_currentStatus) {
      case 'completed':
        return const Color(0xFFE8F9ED);
      case 'cancelled':
        return AppTheme.lightRedColor;
      case 'work_in_process':
        return AppTheme.lightBlueColor;
      case 're_order':
        return AppTheme.PendingLightColor;
      default:
        return AppTheme.appBackgroundColor;
    }
  }

  String get _statusLabel => kOrderStatuses
      .firstWhere(
        (s) => s.value == _currentStatus,
    orElse: () => OrderStatusOption(
      _currentStatus,
      _currentStatus.replaceAll('_', ' '),
    ),
  )
      .label;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    final success =
    await context.read<OrdersCubit>().updateOrderStatus(
      widget.order.uuid,
      newStatus,
    );
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (success) _currentStatus = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Status updated successfully'
            : 'Failed to update status'),
        backgroundColor:
        success ? AppTheme.btnColor : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.order.student;
    final school = widget.order.school;

    return GestureDetector(
       onTap: (){},
      // => Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (_) => StaffOrderDetailPage(
      //       uuid: widget.order.uuid,
      //       schoolId: widget.schoolId,
      //     ),
      //   ),
      // ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Checkbox ──
            Padding(
              padding: const EdgeInsets.only(top: 18, right: 10),
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.btnColor
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: widget.isSelected
                          ? AppTheme.btnColor
                          : Colors.grey.shade400,
                      width: 1.5,
                    ),
                  ),
                  child: widget.isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (student?.profilePhotoUrl != null &&
                  student!.profilePhotoUrl!.isNotEmpty)
                  ? CachedNetworkImage(
                imageUrl: student.profilePhotoUrl!,
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                placeholder: (_, __) => _placeholder(),
                errorWidget: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          student?.name ?? '-',
                          style: MyStyles.boldText(
                              size: 14,
                              color: AppTheme.black_Color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (student?.className != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            '• ${student!.className!}',
                            style: MyStyles.boldText(
                                size: 12,
                                color: AppTheme.btnColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (school?.name != null)
                    Text(
                      school!.name,
                      style: MyStyles.regularText(
                          size: 10,
                          color: AppTheme.graySubTitleColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusBg,
                          borderRadius:
                          BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(_statusLabel,
                                style: MyStyles.mediumText(
                                    size: 8,
                                    color: _statusColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 10,
                              color: AppTheme.graySubTitleColor),
                          const SizedBox(width: 3),
                          Text(widget.order.formattedOrderedAt,
                              style: MyStyles.regularText(
                                  size: 10,
                                  color: AppTheme.graySubTitleColor)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _updating
                ? const Padding(
              padding: EdgeInsets.all(4),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.btnColor),
              ),
            )
                : PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: Colors.grey),
              offset: const Offset(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
              onSelected: _updateStatus,
              itemBuilder: (_) =>
                  _buildStatusMenuItems(),
            ),
          ],
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _buildStatusMenuItems() {
    return kOrderStatuses
        .where((s) => s.value != _currentStatus)
        .map((s) => PopupMenuItem<String>(
      value: s.value,
      child: Row(
        children: [
          Icon(_statusIcon(s.value),
              size: 16,
              color: AppTheme.graySubTitleColor),
          const SizedBox(width: 10),
          Text(s.label),
        ],
      ),
    ))
        .toList();
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 're_order':
        return Icons.refresh_rounded;
      case 'work_in_process':
        return Icons.hourglass_top_rounded;
      case 'order_created':
        return Icons.add_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _placeholder() => Container(
    height: 60,
    width: 60,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, color: Colors.grey),
  );
}


class _StaffDotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final text = newValue.text
        .replaceAll('/', '-')
        .replaceAll('.', '-');
    return newValue.copyWith(
      text: text,
      selection:
      TextSelection.collapsed(offset: text.length),
    );
  }
}


class _StaffStudentsProcessChecklistDialog extends StatefulWidget {
  final String schoolId;
  final List<String> studentUuids;
  final VoidCallback? onSuccess;

  const _StaffStudentsProcessChecklistDialog({
    required this.schoolId,
    required this.studentUuids,
    this.onSuccess,
  });

  @override
  State<_StaffStudentsProcessChecklistDialog> createState() =>
      _StaffStudentsProcessChecklistDialogState();
}

class _StaffStudentsProcessChecklistDialogState
    extends State<_StaffStudentsProcessChecklistDialog> {


  static const _listTypes = [
    {'value': '', 'label': '- Select List Type -'},

    {
      'value': 'class_wise',
      'label': 'Class Wise',
    },

    {
      'value': 'section_wise',
      'label': 'Section Wise',
    },
  ];


  static const _processTypes = [
    {'value': '', 'label': '- Select Process Type -'},

    {
      'value': 'create',
      'label': 'Create Correction List',
    },
  ];

  String _selectedListType = '';
  String _selectedProcessType = '';

  @override
  Widget build(BuildContext context) {

    return BlocConsumer<CorrectionCubit, CorrectionState>(

      listenWhen: (p, c) =>
      p.sendOrderLoading != c.sendOrderLoading ||
          p.sendOrderSuccess != c.sendOrderSuccess ||
          p.sendOrderError != c.sendOrderError,

      listener: (ctx, state) {

        print("=========== LISTENER ===========");
        print("Loading => ${state.sendOrderLoading}");
        print("Success => ${state.sendOrderSuccess}");
        print("Error => ${state.sendOrderError}");
        print("Message => ${state.sendOrderMessage}");

        /// SUCCESS
        if (!state.sendOrderLoading &&
            state.sendOrderSuccess) {

          Navigator.of(context).pop();

          widget.onSuccess?.call();

          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                state.sendOrderMessage ??
                    'Correction list created successfully!',
              ),

              backgroundColor: AppTheme.btnColor,

              behavior: SnackBarBehavior.floating,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),

              margin: const EdgeInsets.all(12),
            ),
          );
        }

        /// ERROR
        if (!state.sendOrderLoading &&
            state.sendOrderError != null) {

          final isAlready = state.sendOrderError!
              .toLowerCase()
              .contains('already processed');

          if (!isAlready) {
            Navigator.of(context).pop();
          }

          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.sendOrderError!),

              backgroundColor:
              isAlready ? Colors.orange : Colors.red,

              behavior: SnackBarBehavior.floating,

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),

              margin: const EdgeInsets.all(12),
            ),
          );
        }
      },

      builder: (context, state) {

        return Dialog(

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          backgroundColor: Colors.white,

          child: Padding(
            padding: const EdgeInsets.all(20),

            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                /// =========================
                /// HEADER
                /// =========================
                Row(
                  children: [

                    Text(
                      'Process Checklist Or Orders',

                      style: MyStyles.boldText(
                        size: 16,
                        color: AppTheme.black_Color,
                      ),
                    ),

                    const Spacer(),

                    GestureDetector(

                      onTap: state.sendOrderLoading
                          ? null
                          : () => Navigator.of(context).pop(),

                      child: Container(
                        width: 32,
                        height: 32,

                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF6B6B),
                              Color(0xFFFF8E53),
                            ],
                          ),

                          borderRadius:
                          BorderRadius.circular(8),
                        ),

                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),

                const Divider(height: 24),

                /// =========================
                /// LIST TYPE
                /// =========================
                Text(
                  'List Type',

                  style: MyStyles.mediumText(
                    size: 13,
                    color: AppTheme.black_Color,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 48,

                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedListType.isNotEmpty
                          ? AppTheme.btnColor
                          : Colors.grey.shade300,

                      width:
                      _selectedListType.isNotEmpty
                          ? 1.5
                          : 1,
                    ),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: DropdownButtonHideUnderline(

                    child: DropdownButton<String>(

                      value: _selectedListType,

                      isExpanded: true,

                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor,
                      ),

                      style: MyStyles.regularText(
                        size: 14,
                        color: AppTheme.black_Color,
                      ),

                      items: _listTypes
                          .map(
                            (t) => DropdownMenuItem<String>(

                          value: t['value']!,

                          child: Text(
                            t['label']!,

                            style: MyStyles.regularText(
                              size: 14,

                              color: t['value']!.isEmpty
                                  ? AppTheme.graySubTitleColor
                                  : AppTheme.black_Color,
                            ),
                          ),
                        ),
                      )
                          .toList(),

                      onChanged: (v) {

                        print("Selected List Type => $v");

                        setState(() {
                          _selectedListType = v ?? '';
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// =========================
                /// PROCESS TYPE
                /// =========================
                Text(
                  'Select Process Type',

                  style: MyStyles.mediumText(
                    size: 13,
                    color: AppTheme.black_Color,
                  ),
                ),

                const SizedBox(height: 8),

                Container(
                  height: 48,

                  padding:
                  const EdgeInsets.symmetric(horizontal: 12),

                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _selectedProcessType.isNotEmpty
                          ? AppTheme.btnColor
                          : Colors.grey.shade300,

                      width:
                      _selectedProcessType.isNotEmpty
                          ? 1.5
                          : 1,
                    ),

                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: DropdownButtonHideUnderline(

                    child: DropdownButton<String>(

                      value: _selectedProcessType,

                      isExpanded: true,

                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.graySubTitleColor,
                      ),

                      style: MyStyles.regularText(
                        size: 14,
                        color: AppTheme.black_Color,
                      ),

                      items: _processTypes
                          .map(
                            (t) => DropdownMenuItem<String>(

                          value: t['value']!,

                          child: Text(
                            t['label']!,

                            style: MyStyles.regularText(
                              size: 14,

                              color: t['value']!.isEmpty
                                  ? AppTheme.graySubTitleColor
                                  : AppTheme.black_Color,
                            ),
                          ),
                        ),
                      )
                          .toList(),

                      onChanged: (v) {

                        print("Selected Process Type => $v");

                        setState(() {
                          _selectedProcessType = v ?? '';
                        });
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// =========================
                /// BUTTONS
                /// =========================
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,

                  children: [

                    /// CANCEL BUTTON
                    GestureDetector(

                      onTap: state.sendOrderLoading
                          ? null
                          : () => Navigator.of(context).pop(),

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),

                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B),

                          borderRadius:
                          BorderRadius.circular(25),
                        ),

                        child: Text(
                          'Cancel',

                          style: MyStyles.mediumText(
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    /// CONFIRM BUTTON
                    GestureDetector(

                      onTap: state.sendOrderLoading
                          ? null
                          : () async {

                        print("=========== PROCESS ORDER ===========");

                        print("schoolId => ${widget.schoolId}");

                        print("studentUuids => ${widget.studentUuids}");

                        print("processType => $_selectedProcessType");

                        print("listType => $_selectedListType");

                        /// NO STUDENT
                        if (widget.studentUuids.isEmpty) {

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: const Text(
                                'No students selected',
                              ),

                              backgroundColor: Colors.red,

                              behavior:
                              SnackBarBehavior.floating,

                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),

                              margin:
                              const EdgeInsets.all(12),
                            ),
                          );

                          return;
                        }

                        /// NO LIST TYPE
                        if (_selectedListType.isEmpty) {

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Please select a list type',
                              ),

                              backgroundColor: Colors.orange,

                              behavior:
                              SnackBarBehavior.floating,

                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),

                              margin:
                              const EdgeInsets.all(12),
                            ),
                          );

                          return;
                        }

                        /// NO PROCESS TYPE
                        if (_selectedProcessType.isEmpty) {

                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Please select a process type',
                              ),

                              backgroundColor: Colors.orange,

                              behavior:
                              SnackBarBehavior.floating,

                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),

                              margin:
                              const EdgeInsets.all(12),
                            ),
                          );

                          return;
                        }

                        /// API CALL
                        await context
                            .read<CorrectionCubit>()
                            .processOrder(

                          schoolId: widget.schoolId,

                          processType:
                          _selectedProcessType,

                          listType:
                          _selectedListType,

                          studentUuids:
                          widget.studentUuids,
                        );
                      },

                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 11,
                        ),

                        decoration: BoxDecoration(
                          color: state.sendOrderLoading
                              ? Colors.grey
                              : AppTheme.btnColor,

                          borderRadius:
                          BorderRadius.circular(25),
                        ),

                        child: state.sendOrderLoading

                            ? const SizedBox(
                          width: 18,
                          height: 18,

                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )

                            : Text(
                          'Confirm',

                          style: MyStyles.mediumText(
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}