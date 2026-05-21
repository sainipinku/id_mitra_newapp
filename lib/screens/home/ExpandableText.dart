import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
class ExpandableText extends StatefulWidget {
  final String text;

  const ExpandableText({super.key, required this.text});

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: isExpanded ? null : 1, // 👈 2 line limit
          overflow: isExpanded
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
          style: MyStyles.regularText(
            size: 12,
            color: AppTheme.redBtnBgColor,
          ),
        ),

        /// 🔹 SEE MORE / LESS
        GestureDetector(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Text(
            isExpanded ? "See less" : "See more",
            style: MyStyles.mediumText(
              size: 12,
              color: AppTheme.greenColor,
            ),
          ),
        ),
      ],
    );
  }
}