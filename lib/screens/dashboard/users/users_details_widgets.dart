import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/screens/dashboard/users/user_details_page.dart';
import 'package:idmitra/utils/navigation_utils.dart';

class UsersDetailsWidgets extends StatefulWidget {
  SchoolDetailsModel? schoolDetailsModel;
  UsersDetailsWidgets({super.key,required this.schoolDetailsModel});

  @override
  State<UsersDetailsWidgets> createState() => _UsersDetailsWidgetsState();
}

class _UsersDetailsWidgetsState extends State<UsersDetailsWidgets> {
  String _formatDate(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),

      child: GestureDetector(
        onTap: (){
          navigateWithTransition(
            context: context,
            page: UserDetailsPage(schoolDetailsModel: widget.schoolDetailsModel,),
          );
        },
        child: Row(
          children: [

            /// PROFILE IMAGE
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: (widget.schoolDetailsModel!.logoUrl != null &&
                  widget.schoolDetailsModel!.logoUrl!.isNotEmpty)
                  ? Image.network(
                widget.schoolDetailsModel!.logoUrl ?? '',
                height: 60,
                width: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 60,
                    width: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: Colors.grey,
                    ),
                  );
                },
              )
                  : Container(
                height: 60,
                width: 60,
                color: Colors.grey.shade300,
                child: const Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.grey,
                ),
              ),
            ),


            const SizedBox(width: 12),

            /// STUDENT DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  Text(
                    widget.schoolDetailsModel!.name ?? '',maxLines: 1,overflow: TextOverflow.ellipsis,
                    style:
                    MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                  ),


                  const SizedBox(height: 3),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on,size: 15,),
                      Expanded(
                        child: Text(
                          widget.schoolDetailsModel!.address ?? '',maxLines: 2,overflow: TextOverflow.ellipsis,
                          style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),


                  Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,size: 15,),
                      Text(
                        widget.schoolDetailsModel?.createdAt != null
                            ? _formatDate(widget.schoolDetailsModel!.createdAt!)
                            : '',
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  /// STATUS BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.activeBtn10perOpacityColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child:  Text(
                      "ACTIVE",
                      style: MyStyles.boldText(size: 10, color: AppTheme.activeBtn),
                    ),
                  )
                ],
              ),
            ),

            /// STATUS BADGE
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.appBackgroundColor,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
              ),
            )
          ],
        ),
      ),
    );
  }
}
