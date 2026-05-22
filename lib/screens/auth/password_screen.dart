import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:idmitra/Widgets/snack_bar_widget.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/providers/login_auth/login_cubit.dart';
import 'package:idmitra/screens/auth/ConfirmPasswordTextField.dart';
import 'package:idmitra/screens/auth/PasswordTextField.dart';
import 'package:idmitra/screens/dashboard/dashboard.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:idmitra/utils/navigation_utils.dart';
import 'package:page_transition/page_transition.dart';

import '../admin/admin_home/admin_dashboard.dart';
import '../staff/staff_home/staff_dashboard.dart';



class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final formkey = GlobalKey<FormState>();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final pinController = TextEditingController();
  final confirmPinController = TextEditingController();
  late LoginCubit loginCubit;
  late BuildContext buildContext;
  initCubit() {
    loginCubit = context.read<LoginCubit>();
  }
  @override
  void initState() {
    // TODO: implement initState
    initCubit();
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: AppTheme.appBackgroundColor),
      body: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LoginLoading) {
            showDialog(
              barrierDismissible: false,
              context: context,
              builder: (_ctx) {
                return Dialog(
                  backgroundColor: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppTheme.progressLowColor,
                        ),
                        SizedBox(height: 10.h),
                        const Text('Loading...'),
                      ],
                    ),
                  ),
                );
              },
            );
          } else if (state is PasswordSuccess) {
            final userType = state.userType;
            if (userType == 'school_staff') {
              navigateAndRemoveUntil(
                context: context,
                page:  StaffDashboard(),
                transition: PageTransitionType.rightToLeft,
              );
            } else if (userType == 'school_admin' || userType == 'super_admin') {
              navigateAndRemoveUntil(
                context: context,
                page:  AdminDashboard(),
                transition: PageTransitionType.rightToLeft,
              );
            } else {
              navigateAndRemoveUntil(
                context: context,
                page: Dashboard(index: 0),
                transition: PageTransitionType.rightToLeft,
              );
            }
          } else if (state is LoginNoFound) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              state.message,
              Icons.done,
              Colors.green,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          }
          else if (state is LoginResendSuccess) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              'Otp sent successfully',
              Icons.done,
              Colors.green,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          } else if (state is LoginFailed) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              'Failed to send an OTP.',
              Icons.warning,
              Colors.red,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          } else if (state is LoginOnHold) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              'Your account on holding contact with owner!!',
              Icons.warning,
              Colors.red,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          } else if (state is LoginTimeout) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              'Time out exception',
              Icons.warning,
              Colors.red,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          } else if (state is LoginInternetError) {
            Navigator.of(context).pop();
            final _snackBar = snackBar(
              'Internet connection failed.',
              Icons.wifi,
              Colors.red,
            );

            ScaffoldMessenger.of(context).showSnackBar(_snackBar);
          }
        },
        child: SafeArea(
          child: Column(
            children: [
              /// 🔹 Scrollable Content
              Expanded(
                child: Form(
                  key: formkey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 40),

                        Image.asset('assets/images/login_top_img.png'),

                        const SizedBox(height: 30),

                        Text(
                          "Set Your Security",
                          style: MyStyles.boldText(
                            size: 16,
                            color: AppTheme.black_Color,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Create a secure password and PIN to protect your account.",
                          textAlign: TextAlign.center,
                          style: MyStyles.regularText(
                            size: 14,
                            color: AppTheme.garyColor,
                          ),
                        ),

                        const SizedBox(height: 30),

                        /// Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Create Password",
                                style: MyStyles.boldText(
                                  size: 14,
                                  color: AppTheme.black_Color,
                                ),
                              ),


                              PasswordTextField(controller: passwordController),
                              Text(
                                "Confirm Password",
                                style: MyStyles.boldText(
                                  size: 14,
                                  color: AppTheme.black_Color,
                                ),
                              ),

                              ConfirmPasswordTextField(
                                controller: confirmPasswordController,
                                passwordController: passwordController,
                              ),
                              Text(
                                "Create PIN",
                                style: MyStyles.boldText(
                                  size: 14,
                                  color: AppTheme.black_Color,
                                ),
                              ),


                              phoneNumberTextField(controller: pinController,hintName: "Enter 6-digit PIN",isRequired: false,digitNo: 6),
                              Text(
                                "Confirm Pin Number",
                                style: MyStyles.boldText(
                                  size: 14,
                                  color: AppTheme.black_Color,
                                ),
                              ),

                              phoneNumberTextField(
                                  controller: confirmPinController,hintName: "Enter 6-digit PIN",isRequired: false,digitNo: 6
                              ),
                              const SizedBox(height: 20),

                              AppButton(
                                title: "Save",
                                isLoading: false,
                                color: AppTheme.btnColor,
                                onTap: () {
                                  if (formkey.currentState!.validate()) {
                                    Map<String, String> map = {
                                      "password": passwordController.text.trim(),
                                      "password_confirmation": confirmPasswordController.text.trim(),
                                      "pin": pinController.text.trim(),
                                      "pin_confirmation": confirmPinController.text.trim(),
                                    };
                                    if (formkey.currentState!.validate()) {
                                      loginCubit.constGenratePassPinFun(map);
                                    }
                                  }
                                },
                              ),
                            ].map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: e,
                            ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              /// 🔹 FIXED BOTTOM TEXT ✅
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Text(
                  "By logging in, you agree to our\nTerms of Service and Privacy Policy.",
                  textAlign: TextAlign.center,
                  style: MyStyles.regularText(
                    size: 12,
                    color: AppTheme.garyColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
