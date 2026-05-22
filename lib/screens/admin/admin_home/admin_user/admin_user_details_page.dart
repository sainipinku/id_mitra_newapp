import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/config/ScreenSize.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/providers/school/school_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/screens/admin/admin_edit_profile/admin_student_form.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:idmitra/screens/admin/admin_home/admin_students_list.dart';
import 'package:idmitra/providers/staff/staff_cubit.dart';
import 'package:idmitra/utils/navigation_utils.dart';
import 'package:idmitra/screens/admin/admin_edit_profile/admin_edit_profile.dart';

import '../../../edit_profile/image_setting.dart';
import '../../../staff/staff_student_list/staff_list.dart';

class AdminUserDetailsPage extends StatefulWidget {
  SchoolDetailsModel? schoolDetailsModel;
  AdminUserDetailsPage({super.key, this.schoolDetailsModel});

  @override
  State<AdminUserDetailsPage> createState() => _AdminUserDetailsPageState();
}

class _AdminUserDetailsPageState extends State<AdminUserDetailsPage> {
  List<String> tabs = ["Overview", "Admin"];
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return _AdminUserDetailsContent(
      schoolDetailsModel: widget.schoolDetailsModel,
      tabs: tabs,
      selectedIndex: selectedIndex,
      onTabChanged: (i) => setState(() => selectedIndex = i),
    );
  }
}

class _AdminUserDetailsContent extends StatelessWidget {
  final SchoolDetailsModel? schoolDetailsModel;
  final List<String> tabs;
  final int selectedIndex;
  final void Function(int) onTabChanged;

