import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/models/home/SchoolDashboardModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/admin_dashboard/admin_dashboard_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/screens/add_student/add_student_form.dart';
import 'package:idmitra/providers/add_staff/add_staff_cubit.dart';
import 'package:idmitra/screens/dashboard/StatCard.dart';
import 'package:idmitra/screens/admin/admin_order/admin_orders_page.dart';
import 'package:idmitra/utils/MyStyles.dart';

import '../../../models/schools/SchoolListModel.dart';
import '../../staff/staff_student_list/add_staff_form.dart';
import '../attendance/attendance_screen.dart';
import '../holidays/holidays_screen.dart';

class AdminHome extends StatelessWidget {
  final VoidCallback? onStudentAdded;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onStaffTap;
  SchoolDetailsModel? schoolDetailsModel;
  AdminHome({super.key, this.onStudentAdded, this.onStudentsTap, this.onStaffTap,this.schoolDetailsModel});

  @override
  Widget build(BuildContext context) {
    return _AdminHomeView(onStudentAdded: onStudentAdded, onStudentsTap: onStudentsTap, onStaffTap: onStaffTap);
  }
}

class _AdminHomeView extends StatelessWidget {
  final VoidCallback? onStudentAdded;
  final VoidCallback? onStudentsTap;
  final VoidCallback? onStaffTap;
  SchoolDetailsModel? schoolDetailsModel;

