import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/bottom_diloag/logout.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/config/sharedpref.dart';
import 'package:idmitra/providers/admin_dashboard/admin_dashboard_cubit.dart';
import 'package:idmitra/providers/login_auth/login_cubit.dart';
import 'package:idmitra/screens/WebViewPage/WebViewPage.dart';
import 'package:idmitra/screens/auth/login.dart';
import 'package:idmitra/screens/edit_profile/edit_profile.dart';
import 'package:idmitra/utils/navigation_utils.dart';

class AdminProfilePage extends StatelessWidget {
  const AdminProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // AdminDashboardCubit is passed via BlocProvider.value from AdminDashboard
    return BlocProvider(
      create: (_) => LoginCubit(),
      child: const _AdminProfileView(),
    );
  }
}

class _AdminProfileView extends StatelessWidget {
  const _AdminProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(title: 'Profile Setting', backgroundColor: Colors.white),
      body: BlocListener<LoginCubit, LoginState>(
        listener: (context, state) {
          if (state is LogoutSuccess) {
            SharedPref.removeAll();
            UserSecureStorage.deleteAll();
            navigateAndRemoveUntil(context: context, page: const LoginScreen());
          }
        },
        child: Column(
          children: [
            _ProfileHeader(),
            const Divider(height: 1),
            Expanded(child: _MenuSection()),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminDashboardCubit, AdminDashboardState>(
      builder: (context, state) {
        if (state.loading) {
          return const ProfileHeaderShimmer();
        }

        final user = state.dashboard?.data.user;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Column(
            children: [
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 55,
                backgroundColor: const Color(0xFFE0E0E0),
                backgroundImage: (user?.profilePhotoUrl.isNotEmpty == true &&
                        !(user?.profilePhotoUrl.contains('ui-avatars.com') ?? false))
                    ? NetworkImage(user!.profilePhotoUrl)
                    : null,
                child: ((user?.profilePhotoUrl.isEmpty ?? true) ||
                        (user?.profilePhotoUrl.contains('ui-avatars.com') ?? false))
                    ? const Icon(Icons.person, size: 50, color: Colors.grey)
                    : null,
              ),
              const SizedBox(height: 16),
              Text(
                user?.name ?? '',
                style: MyStyles.boldText(size: 18, color: AppTheme.black_Color),
              ),
              const SizedBox(height: 4),
              Text(
                user?.email ?? '',
                style: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
              ),
              if ((user?.phone ?? '').isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  user!.phone,
                  style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _MenuSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _menuItem(context, "Edit Profile", Icons.person_outline, () {
          navigateWithTransition(context: context, page: const EditProfilePage());
        }),
        const Divider(height: 1),
        _menuItem(context, "Privacy & Policy", Icons.privacy_tip, () {
          navigateWithTransition(
            context: context,
            page: WebViewPage(url: 'https://idmitra.com/privacy-policy', title: 'Privacy & Policy'),
          );
        }),
        const Divider(height: 1),
        _menuItem(context, "Terms & Conditions", Icons.description, () {
          navigateWithTransition(
            context: context,
            page: WebViewPage(url: 'https://idmitra.com/term-and-condition', title: 'Terms & Conditions'),
          );
        }),
        const Divider(height: 1),
        _menuItem(context, "Logout", Icons.logout, () {
          LogoutBottomDilog(
            buildContext: context,
            title: 'Logout',
            desc: 'Are you sure you want to logout?',
            button: () => context.read<LoginCubit>().constLogoutFun(),
          );
        }, isLogout: true),
      ],
    );
  }

  Widget _menuItem(BuildContext context, String title, IconData icon, VoidCallback onTap,
      {bool isLogout = false}) {
    return ListTile(
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.black),
      title: Text(title, style: TextStyle(color: isLogout ? Colors.red : Colors.black)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
