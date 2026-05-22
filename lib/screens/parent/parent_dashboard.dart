import 'package:flutter/material.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/utils/MyStyles.dart';
// import 'package:idmitra/screens/parent/mark_leave_screen.dart';
// import 'package:idmitra/screens/parent/view_homework_screen.dart';
// import 'package:idmitra/screens/parent/fee_status_screen.dart';
// import 'package:smooth_page_indicator/smooth_page_indicator.dart';


class _AbsentNotification {
  final String studentName;
  final String className;
  final String schoolName;
  final String date;
  final String time;
  final bool isRead;

  const _AbsentNotification({
    required this.studentName,
    required this.className,
    required this.schoolName,
    required this.date,
    required this.time,
    this.isRead = false,
  });
}

class _StudentInfo {
  final String name;
  final String rollNo;
  final String className;
  final String schoolName;
  final String section;

  const _StudentInfo({
    required this.name,
    required this.rollNo,
    required this.className,
    required this.schoolName,
    required this.section,
  });
}


const _kParentName = 'Rahul Sharma';
const _kSchoolName = 'Green Valley School';

const _kStudents = [
  _StudentInfo(
    name: 'Aarav Sharma',
    rollNo: 'R-101',
    className: 'Class 5',
    section: 'A',
    schoolName: 'Green Valley School',
  ),
  _StudentInfo(
    name: 'Priya Sharma',
    rollNo: 'R-204',
    className: 'Class 3',
    section: 'B',
    schoolName: 'Green Valley School',
  ),
];

const _kNotifications = [
  _AbsentNotification(
    studentName: 'Aarav Sharma',
    className: 'Class 5A',
    schoolName: 'Green Valley School',
    date: '11 May 2026',
    time: '09:15 AM',
    isRead: false,
  ),
  _AbsentNotification(
    studentName: 'Priya Sharma',
    className: 'Class 3B',
    schoolName: 'Green Valley School',
    date: '10 May 2026',
    time: '09:30 AM',
    isRead: false,
  ),
  _AbsentNotification(
    studentName: 'Aarav Sharma',
    className: 'Class 5A',
    schoolName: 'Green Valley School',
    date: '08 May 2026',
    time: '09:10 AM',
    isRead: true,
  ),
];


const _kAttendanceData = [
  {'day': '1', 'val': 6.0},
  {'day': '2', 'val': 7.0},
  {'day': '3', 'val': 5.0},
  {'day': '4', 'val': 8.0},
  {'day': '5', 'val': 9.0},
  {'day': '6', 'val': 10.0},
  {'day': '7', 'val': 6.0},
  {'day': '8', 'val': 7.0},
  {'day': '9', 'val': 5.0},
  {'day': '10', 'val': 8.0},
  {'day': '11', 'val': 4.0},
  {'day': '12', 'val': 6.0},
  {'day': '13', 'val': 7.0},
  {'day': '14', 'val': 5.0},
  {'day': '15', 'val': 8.0},
  {'day': '16', 'val': 2.0},
  {'day': '17', 'val': 9.0},
  {'day': '18', 'val': 6.0},
  {'day': '19', 'val': 7.0},
  {'day': '20', 'val': 5.0},
  {'day': '21', 'val': 8.0},
  {'day': '22', 'val': 6.0},
  {'day': '23', 'val': 7.0},
  {'day': '24', 'val': 9.0},
  {'day': '25', 'val': 4.0},
  {'day': '26', 'val': 8.0},
  {'day': '27', 'val': 6.0},
  {'day': '28', 'val': 10.0},
  {'day': '29', 'val': 5.0},
  {'day': '30', 'val': 7.0},
  {'day': '31', 'val': 6.0},
];


