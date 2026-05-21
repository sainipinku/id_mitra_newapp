import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/attendance/AttendanceModel.dart';
import 'package:idmitra/providers/attendance/attendance_cubit.dart';
import 'package:idmitra/providers/attendance/attendance_state.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';

class AttendanceScreen extends StatelessWidget {
  final String schoolId;
  final bool todayOnly;
  final bool presentOnly;
  final List<int> allowedClassIds;

  const AttendanceScreen({
    super.key,
    required this.schoolId,
    this.todayOnly = false,
    this.presentOnly = false,
    this.allowedClassIds = const [],
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AttendanceCubit()
        ..fetchAttendance(
          schoolId: schoolId,
          date: todayOnly ? _todayStr() : null,
        ),
      child: _AttendanceView(
        schoolId: schoolId,
        todayOnly: todayOnly,
        presentOnly: presentOnly,
        allowedClassIds: allowedClassIds,
      ),
    );
  }

  static String _todayStr() {
    final t = DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}

class _AttendanceView extends StatefulWidget {
  final String schoolId;
  final bool todayOnly;
  final bool presentOnly;
  final List<int> allowedClassIds;
  const _AttendanceView({
    required this.schoolId,
    this.todayOnly = false,
    this.presentOnly = false,
    this.allowedClassIds = const [],
  });

