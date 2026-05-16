import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:idmitra/providers/students/students_state.dart';
import 'package:idmitra/screens/partner/dashboard/home/FilterBottomSheet.dart';
import 'package:idmitra/screens/partner/dashboard/home/StudentCard.dart';
import 'package:idmitra/screens/partner/dashboard/home/StudentIdCardWidget.dart';
import 'package:idmitra/screens/staff/staff_add_student_form/staff_add_student_form.dart';
import 'package:idmitra/screens/staff/staff_order_page/staff_order_detail_page.dart';

class StaffStudentsScreen extends StatefulWidget {
  final String? schoolId;
  final bool showAppBar;
  final SchoolDetailsModel? schoolDetailsModel;

  const StaffStudentsScreen({
    super.key,
    this.schoolId,
    this.showAppBar = false,
    this.schoolDetailsModel,
  });

  @override
  State<StaffStudentsScreen> createState() => _StaffStudentsScreenState();
}

class _StaffStudentsScreenState extends State<StaffStudentsScreen>
    with SingleTickerProviderStateMixin {
  String _schoolId = '';
  bool _schoolLoaded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    if (widget.schoolId != null && widget.schoolId!.isNotEmpty) {
      _schoolId = widget.schoolId!;
      _schoolLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StudentsCubit>().fetchStudents(search: '',);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant StaffStudentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newId = widget.schoolId ?? '';
    if (newId.isNotEmpty && newId != _schoolId) {
      setState(() {
        _schoolId = newId;
        _schoolLoaded = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<StudentsCubit>().fetchStudents(search: '',);
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
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5.0),
                      child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
                    ),
                  ),
                ),
              ),
              centerTitle: true,
              title: Text('Student Listings', style: MyStyles.boldText(size: 20, color: Colors.black)),
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppTheme.btnColor,
                unselectedLabelColor: AppTheme.graySubTitleColor,
                indicatorColor: AppTheme.btnColor,
                indicatorWeight: 2.5,
                labelStyle: MyStyles.mediumText(size: 13,color: Colors.white),
                unselectedLabelStyle: MyStyles.regularText(size: 13,color: Colors.white),
                tabs: const [
                  Tab(text: 'Students'),
                  Tab(text: 'Correction List'),
                  Tab(text: 'Orders'),
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
                  labelStyle: MyStyles.mediumText(size: 13,color: Colors.white),
                  unselectedLabelStyle: MyStyles.regularText(size: 13,color: Colors.white),
                  tabs: const [
                    Tab(text: 'Students'),
                    Tab(text: 'Correction List'),
                    Tab(text: 'Orders'),
                  ],
                ),
              ),
            ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Students
          _StaffStudentsTab(
            schoolId: _schoolId,
            schoolDetailsModel: widget.schoolDetailsModel,
          ),
          // Tab 2: Correction List (isSchool = true for staff)
          BlocProvider(
            create: (_) => CorrectionCubit()
              ..fetchCorrectionList(schoolId: _schoolId, isSchool: true),
            child: _StaffCorrectionTab(schoolId: _schoolId),
          ),
          // Tab 3: Orders
          BlocProvider(
            create: (_) => OrdersCubit()
              ..fetchOrders(schoolId: _schoolId, isSchool: true)
              ..fetchSchoolClasses(_schoolId),
            child: _StaffOrdersTab(schoolId: _schoolId),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Students ──────────────────────────────────────────────────────────

class _StaffStudentsTab extends StatefulWidget {
  final String schoolId;
  final SchoolDetailsModel? schoolDetailsModel;
  const _StaffStudentsTab({required this.schoolId, this.schoolDetailsModel});

  @override
  State<_StaffStudentsTab> createState() => _StaffStudentsTabState();
}

class _StaffStudentsTabState extends State<_StaffStudentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ScrollController _gridScrollCtrl = ScrollController();
  Timer? _debounce;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels == _scrollCtrl.position.maxScrollExtent) {
        context.read<StudentsCubit>().fetchStudents(
          search: _searchCtrl.text.trim(),
          gender: '',
          classId: '',
        );
      }
    });
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
                ..loadFromSchoolId(schoolId: widget.schoolId, schoolName: ''),
            ),
            BlocProvider(create: (_) => StudentFormDataCubit()..load(widget.schoolId)),
            BlocProvider(create: (_) => AddStudentCubit()),
          ],
          child: StaffAddStudentFormPage(schoolId: widget.schoolId),
        ),
      ),
    ).then((_) {
      context.read<StudentsCubit>().fetchStudents(
        search: _searchCtrl.text.trim(),
        gender: '',
        classId: '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _isGridView
          ? null
          : FloatingActionButton(
              backgroundColor: AppTheme.btnColor,
              tooltip: 'Add Student',
              onPressed: _navigateToAddStudent,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: RefreshIndicator(
        onRefresh: () async => context.read<StudentsCubit>().fetchStudents(
          search: _searchCtrl.text.trim(),
          gender: '',
          classId: '',
        ),
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
                      final result = await showModalBottomSheet<Map<String, dynamic>>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.whiteColor,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                        ),
                        builder: (_) => BlocProvider(
                          create: (_) => OrdersCubit()..fetchSchoolClasses(widget.schoolId),
                          child: FilterBottomSheet(schoolId: widget.schoolId),
                        ),
                      );
                      if (result != null) {
                        _debounce?.cancel();
                        _debounce = Timer(const Duration(milliseconds: 300), () {
                          context.read<StudentsCubit>().fetchStudents(
                            search: '',
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
                      child: svgIcon(icon: 'assets/icons/filtter.svg', clr: AppTheme.black_Color),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _isGridView = !_isGridView),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isGridView ? AppTheme.btnColor : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isGridView ? AppTheme.btnColor : Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: _isGridView
                            ? [BoxShadow(color: AppTheme.btnColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isGridView ? Icons.view_list_rounded : Icons.badge_outlined,
                            size: 18,
                            color: _isGridView ? Colors.white : AppTheme.black_Color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isGridView ? 'List' : 'ID Card',
                            style: MyStyles.mediumText(
                              size: 12,
                              color: _isGridView ? Colors.white : AppTheme.black_Color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Expanded(
                child: BlocBuilder<StudentsCubit, StudentsState>(
                  builder: (context, state) {
                    if (state.loading) return const ShimmerList(expanded: false);
                    if (state.studentsList.isEmpty) {
                      return Center(child: Image.asset('assets/images/no_data.png', height: 200));
                    }
                    final itemCount = state.studentsList.length + (state.hasMore ? 1 : 0);
                    if (_isGridView) {
                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        controller: _gridScrollCtrl,
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index < state.studentsList.length) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Center(
                                child: SizedBox(
                                  width: 300,
                                  child: Hero(
                                    tag: 'student_card_${state.studentsList[index].uuid}',
                                    child: Material(
                                      color: Colors.transparent,
                                      child: StudentIdCardWidget(
                                        student: state.studentsList[index],
                                        schoolId: widget.schoolId,
                                        schoolDetailsModel: widget.schoolDetailsModel,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
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
                          return StudentCard(
                            key: ValueKey(student.uuid),
                            studentData: student,
                            schoolId: widget.schoolId,
                          );
                        }
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
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
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
    onChanged: (value) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        context.read<StudentsCubit>().fetchStudents(
          search: value.trim(),
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
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      hintStyle: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
    ),
  );
}

// ─── Tab 2: Correction List ───────────────────────────────────────────────────

class _StaffCorrectionTab extends StatefulWidget {
  final String schoolId;
  const _StaffCorrectionTab({required this.schoolId});

  @override
  State<_StaffCorrectionTab> createState() => _StaffCorrectionTabState();
}

class _StaffCorrectionTabState extends State<_StaffCorrectionTab> {
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<CorrectionCubit>().fetchCorrectionList(
          schoolId: widget.schoolId,
          isSchool: true,
          isLoadMore: true,
        );
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(child: _searchBar()),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () async {
                  final result = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppTheme.whiteColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                    ),
                    builder: (_) => BlocProvider(
                      create: (_) => OrdersCubit()..fetchSchoolClasses(widget.schoolId),
                      child: FilterBottomSheet(schoolId: widget.schoolId),
                    ),
                  );
                  if (result != null) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () {
                      context.read<CorrectionCubit>().fetchCorrectionList(
                        schoolId: widget.schoolId,
                        isSchool: true,
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
                  child: svgIcon(icon: 'assets/icons/filtter.svg', clr: AppTheme.black_Color),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: BlocBuilder<CorrectionCubit, CorrectionState>(
            builder: (context, state) {
              if (state.loading && state.items.isEmpty) {
                return const Center(child: CircularProgressIndicator(color: AppTheme.btnColor));
              }
              if (state.error != null && state.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(state.error!, style: MyStyles.regularText(size: 14, color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.read<CorrectionCubit>().fetchCorrectionList(
                          schoolId: widget.schoolId, isSchool: true),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (state.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/no_data.png', height: 160),
                      const SizedBox(height: 12),
                      Text('No correction items found',
                          style: MyStyles.mediumText(size: 14, color: AppTheme.graySubTitleColor)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  if (state.selectedIds.isNotEmpty)
                    Container(
                      color: AppTheme.btnColor.withOpacity(0.08),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Text('${state.selectedIds.length} selected',
                              style: MyStyles.mediumText(size: 13, color: AppTheme.btnColor)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => context.read<CorrectionCubit>().selectAll(),
                            child: Text('Select All', style: MyStyles.mediumText(size: 12, color: AppTheme.btnColor)),
                          ),
                          TextButton(
                            onPressed: () => context.read<CorrectionCubit>().clearSelection(),
                            child: Text('Clear', style: MyStyles.mediumText(size: 12, color: AppTheme.cancelTextColor)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppTheme.btnColor,
                      onRefresh: () async => context.read<CorrectionCubit>().fetchCorrectionList(
                        schoolId: widget.schoolId, isSchool: true),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: state.items.length + (state.hasMore ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i < state.items.length) {
                            final item = state.items[i];
                            final isSelected = state.selectedIds.contains(item.id);
                            return _CorrectionCard(
                              item: item,
                              isSelected: isSelected,
                              onToggle: () => context.read<CorrectionCubit>().toggleSelection(item.id),
                            );
                          }
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator(color: AppTheme.btnColor, strokeWidth: 2)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _searchBar() => TextField(
    controller: _searchCtrl,
    style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
    onChanged: (value) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        context.read<CorrectionCubit>().fetchCorrectionList(
          schoolId: widget.schoolId,
          isSchool: true,
          search: value.trim(),
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
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(15),
      ),
      hintStyle: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
    ),
  );
}

class _CorrectionCard extends StatelessWidget {
  final CorrectionItem item;
  final bool isSelected;
  final VoidCallback onToggle;

  const _CorrectionCard({required this.item, required this.isSelected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.btnColor.withOpacity(0.06) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppTheme.btnColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.btnColor : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? AppTheme.btnColor : Colors.grey.shade400,
                  width: 1.5,
                ),
              ),
              child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (item.profilePhotoUrl != null && item.profilePhotoUrl!.isNotEmpty)
                  ? Image.network(item.profilePhotoUrl!, height: 52, width: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
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
                        child: Text(item.studentName ?? '-',
                            style: MyStyles.boldText(size: 15, color: AppTheme.black_Color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (item.className != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('• ${item.className}',
                              style: MyStyles.mediumText(size: 13, color: AppTheme.btnColor),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  if (item.issue != null && item.issue!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.issue!,
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                  if (item.createdAt != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.graySubTitleColor),
                        const SizedBox(width: 3),
                        Text(item.createdAt!,
                            style: MyStyles.regularText(size: 11, color: AppTheme.graySubTitleColor)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 52, width: 52,
    color: Colors.grey.shade200,
    child: const Icon(Icons.person, color: Colors.grey),
  );
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
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        context.read<OrdersCubit>().fetchOrders(
          isLoadMore: true,
          search: _searchCtrl.text.trim(),
          status: _selectedStatus,
          classId: _selectedClass,
          schoolId: widget.schoolId,
          isSchool: true,
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
    context.read<OrdersCubit>().fetchOrders(
      search: _searchCtrl.text.trim(),
      status: _selectedStatus,
      classId: _selectedClass,
      schoolId: widget.schoolId,
      isSchool: true,
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
                  Expanded(child: _dateField(_dateFromCtrl, 'From dd-mm-yyyy')),
                  const SizedBox(width: 8),
                  Expanded(child: _dateField(_dateToCtrl, 'To dd-mm-yyyy')),
                ],
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _clearFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.lightRedColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close, size: 12, color: AppTheme.cancelTextColor),
                          const SizedBox(width: 4),
                          Text('Clear Filters',
                              style: MyStyles.mediumText(size: 11, color: AppTheme.cancelTextColor)),
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
                return const Padding(padding: EdgeInsets.all(16), child: OrderListShimmer());
              }
              if (state.error != null && state.ordersList.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                      const SizedBox(height: 12),
                      Text(state.error!, style: MyStyles.regularText(size: 14, color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _resetAndFetch,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.btnColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      Image.asset('assets/images/no_data.png', height: 160),
                      const SizedBox(height: 12),
                      Text('No orders found',
                          style: MyStyles.mediumText(size: 14, color: AppTheme.graySubTitleColor)),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: Text('Clear filters',
                              style: MyStyles.mediumText(size: 13, color: AppTheme.btnColor)),
                        ),
                      ],
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                color: AppTheme.btnColor,
                onRefresh: () async => _resetAndFetch(),
                child: ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  itemCount: state.ordersList.length + (state.hasMore ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i < state.ordersList.length) {
                      return _StaffOrderCard(
                        order: state.ordersList[i],
                        schoolId: widget.schoolId,
                      );
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.btnColor, strokeWidth: 2)),
                    );
                  },
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
    style: MyStyles.regularText(size: 14, color: AppTheme.black_Color),
    onChanged: (_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), _resetAndFetch);
    },
    decoration: InputDecoration(
      filled: true,
      fillColor: AppTheme.appBackgroundColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintText: 'Search by student name, order ID...',
      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.graySubTitleColor),
      suffixIcon: _searchCtrl.text.isNotEmpty
          ? GestureDetector(
              onTap: () { _searchCtrl.clear(); setState(() {}); _resetAndFetch(); },
              child: const Icon(Icons.close, size: 16, color: AppTheme.graySubTitleColor),
            )
          : null,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppTheme.btnColor),
        borderRadius: BorderRadius.circular(12),
      ),
      hintStyle: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
    ),
  );

  Widget _classDropdown() => BlocBuilder<OrdersCubit, OrdersState>(
    buildWhen: (p, c) => p.availableClasses != c.availableClasses || p.classesLoading != c.classesLoading,
    builder: (_, state) => _dropdown(
      value: _selectedClass.isEmpty ? '' : _selectedClass,
      hint: 'All Classes',
      loading: state.classesLoading,
      items: [
        const DropdownMenuItem(value: '', child: Text('All Classes')),
        ...state.availableClasses.map((c) => DropdownMenuItem(
          value: c.classId.toString(),
          child: Text(c.nameWithprefix ?? c.name, overflow: TextOverflow.ellipsis),
        )),
      ],
      onChanged: (v) {
        setState(() => _selectedClass = v ?? '');
        WidgetsBinding.instance.addPostFrameCallback((_) => _resetAndFetch());
      },
    ),
  );

  Widget _statusDropdown() => _dropdown(
    value: _selectedStatus,
    hint: 'All Status',
    items: kOrderFilterStatuses
        .map((s) => DropdownMenuItem<String>(value: s.value, child: Text(s.label, overflow: TextOverflow.ellipsis)))
        .toList(),
    onChanged: (v) {
      setState(() => _selectedStatus = v ?? '');
      WidgetsBinding.instance.addPostFrameCallback((_) => _resetAndFetch());
    },
  );

  Widget _dropdown({
    required String value,
    required String hint,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    bool loading = false,
  }) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: AppTheme.appBackgroundColor,
      border: Border.all(color: AppTheme.backBtnBgColor.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(10),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isExpanded: true,
        menuMaxHeight: 300,
        icon: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.btnColor))
            : const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppTheme.graySubTitleColor),
        style: MyStyles.regularText(size: 13, color: AppTheme.black_Color),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );

  Widget _dateField(TextEditingController ctrl, String hint) {
    return StatefulBuilder(
      builder: (context, setLocal) => AppTextField(
        controller: ctrl,
        hintText: hint,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d.\-/]')),
          LengthLimitingTextInputFormatter(10),
          _StaffDotDateFormatter(),
        ],
        suffixIcon: ctrl.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  ctrl.clear();
                  setLocal(() {});
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 200), _resetAndFetch);
                },
                child: const Icon(Icons.close, size: 16),
              )
            : null,
        onChanged: (_) {
          setLocal(() {});
          if (ctrl.text.length == 10 || ctrl.text.isEmpty) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), _resetAndFetch);
          }
        },
      ),
    );
  }
}

class _StaffOrderCard extends StatefulWidget {
  final OrderModel order;
  final String schoolId;
  const _StaffOrderCard({required this.order, this.schoolId = ''});

  @override
  State<_StaffOrderCard> createState() => _StaffOrderCardState();
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
      case 'completed': return const Color(0xFF2DC24E);
      case 'cancelled': return AppTheme.cancelTextColor;
      case 'work_in_process': return AppTheme.btnColor;
      case 're_order': return AppTheme.PendingDotColor;
      default: return AppTheme.graySubTitleColor;
    }
  }

  Color get _statusBg {
    switch (_currentStatus) {
      case 'completed': return const Color(0xFFE8F9ED);
      case 'cancelled': return AppTheme.lightRedColor;
      case 'work_in_process': return AppTheme.lightBlueColor;
      case 're_order': return AppTheme.PendingLightColor;
      default: return AppTheme.appBackgroundColor;
    }
  }

  String get _statusLabel => kOrderStatuses
      .firstWhere((s) => s.value == _currentStatus,
          orElse: () => OrderStatusOption(_currentStatus, _currentStatus.replaceAll('_', ' ')))
      .label;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _updating = true);
    final success = await context.read<OrdersCubit>().updateOrderStatus(widget.order.uuid, newStatus);
    if (!mounted) return;
    setState(() { _updating = false; if (success) _currentStatus = newStatus; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success ? 'Status updated successfully' : 'Failed to update status'),
      backgroundColor: success ? AppTheme.btnColor : Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.order.student;
    final school = widget.order.school;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StaffOrderDetailPage(uuid: widget.order.uuid, schoolId: widget.schoolId),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (student?.profilePhotoUrl != null && student!.profilePhotoUrl!.isNotEmpty)
                  ? Image.network(student.profilePhotoUrl!, height: 60, width: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder())
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
                        child: Text(student?.name ?? '-',
                            style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (student?.className != null) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text('• ${student!.className!}',
                              style: MyStyles.boldText(size: 14, color: AppTheme.btnColor),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (school?.name != null)
                    Text(school!.name,
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: _statusBg, borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 5, height: 5,
                                decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(_statusLabel, style: MyStyles.mediumText(size: 11, color: _statusColor)),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.calendar_today_outlined, size: 11, color: AppTheme.graySubTitleColor),
                      const SizedBox(width: 3),
                      Text(widget.order.orderedAt,
                          style: MyStyles.regularText(size: 11, color: AppTheme.graySubTitleColor)),
                    ],
                  ),
                ],
              ),
            ),
            _updating
                ? const Padding(padding: EdgeInsets.all(4),
                    child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.btnColor)))
                : _currentStatus == 'completed'
                    ? const SizedBox.shrink()
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.grey),
                        offset: const Offset(0, 32),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 8,
                        onSelected: _updateStatus,
                        itemBuilder: (_) => [
                          const PopupMenuItem<String>(
                            value: 'completed',
                            child: Row(children: [
                              Icon(Icons.check_circle_outline, size: 16, color: AppTheme.graySubTitleColor),
                              SizedBox(width: 10),
                              Text('Mark as Completed'),
                            ]),
                          ),
                        ],
                      ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 60, width: 60,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, color: Colors.grey),
  );
}

class _StaffDotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.replaceAll('/', '-').replaceAll('.', '-');
    return newValue.copyWith(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
