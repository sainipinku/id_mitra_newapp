import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:idmitra/screens/employee_dashboard/employee_dashboard.dart';
import 'package:idmitra/utils/navigation_utils.dart';

class CorporateCard extends StatefulWidget {
  final Map<String, String> corporateData;
  final Function(String) onImageUpdate;
  final VoidCallback? onDelete;
  final VoidCallback? onStatusToggle;
  final Function(Map<String, String>)? onEdit;

  const CorporateCard({
    super.key,
    required this.corporateData,
    required this.onImageUpdate,
    this.onDelete,
    this.onStatusToggle,
    this.onEdit,
  });

  @override
  State<CorporateCard> createState() => _CorporateCardState();
}

class _CorporateCardState extends State<CorporateCard> {
  File? _localImageFile;

  Future<void> _fromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _fromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _cropImage(pickedFile.path);
    }
  }

  Future<void> _cropImage(String path) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile != null) {
      setState(() {
        _localImageFile = File(croppedFile.path);
      });
      widget.onImageUpdate(croppedFile.path);
    }
  }

  void showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Image",
                style: MyStyles.boldText(size: 14, color: Colors.black),
              ),
              const SizedBox(height: 15),
              _pickerItem(
                icon: Icons.camera_alt_outlined,
                title: "Camera",
                onTap: () {
                  Navigator.pop(context);
                  _fromCamera();
                },
              ),
              _divider(),
              _pickerItem(
                icon: Icons.image_outlined,
                title: "Gallery",
                onTap: () {
                  Navigator.pop(context);
                  _fromGallery();
                },
              ),
              _divider(),
              _pickerItem(
                icon: Icons.delete_outline,
                title: "Remove Photo",
                color: Colors.red,
                onTap: () {
                  setState(() {
                    _localImageFile = null;
                  });
                  widget.onImageUpdate("");
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: MyStyles.regularText(size: 14, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: Colors.grey.shade300);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onEdit != null) {
          widget.onEdit!(widget.corporateData);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            /// PROFILE IMAGE WITH CAMERA ICON
            Stack(
              children: [
                GestureDetector(
                  onTap: () => showPicker(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildImage(),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => showPicker(context),
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(width: 12),

            /// DETAILS
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.corporateData['name']!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        "• Corporate",
                        style: MyStyles.boldText(size: 14, color: AppTheme.btnColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on, size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          widget.corporateData['address']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 15, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        widget.corporateData['date']!,
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: (widget.corporateData['status'] ?? '1') == '1'
                          ? AppTheme.activeBtn10perOpacityColor
                          : AppTheme.redBtnBgColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      (widget.corporateData['status'] ?? '1') == '1' ? "ACTIVE" : "INACTIVE",
                      style: MyStyles.boldText(
                        size: 10,
                        color: (widget.corporateData['status'] ?? '1') == '1'
                            ? AppTheme.activeBtn
                            : AppTheme.redBtnBgColor,
                      ),
                    ),
                  )
                ],
              ),
            ),

            /// POPUP MENU
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.grey),
              onSelected: (value) {
                if (value == 'delete' && widget.onDelete != null) {
                  widget.onDelete!();
                } else if (value == 'toggle' && widget.onStatusToggle != null) {
                  widget.onStatusToggle!();
                } else if (value == 'edit' && widget.onEdit != null) {
                  widget.onEdit!(widget.corporateData);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        (widget.corporateData['status'] ?? '1') == '1'
                            ? Icons.toggle_on
                            : Icons.toggle_off,
                        size: 22,
                        color: (widget.corporateData['status'] ?? '1') == '1'
                            ? Colors.green
                            : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        (widget.corporateData['status'] ?? '1') == '1'
                            ? 'Deactivate'
                            : 'Activate',
                      ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_localImageFile != null) {
      return Image.file(
        _localImageFile!,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
      );
    }

    final logoUrl = widget.corporateData['logo']!;
    if (logoUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: logoUrl,
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else if (logoUrl.isNotEmpty) {
      return Image.file(
        File(logoUrl),
        height: 60,
        width: 60,
        fit: BoxFit.cover,
      );
    }

    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      height: 60,
      width: 60,
      color: Colors.grey.shade300,
      child: const Icon(Icons.business, color: Colors.grey),
    );
  }
}