  @override
  State<_AttendanceView> createState() => _AttendanceViewState();
}

class _AttendanceViewState extends State<_AttendanceView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.presentOnly ? 1 : 3,
      vsync: this,
    );
    _tabController.addListener(() => setState(() {}));

    if (widget.allowedClassIds.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final cubit = context.read<AttendanceCubit>();
        final state = cubit.state;
        if (!state.loading && state.classes.isNotEmpty) {
          _autoSelectFirstAllowedClass(cubit, state);
        }
      });
    }
  }

  void _autoSelectFirstAllowedClass(AttendanceCubit cubit, AttendanceState state) {
    if (widget.allowedClassIds.isEmpty) return;
    final filtered = state.classes
        .where((c) => widget.allowedClassIds.contains(c.id))
        .toList();
    if (filtered.isEmpty) return;
    final first = filtered.first;
    if (state.selectedClass?.id != first.id) {
      cubit.selectClassAndFetch(
        schoolId: widget.schoolId,
        cls: first,
        date: AttendanceScreen._todayStr(),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<AttendanceStudent> _filter(List<AttendanceStudent> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list
        .where((s) =>
    s.name.toLowerCase().contains(q) ||
        (s.rollNo?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceCubit, AttendanceState>(
      listener: (context, state) {
        if (!state.loading &&
            state.classes.isNotEmpty &&
            state.selectedClass == null &&
            widget.allowedClassIds.isNotEmpty) {
          _autoSelectFirstAllowedClass(
              context.read<AttendanceCubit>(), state);
        }
      },
      builder: (context, state) {
        final students = state.students;
        final stats    = state.stats;
        final present  = students.where((s) => s.isPresent).toList();
        final absent   = students.where((s) => s.isAbsent).toList();

        final displayList = widget.presentOnly ? present : students;

        final currentList = widget.presentOnly
            ? _filter(present)
            : _tabController.index == 0
            ? _filter(students)
            : _tabController.index == 1
            ? _filter(present)
            : _filter(absent);

        final allSelected = currentList.isNotEmpty &&
            currentList.every((s) => state.selectedStudentIds.contains(s.id));

        return Scaffold(
          backgroundColor: AppTheme.appBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: state.bulkMode
                ? IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () =>
                  context.read<AttendanceCubit>().toggleBulkMode(),
            )
                : Padding(
              padding: const EdgeInsets.all(10),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.titleHintColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.black87),
                  ),
                ),
              ),
            ),
            centerTitle: true,
            title: state.bulkMode
                ? Text(
              '${state.selectedStudentIds.length} Selected',
              style: MyStyles.boldText(size: 18, color: Colors.black),
            )
                : Text('Attendance',
                style: MyStyles.boldText(size: 20, color: Colors.black)),
            actions: [
              if (state.bulkMode) ...[
                // Select all toggle
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => context
                        .read<AttendanceCubit>()
                        .selectAllStudents(currentList),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: allSelected
                            ? AppTheme.btnColor.withOpacity(0.1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.btnColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            allSelected
                                ? Icons.deselect_rounded
                                : Icons.select_all_rounded,
                            size: 16,
                            color: AppTheme.btnColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            allSelected ? 'Deselect' : 'Select All',
                            style: MyStyles.mediumText(
                                size: 12, color: AppTheme.btnColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                TextButton(
                  onPressed: () =>
                      context.read<AttendanceCubit>().toggleBulkMode(),
                  child: Text('Bulk',
                      style: MyStyles.mediumText(
                          size: 13, color: AppTheme.btnColor)),
                ),
              ],
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: AppTheme.btnColor,
              unselectedLabelColor: AppTheme.graySubTitleColor,
              indicatorColor: AppTheme.btnColor,
              indicatorWeight: 2.5,
              labelStyle: MyStyles.mediumText(size: 13, color: Colors.white),
              unselectedLabelStyle:
              MyStyles.regularText(size: 13, color: Colors.white),
              tabs: widget.presentOnly
                  ? [Tab(text: 'Present (${stats.present})')]
                  : [
                Tab(text: 'All (${stats.total})'),
                Tab(text: 'Present (${stats.present})'),
                Tab(text: 'Absent (${stats.absent})'),
              ],
            ),
          ),
          bottomNavigationBar: state.bulkMode
              ? _bulkBottomBar(context, state)
              : null,
          body: state.loading
              ? Column(
            children: [
              const AttendanceStatsShimmer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: shimmerBox(height: 48, radius: 15),
                    ),
                    const SizedBox(width: 8),
                    shimmerBox(width: 100, height: 48, radius: 12),
                  ],
                ),
              ),
              const AttendanceCardShimmer(),
            ],
          )
              : Column(
            children: [
              if (state.error != null)
                _errorBanner(context, state.error!)
              else if (state.selectedClass == null &&
                  state.classes.isEmpty)
                Expanded(child: _emptyClasses())
              else ...[
                //  _statsRow(stats),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Expanded(child: _searchBar()),
                        const SizedBox(width: 8),
                        _classDropdown(context, state),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: widget.presentOnly
                          ? [
                        _list(_filter(present), context, state),
                      ]
                          : [
                        _list(_filter(students), context, state),
                        _list(_filter(present), context, state),
                        _list(_filter(absent), context, state),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        );
      },
    );
  }

  Widget _bulkBottomBar(BuildContext context, AttendanceState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -3)),
        ],
      ),
      child: state.bulkSubmitting
          ? const AttendanceBulkBottomShimmer()
          : Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: state.selectedStudentIds.isEmpty
                  ? null
                  : () => context
                  .read<AttendanceCubit>()
                  .bulkMarkAttendance(
                schoolId: widget.schoolId,
                status: 'absent',
              ),
              icon: const Icon(Icons.cancel_outlined,
                  color: Colors.red, size: 18),
              label: Text('Mark Absent',
                  style: MyStyles.mediumText(
                      size: 13, color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: state.selectedStudentIds.isEmpty
                  ? null
                  : () => context
                  .read<AttendanceCubit>()
                  .bulkMarkAttendance(
                schoolId: widget.schoolId,
                status: 'present',
              ),
              icon: const Icon(Icons.check_circle_outline,
                  color: Colors.white, size: 18),
              label: Text('Mark Present',
                  style: MyStyles.mediumText(
                      size: 13, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
    onChanged: (v) => setState(() => _searchQuery = v),
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.whiteColor,
      contentPadding: const EdgeInsets.all(12),
      hintText: 'Search by name or roll no...',
      prefixIcon: const Icon(Icons.search),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      hintStyle: MyStyles.regularText(
          size: 14, color: AppTheme.graySubTitleColor),
    ),
  );

  Widget _classDropdown(BuildContext context, AttendanceState state) {
    final filteredClasses = widget.allowedClassIds.isEmpty
        ? state.classes
        : state.classes
        .where((c) => widget.allowedClassIds.contains(c.id))
        .toList();

    if (filteredClasses.isEmpty) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.backBtnBgColor),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Center(
          child: Text('No class',
              style: MyStyles.regularText(
                  size: 12, color: AppTheme.graySubTitleColor)),
        ),
      );
    }

    final selectedClass = state.selectedClass != null &&
        filteredClasses.any((c) => c.id == state.selectedClass!.id)
        ? state.selectedClass
        : null;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AttendanceClassItem>(
          value: selectedClass,
          hint: Text('Class',
              style: MyStyles.regularText(
                  size: 12, color: AppTheme.graySubTitleColor)),
          icon: Icon(Icons.arrow_drop_down,
              color: AppTheme.graySubTitleColor, size: 20),
          items: filteredClasses
              .map((c) => DropdownMenuItem(
            value: c,
            child: Text(c.displayName,
                style: MyStyles.regularText(
                    size: 13, color: AppTheme.black_Color)),
          ))
              .toList(),
          onChanged: (val) {
            if (val == null) return;
            final date = widget.todayOnly
                ? AttendanceScreen._todayStr()
                : (context.read<AttendanceCubit>().state.selectedDate.isNotEmpty
                ? context.read<AttendanceCubit>().state.selectedDate
                : AttendanceScreen._todayStr());
            context.read<AttendanceCubit>().selectClassAndFetch(
              schoolId: widget.schoolId,
              cls: val,
              date: date,
            );
          },
        ),
      ),
    );
  }

  // Widget _statsRow(AttendanceStats stats) {
  //   return Container(
  //     color: Colors.white,
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  //     child: Row(
  //       children: [
  //         _statChip('Total', stats.total, AppTheme.btnColor),
  //         _statChip('Present', stats.present, Colors.green),
  //         _statChip('Absent', stats.absent, Colors.red),
  //         _statChip('Late', stats.late, Colors.orange),
  //         _statChip('Leave', stats.leave, Colors.blue),
  //       ],
  //     ),
  //   );
  // }
  //
  // Widget _statChip(String label, int count, Color color) {
  //   return Expanded(
  //     child: Column(
  //       children: [
  //         Text('$count', style: MyStyles.boldText(size: 16, color: color)),
  //         Text(label,
  //             style: MyStyles.regularText(
  //                 size: 10, color: AppTheme.graySubTitleColor)),
  //       ],
  //     ),
  //   );
  // }

  Widget _errorBanner(BuildContext context, String error) {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(error,
                  style: MyStyles.regularText(
                      size: 14, color: AppTheme.graySubTitleColor),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context
                    .read<AttendanceCubit>()
                    .fetchAttendance(schoolId: widget.schoolId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyClasses() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.class_outlined,
              size: 60,
              color: AppTheme.graySubTitleColor.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text('No classes found',
              style: MyStyles.regularText(
                  size: 14, color: AppTheme.graySubTitleColor)),
        ],
      ),
    );
  }

  Widget _list(
      List<AttendanceStudent> list, BuildContext context, AttendanceState state) {
    if (list.isEmpty) {
      return Center(
          child: Image.asset('assets/images/no_data.png', height: 200));
    }
    final isAllTab = !widget.presentOnly && _tabController.index == 0;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(list[i], context, state, isAllTab),
    );
  }

  Widget _card(
      AttendanceStudent s, BuildContext context, AttendanceState state, bool showToggle) {
    final bool isPresent   = s.isPresent;
    final bool isSelected  = state.selectedStudentIds.contains(s.id);

    final Color statusColor = isPresent
        ? Colors.green
        : s.isLate
        ? Colors.orange
        : s.isLeave
        ? Colors.blue
        : Colors.red;

    final String statusLabel = isPresent
        ? 'Present'
        : s.isLate
        ? 'Late'
        : s.isLeave
        ? 'Leave'
        : s.isAbsent
        ? 'Absent'
        : 'Unmarked';

    return GestureDetector(
      onTap: state.bulkMode
          ? () => context
          .read<AttendanceCubit>()
          .toggleStudentSelection(s.id)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: state.bulkMode && isSelected
              ? AppTheme.btnColor.withOpacity(0.07)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: state.bulkMode && isSelected
              ? Border.all(color: AppTheme.btnColor.withOpacity(0.4))
              : null,
        ),
        child: Row(
          children: [
            if (state.bulkMode)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppTheme.btnColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.btnColor
                          : AppTheme.graySubTitleColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: statusColor.withOpacity(0.12),
              backgroundImage:
              (s.fixedPhoto != null && s.fixedPhoto!.isNotEmpty)
                  ? NetworkImage(s.fixedPhoto!)
                  : null,
              child: (s.fixedPhoto == null || s.fixedPhoto!.isEmpty)
                  ? Text(s.initial,
                  style: MyStyles.boldText(size: 18, color: statusColor))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(s.name,
                            style: MyStyles.boldText(
                                size: 15, color: AppTheme.black_Color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (s.rollNo != null && s.rollNo!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text('• ${s.rollNo}',
                            style: MyStyles.mediumText(
                                size: 13, color: AppTheme.btnColor)),
                      ],
                    ],
                  ),
                  if (s.fatherName != null && s.fatherName!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text('Father: ${s.fatherName}',
                        style: MyStyles.regularText(
                            size: 12, color: AppTheme.graySubTitleColor)),
                  ],
                  if (s.motherName != null && s.motherName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Mother: ${s.motherName}',
                        style: MyStyles.regularText(
                            size: 12, color: AppTheme.graySubTitleColor)),
                  ],
                  if (s.className != null && s.className!.isNotEmpty ||
                      s.section != null && s.section!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (s.className != null && s.className!.isNotEmpty)
                          'Class: ${s.className}',
                        if (s.section != null && s.section!.isNotEmpty)
                          'Section: ${s.section}',
                      ].join('  |  '),
                      style: MyStyles.regularText(
                          size: 12, color: AppTheme.graySubTitleColor),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(statusLabel,
                        style:
                        MyStyles.mediumText(size: 11, color: statusColor)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!state.bulkMode && showToggle)
              GestureDetector(
                onTap: () => context
                    .read<AttendanceCubit>()
                    .toggleAttendance(
                  schoolId: widget.schoolId,
                  studentId: s.id,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 52,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isPresent ? Colors.green : Colors.red.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    alignment: isPresent
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
