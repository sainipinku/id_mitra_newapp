import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/config/sharedpref.dart';
import 'package:idmitra/models/LoginModel.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/home/SchoolDashboardModel.dart';
import 'package:idmitra/providers/admin_dashboard/admin_dashboard_cubit.dart';
import 'package:idmitra/providers/login_auth/login_cubit.dart';
import 'package:idmitra/screens/auth/login.dart';
import 'package:idmitra/screens/admin/admin_home/admin_user/admin_user_details_page.dart';
import 'package:idmitra/screens/staff/staff_user_details/staff_user_details_page.dart';
import 'package:idmitra/utils/MyStyles.dart';
import 'package:idmitra/utils/navigation_utils.dart';
import 'package:page_transition/page_transition.dart';

import 'package:idmitra/providers/staff/staff_cubit.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:idmitra/screens/admin/admin_edit_profile/admin_profile_page.dart';
import 'package:idmitra/screens/staff/staff_student_list/staff_student_list.dart';
import 'package:idmitra/screens/parent/parent_dashboard.dart';
import '../staff_student_list/staff_list.dart';
import 'staff_home.dart';

class StaffDashboard extends StatefulWidget {
  SchoolDetailsModel? schoolDetailsModel;

  StaffDashboard({super.key,this.schoolDetailsModel});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard> {
  int _selectedIndex = 0;
  String _userName = 'Staff';
  String _profileImage = '';
  String _schoolId = '';
  List<int> _assignedClassIds = [];
  bool _userLoaded = false;
  final StudentsCubit _studentsCubit = StudentsCubit();
  final StaffCubit _staffCubit = StaffCubit();

  // Cached widgets — rebuilt only when schoolId or key data changes
  List<Widget>? _cachedWidgets;
  String _cachedSchoolId = '';
  SchoolDetailsModel? _cachedSchoolDetailsModel;

  List<Widget> _getWidgets(String schoolId, SchoolDetailsModel? schoolDetailsModel) {
    // Rebuild only when schoolId changes (not on every setState)
    if (_cachedWidgets != null &&
        _cachedSchoolId == schoolId &&
        _cachedSchoolDetailsModel?.id == schoolDetailsModel?.id) {
      return _cachedWidgets!;
    }
    _cachedSchoolId = schoolId;
    _cachedSchoolDetailsModel = schoolDetailsModel;
    _cachedWidgets = [
      StaffHome(
        onStudentAdded: _onStudentAdded,
        onStudentsTap: _onStudentsTap,
        onStaffTap: _onStaffTap,
        schoolId: schoolId,
      ),
      BlocProvider.value(
        value: _studentsCubit,
        child: StaffStudentsScreen(
          schoolId: schoolId,
          schoolDetailsModel: schoolDetailsModel,
          assignedClassIds: _assignedClassIds,
          userLoaded: _userLoaded,
        ),
      ),
      BlocProvider.value(
        value: _staffCubit,
        child: StaffListingPage(schoolId: schoolId, showAppBar: false),
      ),
    ];
    return _cachedWidgets!;
  }

  void _onStudentAdded() => setState(() => _selectedIndex = 1);
  void _onStudentsTap() => setState(() => _selectedIndex = 1);
  void _onStaffTap() => setState(() => _selectedIndex = 2);

  @override
  void dispose() {
    _studentsCubit.close();
    _staffCubit.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await UserLocal.getUser();
    final school = await UserLocal.getSchool();

    // First set from local cache so UI shows quickly
    final cachedClasses = await UserLocal.getAssignedClasses();
    final newSchoolId = school['schoolId'] ?? '';

    if (mounted) {
      setState(() {
        _userName = user['name'] ?? 'Staff';
        _profileImage = user['profileImage'] ?? '';
        _schoolId = newSchoolId;
        _assignedClassIds = cachedClasses.map((c) => c.id).toList();
        _userLoaded = true;
        _cachedWidgets = null; // force rebuild with updated assignedClassIds
      });
      if (newSchoolId.isNotEmpty) {
        _staffCubit.fetchStaff(schoolId: newSchoolId);
      }
    }

    // Then fetch fresh assigned classes from API and update if different
    try {
      final api = ApiManager();
      final userUuid = user['userUuid'] as String? ?? '';

      // Use staffAssignedClasses endpoint if we have UUID and schoolId
      if (userUuid.isNotEmpty && newSchoolId.isNotEmpty) {
        final assignedUrl = Config.baseUrl +
            Routes.staffAssignedClasses(newSchoolId, userUuid);
        print('Fetching assigned classes from: $assignedUrl');
        final assignedResponse = await api.getRequest(assignedUrl);
        if (assignedResponse != null && assignedResponse.statusCode == 200) {
          final jsonData = jsonDecode(assignedResponse.body);
          // Response: {"data": {"assigned_classes": {uuid: {...}, ...}}}
          final rawData = jsonData['data']?['assigned_classes'];
          print('Fresh assigned_classes from staffAssignedClasses API: $rawData');
          List<AssignedClass> freshClasses = [];
          if (rawData is Map) {
            rawData.forEach((key, value) {
              final item = Map<String, dynamic>.from(value as Map);
              freshClasses.add(AssignedClass.fromJson(item));
            });
          } else if (rawData is List) {
            freshClasses = (rawData as List)
                .map((e) => AssignedClass.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
          final freshIds = freshClasses.map((c) => c.id).toList();
          print('Fresh assignedClassIds: $freshIds');
          await UserLocal.saveAssignedClasses(freshClasses);
          if (mounted && freshIds.toString() != _assignedClassIds.toString()) {
            setState(() {
              _assignedClassIds = freshIds;
              _cachedWidgets = null; // force rebuild with fresh assignedClassIds
            });
          }
          return; // done
        }
      }

      // Fallback: try auth/user endpoint
      final response = await api.getRequest(
        Config.baseUrl + Routes.getUserDetails(),
      );
      if (response != null && response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final rawClasses = jsonData['user']?['assigned_classes'];
        print('Fresh assigned_classes from auth/user API: $rawClasses');
        if (rawClasses is List && rawClasses.isNotEmpty) {
          final freshClasses = rawClasses
              .map((e) => AssignedClass.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          final freshIds = freshClasses.map((c) => c.id).toList();
          print('Fresh assignedClassIds: $freshIds');
          await UserLocal.saveAssignedClasses(freshClasses);
          if (mounted && freshIds.toString() != _assignedClassIds.toString()) {
            setState(() {
              _assignedClassIds = freshIds;
              _cachedWidgets = null; // force rebuild with fresh assignedClassIds
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching fresh assigned classes: $e');
    }
  }

  void _onItemTapped(int index) => setState(() => _selectedIndex = index);

  void _onSchoolTap(BuildContext context, DashSchool? dashSchool, AdminDashboardState dashState) {
    if (dashSchool == null) return;
    final summary = dashState.dashboard?.data.summary;
    final schoolModel = SchoolDetailsModel(
      id: dashSchool.id,
      name: dashSchool.name,
      schoolPrefix: dashSchool.schoolPrefix,
      logoUrl: dashSchool.logoUrl,
      studentCount: summary?.students,
      staffCount: summary?.staff,
      orderCount: summary?.orders.total,
    );
    navigateWithTransition(
      context: context,
      page: StaffUserDetailsPage(schoolDetailsModel: schoolModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LoginCubit()),
        BlocProvider(create: (_) => AdminDashboardCubit()..loadDashboard()),
      ],
      child: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LogoutSuccess) {
            SharedPref.removeAll();
            UserSecureStorage.deleteAll();
            navigateAndRemoveUntil(
              context: context,
              page: const LoginScreen(),
              transition: PageTransitionType.leftToRight,
            );
          }
        },
        child: BlocConsumer<AdminDashboardCubit, AdminDashboardState>(
          listener: (context, dashState) {
            final dashSchoolId = dashState.dashboard?.data.school?.id;
            if (dashSchoolId != null && dashSchoolId != 0) {
              final id = dashSchoolId.toString();
              if (_schoolId.isEmpty) {
                _staffCubit.fetchStaff(schoolId: id);
              }
            }
          },
          builder: (context, dashState) {
            final dashSchool = dashState.dashboard?.data.school;
            final dashSchoolId = dashSchool?.id != null && dashSchool!.id != 0
                ? dashSchool.id.toString()
                : '';
            final schoolId = dashSchoolId.isNotEmpty ? dashSchoolId : _schoolId;
            final summary = dashState.dashboard?.data.summary;
            final schoolDetailsModel = dashSchool != null
                ? SchoolDetailsModel(
              id: dashSchool.id,
              name: dashSchool.name,
              schoolPrefix: dashSchool.schoolPrefix,
              logoUrl: dashSchool.logoUrl,
              studentCount: summary?.students,
              staffCount: summary?.staff,
              orderCount: summary?.orders.total,
            )
                : null;
            return Scaffold(
              appBar: _appBar(context, dashSchool, dashState),
              body: IndexedStack(
                index: _selectedIndex,
                children: _getWidgets(schoolId, schoolDetailsModel),
              ),
              bottomNavigationBar: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BottomNavigationBar(
                        type: BottomNavigationBarType.fixed,
                        backgroundColor: Colors.white,
                        elevation: 0,
                        currentIndex: _selectedIndex,
                        onTap: _onItemTapped,
                        selectedItemColor: AppTheme.btnColor,
                        unselectedItemColor: AppTheme.black_Color,
                        showUnselectedLabels: true,
                        items: [
                          BottomNavigationBarItem(
                            icon: svgIcon(
                              icon: 'assets/icons/home/home.svg',
                              clr: _selectedIndex == 0
                                  ? AppTheme.btnColor
                                  : AppTheme.black_Color,
                            ),
                            label: "Dashboard",
                          ),
                          BottomNavigationBarItem(
                            icon: Icon(
                              Icons.school_outlined,
                              color: _selectedIndex == 1
                                  ? AppTheme.btnColor
                                  : AppTheme.black_Color,
                            ),
                            label: "Students",
                          ),
                          // BottomNavigationBarItem(
                          //   icon: Icon(
                          //     Icons.group_outlined,
                          //     color: _selectedIndex == 2
                          //         ? AppTheme.btnColor
                          //         : AppTheme.black_Color,
                          //   ),
                          //   label: "Staff",
                          // ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(
      BuildContext context,
      DashSchool? dashSchool,
      AdminDashboardState dashState,
      ) {
    final schoolName = dashSchool?.name ?? '';
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: dashState.loading
          ? const DashboardAppBarShimmer()
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE0E0E0),
              backgroundImage: _profileImage.isNotEmpty
                  ? NetworkImage(_profileImage)
                  : null,
              child: _profileImage.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: dashSchool != null
                    ? () => _onSchoolTap(context, dashSchool, dashState)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: MyStyles.boldTxt(AppTheme.black_Color, 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (schoolName.isNotEmpty)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              schoolName,
                              style: MyStyles.regularTxt(
                                  AppTheme.btnColor, 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_forward_ios,
                              size: 10, color: AppTheme.btnColor),
                        ],
                      )
                    else
                      Text(
                        "ID Mitra Staff",
                        style: MyStyles.regularTxt(
                            AppTheme.graySubTitleColor, 12),
                      ),
                  ],
                ),
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.btn10perOpacityColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: svgIcon(
                        icon: 'assets/icons/home/notification.svg',
                        clr: AppTheme.btnColor,
                      ),
                    ),
                  ),
                  onPressed: () {
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => const ParentDashboard(),
                    //   ),
                    // );
                  },
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      "2",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              icon: Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.btn10perOpacityColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3.0),
                  child: svgIcon(
                    icon: 'assets/icons/home/user-profile.svg',
                    clr: AppTheme.btnColor,
                  ),
                ),
              ),
              onPressed: () {
                navigateWithTransition(
                  context: context,
                  page: BlocProvider.value(
                    value: context.read<AdminDashboardCubit>(),
                    child: const AdminProfilePage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
