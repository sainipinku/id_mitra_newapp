
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/svg_file.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/screens/backup_global_data/backup_global_data_screen.dart';



import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/providers/home/home_cubit.dart';
import 'package:idmitra/screens/profile_setting/profile_setting.dart';
import 'package:idmitra/utils/navigation_utils.dart';


class CommonAppBar extends StatelessWidget
    implements PreferredSizeWidget {

  final String title;
  final List<Widget>? actions;
  final bool showText;
  final bool showBackButton;
  final bool isGradient;
  final bool isGlass;
  final bool showDivider;
  final double elevation;
  final Color backgroundColor;
  final Color titleColor;
  final VoidCallback? onBackPressed;

  const CommonAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showText = true,
    this.showBackButton = true,
    this.isGradient = false,
    this.isGlass = false,
    this.showDivider = false,
    this.elevation = 0,
    this.backgroundColor = Colors.white,
    this.titleColor = Colors.black,
    this.onBackPressed,
  });

  @override
  Widget build(BuildContext context) {

    Widget appBarContent = AppBar(
      elevation: elevation,
      automaticallyImplyLeading: false,
      centerTitle: true,
      backgroundColor:
      isGradient || isGlass ? Colors.transparent : backgroundColor,
      surfaceTintColor: Colors.transparent,

      leading: showBackButton
          ? Padding(
        padding: const EdgeInsets.all(10.0),
        child: _modernBackButton(context),
      )
          : null,

      title: showText
          ? AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Text(
          title,
          key: ValueKey(title),
          style: MyStyles.boldText(
            size: 20,
            color: titleColor,
          ),
        ),
      )
          : null,

      actions: actions,
    );

    /// 🔥 Gradient Effect
    if (isGradient) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xff667eea),
              Color(0xff764ba2),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: appBarContent,
      );
    }

    /// 🔥 Glass Effect
    if (isGlass) {
      return ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              border: showDivider
                  ? Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                ),
              )
                  : null,
            ),
            child: appBarContent,
          ),
        ),
      );
    }

    /// Default Style with optional divider
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showDivider
            ? Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
          ),
        )
            : null,
      ),
      child: appBarContent,
    );
  }

  /// 🔥 Modern Circular Back Button
  Widget _modernBackButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.rectangle,
            border: Border.all(color: AppTheme.titleHintColor),
            borderRadius: BorderRadius.all(Radius.circular(8),)
          ),
          child: const Padding(
            padding: EdgeInsets.all(5.0),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
PreferredSizeWidget dashboardAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    title: BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {

        /// 🔄 LOADING
        if (state.loading) {
          return const DashboardAppBarShimmer();
        }

        /// ✅ SUCCESS
        else if (state.dashboard != null) {
          final data = state.user?.user;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [

                /// Profile Image
                CachedNetworkImage(
                  imageUrl: data?.profilePhotoUrl ?? '',
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 20,
                    backgroundImage: imageProvider,
                  ),
                  placeholder: (context, url) => CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    child: const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey.shade200,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),

                const SizedBox(width: 12),

                /// Name + ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data?.name ?? '',
                        style: MyStyles.boldText(size: 20, color: AppTheme.black_Color),
                      ),
                      Text(
                        "ID Mitra partner",
                        style: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
                      ),
                    ],
                  ),
                ),

                /// Notification Icon
                Stack(
                  children: [
                    IconButton(
                      icon: Container(
                          height: 70,
                          width: 70,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.btn10perOpacityColor
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(3.0),
                            child: svgIcon(icon: 'assets/icons/home/notification.svg', clr: AppTheme.btnColor,),
                          )),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BackupGlobalDataScreen(),
                          ),
                       );
                      },
                    ),

                    /// Notification Badge
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
                          "1",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )
                  ],
                ),

                /// Setting Icon
                IconButton(
                  icon: Container(
                      height: 70,
                      width: 70,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.btn10perOpacityColor
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3.0),
                        child: svgIcon(icon: 'assets/icons/home/user-profile.svg', clr: AppTheme.btnColor,),
                      )),
                  onPressed: () {
                    navigateWithTransition(
                      context: context,
                      page: ProfileSetting(),
                    );
                  },
                ),
              ],
            ),
          );
        }

        /// ❌ ERROR / FALLBACK
        else {
          return const Center(
            child: Text("Something went wrong"),
          );
        }
      },
    )
    ,
  );
}
Widget commonButton({
  required Color color,
  required String text,
  required VoidCallback button,
  double? borderRadius,
}) {
  return GestureDetector(
    onTap: () {
      // Custom tap logic
    },
    child: SizedBox(
      height: 45.h,
      width: double.infinity, // Set to full width
      child: ElevatedButton(
        onPressed: button,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 25.0),
          ),
        ),
        child: Text(
          text,
          style: GoogleFonts.roboto(
            color: AppTheme.whiteColor,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
  );
}