class ParentDashboard extends StatefulWidget {
  const ParentDashboard({super.key});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: _buildAppBar(),
      body: _selectedIndex == 0 ? _buildHomeTab() : _buildNotificationsTab(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }


  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.btn10perOpacityColor,
              child: Icon(Icons.person, color: AppTheme.btnColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kParentName,
                    style: MyStyles.boldTxt(AppTheme.black_Color, 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _kSchoolName,
                    style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Stack(
              children: [
                IconButton(
                  icon: Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.btn10perOpacityColor,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: svgIcon(
                        icon: 'assets/icons/home/notification.svg',
                        clr: AppTheme.btnColor,
                      ),
                    ),
                  ),
                  onPressed: () => setState(() => _selectedIndex = 1),
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
                      '2',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _onRefresh() async {
    await Future.delayed(const Duration(seconds: 1));
  }

  Widget _buildHomeTab() {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.btnColor,
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          //const _AdBannerSlider(),
          const SizedBox(height: 16),
          _AbsenceAlertCard(student: _kStudents[0]),
          const SizedBox(height: 16),
          _AttendanceStatsRow(),
          const SizedBox(height: 16),
          _MonthlyAttendanceChart(),
          const SizedBox(height: 20),
          _TodayScheduleSection(),
          const SizedBox(height: 20),
          _RecentActivitySection(),
          const SizedBox(height: 20),
          _StudentInfoCard(student: _kStudents[0]),
          const SizedBox(height: 24),
        ],
      ),
    ),
    );
  }


  Widget _buildNotificationsTab() {
    final unread = _kNotifications.where((n) => !n.isRead).toList();
    final read = _kNotifications.where((n) => n.isRead).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unread.isNotEmpty) ...[
            Text('New', style: MyStyles.boldTxt(AppTheme.black_Color, 15)),
            const SizedBox(height: 10),
            ...unread.map((n) => _NotificationCard(notif: n)),
            const SizedBox(height: 16),
          ],
          if (read.isNotEmpty) ...[
            Text('Earlier',
                style: MyStyles.boldTxt(AppTheme.graySubTitleColor, 14)),
            const SizedBox(height: 10),
            ...read.map((n) => _NotificationCard(notif: n)),
          ],
        ],
      ),
    );
  }


  Widget _buildBottomNav() {
    return Padding(
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
            ),
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
              onTap: (i) => setState(() => _selectedIndex = i),
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
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      svgIcon(
                        icon: 'assets/icons/home/notification.svg',
                        clr: _selectedIndex == 1
                            ? AppTheme.btnColor
                            : AppTheme.black_Color,
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            '2',
                            style: TextStyle(color: Colors.white, fontSize: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  label: 'Notifications',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _AbsenceAlertCard extends StatelessWidget {
  final _StudentInfo student;
  const _AbsenceAlertCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: Colors.white.withOpacity(0.6), width: 2),
              color: Colors.white.withOpacity(0.15),
            ),
            child:
                const Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Absence Alert',
                    style: MyStyles.boldTxt(Colors.white, 16)),
                const SizedBox(height: 2),
                Text(student.name,
                    style: MyStyles.semiBoldTxt(Colors.white, 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _chip('Absent Today'),
                    const SizedBox(width: 8),
                    Text(
                      '${student.className}${student.section}',
                      style: MyStyles.regularTxt(
                          Colors.white.withOpacity(0.85), 12),
                    ),
                    const Spacer(),
                    Text(
                      '11 May 2026',
                      style: MyStyles.regularTxt(
                          Colors.white.withOpacity(0.85), 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: MyStyles.mediumTxt(Colors.white, 10)),
    );
  }
}


class _AttendanceStatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatBox(
            label: 'Present', value: '78%', color: AppTheme.btnColor),
        const SizedBox(width: 10),
        _StatBox(label: 'Absent', value: '18%', color: Colors.red),
        const SizedBox(width: 10),
        _StatBox(
            label: 'Leave',
            value: '4%',
            color: const Color(0xFFF2A922)),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBox(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05), blurRadius: 6),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: MyStyles.regularTxt(
                    AppTheme.graySubTitleColor, 11)),
            const SizedBox(height: 4),
            Text(value,
                style: MyStyles.boldTxt(AppTheme.black_Color, 20)),
            const SizedBox(height: 4),
            Container(
              height: 3,
              width: 28,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _MonthlyAttendanceChart extends StatefulWidget {
  @override
  State<_MonthlyAttendanceChart> createState() =>
      _MonthlyAttendanceChartState();
}

class _MonthlyAttendanceChartState
    extends State<_MonthlyAttendanceChart> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final absentIndex = _kAttendanceData.indexWhere(
            (e) => (e['val'] as double) <= 3,
      );

      if (absentIndex != -1) {
        final offset = absentIndex * 28.0;

        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    color: AppTheme.btnColor,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Monthly Attendance',
                    style: MyStyles.boldTxt(
                      AppTheme.black_Color,
                      14,
                    ),
                  ),
                ],
              ),
              Text(
                'May 2026',
                style: MyStyles.regularTxt(
                  AppTheme.graySubTitleColor,
                  12,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          SizedBox(
            height: 160,
            child: Row(
              children: [
                Column(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                  CrossAxisAlignment.end,
                  children: ['10', '8', '6', '4', '2', '0']
                      .map(
                        (e) => Text(
                      e,
                      style: MyStyles.regularTxt(
                        AppTheme.graySubTitleColor,
                        9,
                      ),
                    ),
                  )
                      .toList(),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width:
                      _kAttendanceData.length * 28,
                      child: Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.end,
                        children:
                        _kAttendanceData.map((d) {
                          final day =
                          d['day'] as String;
                          final val =
                          d['val'] as double;

                          final bool isAbsent =
                              val <= 3;

                          final double barHeight =
                              (val / 10) * 100;

                          return Padding(
                            padding:
                            const EdgeInsets
                                .symmetric(
                                horizontal: 4),
                            child: Column(
                              mainAxisAlignment:
                              MainAxisAlignment.end,
                              children: [
                                if (isAbsent)
                                  Container(
                                    margin:
                                    const EdgeInsets
                                        .only(
                                        bottom: 6),
                                    padding:
                                    const EdgeInsets
                                        .symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration:
                                    BoxDecoration(
                                      color: Colors.red,
                                      borderRadius:
                                      BorderRadius
                                          .circular(
                                          8),
                                    ),
                                    child: Text(
                                      'Absent',
                                      style: MyStyles
                                          .boldTxt(
                                        Colors.white,
                                        8,
                                      ),
                                    ),
                                  ),

                                Container(
                                  width: 18,
                                  height: barHeight,
                                  decoration:
                                  BoxDecoration(
                                    color: isAbsent
                                        ? Colors.red
                                        : AppTheme
                                        .btnColor
                                        .withOpacity(
                                        0.25),
                                    borderRadius:
                                    BorderRadius
                                        .circular(6),
                                  ),
                                ),

                                const SizedBox(
                                    height: 6),

                                Text(
                                  day,
                                  style:
                                  MyStyles.regularTxt(
                                    isAbsent
                                        ? Colors.red
                                        : AppTheme
                                        .graySubTitleColor,
                                    10,
                                  ),
                                ),

                                const SizedBox(
                                    height: 4),

                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration:
                                  BoxDecoration(
                                    color: isAbsent
                                        ? Colors.red
                                        : Colors
                                        .transparent,
                                    shape:
                                    BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



const _kSchedule = [
  {'subject': 'Mathematics', 'time': '08:00 – 08:45', 'teacher': 'Mr. Sharma', 'icon': Icons.calculate_outlined, 'color': Color(0xFF1565C0)},
  {'subject': 'Science', 'time': '09:00 – 09:45', 'teacher': 'Ms. Verma', 'icon': Icons.science_outlined, 'color': Color(0xFF2E7D32)},
  {'subject': 'English', 'time': '10:00 – 10:45', 'teacher': 'Mrs. Gupta', 'icon': Icons.menu_book_outlined, 'color': Color(0xFF6A1B9A)},
  {'subject': 'Social Studies', 'time': '11:00 – 11:45', 'teacher': 'Mr. Patel', 'icon': Icons.public_outlined, 'color': Color(0xFFE65100)},
];

class _TodayScheduleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's Schedule", style: MyStyles.boldTxt(AppTheme.black_Color, 16)),
            Text('Mon, 11 May', style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 12)),
          ],
        ),
        const SizedBox(height: 12),
        ..._kSchedule.map((s) => _ScheduleTile(
              subject: s['subject'] as String,
              time: s['time'] as String,
              teacher: s['teacher'] as String,
              icon: s['icon'] as IconData,
              color: s['color'] as Color,
            )),
      ],
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final String subject, time, teacher;
  final IconData icon;
  final Color color;
  const _ScheduleTile({required this.subject, required this.time, required this.teacher, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject, style: MyStyles.semiBoldTxt(AppTheme.black_Color, 13)),
                const SizedBox(height: 2),
                Text(teacher, style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(time, style: MyStyles.mediumTxt(color, 10)),
          ),
        ],
      ),
    );
  }
}


const _kActivities = [
  {'title': 'Homework Submitted', 'desc': 'Mathematics – Chapter 5 Exercise', 'time': 'Today, 10:30 AM', 'icon': Icons.task_alt_rounded, 'color': Color(0xFF2E7D32)},
  {'title': 'Fee Payment Due', 'desc': 'Term 2 fee due on 15 May 2026', 'time': 'Yesterday', 'icon': Icons.receipt_long_outlined, 'color': Color(0xFFE65100)},
  {'title': 'Test Result', 'desc': 'Science Unit Test – 42/50', 'time': '09 May 2026', 'icon': Icons.emoji_events_outlined, 'color': Color(0xFF1565C0)},
  {'title': 'Leave Approved', 'desc': 'Leave on 08 May was approved', 'time': '08 May 2026', 'icon': Icons.event_available_outlined, 'color': Color(0xFF6A1B9A)},
];

class _RecentActivitySection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity', style: MyStyles.boldTxt(AppTheme.black_Color, 16)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: Column(
            children: List.generate(_kActivities.length, (i) {
              final a = _kActivities[i];
              final isLast = i == _kActivities.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: (a['color'] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(a['icon'] as IconData, color: a['color'] as Color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a['title'] as String, style: MyStyles.semiBoldTxt(AppTheme.black_Color, 13)),
                              const SizedBox(height: 2),
                              Text(a['desc'] as String, style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        Text(a['time'] as String, style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 10)),
                      ],
                    ),
                  ),
                  if (!isLast) Divider(height: 1, indent: 64, color: Colors.grey.shade100),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}


class _StudentInfoCard extends StatelessWidget {
  final _StudentInfo student;
  const _StudentInfoCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.btnColor, AppTheme.btnColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: AppTheme.btnColor.withOpacity(0.3), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Row(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name, style: MyStyles.boldTxt(Colors.white, 16)),
                const SizedBox(height: 4),
                Text('${student.className} – Section ${student.section}', style: MyStyles.regularTxt(Colors.white.withOpacity(0.85), 12)),
                const SizedBox(height: 4),
                Text('Roll No: ${student.rollNo}', style: MyStyles.regularTxt(Colors.white.withOpacity(0.75), 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                child: Text('Active', style: MyStyles.boldTxt(Colors.white, 11)),
              ),
              const SizedBox(height: 8),
              Text(student.schoolName, style: MyStyles.regularTxt(Colors.white.withOpacity(0.7), 10), textAlign: TextAlign.end),
            ],
          ),
        ],
      ),
    );
  }
}

