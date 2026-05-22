import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';

import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/screens/admin/admin_home/admin_dashboard.dart';

import 'package:idmitra/screens/auth/login.dart';
import 'package:idmitra/screens/dashboard/dashboard.dart';
import 'package:idmitra/services/update_service.dart';
import 'package:idmitra/utils/navigation_utils.dart';


import 'package:page_transition/page_transition.dart';

import '../add_school/add_newschool.dart';
import '../staff/staff_home/staff_dashboard.dart';


class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);

    _controller.forward(); // Start animation

    Timer(const Duration(seconds: 3), () {
      navigationToScreen();
    });
  }

  void navigationToScreen() async {
    var token = await UserSecureStorage.fetchToken();
    var accountType = await UserSecureStorage.fetchRole();
    print('token----------->$token');
    if (token != null && token.isNotEmpty) {
      if(accountType == "partner"){
        navigateAndRemoveUntil(
          context: context,
          page: Dashboard(index: 0,),
          transition: PageTransitionType.rightToLeft,
        );
      }else if (accountType != 'partner' && accountType != 'super_admin' && accountType != 'school_admin') {
        navigateAndRemoveUntil(
          context: context,
          page:  StaffDashboard(),
          transition: PageTransitionType.rightToLeft,
        );
      } else {
        navigateAndRemoveUntil(
          context: context,
          page:  AdminDashboard(),
          transition: PageTransitionType.rightToLeft,
        );
      }

    } else {
      navigateAndRemoveUntil(
        context: context,
        page: LoginScreen(),
        transition: PageTransitionType.rightToLeft,
      );
    }

    // Check for app update after navigation
    UpdateService.instance.checkForUpdate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.whiteColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Image.asset(
            "assets/images/app_logo.png",
            width: 250.w,
          ),
        ),
      ),
    );
  }
}
