import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback button;
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.button,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: (){
        button();
      },
      child: Container(
        padding: EdgeInsets.all(width * 0.035), // ✅ responsive padding
        constraints: const BoxConstraints(minHeight: 120), // ✅ prevents collapse
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween, // ✅ no Spacer issue
          children: [

            /// 🔹 TOP ROW
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis, // ✅ no overflow
                    style: MyStyles.boldText(
                      size: width * 0.04, // ✅ responsive font
                      color: AppTheme.black_Color,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                CircleAvatar(
                  radius: width * 0.045, // ✅ responsive icon size
                  backgroundColor: color.withOpacity(0.2),
                  child: Icon(
                    icon,
                    size: width * 0.045,
                    color: color,
                  ),
                )
              ],
            ),

            /// 🔹 VALUE TEXT
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: MyStyles.boldText(
                  size: width * 0.065, // ✅ responsive value
                  color: AppTheme.black_Color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}