  _AdminHomeView({this.onStudentAdded, this.onStudentsTap, this.onStaffTap,this.schoolDetailsModel});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
      builder: (context, state) {
        if (state.loading) {
          return const HomeShimmer();
        }
        if (state.error != null && state.dashboard == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  state.error!,
                  style: MyStyles.regularTxt(Colors.red, 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      context.read<AdminDashboardCubit>().loadDashboard(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final data = state.dashboard?.data;
        return RefreshIndicator(
          onRefresh: () => context.read<AdminDashboardCubit>().loadDashboard(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(
                      title: "Total Students",
                      value: '${data?.summary.students ?? 0}',
                      icon: Icons.school,
                      color: Colors.orange,
                      button: onStudentsTap ?? () {},
                    ),
                    StatCard(
                      title: "Total Staff",
                      value: '${data?.summary.staff ?? 0}',
                      icon: Icons.group,
                      color: Colors.blue,
                      button: onStaffTap ?? () {},
                    ),
                    StatCard(
                      title: "Total Orders",
                      value: '${data?.summary.orders.total ?? 0}',
                      icon: Icons.receipt_long,
                      color: Colors.indigo,
                      button: () {},
                    ),
                    StatCard(
                      title: "Completed Orders",
                      value: '${data?.summary.orders.completed ?? 0}',
                      icon: Icons.check_circle_outline,
                      color: Colors.teal,
                      button: () {},
                    ),
                    StatCard(
                      title: "Total Classes",
                      value: '${data?.summary.classes ?? 0}',
                      icon: Icons.class_outlined,
                      color: Colors.purple,
                      button: () {},
                    ),
                    StatCard(
                      title: "Total Checklists",
                      value: '${data?.summary.checklists ?? 0}',
                      icon: Icons.checklist_outlined,
                      color: Colors.green,
                      button: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                if (data != null) _AttendanceCard(attendance: data.attendance),
                const SizedBox(height: 20),
                _HolidaysTile(),
                const SizedBox(height: 20),
                Text(
                  "Quick Actions",
                  style: MyStyles.boldTxt(AppTheme.black_Color, 16),
                ),
                const SizedBox(height: 12),
                _QuickActions(onStudentAdded: onStudentAdded),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChecklistItem {
  final String label;
  final bool done;
  const _ChecklistItem(this.label, this.done);
}

class _ChecklistSection extends StatelessWidget {
  final List<_ChecklistItem> items;
  final Color accentColor;
  const _ChecklistSection({required this.items, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: item.done
                      ? accentColor.withOpacity(0.15)
                      : Colors.grey.shade100,
                  child: Icon(
                    item.done ? Icons.check : Icons.radio_button_unchecked,
                    size: 16,
                    color: item.done ? accentColor : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: MyStyles.regularTxt(
                      item.done
                          ? AppTheme.graySubTitleColor
                          : AppTheme.black_Color,
                      14,
                    ),
                  ),
                ),
                if (item.done)
                  Text("Done", style: MyStyles.mediumTxt(accentColor, 12))
                else
                  Text("Pending", style: MyStyles.mediumTxt(Colors.orange, 12)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final DashAttendance attendance;
  const _AttendanceCard({required this.attendance});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final school = await UserLocal.getSchool();
        final schoolId = school['schoolId']?.toString() ?? '';
        if (!context.mounted || schoolId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(schoolId: schoolId),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.how_to_reg_outlined,
                  color: AppTheme.btnColor,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  "Today's Attendance",
                  style: MyStyles.boldTxt(AppTheme.black_Color, 15),
                ),
                const Spacer(),
                if (attendance.attendanceDate.isNotEmpty)
                  Text(
                    attendance.attendanceDate,
                    style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11),
                  ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.graySubTitleColor),
              ],
            ),
            const SizedBox(height: 12),
            if (!attendance.hasAttendance)
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      attendance.message,
                      style: MyStyles.regularTxt(Colors.orange, 13),
                    ),
                  ),
                ],
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: attendance.attendancePercentage / 100,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    attendance.attendancePercentage >= 75
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${attendance.attendancePercentage.toStringAsFixed(1)}% attendance',
                style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AttStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _AttStat(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text('$count', style: MyStyles.boldTxt(color, 18)),
          Text(
            label,
            style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback? onStudentAdded;
  const _QuickActions({this.onStudentAdded});

  Future<void> _navigateToAddStudent(BuildContext context) async {
    final school = await UserLocal.getSchool();
    final schoolId = school['schoolId'] ?? '';
    if (!context.mounted || schoolId.isEmpty) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
              StudentFormCubit()
                ..loadFromSchoolId(schoolId: schoolId, schoolName: ''),
            ),
            BlocProvider(create: (_) => StudentFormDataCubit()..load(schoolId)),
            BlocProvider(create: (_) => AddStudentCubit()),
          ],
          child: AddStudentFormPage(schoolId: schoolId),
        ),
      ),
    );
    onStudentAdded?.call();
  }

  Future<void> _navigateToAddStaff(BuildContext context) async {
    final school = await UserLocal.getSchool();
    final schoolId = school['schoolId'] ?? '';
    if (!context.mounted || schoolId.isEmpty) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (_) => AddStaffCubit(),
          child: AddStaffFormPage(
            editStaff: null,
            schoolId: schoolId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            label: "Add Student",
            icon: Icons.person_add_outlined,
            color: Colors.green,
            width: width,
            onTap: () => _navigateToAddStudent(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionTile(
            label: "Add Staff",
            icon: Icons.group_add_outlined,
            color: AppTheme.btnColor,
            width: width,
            onTap: () => _navigateToAddStaff(context),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final double width;
  final VoidCallback onTap;
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: width * 0.065,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(icon, color: color, size: width * 0.06),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: MyStyles.regularTxt(AppTheme.black_Color, width * 0.033),
            ),
          ],
        ),
      ),
    );
  }
}
class _HolidaysTile extends StatelessWidget {
  const _HolidaysTile();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final school = await UserLocal.getSchool();
        final schoolId = school['schoolId']?.toString() ?? '';
        if (!context.mounted || schoolId.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => HolidaysScreen(schoolId: schoolId)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.btnColor.withOpacity(0.12),
              child: Icon(Icons.calendar_month, color: AppTheme.btnColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Holidays', style: MyStyles.boldTxt(AppTheme.black_Color, 15)),
                  Text(
                    'View & manage school holidays',
                    style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppTheme.graySubTitleColor),
          ],
        ),
      ),
    );
  }
}


