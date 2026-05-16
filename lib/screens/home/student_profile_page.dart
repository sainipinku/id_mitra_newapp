import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/api_mamanger/api_manager.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/local_db/student_local_ds/student_local_ds.dart';
import 'package:idmitra/models/students/StudentsListModel.dart';
import 'package:idmitra/providers/add_student/add_student_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_data_cubit.dart';
import 'package:idmitra/screens/add_student/add_student_form.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class StudentProfilePage extends StatefulWidget {
  final StudentDetailsData student;
  final String schoolId;
  const StudentProfilePage({
    super.key,
    required this.student,
    required this.schoolId,
  });

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  late StudentDetailsData _student;
  final StudentLocalDS _localDS = StudentLocalDS();
  File? _profileImageFile;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _refreshFromLocal();
  }

  Future<void> _refreshFromLocal() async {
    // 🔥 Load the latest data from Local DB to ensure we have everything
    try {
      final db = await _localDS.getStudents(search: _student.name ?? '');
      final latest = db.firstWhere((s) => s.uuid == _student.uuid, orElse: () => _student);
      if (mounted) {
        setState(() => _student = latest);
      }
    } catch (e) {
      debugPrint("Error refreshing profile from local DB: $e");
    }
  }

  Future<void> _fromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      await _uploadImage(pickedFile.path);
    }
  }

  Future<void> _fromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _profileImageFile = File(pickedFile.path);
      await _cropAndUpload();
    }
  }

  Future<void> _cropAndUpload() async {
    if (_profileImageFile == null) return;

    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: _profileImageFile!.path,
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

  Future<void> _uploadImage(String path) async {
    setState(() => _isUploading = true);
    try {
      var response = await ApiManager().multiRequestRoute(
        path,
        Config.baseUrl + Routes.updateStudentProfile(_student.uuid ?? ''),
      );
      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final updatedUrl = jsonData['data']['profile_photo_url'];
        setState(() {
          _student = _student.copyWith(
            profilePhotoUrl: updatedUrl,
          );
        });
        
        // 🔥 Save updated photo to Local DB
        await _localDS.insertStudents([_student]);
        debugPrint("Profile photo updated in Local DB");
      }
    } catch (e) {
      debugPrint("Upload error: $e");
    }
    setState(() => _isUploading = false);
  }

  void _showPicker(BuildContext context) {
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
              Text("Choose Image",
                  style: MyStyles.boldText(size: 14, color: Colors.black)),
              const SizedBox(height: 15),
              _pickerItem(
                icon: 'assets/icons/camera_single.svg',
                title: "Camera",
                onTap: () { Navigator.pop(context); _fromCamera(); },
              ),
              _divider(),
              _pickerItem(
                icon: 'assets/icons/choose_from_gallery.svg',
                title: "Gallery",
                onTap: () { Navigator.pop(context); _fromGallery(); },
              ),
              _divider(),
              _pickerItem(
                icon: 'assets/icons/remove_image.svg',
                title: "Remove Photo",
                color: Colors.red,
                onTap: () async {
                  setState(() {
                    _profileImageFile = null;
                    _student = _student.copyWith(profilePhotoUrl: "");
                  });
                  // 🔥 Update Local DB
                  await _localDS.insertStudents([_student]);
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
          Text(title, style: MyStyles.regularText(size: 14, color: color)),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 1,
        color: Colors.grey.shade300,
      );

  void _showImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 300,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 300,
                        width: double.infinity,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person, size: 80, color: Colors.grey),
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
                      _showPicker(context);
                    },
                    icon: const Icon(Icons.edit),
                    label: const Text("Edit Profile Image"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get schoolId => widget.schoolId;

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => StudentFormCubit()
                ..loadFromSchoolId(schoolId: schoolId, schoolName: ''),
            ),
            BlocProvider(
              create: (_) => StudentFormDataCubit()..load(schoolId),
            ),
            BlocProvider(create: (_) => AddStudentCubit()),
          ],
          child: AddStudentFormPage(
            schoolId: schoolId,
            editStudent: _student,
          ),
        ),
      ),
    ).then((updatedStudent) {
      if (updatedStudent is StudentDetailsData && mounted) {
        setState(() => _student = updatedStudent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Student Profile',
        backgroundColor: Colors.white,
        showText: true,
        onBackPressed: () => Navigator.pop(context, _student),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        child: Column(
          children: [
            _headerCard(context),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            _sectionCard(
              icon: Icons.person_outline_rounded,
              title: 'Personal Information',
              rows: _personalRows(),
            ),
            _sectionCard(
              icon: Icons.school_outlined,
              title: 'Academic Information',
              rows: _academicRows(),
            ),
            _sectionCard(
              icon: Icons.family_restroom_outlined,
              title: 'Parent Information',
              rows: _parentRows(),
            ),
            _sectionCard(
              icon: Icons.location_on_outlined,
              title: 'Address',
              rows: _addressRows(),
            ),
            //_markStudentCard(context),
          ],
        ),
      ),
    );
  }

  Widget _headerCard(BuildContext context) {
    final isActive = (_student.status ?? 0) == 1;
    final hasPhoto = _student.profilePhotoUrl?.isNotEmpty ?? false;
    final admNo = _student.admissionNo?.toString() ?? '';
    final phone = _student.phone?.toString() ?? '';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          final url = _student.profilePhotoUrl;
                          if (url != null && url.isNotEmpty) {
                            _showImagePreview(context, url);
                          } else {
                            _showPicker(context);
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.btnColor.withOpacity(0.3), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundColor: AppTheme.btnColor.withOpacity(0.1),
                                backgroundImage: hasPhoto
                                    ? NetworkImage(_student.profilePhotoUrl!)
                                    : null,
                                child: _isUploading
                                    ? shimmerBox(width: 80, height: 80, radius: 40)
                                    : !hasPhoto
                                        ? Icon(Icons.person_rounded,
                                            size: 40, color: AppTheme.btnColor)
                                        : null,
                              ),
                            ),
                            Positioned(
                              bottom: 2, right: 2,
                              child: Container(
                                width: 24, height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  hasPhoto ? Icons.visibility : Icons.camera_alt,
                                  size: 13,
                                  color: AppTheme.btnColor,
                                ),
                              ),
                            ),
                            // Online dot
                            Positioned(
                              top: 2, right: 2,
                              child: Container(
                                width: 14, height: 14,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? const Color(0xFF4CAF50) : Colors.grey,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _student.name ?? '-',
                              style: MyStyles.boldText(size: 18, color: AppTheme.black_Color),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.school_outlined, size: 13, color: AppTheme.btnColor),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _classSection(),
                                    style: MyStyles.mediumText(size: 12, color: AppTheme.graySubTitleColor),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (admNo.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 13, color: AppTheme.btnColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Adm: $admNo',
                                    style: MyStyles.regularText(size: 11, color: AppTheme.graySubTitleColor),
                                  ),
                                ],
                              ),
                            ],
                            if (phone.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 13, color: AppTheme.btnColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone,
                                    style: MyStyles.regularText(size: 11, color: AppTheme.graySubTitleColor),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _chipWhite(
                        label: isActive ? 'Active' : 'Inactive',
                        bgColor: isActive
                            ? const Color(0xFF4CAF50).withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                        textColor: isActive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                        icon: isActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                      ),
                      if (_student.isOffline) ...[
                        const SizedBox(width: 8),
                        _chipWhite(
                          label: 'Offline',
                          bgColor: Colors.orange.withOpacity(0.12),
                          textColor: Colors.orange.shade800,
                          icon: Icons.cloud_off_outlined,
                        ),
                      ],
                      if (_sessionName().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _chipWhite(
                          label: _sessionName(),
                          bgColor: AppTheme.btnColor.withOpacity(0.08),
                          textColor: AppTheme.btnColor,
                          icon: Icons.calendar_today_outlined,
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _openEdit(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.btnColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.btnColor.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                'Edit',
                                style: MyStyles.mediumText(size: 12, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        ),
    );
  }

  Widget _chipWhite({
    required String label,
    required Color bgColor,
    required Color textColor,
    required IconData icon,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
            Text(label, style: MyStyles.mediumText(size: 11, color: textColor)),
          ],
        ),
      );




  Widget _chip({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: MyStyles.mediumText(size: 11, color: textColor)),
      );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<_InfoRow> rows,
  }) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.btnColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(
                left: BorderSide(color: AppTheme.btnColor, width: 3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.btnColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 13, color: AppTheme.btnColor),
                ),
                const SizedBox(width: 8),
                Text(title,
                    style: MyStyles.boldText(size: 12, color: AppTheme.black_Color)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.LineColor),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: _buildGrid(rows)),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_InfoRow> rows) {
    final widgets = <Widget>[];
    for (int i = 0; i < rows.length; i += 2) {
      final left = rows[i];
      final right = i + 1 < rows.length ? rows[i + 1] : null;
      widgets.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _cell(left.label, left.value)),
          if (right != null) ...[
            Container(width: 1, height: 32, color: AppTheme.LineColor),
            const SizedBox(width: 10),
            Expanded(child: _cell(right.label, right.value)),
          ] else
            const Expanded(child: SizedBox()),
        ],
      ));
      if (i + 2 < rows.length) {
        widgets.add(const SizedBox(height: 7));
        widgets.add(Divider(height: 1, color: AppTheme.LineColor));
        widgets.add(const SizedBox(height: 7));
      }
    }
    return Column(children: widgets);
  }

  Widget _cell(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MyStyles.regularText(size: 9, color: AppTheme.graySubTitleColor),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style: MyStyles.boldText(size: 11, color: AppTheme.black_Color),
          ),
        ],
      );

  List<_InfoRow> _personalRows() => [
       // _InfoRow('Login ID', _student.loginId ?? ''),
        _InfoRow('Email', _student.email?.toString() ?? ''),
        _InfoRow('WhatsApp', _student.whatsappPhone?.toString() ?? ''),
        _InfoRow('Gender', _cap(_student.gender?.toString() ?? '')),
        _InfoRow('Date of Birth', _student.dob ?? ''),
        _InfoRow('Blood Group', _student.bloodGroup?.toString() ?? ''),
        _InfoRow('Aadhar No', _student.aadharNo?.toString() ?? ''),
        _InfoRow('UID No', _student.uidNo?.toString() ?? ''),
        _InfoRow('NIC ID', _student.studentNicId?.toString() ?? ''),
        _InfoRow('Caste', _student.caste?.toString() ?? ''),
        _InfoRow('Religion', _student.religion?.toString() ?? ''),
        _InfoRow('RTE Student', _student.isRteStudent?.toString() ?? ''),
        _InfoRow('PEN Number', _student.panNo?.toString() ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_InfoRow> _academicRows() => [
        _InfoRow('Roll No', _student.rollNo?.toString() ?? ''),
        _InfoRow('Reg No', _student.regNo?.toString() ?? ''),
        _InfoRow('Admission No', _student.admissionNo?.toString() ?? ''),
        _InfoRow('SR No', _student.srNo ?? ''),
        _InfoRow('RFID No', _student.rfidNo?.toString() ?? ''),
        _InfoRow('Transport',
            _cap((_student.transportMode?.toString() ?? '').replaceAll('_', ' '))),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_InfoRow> _parentRows() => [
        _InfoRow('Father Name', _student.fatherName ?? ''),
        _InfoRow('Father Phone', _student.fatherPhone ?? ''),
        _InfoRow('Father WhatsApp', _student.fatherWphone?.toString() ?? ''),
        _InfoRow('Father Email', _student.fatherEmail?.toString() ?? ''),
        _InfoRow('Mother Name', _student.motherName ?? ''),
        _InfoRow('Mother Phone', _student.motherPhone?.toString() ?? ''),
        _InfoRow('Mother WhatsApp', _student.motherWphone?.toString() ?? ''),
        _InfoRow('Mother Email', _student.motherEmail?.toString() ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_InfoRow> _addressRows() => [
        _InfoRow('Address', _student.address ?? ''),
        _InfoRow('Pincode', _student.pincode?.toString() ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  String _classSection() {
    final cls = _student.datumClass?.nameWithprefix ?? '';
    final sec = _student.section?.name ?? '';
    if (cls.isEmpty && sec.isEmpty) return '-';
    if (sec.isEmpty) return cls;
    return '$cls - $sec';
  }

  String _sessionName() {
    return _student.session?.name?.toString() ?? '';
  }

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _InfoRow {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
}