// Quick Actions (commented out)
/*
class _QuickActionsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions',
            style: MyStyles.boldTxt(AppTheme.black_Color, 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionTile(
              label: 'Mark Leave',
              icon: Icons.event_busy_outlined,
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const MarkLeaveScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _ActionTile(
              label: 'View Homework',
              icon: Icons.menu_book_outlined,
              color: AppTheme.btnColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ViewHomeworkScreen()),
              ),
            ),
            const SizedBox(width: 12),
            _ActionTile(
              label: 'Fee Status',
              icon: Icons.receipt_long_outlined,
              color: Colors.green,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const FeeStatusScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: MyStyles.regularTxt(AppTheme.black_Color, 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}


class _MessageSection extends StatefulWidget {
  @override
  State<_MessageSection> createState() => _MessageSectionState();
}

class _MessageSectionState extends State<_MessageSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Message',
            style: MyStyles.boldTxt(AppTheme.black_Color, 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05), blurRadius: 6),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: MyStyles.regularTxt(AppTheme.black_Color, 13),
                  decoration: InputDecoration(
                    hintText: 'Send Message to Teacher',
                    hintStyle: MyStyles.regularTxt(
                        AppTheme.graySubTitleColor, 13),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  if (_controller.text.trim().isNotEmpty) {
                    _controller.clear();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.btnColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('Send',
                      style: MyStyles.semiBoldTxt(Colors.white, 13)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
*/

