import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/providers/home/home_cubit.dart';
import 'package:idmitra/screens/dashboard/home.dart';
// import 'package:idmitra/screens/dashboard/reports.dart';
import 'package:idmitra/screens/dashboard/users/users.dart';
import 'package:idmitra/screens/dashboard/setting.dart';
import 'package:idmitra/screens/home/student_list.dart';

class Dashboard extends StatefulWidget {
  int index;
   Dashboard({super.key,required this.index});

  @override
  State<Dashboard> createState() =>
      _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;
  static const TextStyle optionStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );
  static const List<Widget> _widgetOptions = <Widget>[
    Home(),
    // Reports(),
    Schools(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  late HomeCubit homeCubit;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.index;
    homeCubit = context.read<HomeCubit>();
    homeCubit.loadHomeData();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: dashboardAppBar(context),
      body: Center(child: _widgetOptions.elementAt(_selectedIndex)),
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

                  items:  [
                    BottomNavigationBarItem(
                        icon: svgIcon(icon: 'assets/icons/home/home.svg', clr: _selectedIndex == 0 ? AppTheme.btnColor : AppTheme.black_Color,), label: "Dashboard"),
                    // BottomNavigationBarItem(
                    //     icon: svgIcon(icon: 'assets/icons/home/report.svg', clr: _selectedIndex == 1 ? AppTheme.btnColor : AppTheme.black_Color,), label: "Reports"),
                    BottomNavigationBarItem(
                        icon: svgIcon(icon: 'assets/icons/home/school.svg', clr: _selectedIndex == 1 ? AppTheme.btnColor : AppTheme.black_Color,), label: "Schools"),

                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}