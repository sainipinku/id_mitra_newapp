import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
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
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/school/school_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/screens/add_student/add_student_form.dart';
import 'package:idmitra/face_capture/screens/camera_screen.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import '../../models/face_capture/upload_result.dart';
import '../../providers/students/students_state.dart';

class StudentCard extends StatefulWidget {
  StudentDetailsData studentData;
  final String schoolId;
  final String? imageShape;
  final int? schoolIntId;
  final VoidCallback? onEdit;
  final bool isSelected;
  final VoidCallback? onToggle;
  final bool showPopupMenu;
  final bool showExtraOption;
  final bool showActivateOption;

  StudentCard({
    super.key,
    required this.studentData,
    required this.schoolId,
    this.imageShape,
    this.schoolIntId,
    this.onEdit,
    this.isSelected = false,
    this.onToggle,
    this.showPopupMenu = true,
    this.showExtraOption = true,
    this.showActivateOption = true,
  });

  @override
  State<StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<StudentCard> {
  late StudentDetailsData studentDetailsData;

  File? studentProfileImageFile;
  bool isUploading = false;

  /// 📸 Camera — face capture, background upload, camera screen pe hi raho
  Future<void> _fromCamera() async {
    final uuid = studentDetailsData.uuid ?? '';
    final uploadUrl = Config.url(Routes.updateStudentProfile(uuid));

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          uploadUrl: uploadUrl,
          onUploaded: (newPhotoUrl) {
            // Online: CDN URL se student update karo
            if (!mounted) return;
            final updated = studentDetailsData.copyWith(
              profilePhotoUrl: newPhotoUrl,
              isPhotoPendingSync: false,
              clearOfflinePhotoPath: true,
            );
            context.read<StudentsCubit>().updateStudentInState(updated);
            setState(() => studentDetailsData = updated);
          },
          onOfflineSave: (filePath) async {
            // Offline: cubit se localDB me save karo (camera screen pe hi raho)
            if (!mounted) return;
            await context.read<StudentsCubit>().uploadStudentImage(
              path: filePath,
              student: studentDetailsData,
            );
            if (!mounted) return;
            final updated = context
                .read<StudentsCubit>()
                .state
                .studentsList
                .firstWhere(
                  (s) => s.uuid == studentDetailsData.uuid,
                  orElse: () => studentDetailsData,
                );
            setState(() => studentDetailsData = updated);
          },
        ),
      ),
    );

    // Fallback: agar kisi reason se ProcessedImage mila
    if (result != null && result is ProcessedImage && mounted) {
      await _uploadImage(result.filePath);
    }
  }

  /// 🖼 Gallery — crop then upload
  Future<void> _fromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null && mounted) {
      studentProfileImageFile = File(pickedFile.path);
      await _cropAndUpload();
    }
  }

  /// ✂️ Crop image
  Future<void> _cropAndUpload() async {
    if (studentProfileImageFile == null || !mounted) return;

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
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioLockEnabled: true,
        ),
      ],
    );

    if (croppedFile != null && mounted) {
      await _uploadImage(croppedFile.path);
    }
  }

  /// 🔀 Move student to extra
  Future<bool> _moveToExtra() async {
    try {
      final success = await context.read<StudentsCubit>().moveStudentToExtra(
        studentDetailsData.uuid ?? '',
        studentDetailsData.schoolId?.toString() ?? widget.schoolId,
      );

      return success;
    } catch (e) {
      debugPrint("Move to extra error: $e");
      return false;
    }
  }

  /// ⬆️ Upload image
  Future<void> _uploadImage(String path) async {
    if (!mounted) return;

    setState(() => isUploading = true);

    final beforeUrl = studentDetailsData.profilePhotoUrl;

    try {
      await context.read<StudentsCubit>().uploadStudentImage(
        path: path,
        student: studentDetailsData,
      );

      if (mounted) {
        final updatedStudent = context
            .read<StudentsCubit>()
            .state
            .studentsList
            .firstWhere(
              (s) => s.uuid == studentDetailsData.uuid,
          orElse: () => studentDetailsData,
        );

        setState(() {
          studentDetailsData = updatedStudent;
        });

        // Check if photo actually updated or was saved offline
        final afterUrl = updatedStudent.profilePhotoUrl;
        final savedOffline = updatedStudent.isPhotoPendingSync;

        if (savedOffline) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo saved offline, will sync when online'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ));
        } else if (afterUrl != beforeUrl && afterUrl != null && afterUrl.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo uploaded successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Upload failed, please try again'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ));
        }
      }
    } catch (e) {
      debugPrint("Upload error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ));
      }
    }

    if (!mounted) return;

    setState(() => isUploading = false);
  }

  /// 📂 Image picker bottom sheet
  void showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(25),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Choose Image",
                style: MyStyles.boldText(
                  size: 14,
                  color: Colors.black,
                ),
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

              _divider(),

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
              ),
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
          Text(
            title,
            style: MyStyles.regularText(
              size: 14,
              color: color,
            ),
          ),
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

    if (oldWidget.studentData.uuid != widget.studentData.uuid ||
        oldWidget.studentData.name != widget.studentData.name ||
        oldWidget.studentData.schoolClassSectionId !=
            widget.studentData.schoolClassSectionId ||
        oldWidget.studentData.profilePhotoUrl !=
            widget.studentData.profilePhotoUrl ||
        oldWidget.studentData.isPhotoPendingSync !=
            widget.studentData.isPhotoPendingSync ||
        oldWidget.studentData.offlinePhotoPath !=
            widget.studentData.offlinePhotoPath) {
      setState(() {
        studentDetailsData = widget.studentData;
      });
    }
  }

  /// ✏️ Open edit screen
  void _openEditScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => StudentFormCubit()
                ..loadFromSchoolId(
                  schoolId: widget.schoolId,
                  schoolName: '',
                ),
            ),
            BlocProvider(
              create: (_) =>
              StudentFormDataCubit()..load(widget.schoolId),
            ),
            BlocProvider(
              create: (_) => AddStudentCubit(),
            ),
          ],
          child: AddStudentFormPage(
            schoolId: widget.schoolId,
            editStudent: studentDetailsData,
          ),
        ),
      ),
    ).then((updatedStudent) {
      if (updatedStudent is StudentDetailsData && mounted) {
        setState(() => studentDetailsData = updatedStudent);

        context
            .read<StudentsCubit>()
            .updateStudentInState(updatedStudent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    /// 🔥 Resolve image shape dynamically
    String? resolvedShape = widget.imageShape;

    try {
      final schoolState = context.watch<SchoolCubit>().state;
    
      final schoolId =
          widget.schoolIntId ?? int.tryParse(widget.schoolId);
        print("Student list image ${studentDetailsData.profilePhotoUrl}");
      if (schoolId != null) {
        if (schoolState.imageShapeMap.containsKey(schoolId)) {
          resolvedShape = schoolState.imageShapeMap[schoolId];
        } else {
          final match = schoolState.students.firstWhere(
                (s) => s.id == schoolId,
            orElse: () => SchoolDetailsModel(),
          );

          if (match.imageShape != null &&
              match.imageShape!.isNotEmpty) {
            resolvedShape = match.imageShape;
          }
        }
      }
    } catch (_) {}

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          if (widget.onToggle != null)
            GestureDetector(
              onTap: widget.onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.isSelected,
                    onChanged: (_) => widget.onToggle!(),
                    activeColor: AppTheme.btnColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                    side: BorderSide(color: AppTheme.graySubTitleColor),
                  ),
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                final url = studentDetailsData.profilePhotoUrl?.trim();
                final hasRealPhoto = url != null &&
                    url.isNotEmpty &&
                    !url.contains('ui-avatars.com');

                if (hasRealPhoto) {
                  _openEditScreen(context);
                } else {
                  _fromCamera();
                }
              },
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  /// 👤 PROFILE IMAGE
                  Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    final url =
                    studentDetailsData.profilePhotoUrl?.trim();

                    final hasRealPhoto = url != null &&
                        url.isNotEmpty &&
                        !url.contains('ui-avatars.com');

                    if (hasRealPhoto) {
                      _showImagePreview(
                        context,
                        url,
                        resolvedShape: resolvedShape,
                      );
                    } else {
                      Future.delayed(Duration.zero, _fromCamera);
                    }
                  },
                  child: _buildPhoto(
                    context,
                    resolvedShape: resolvedShape,
                  ),
                ),

                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: () {
                      final url = studentDetailsData.profilePhotoUrl?.trim();
                      final hasRealPhoto = url != null &&
                          url.isNotEmpty &&
                          !url.contains('ui-avatars.com');

                      if (hasRealPhoto) {
                        _showImagePreview(
                          context,
                          url,
                          resolvedShape: resolvedShape,
                        );
                      } else {
                        Future.delayed(Duration.zero, _fromCamera);
                      }
                    },
                    child: Container(
                      height: 22,
                      width: 22,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
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

                      const SizedBox(width: 5),

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

                  studentDetailsData.missingFields!.isNotEmpty
                      ? Text(
                    "Missing details: ${studentDetailsData.missingFields?.map((e) => _formatField(e.toString())).join(', ') ?? ''}",
                    style: MyStyles.regularText(
                      size: 12,
                      color: AppTheme.redBtnBgColor,
                    ),
                  )
                      : const SizedBox(),
                ],
              ),
            ),

            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.grey,
              ),
              onSelected: (value) async {
                if (value == 'edit') {
                  _openEditScreen(context);
                } else if (value == 'delete') {
                  _confirmDelete(context);
                } else if (value == 'extra') {
                  final success = await _moveToExtra();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Student moved to extra list'
                              : 'Failed to move student to extra',
                        ),
                        backgroundColor:
                        success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else if (value == 'toggle') {
                  final success = await context.read<StudentsCubit>().toggleStudentStatus(
                    studentDetailsData.uuid ?? '',
                    studentDetailsData.schoolId?.toString() ??
                        widget.schoolId,
                    studentDetailsData.status ?? 0,
                  );

                  if (success) {
                    final updated = context.read<StudentsCubit>().state.studentsList
                        .firstWhere(
                          (s) =>
                      s.uuid == studentDetailsData.uuid,
                      orElse: () => studentDetailsData,
                    );

                    setState(() => studentDetailsData = updated);
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Status updated'
                              : 'Failed to update status',
                        ),
                        backgroundColor:
                        success ? Colors.green : Colors.red,
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                if (widget.showExtraOption)
                  const PopupMenuItem(
                    value: 'extra',
                    child: Row(
                      children: [
                        Icon(
                          Icons.move_to_inbox,
                          size: 18,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 8),
                        Text('Extra'),
                      ],
                    ),
                  ),

                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete,
                        size: 18,
                        color: Colors.red,
                      ),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),

                if (widget.showActivateOption)
                  PopupMenuItem(
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          (studentDetailsData.status ?? 0) == 1
                              ? Icons.toggle_on
                              : Icons.toggle_off,
                          size: 22,
                          color:
                          (studentDetailsData.status ?? 0) == 1
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
          ),
        ],
      ),
    );
  }

  String _formatField(String text) {
    return text
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isNotEmpty
          ? word[0].toUpperCase() +
          word.substring(1).toLowerCase()
          : '',
    )
        .join(' ');
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 32,
          ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
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
                          widget.schoolId,
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
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
      child: const Icon(
        Icons.person,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildPhoto(
      BuildContext context, {
        String? resolvedShape,
      }) {
    const shape = 'rectangle';

    Widget content;

    if (isUploading) {
      content = const SizedBox(
        height: 60,
        width: 60,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      );
    } else if (studentDetailsData.isPhotoPendingSync &&
        studentDetailsData.offlinePhotoPath != null) {
      final file = File(
        studentDetailsData.offlinePhotoPath!,
      );

      content = FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data == true) {
            return Image.file(
              file,
              height: 60,
              width: 60,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            );
          }

          return _placeholder();
        },
      );
    } else if (studentDetailsData.profilePhotoUrl != null &&
        studentDetailsData.profilePhotoUrl!
            .trim()
            .isNotEmpty &&
        !studentDetailsData.profilePhotoUrl!
            .contains('ui-avatars.com')) {
      content = CachedNetworkImage(
        imageUrl: studentDetailsData.profilePhotoUrl!.trim(),
        height: 60,
        width: 60,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        placeholder: (_, __) => _placeholder(),
        errorWidget: (_, __, ___) => _placeholder(),
      );
    } else {
      content = _placeholder();
    }

    switch (shape) {
      case 'round':
      case 'oval':
        return ClipOval(
          child: SizedBox(
            width: 60,
            height: 60,
            child: content,
          ),
        );

      case 'square':
        return ClipRRect(
          borderRadius: BorderRadius.zero,
          child: SizedBox(
            width: 60,
            height: 60,
            child: content,
          ),
        );

      case 'rectangle':
      default:
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 60,
            height: 60,
            child: content,
          ),
        );
    }
  }

  void _showImagePreview(
      BuildContext context,
      String imageUrl, {
        String? resolvedShape,
      }) {
    String shape =
        resolvedShape ?? widget.imageShape ?? 'rectangle';

    try {
      final schoolState = context.read<SchoolCubit>().state;

      final schoolId =
          widget.schoolIntId ?? int.tryParse(widget.schoolId);

      if (schoolId != null) {
        if (schoolState.imageShapeMap.containsKey(schoolId)) {
          shape = schoolState.imageShapeMap[schoolId] ?? shape;
        } else {
          final match = schoolState.students.firstWhere(
                (s) => s.id == schoolId,
            orElse: () => SchoolDetailsModel(),
          );

          if (match.imageShape != null &&
              match.imageShape!.isNotEmpty) {
            shape = match.imageShape!;
          }
        }
      }
    } catch (_) {}

    final isOffline =
        studentDetailsData.isPhotoPendingSync &&
            studentDetailsData.offlinePhotoPath != null;

    final displayPath = isOffline
        ? studentDetailsData.offlinePhotoPath!
        : (studentDetailsData.profilePhotoUrl
        ?.trim()
        .isNotEmpty ==
        true &&
        !studentDetailsData.profilePhotoUrl!
            .contains('ui-avatars.com')
        ? studentDetailsData.profilePhotoUrl!
        : imageUrl);

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
                  Flexible(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 4,
                      child: _buildShapedPreview(
                        displayPath,
                        shape,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _fromCamera();
                          },
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                          ),
                          label: const Text("Camera"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            AppTheme.btnColor,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _fromGallery();
                          },
                          icon: const Icon(
                            Icons.photo_library,
                            size: 18,
                          ),
                          label: const Text("Gallery"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            AppTheme.btnColor,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);

                            setState(() {
                              studentProfileImageFile =
                              null;

                              studentDetailsData =
                                  studentDetailsData
                                      .copyWith(
                                    profilePhotoUrl: "",
                                  );
                            });
                          },
                          icon: const Icon(
                            Icons.delete,
                            size: 18,
                          ),
                          label: const Text("Remove"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
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

Widget _buildShapedPreview(
    String imageUrl,
    String shape,
    ) {
  final isLocal =
      !imageUrl.startsWith('http') &&
          !imageUrl.startsWith('https');

  final imageWidget = isLocal
      ? Image.file(
    File(imageUrl),
    width: double.infinity,
    fit: BoxFit.contain,
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
  )
      : CachedNetworkImage(
    imageUrl: imageUrl,
    width: double.infinity,
    fit: BoxFit.contain,
    placeholder: (_, __) => const SizedBox(
      height: 300,
      child: Center(child: CircularProgressIndicator()),
    ),
    errorWidget: (_, __, ___) => Container(
      height: 300,
      width: double.infinity,
      color: Colors.grey.shade300,
      child: const Icon(Icons.person, size: 80, color: Colors.grey),
    ),
  );

  switch (shape) {
    case 'round':
    case 'oval':
      return ClipOval(child: imageWidget);

    case 'square':
      return ClipRRect(
        borderRadius: BorderRadius.zero,
        child: imageWidget,
      );

    case 'rectangle':
    default:
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageWidget,
      );
  }
}