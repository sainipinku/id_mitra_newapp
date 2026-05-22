import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/staff/StaffDetailModel.dart';
import 'package:idmitra/models/staff/StaffListModel.dart';
import 'package:idmitra/providers/staff_detail/staff_detail_cubit.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'add_staff_form.dart';

class StaffProfilePage extends StatelessWidget {
  final StaffListModel staff;
  final String schoolId;

  const StaffProfilePage({
    super.key,
    required this.staff,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => StaffDetailCubit()..load(schoolId, staff.uuid),
      child: _StaffProfileBody(staff: staff, schoolId: schoolId),
    );
  }
}

class _StaffProfileBody extends StatefulWidget {
  final StaffListModel staff;
  final String schoolId;
  const _StaffProfileBody({required this.staff, required this.schoolId});

  @override
  State<_StaffProfileBody> createState() => _StaffProfileBodyState();
}

class _StaffProfileBodyState extends State<_StaffProfileBody> {
  File? _photoFile;
  bool _isUploading = false;
  String? _uploadedPhotoUrl;

  Future<void> _fromCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked != null) await _uploadPhoto(picked.path);
  }

  Future<void> _fromGallery() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _photoFile = File(picked.path);
      await _cropAndUpload();
    }
  }

  Future<void> _cropAndUpload() async {
    if (_photoFile == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: _photoFile!.path,
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
    if (cropped != null) await _uploadPhoto(cropped.path);
  }

  Future<void> _uploadPhoto(String path) async {
    setState(() => _isUploading = true);
    try {
      final token = await UserSecureStorage.fetchToken();
      final url = Config.baseUrl +
          Routes.uploadStaffPhoto(widget.schoolId, widget.staff.uuid);
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.files.add(await http.MultipartFile.fromPath('photo', path));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = jsonDecode(response.body);
        String? newUrl = jsonData['data']?['profile_photo_url'] as String?;
        if (newUrl != null) {
          final regex = RegExp(r'https?://');
          final matches = regex.allMatches(newUrl).toList();
          if (matches.length > 1) newUrl = newUrl.substring(matches.last.start);
          newUrl = newUrl
              .replaceAll('http://127.0.0.1:8000', 'https://idmitra.com')
              .replaceAll('http://localhost:8000', 'https://idmitra.com');
          if (mounted) setState(() => _uploadedPhotoUrl = newUrl);
        }
      }
    } catch (e) {
      debugPrint('uploadPhoto error: $e');
    }
    if (mounted) setState(() => _isUploading = false);
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose Image',
                style: MyStyles.boldText(size: 14, color: Colors.black)),
            const SizedBox(height: 15),
            _pickerItem(
              icon: 'assets/icons/camera_single.svg',
              title: 'Camera',
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(
                    const Duration(milliseconds: 300), _fromCamera);
              },
            ),
            _divider(),
            _pickerItem(
              icon: 'assets/icons/choose_from_gallery.svg',
              title: 'Gallery',
              onTap: () {
                Navigator.pop(ctx);
                Future.delayed(
                    const Duration(milliseconds: 300), _fromGallery);
              },
            ),
          ],
        ),
      ),
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
      child: Row(children: [
        SvgPicture.asset(icon),
        const SizedBox(width: 10),
        Text(title, style: MyStyles.regularText(size: 14, color: color)),
      ]),
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
                            child:
                                Center(child: CircularProgressIndicator()));
                      },
                      errorBuilder: (_, __, ___) => Container(
                        height: 300,
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.person,
                            size: 80, color: Colors.grey),
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
                    label: const Text('Edit Profile Image'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEdit(BuildContext context, StaffDetailModel staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStaffFormPage(
          editStaff: staff,
          schoolId: widget.schoolId,
        ),
      ),
    ).then((result) {
      if (!mounted) return;
      if (result is StaffDetailModel) {
        context.read<StaffDetailCubit>().emitUpdated(result);
      } else if (result == true) {
        context
            .read<StaffDetailCubit>()
            .load(widget.schoolId, widget.staff.uuid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Staff Profile',
        backgroundColor: Colors.white,
        showText: true,
      ),
      body: BlocBuilder<StaffDetailCubit, StaffDetailState>(
        builder: (context, state) {
          if (state.loading) {
            return const ShimmerDetail(sectionRowCounts: [4, 4, 3]);
          }
          if (state.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  Text(state.error!,
                      style:
                          MyStyles.regularText(size: 13, color: Colors.red),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context
                        .read<StaffDetailCubit>()
                        .load(widget.schoolId, widget.staff.uuid),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final s = state.staff;
          if (s == null) return const SizedBox.shrink();

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
            child: Column(
              children: [
                _headerCard(context, s),
                const SizedBox(height: 10),
                _sectionCard(
                  icon: Icons.person_outline_rounded,
                  title: 'Staff Details',
                  rows: _staffRows(s),
                ),
                _sectionCard(
                  icon: Icons.work_outline_rounded,
                  title: 'Employment Details',
                  rows: _employmentRows(s),
                ),
                _sectionCard(
                  icon: Icons.family_restroom_outlined,
                  title: 'Personal Details',
                  rows: _personalRows(s),
                ),
                _sectionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Address',
                  rows: _addressRows(s),
                ),
                if (s.emergencyContacts.isNotEmpty)
                  _emergencyContactsCard(s),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard(BuildContext context, StaffDetailModel staff) {
    final isActive = staff.status == 1;
    final photoUrl = _uploadedPhotoUrl ??
        (staff.profilePhotoUrl.isNotEmpty ? staff.profilePhotoUrl : null);
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final phone = staff.phone;
    final designation = staff.designation;

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
                    if (hasPhoto) {
                      _showImagePreview(context, photoUrl!);
                    } else {
                      _showPicker(context);
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppTheme.btnColor.withOpacity(0.3),
                              width: 3),
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
                          backgroundImage:
                              hasPhoto ? NetworkImage(photoUrl!) : null,
                          child: _isUploading
                              ? shimmerBox(width: 80, height: 80, radius: 40)
                              : !hasPhoto
                                  ? Icon(Icons.person_rounded,
                                      size: 40, color: AppTheme.btnColor)
                                  : null,
                        ),
                      ),
                      // camera / view icon
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: Container(
                          width: 24,
                          height: 24,
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
                      // status dot
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? const Color(0xFF4CAF50)
                                : Colors.grey,
                            border:
                                Border.all(color: Colors.white, width: 2),
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
                        staff.name,
                        style: MyStyles.boldText(
                            size: 18, color: AppTheme.black_Color),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (designation.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.work_outline,
                                size: 13, color: AppTheme.btnColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                designation,
                                style: MyStyles.mediumText(
                                    size: 12,
                                    color: AppTheme.graySubTitleColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      if (staff.department.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.apartment_outlined,
                                size: 13, color: AppTheme.btnColor),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                staff.department,
                                style: MyStyles.regularText(
                                    size: 11,
                                    color: AppTheme.graySubTitleColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                      ],
                      if (phone.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 13, color: AppTheme.btnColor),
                            const SizedBox(width: 4),
                            Text(
                              phone,
                              style: MyStyles.regularText(
                                  size: 11,
                                  color: AppTheme.graySubTitleColor),
                            ),
                          ],
                        ),
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
                  textColor: isActive
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFC62828),
                  icon: isActive
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                ),
                if (staff.roleName.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _chipWhite(
                    label: staff.roleName,
                    bgColor: AppTheme.btnColor.withOpacity(0.08),
                    textColor: AppTheme.btnColor,
                    icon: Icons.badge_outlined,
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () => _openEdit(context, staff),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
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
                        const Icon(Icons.edit_outlined,
                            size: 14, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          'Edit',
                          style: MyStyles.mediumText(
                              size: 12, color: Colors.white),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: textColor),
            const SizedBox(width: 4),
            Text(label,
                style: MyStyles.mediumText(size: 11, color: textColor)),
          ],
        ),
      );

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required List<_Row> rows,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.btnColor.withOpacity(0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
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
                    style: MyStyles.boldText(
                        size: 12, color: AppTheme.black_Color)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.LineColor),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            child: _buildGrid(rows),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<_Row> rows) {
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
            style: MyStyles.regularText(
                size: 9, color: AppTheme.graySubTitleColor),
          ),
          const SizedBox(height: 2),
          Text(
            value.isEmpty ? '-' : value,
            style:
                MyStyles.boldText(size: 11, color: AppTheme.black_Color),
          ),
        ],
      );

  Widget _emergencyContactsCard(StaffDetailModel staff) {
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.btnColor.withOpacity(0.04),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
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
                  child: Icon(Icons.emergency_outlined,
                      size: 13, color: AppTheme.btnColor),
                ),
                const SizedBox(width: 8),
                Text('Emergency Contacts',
                    style: MyStyles.boldText(
                        size: 12, color: AppTheme.black_Color)),
              ],
            ),
          ),
          Divider(height: 1, color: AppTheme.LineColor),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 10),
            child: Column(
              children:
                  staff.emergencyContacts.asMap().entries.map<Widget>((e) {
                final i = e.key;
                final c = e.value;
                return Column(
                  children: [
                    if (i > 0) ...[
                      const SizedBox(height: 7),
                      Divider(height: 1, color: AppTheme.LineColor),
                      const SizedBox(height: 7),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _cell('Name', c.name)),
                        Container(
                            width: 1,
                            height: 32,
                            color: AppTheme.LineColor),
                        const SizedBox(width: 10),
                        Expanded(child: _cell('Relation', c.relation)),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Divider(height: 1, color: AppTheme.LineColor),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(child: _cell('Phone', c.phone)),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<_Row> _staffRows(StaffDetailModel s) => [
        _Row('Name', s.name),
        _Row('Email', s.email),
        _Row('Phone', s.phone),
        _Row('WhatsApp', s.whatsappPhone ?? ''),
     //   _Row('Login ID', s.loginId ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_Row> _employmentRows(StaffDetailModel s) => [
        _Row('Designation', s.designation),
        _Row('Department', s.department),
        _Row('Role', s.roleName),
        _Row('Employee ID', s.employeeId ?? ''),
        _Row('National Code', s.nationalCode ?? ''),
        _Row('Date of Joining', s.dateOfJoining ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_Row> _personalRows(StaffDetailModel s) => [
        _Row('Father Name', s.fatherName ?? ''),
        _Row('Mother Name', s.motherName ?? ''),
        _Row('Husband Name', s.husbandName ?? ''),
        _Row('Date of Birth', s.dob ?? ''),
        _Row('Gender', _cap(s.gender ?? '')),
        _Row('Blood Group', s.bloodGroup ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  List<_Row> _addressRows(StaffDetailModel s) => [
        _Row('Address', s.address ?? ''),
        _Row('Pincode', s.pincode ?? ''),
      ].where((r) => r.value.isNotEmpty).toList();

  String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class _Row {
  final String label;
  final String value;
  const _Row(this.label, this.value);
}