class _NotificationCard extends StatelessWidget {
  final _AbsentNotification notif;
  const _NotificationCard({required this.notif});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: notif.isRead
            ? Border.all(color: Colors.grey.shade200, width: 1)
            : Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: notif.isRead
                ? Colors.black.withOpacity(0.03)
                : Colors.red.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 75,
              decoration: BoxDecoration(
                gradient: notif.isRead
                    ? LinearGradient(
                        colors: [Colors.grey.shade300, Colors.grey.shade400],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: notif.isRead
                            ? Colors.grey.shade100
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.event_busy_rounded,
                        color: notif.isRead
                            ? Colors.grey.shade500
                            : Colors.red.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.studentName,
                                  style: MyStyles.boldTxt(
                                    notif.isRead
                                        ? AppTheme.black_Color
                                        : Colors.red.shade800,
                                    13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!notif.isRead) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: MyStyles.boldTxt(Colors.white, 8),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Marked Absent • ${notif.className}',
                            style: MyStyles.regularTxt(
                                AppTheme.graySubTitleColor, 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.schedule,
                                  size: 10,
                                  color: AppTheme.graySubTitleColor),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${notif.date} at ${notif.time}',
                                  style: MyStyles.regularTxt(
                                      AppTheme.graySubTitleColor, 9),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Arrow
                    Icon(
                      Icons.chevron_right_rounded,
                      color: notif.isRead
                          ? Colors.grey.shade400
                          : AppTheme.btnColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


//
// const _kBannerData = [
//   _BannerItem(
//     gradient: [Color(0xFF1565C0), Color(0xFF42A5F5)],
//     title: 'IDMitra Smart ID Cards',
//     subtitle: 'Digital identity for every student',
//     tag: 'New',
//     icon: Icons.badge_outlined,
//   ),
//   _BannerItem(
//     gradient: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
//     title: 'Attendance Tracking',
//     subtitle: 'Real-time updates for parents',
//     tag: 'Feature',
//     icon: Icons.fact_check_outlined,
//   ),
//   _BannerItem(
//     gradient: [Color(0xFF6A1B9A), Color(0xFFAB47BC)],
//     title: 'Fee Management',
//     subtitle: 'Pay fees online, anytime',
//     tag: 'Easy',
//     icon: Icons.account_balance_wallet_outlined,
//   ),
//   _BannerItem(
//     gradient: [Color(0xFFE65100), Color(0xFFFFA726)],
//     title: 'Homework Alerts',
//     subtitle: 'Never miss an assignment',
//     tag: 'Smart',
//     icon: Icons.menu_book_outlined,
//   ),
// ];
//
// class _BannerItem {
//   final List<Color> gradient;
//   final String title;
//   final String subtitle;
//   final String tag;
//   final IconData icon;
//   const _BannerItem({
//     required this.gradient,
//     required this.title,
//     required this.subtitle,
//     required this.tag,
//     required this.icon,
//   });
// }
//
// class _AdBannerSlider extends StatefulWidget {
//   const _AdBannerSlider();
//
//   @override
//   State<_AdBannerSlider> createState() => _AdBannerSliderState();
// }
//
// class _AdBannerSliderState extends State<_AdBannerSlider> {
//   final PageController _pageController = PageController();
//   int _currentPage = 0;
//
//   @override
//   void initState() {
//     super.initState();
//     _startAutoSlide();
//   }
//
//   void _startAutoSlide() {
//     Future.delayed(const Duration(seconds: 3), () {
//       if (!mounted) return;
//       final next = (_currentPage + 1) % _kBannerData.length;
//       _pageController.animateToPage(
//         next,
//         duration: const Duration(milliseconds: 500),
//         curve: Curves.easeInOut,
//       );
//       _startAutoSlide();
//     });
//   }
//
//   @override
//   void dispose() {
//     _pageController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         SizedBox(
//           height: 140,
//           child: PageView.builder(
//             controller: _pageController,
//             itemCount: _kBannerData.length,
//             onPageChanged: (i) => setState(() => _currentPage = i),
//             itemBuilder: (context, index) {
//               final banner = _kBannerData[index];
//               return _BannerCard(banner: banner);
//             },
//           ),
//         ),
//         const SizedBox(height: 10),
//         SmoothPageIndicator(
//           controller: _pageController,
//           count: _kBannerData.length,
//           effect: ExpandingDotsEffect(
//             activeDotColor: AppTheme.btnColor,
//             dotColor: AppTheme.btnColor.withOpacity(0.25),
//             dotHeight: 6,
//             dotWidth: 6,
//             expansionFactor: 3,
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// class _BannerCard extends StatelessWidget {
//   final _BannerItem banner;
//   const _BannerCard({required this.banner});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(horizontal: 2),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           colors: banner.gradient,
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: [
//           BoxShadow(
//             color: banner.gradient.last.withOpacity(0.35),
//             blurRadius: 12,
//             offset: const Offset(0, 6),
//           ),
//         ],
//       ),
//       child: Stack(
//         children: [
//           // Background decorative circle
//           Positioned(
//             right: -20,
//             top: -20,
//             child: Container(
//               width: 120,
//               height: 120,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.08),
//               ),
//             ),
//           ),
//           Positioned(
//             right: 20,
//             bottom: -30,
//             child: Container(
//               width: 80,
//               height: 80,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 color: Colors.white.withOpacity(0.06),
//               ),
//             ),
//           ),
//           // Content
//           Padding(
//             padding: const EdgeInsets.all(18),
//             child: Row(
//               children: [
//                 Expanded(
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 8, vertical: 3),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           banner.tag,
//                           style: MyStyles.boldTxt(Colors.white, 9),
//                         ),
//                       ),
//                       const SizedBox(height: 8),
//                       Text(
//                         banner.title,
//                         style: MyStyles.boldTxt(Colors.white, 16),
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         banner.subtitle,
//                         style: MyStyles.regularTxt(
//                             Colors.white.withOpacity(0.85), 12),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 16),
//                 Container(
//                   width: 64,
//                   height: 64,
//                   decoration: BoxDecoration(
//                     shape: BoxShape.circle,
//                     color: Colors.white.withOpacity(0.15),
//                     border: Border.all(
//                         color: Colors.white.withOpacity(0.3), width: 1.5),
//                   ),
//                   child: Icon(banner.icon, color: Colors.white, size: 30),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
