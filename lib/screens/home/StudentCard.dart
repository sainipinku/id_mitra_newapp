import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/helpers/keyboard.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:idmitra/screens/add_student/add_student_form.dart';
import 'package:idmitra/screens/home/student_profile_page.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import '../../providers/students/students_state.dart';

class StudentCard extends StatefulWidget {
  StudentDetailsData studentData;
  final String schoolId;
  final VoidCallback? onEdit;
  StudentCard({super.key, required this.studentData, required this.schoolId, this.onEdit});

  @override
  State<StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<StudentCard> {
  late StudentDetailsData studentDetailsData;
  File? studentProfileImageFile;
  bool isUploading = false;

  /// 📸 Camera — no crop, direct upload

  /// 📸 Camera — fix rotation then direct upload
  Future<void> _fromCamera() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      File rotatedImage = await FlutterExifRotation.rotateImage(
        path: pickedFile.path,
      );

      await _uploadImage(rotatedImage.path);
    }
  }
  /// 🖼 Gallery — crop then upload
  Future<void> _fromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      studentProfileImageFile = File(pickedFile.path);
      await _cropAndUpload();
    }
  }

  /// ✂️ Crop (gallery only)
  Future<void> _cropAndUpload() async {
    if (studentProfileImageFile == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: studentProfileImageFile!.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(title: 'Crop Image', aspectRatioLockEnabled: true),
      ],
    );

    if (croppedFile != null) {
      await _uploadImage(croppedFile.path);
    }
  }

  /// 🔀 Move to extra
  Future<bool> _moveToExtra() async {
    try {
      final response = await ApiManager().postWithoutRequest(
        Config.baseUrl +
            Routes.moveStudentToExtra(
              studentDetailsData.schoolId?.toString() ?? '',
              studentDetailsData.uuid ?? '',
            ),
      );
      return response != null &&
          (response.statusCode == 200 || response.statusCode == 201);
    } catch (e) {
      debugPrint("Move to extra error: $e");
      return false;
    }
  }

  /// ⬆️ Upload image
  Future<void> _uploadImage(String path) async {
    setState(() => isUploading = true);

    try {
      File fixedImage = await FlutterExifRotation.rotateImage(path: path);

      var response = await ApiManager().multiRequestRoute(
        fixedImage.path,
        Config.baseUrl + Routes.updateStudentProfile(studentDetailsData.uuid ?? ''),
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);

        setState(() {
          studentDetailsData = studentDetailsData.copyWith(
            profilePhotoUrl: jsonData['data']['profile_photo_url'],
          );
        });
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    }

    setState(() => isUploading = false);
  }

  /// 📂 Bottom Sheet
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
                icon: 'assets/icons/camera_single.svg',
                title: "Camera",
                onTap: () {
                  Navigator.pop(context);
                  _fromCamera();
                },
              ),

              _divider(),

              _pickerItem(
                icon: 'assets/icons/choose_from_gallery.svg',
                title: "Gallery",
                onTap: () {
                  Navigator.pop(context);
                  _fromGallery();
                },
              ),

       /*       _divider(),

              _pickerItem(
                icon: 'assets/icons/remove_image.svg',
                title: "Remove Photo",
                color: Colors.red,
                onTap: () {
                  setState(() {
                    studentProfileImageFile = null;
                    studentDetailsData = studentDetailsData.copyWith(
                      profilePhotoUrl: "",
                    );
                  });
                  Navigator.pop(context);
                },
              ),*/
            ],
          ),
        );
      },
    );
  }

  Widget _pickerItem({
    required String icon,
    required String title,
    required VoidCallback onTap,
    Color color = Colors.black,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          SvgPicture.asset(icon),
          const SizedBox(width: 10),
          Text(title, style: MyStyles.regularText(size: 14, color: color)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 1,
      color: Colors.grey.shade300,
    );
  }

  @override
  void initState() {
    studentDetailsData = widget.studentData;
    super.initState();
  }

  @override
  void didUpdateWidget(covariant StudentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentData.uuid != widget.studentData.uuid) {
      setState(() {
        studentDetailsData = widget.studentData;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentProfilePage(
              student: studentDetailsData,
              schoolId: widget.schoolId,
            ),
          ),
        ).then((updated) {
          if (updated is StudentDetailsData && mounted) {
            setState(() => studentDetailsData = updated);
          }
        });
      },
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          /// 👤 PROFILE IMAGE
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  final url = studentDetailsData.profilePhotoUrl;
                  if (url != null && url.isNotEmpty) {
                    _showImagePreview(context, url);
                  } else {
                    showPicker(context);
                  }
                },
                child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: isUploading
                    ? const SizedBox(
                        height: 60,
                        width: 60,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (studentDetailsData.profilePhotoUrl != null &&
                          studentDetailsData.profilePhotoUrl!.isNotEmpty)
                    ? Image.network(
                        studentDetailsData.profilePhotoUrl!,
                        height: 60,
                        width: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              ),

              /// 📸 Edit Icon
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: () {

                    final urlPhoto = studentDetailsData.photo;
                    if (urlPhoto != null) {
                      _showImagePreview(context, studentDetailsData.profilePhotoUrl ?? '');
                    } else {
                      showPicker(context);
                    }
                  },
                  child: Container(
                    height: 22,
                    width: 22,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      (studentDetailsData.photo != null && studentDetailsData.photo!.isNotEmpty)
                          ? Icons.preview
                          : Icons.camera_alt,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        studentDetailsData.name ?? '',
                        style: MyStyles.boldText(
                          size: 16,
                          color: AppTheme.black_Color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        "• ${studentDetailsData.datumClass?.nameWithprefix ?? ''}-${studentDetailsData.section?.name ?? ''}",
                        style: MyStyles.boldText(
                          size: 16,
                          color: AppTheme.btnColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // if (studentDetailsData.isOffline) ...[
                    //   const SizedBox(width: 8),
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    //     decoration: BoxDecoration(
                    //       color: Colors.orange.withOpacity(0.1),
                    //       borderRadius: BorderRadius.circular(4),
                    //       border: Border.all(color: Colors.orange, width: 0.5),
                    //     ),
                      //   child: Text(
                      //     "Offline",
                      //     style: MyStyles.mediumText(size: 10, color: Colors.orange),
                      //   ),
                    //   ),
                   // ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  "Father name : ${studentDetailsData.fatherName ?? ''}",
                  style: MyStyles.regularText(
                    size: 12,
                    color: AppTheme.graySubTitleColor,
                  ),
                ),
                const SizedBox(height: 3),
                studentDetailsData.missingFields!.isNotEmpty ?
                Text(
                  "Missing details: ${studentDetailsData.missingFields?.map((e) => _formatField(e.toString())).join(', ') ?? ''}",
                  style: MyStyles.regularText(
                    size: 12,
                    color: AppTheme.redBtnBgColor,
                  ),
                ) : SizedBox(),
              ],
            ),
          ),

          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (value) async {
              if (value == 'edit') {
                widget.onEdit?.call();
              } else if (value == 'delete') {
                _confirmDelete(context);
              } else if (value == 'extra') {
                final success = await context
                    .read<StudentsCubit>()
                    .moveStudentToExtra(
                      studentDetailsData.uuid ?? '',
                      studentDetailsData.schoolId?.toString() ?? widget.schoolId,
                    );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Student moved to extra list'
                            : 'Failed to move student to extra',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } else if (value == 'toggle') {
                final success = await context
                    .read<StudentsCubit>()
                    .toggleStudentStatus(
                      studentDetailsData.uuid ?? '',
                      studentDetailsData.schoolId?.toString() ?? widget.schoolId,
                      studentDetailsData.status ?? 0,
                    );
                if (success) {
                  final updated = context
                      .read<StudentsCubit>()
                      .state
                      .studentsList
                      .firstWhere(
                        (s) => s.uuid == studentDetailsData.uuid,
                        orElse: () => studentDetailsData,
                      );
                  setState(() => studentDetailsData = updated);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success ? 'Status updated' : 'Failed to update status',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'extra',
                child: Row(
                  children: [
                    Icon(Icons.move_to_inbox, size: 18, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Extra'),
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
              PopupMenuItem(
                value: 'toggle',
                child: Row(
                  children: [
                    Icon(
                      (studentDetailsData.status ?? 0) == 1
                          ? Icons.toggle_on
                          : Icons.toggle_off,
                      size: 22,
                      color: (studentDetailsData.status ?? 0) == 1
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (studentDetailsData.status ?? 0) == 1
                          ? 'Deactivate'
                          : 'Activate',
                    ),
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

  String _formatField(String text) {
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : '',
        )
        .join(' ');
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 50,
                      color: Colors.red.shade400,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Are you sure you want to\ndelete this student?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      title: "Yes, I'm sure",
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(context);
                        final success = await context
                            .read<StudentsCubit>()
                            .deleteStudent(
                              studentDetailsData.uuid ?? '',
                              studentDetailsData.schoolId?.toString() ?? widget.schoolId,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Student deleted successfully'
                                    : 'Failed to delete student',
                              ),
                              backgroundColor: success
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      title: 'No, cancel',
                      color: Colors.grey.shade300,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 60,
      width: 60,
      color: Colors.grey.shade300,
      child: const Icon(Icons.person, color: Colors.grey),
    );
  }

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// IMAGE
                  Flexible(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4,
                      child: Image.network(
                        imageUrl,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            height: 300,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 300,
                          width: double.infinity,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showPicker(context);
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Profile Image"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