  const _AdminUserDetailsContent({
    this.schoolDetailsModel,
    required this.tabs,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'School Details',
        showText: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings, color: Colors.black),
            offset: const Offset(0, 45),
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 8,
            onSelected: (value) {
              if (value == 'image_settings') {
                final schoolId = schoolDetailsModel?.id?.toString() ?? '';
                final schoolIntId = schoolDetailsModel?.id;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => ImageSettingsScreen(
                        schoolId: schoolId,
                        schoolIntId: schoolDetailsModel?.id,
                      )),
                ).then((_) {
                  if (schoolIntId != null) {
                    try {
                      context.read<SchoolCubit>().fetchAndApplyImageShape(schoolIntId);
                    } catch (_) {}
                  }
                });
              } else if (value == 'profile_settings') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminEditProfilePage()),
                );
              } else if (value == 'student_form') {
                final schoolId = schoolDetailsModel?.id?.toString() ?? '';
                final schoolName = schoolDetailsModel?.name ?? '';
                navigateWithTransition(
                  context: context,
                  page: BlocProvider(
                    create: (_) => StudentFormCubit()
                      ..loadFromSchoolId(
                          schoolId: schoolId, schoolName: schoolName),
                    child:
                    AdminStudentForm(schoolDetailsModel: schoolDetailsModel!),
                  ),
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'image_settings',
                child: Row(children: [
                  Icon(Icons.image),
                  SizedBox(width: 10),
                  Text('Image Settings')
                ]),
              ),
              // PopupMenuItem(
              //   value: 'profile_settings',
              //   child: Row(children: [
              //     Icon(Icons.person),
              //     SizedBox(width: 10),
              //     Text('Profile Settings')
              //   ]),
              // ),
              PopupMenuItem(
                value: 'student_form',
                child: Row(children: [
                  Icon(Icons.assignment),
                  SizedBox(width: 10),
                  Text('Student Form')
                ]),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 30),

            // TOP CARD
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: ScreenSize.hp(context, 18),
                  decoration: BoxDecoration(
                    color: AppTheme.whiteColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppTheme.whiteColor,
                            border:
                            Border.all(color: AppTheme.backBtnBgColor),
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          schoolDetailsModel?.name ?? '',
                          textAlign: TextAlign.center,
                          style: MyStyles.boldText(
                              size: 20, color: AppTheme.black_Color),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.white20perOpacityColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Icon(Icons.location_on,
                                            size: 14,
                                            color: AppTheme.black_Color),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            schoolDetailsModel?.address ?? '',
                                            maxLines: 2,
                                            style: MyStyles.regularText(
                                                size: 12,
                                                color: AppTheme.black_Color),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.greenColor,
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      "ACTIVE",
                                      style: MyStyles.boldText(
                                          size: 10,
                                          color: AppTheme.whiteColor),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.calendar_month_outlined,
                                      size: 14, color: AppTheme.black_Color),
                                  const SizedBox(width: 4),
                                  Text(
                                    "12 Feb 2026",
                                    style: MyStyles.regularText(
                                        size: 12, color: AppTheme.black_Color),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.network(
                          schoolDetailsModel?.logoUrl ?? '',
                          fit: BoxFit.cover,
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // STATS
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                statCard(
                  title: "STUDENTS",
                  value: "${schoolDetailsModel?.studentCount ?? ''}",
                  callBtn: () => navigateWithTransition(
                    context: context,
                    page: BlocProvider(
                      create: (_) => StudentsCubit(),
                      child: AdminStudentsScreen(
                        schoolId: schoolDetailsModel?.id.toString() ?? '',
                        showAppBar: true,
                        schoolDetailsModel: schoolDetailsModel,

                      ),
                    ),
                  ),
                ),
                statCard(
                  title: "STAFF",
                  value: "${schoolDetailsModel?.staffCount ?? ''}",
                  callBtn: () => navigateWithTransition(
                    context: context,
                    page: BlocProvider(
                      create: (_) => StaffCubit(),
                      child: StaffListingPage(
                          schoolId: schoolDetailsModel?.id.toString() ?? '',
                        schoolDetailsModel: schoolDetailsModel,
                      ),
                    ),
                  ),
                ),
                // statCard(
                //   title: "TOTAL ORDERS",
                //   value: "${schoolDetailsModel?.orderCount ?? 0}",
                //   callBtn: () => Navigator.push(
                //     context,
                //     MaterialPageRoute(
                //       builder: (_) => AdminOrdersPage(
                //         schoolId: schoolDetailsModel?.id.toString() ?? '',
                //         schoolName: schoolDetailsModel?.name ?? '',
                //         totalOrderCount: schoolDetailsModel?.orderCount,
                //         isSchool: true,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),

            const SizedBox(height: 20),

            // TABS
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final isSelected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTabChanged(index),
                      child: tabItem(tabs[index], isSelected),
                    ),
                  );
                }),
              ),
            ),

            const SizedBox(height: 20),

            if (selectedIndex == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("General Information",
                        style: MyStyles.boldText(
                            size: 20, color: AppTheme.black_Color)),
                    const SizedBox(height: 12),
                    infoRow("School Name", schoolDetailsModel?.name ?? '',
                        "School ID", "SH-99283-DX"),
                    divider(),
                    infoRow("Email Address", "Xaviar@school.edu",
                        "Contact number", "+91 9876543210"),
                    divider(),
                    infoRow("Category", "Private Sec. School", "Established",
                        "1995 (29 Years)"),
                    divider(),
                    const Text("Address",
                        style:
                        TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      schoolDetailsModel?.address ?? '',
                      style: MyStyles.regularText(
                          size: 14, color: AppTheme.graySubTitleColor),
                    ),
                  ],
                ),
              ),

            if (selectedIndex == 1)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Admin Information",
                        style: MyStyles.boldText(
                            size: 20, color: AppTheme.black_Color)),
                    const SizedBox(height: 12),
                    infoRow(
                        "Admin Name",
                        schoolDetailsModel?.admin?.name ?? '',
                        "ID Proof",
                        "SH-99283-DX"),
                    divider(),
                    infoRow(
                      "Email Address",
                      schoolDetailsModel?.admin?.email ?? '',
                      "Contact number",
                      schoolDetailsModel?.admin?.phone ?? '',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget statCard(
      {required String title,
        required String value,
        required VoidCallback callBtn}) {
    return Expanded(
      child: GestureDetector(
        onTap: callBtn,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppTheme.whiteColor,
            border: Border.all(color: AppTheme.backBtnBgColor),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(title,
                  style: MyStyles.regularText(
                      size: 14, color: AppTheme.black_Color)),
              const SizedBox(height: 6),
              Text(value,
                  style: MyStyles.boldText(
                      size: 20, color: AppTheme.btnColor)),
            ],
          ),
        ),
      ),
    );
  }

  Widget tabItem(String title, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.btnColor : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget infoRow(
      String title1, String value1, String title2, String value2) {
    return Row(
      children: [
        Expanded(child: infoColumn(title1, value1)),
        Expanded(child: infoColumn(title2, value2)),
      ],
    );
  }

  Widget infoColumn(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: MyStyles.regularText(
                  size: 14, color: AppTheme.graySubTitleColor)),
          const SizedBox(height: 2),
          Text(value,
              style: MyStyles.regularText(
                  size: 14, color: AppTheme.black_Color)),
        ],
      ),
    );
  }

  Widget divider() => const Divider(height: 20);
}