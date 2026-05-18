import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';
import 'package:idmitra/models/students/StudentsListModel.dart'
    hide ClassOption;
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/utils/common_widgets/LogoUploadView.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:idmitra/utils/common_widgets/drop_down/drop_down.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/add_student/StudentFormDataModel.dart';
import '../../providers/add_student/add_student_cubit.dart';
import '../../providers/student_form/student_form_data_cubit.dart';
import '../../providers/students/students_cubit.dart';
import '../../providers/students/students_state.dart';
import 'student_assign_class_sheet.dart';

const List<String> _kGenderOptions = [
  '-Select Gender-',
  'Male',
  'Female',
  'Transgender',
];
const List<String> _kTransportOptions = [
  'Select Mode',
  'self_pickup',
  'school_transport',
];
const List<String> _kBloodGroupOptions = [
  'Select Blood Group',
  'A+',
  'A-',
  'AB+',
  'AB-',
  'B+',
  'B-',
  'O+',
  'O-',
];
const List<String> _kRteOptions = ['-Select-', 'Yes', 'No'];
const List<String> _kSectionOptions = ['A', 'B', 'C', 'D'];

class AddStudentFormPage extends StatefulWidget {
  final String schoolId;
  final StudentDetailsData? editStudent;
  final int initialTab;
  const AddStudentFormPage({
    super.key,
    required this.schoolId,
    this.editStudent,
    this.initialTab = 0,
  });

  @override
  State<AddStudentFormPage> createState() => _AddStudentFormPageState();
}

class _AddStudentFormPageState extends State<AddStudentFormPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, dynamic> _selectVal = {};
  final Map<String, File?> _files = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
    if (widget.editStudent != null) {
      _additionalExpanded = _hasAdditionalData(widget.editStudent!);
      WidgetsBinding.instance.addPostFrameCallback(
            (_) => _prefillStudent(widget.editStudent!),
      );
    }
  }

  bool _hasAdditionalData(StudentDetailsData s) {
    return [
      s.phone,
      s.whatsappPhone?.toString(),
      s.landLineNo?.toString(),
      s.aadharNo?.toString(),
      s.uidNo?.toString(),
      s.studentNicId?.toString(),
      s.caste?.toString(),
      s.religion?.toString(),
      s.isRteStudent?.toString(),
      s.fatherEmail?.toString(),
      s.fatherWphone?.toString(),
      s.motherEmail?.toString(),
      s.motherPhone?.toString(),
      s.motherWphone?.toString(),
      s.pincode?.toString(),
      s.regNo?.toString(),
      s.rollNo?.toString(),
      s.admissionNo?.toString(),
      s.srNo,
      s.rfidNo?.toString(),
      s.transportMode?.toString(),
      s.schoolHouseId?.toString(),
    ].any((v) => v != null && v.isNotEmpty);
  }

  @override
  void dispose() {
    _tabController.dispose();
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  void _clearForm() {
    for (final c in _ctrl.values) c.clear();
    setState(() {
      _selectVal.clear();
      _files.clear();
    });
  }

  String? _validateForm(
      List<StudentFormField> allFields, StudentFormDataModel? data) {
    for (final f in allFields) {
      if (!f.required) continue;
      if (f.name == 'class_section' && widget.editStudent != null) continue;

      if (f.type == 'select') {
        if (_selectFieldHasNoOptions(f.name, data)) continue;

        final val = _selectVal[f.name];
        final isEmpty = val == null ||
            val.toString().isEmpty ||
            val.toString().startsWith('-Select') ||
            val.toString() == 'Select Mode' ||
            val.toString() == 'Select Blood Group';
        if (isEmpty) return '${f.label} is required';
      } else if (f.type == 'file') {
      } else {
        final text = _ctrl[f.name]?.text.trim() ?? '';
        if (text.isEmpty) return '${f.label} is required';
      }
    }

    final hasPasswordField = allFields.any((f) => f.name == 'password');
    final hasConfirmField =
    allFields.any((f) => f.name == 'password_confirmation');

    if (hasPasswordField || hasConfirmField) {
      final password = _ctrl['password']?.text ?? '';
      final confirmPassword = _ctrl['password_confirmation']?.text ?? '';

      if (password.isNotEmpty && confirmPassword != password) {
        return 'Password and Confirm Password do not match';
      }
      if (password.isNotEmpty &&
          confirmPassword.isEmpty &&
          hasConfirmField) {
        return 'Please fill Confirm Password';
      }
    }

    return null;
  }

  bool _selectFieldHasNoOptions(String name, StudentFormDataModel? data) {
    switch (name) {
      case 'class':
        return (data?.classes ?? []).isEmpty;
      case 'session':
        return (data?.sessions ?? []).isEmpty;
      case 'house':
        return (data?.houses ?? []).isEmpty;
      case 'class_section':
        final selectedClassId = _toInt(_selectVal['class']);
        if (selectedClassId == null) return true;
        final selectedClass = data?.classes.firstWhere(
              (c) => c.id == selectedClassId,
          orElse: () => ClassOption(id: -1, name: '', nameWithPrefix: ''),
        );
        return false;
      default:
        return false;
    }
  }

  void _prefillStudent(StudentDetailsData s) {
    setState(() {
      _setCtrl('student_name', s.name);
      _setCtrl('student_email', s.email?.toString());
      _setCtrl('student_phone', s.phone?.toString());
      _setCtrl('student_whatsapp', s.whatsappPhone?.toString());
      _setCtrl('student_whatsapp_number', s.whatsappPhone?.toString());
      _setCtrl('landline_number', s.landLineNo?.toString());
      _setCtrl('landline_contact_number', s.landLineNo?.toString());
      _setCtrl('aadhar_card_number', s.aadharNo?.toString());
      _setCtrl('uid_number', s.uidNo?.toString());
      _setCtrl('nic_id', s.studentNicId?.toString());
      _setCtrl('student_nic_id', s.studentNicId?.toString());
      _setCtrl('caste', s.caste?.toString());
      _setCtrl('religion', s.religion?.toString());
      _setCtrl('address', s.address);
      _setCtrl('pincode', s.pincode?.toString());
      _setCtrl('registration_number', s.regNo?.toString());
      _setCtrl('roll_number', s.rollNo?.toString());
      _setCtrl('admission_number', s.admissionNo?.toString());
      _setCtrl('sr_number', s.srNo);
      _setCtrl('rfid_number', s.rfidNo?.toString());
      _setCtrl('father_name', s.fatherName);
      _setCtrl('father_email', s.fatherEmail?.toString());
      _setCtrl('father_phone', s.fatherPhone);
      _setCtrl('father_whatsapp', s.fatherWphone?.toString());
      _setCtrl('mother_name', s.motherName);
      _setCtrl('mother_email', s.motherEmail?.toString());
      _setCtrl('mother_phone', s.motherPhone?.toString());
      _setCtrl('mother_whatsapp', s.motherWphone?.toString());

      if (s.dob != null && s.dob!.isNotEmpty) {
        final dob = s.dob!;
        if (dob.contains('-')) {
          final parts = dob.split('-');
          if (parts.length == 3) {
            _setCtrl(
                'date_of_birth', '${parts[2]}.${parts[1]}.${parts[0]}');
          } else {
            _setCtrl('date_of_birth', dob);
          }
        } else {
          _setCtrl('date_of_birth', dob.replaceAll('/', '.'));
        }
      }

      if (s.gender != null) {
        _selectVal['gender'] = _capitalizeFirst(s.gender.toString());
      }
      if (s.bloodGroup != null) {
        _selectVal['blood_group'] = s.bloodGroup.toString();
      }
      if (s.transportMode != null) {
        _selectVal['transport_mode'] = s.transportMode.toString();
      }
      if (s.isRteStudent != null) {
        _selectVal['is_rte_student'] = s.isRteStudent.toString();
      }
      if (s.schoolSessionId != null) _selectVal['session'] = s.schoolSessionId;
      if (s.schoolClassId != null) _selectVal['class'] = s.schoolClassId;
      if (s.schoolClassSectionId != null) {
        _selectVal['class_section'] = s.schoolClassSectionId;
      }
      if (s.schoolHouseId != null) _selectVal['house'] = s.schoolHouseId;
    });
  }

  void _setCtrl(String key, String? value) {
    if (value == null || value.isEmpty) return;
    _ctrl.putIfAbsent(key, () => TextEditingController());
    _ctrl[key]!.text = value;
  }

  int? _toInt(dynamic val) {
    if (val == null) return null;
    if (val is int) return val;
    return int.tryParse(val.toString());
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  void _showImagePicker(String fieldName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (bc) => SingleChildScrollView(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    'Choose Your Picker',
                    style: MyStyles.boldText(
                      size: 14,
                      color: AppTheme.black_Color,
                    ),
                  ),
                ),
                _pickerOption(
                  'assets/icons/camera_single.svg',
                  'Camera',
                      () async {
                    Navigator.pop(bc);
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.camera,
                    );
                    if (f != null) _cropAndSet(fieldName, File(f.path));
                  },
                ),
                _divider(),
                _pickerOption(
                  'assets/icons/choose_from_gallery.svg',
                  'Choose From Gallery',
                      () async {
                    Navigator.pop(bc);
                    final f = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                    );
                    if (f != null) _cropAndSet(fieldName, File(f.path));
                  },
                ),
                _divider(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pickerOption(
      String svg,
      String label,
      VoidCallback onTap, {
        bool isRemove = false,
      }) =>
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              SvgPicture.asset(svg, allowDrawingOutsideViewBox: true),
              const SizedBox(width: 10),
              Text(
                label,
                style: MyStyles.regularText(
                  size: 14,
                  color: isRemove
                      ? AppTheme.redBtnBgColor
                      : AppTheme.black_Color,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _divider() => Container(
    height: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: AppTheme.cardBgSecColor,
  );

  Future<void> _cropAndSet(String fieldName, File file) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop',
          toolbarColor: AppTheme.MainColor,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(title: 'Crop', aspectRatioLockEnabled: true),
      ],
    );
    if (cropped != null)
      setState(() => _files[fieldName] = File(cropped.path));
  }

  TextEditingController _ctrlFor(String name) {
    _ctrl.putIfAbsent(name, () => TextEditingController());
    return _ctrl[name]!;
  }

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: RichText(
      text: TextSpan(
        text: text,
        style:
        MyStyles.mediumText(size: 13, color: AppTheme.black_Color),
        children: required
            ? [
          TextSpan(
            text: ' *',
            style: MyStyles.mediumText(
                size: 13, color: Colors.red),
          ),
        ]
            : [],
      ),
    ),
  );

  Widget _stringDropdown(String name, List<String> options) {
    final val = (_selectVal[name] as String?);
    return Dropdown<String>(
      value: (val != null && options.contains(val)) ? val : null,
      items: options,
      hintText: options.first,
      onChange: (v) =>
          setState(() => _selectVal[name] = v ?? options.first),
      displayText: (_, o) => o,
      showClearButton: false,
    );
  }

  Widget _sessionDropdown(List<SessionOption> sessions) {
    if (sessions.isEmpty) return _loadingTile('Loading sessions...');

    final val = _toInt(_selectVal['session']);
    if (val == null && sessions.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          setState(() => _selectVal['session'] = sessions.first.value);
      });
    }
    final selected =
    (val != null && sessions.any((s) => s.value == val))
        ? sessions.firstWhere((s) => s.value == val)
        : sessions.isNotEmpty
        ? sessions.first
        : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.appBackgroundColor,
        border: Border.all(color: AppTheme.backBtnBgColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              selected?.label ?? 'No session available',
              style: MyStyles.regularText(
                  size: 14, color: AppTheme.graySubTitleColor),
            ),
          ),
          Icon(Icons.lock_outline,
              size: 16, color: AppTheme.graySubTitleColor),
        ],
      ),
    );
  }

  Widget _classDropdown(List<ClassOption> classes) {
    if (classes.isEmpty) return _loadingTile('Loading classes...');
    final seen = <String>{};
    final unique =
    classes.where((c) => seen.add(c.nameWithPrefix)).toList();
    final val = _toInt(_selectVal['class']);
    final selected =
    (val != null && unique.any((c) => c.id == val))
        ? unique.firstWhere((c) => c.id == val)
        : null;
    return Dropdown<ClassOption>(
      value: selected,
      items: unique,
      hintText: 'Select Class',
      onChange: (v) {
        setState(() {
          _selectVal['class'] = v?.id;
          _selectVal['class_section'] = null;
        });
      },
      displayText: (_, o) => o.nameWithPrefix,
      showClearButton: false,
    );
  }

  Widget _houseDropdown(List<HouseOption> houses) {
    if (houses.isEmpty) return _loadingTile('Loading houses...');
    final seen = <String>{};
    final unique =
    houses.where((h) => seen.add(h.name)).toList();
    final val = _toInt(_selectVal['house']);
    final selected =
    (val != null && unique.any((h) => h.id == val))
        ? unique.firstWhere((h) => h.id == val)
        : null;
    return Dropdown<HouseOption>(
      value: selected,
      items: unique,
      hintText: 'Select House',
      onChange: (v) => setState(() => _selectVal['house'] = v?.id),
      displayText: (_, o) => o.name,
      showClearButton: false,
    );
  }

  Widget _sectionDropdown(List<SectionOption> sections) {
    final val = _toInt(_selectVal['class_section']);
    SectionOption? selected;
    if (val != null) {
      if (sections.any((s) => s.id == val)) {
        selected = sections.firstWhere((s) => s.id == val);
      } else {
        selected = SectionOption(id: val, name: 'Section $val');
        if (!sections.contains(selected)) {
          sections = [selected, ...sections];
        }
      }
    }
    return Dropdown<SectionOption>(
      value: selected,
      items: sections,
      hintText:
      sections.isEmpty ? 'No sections available' : 'Select Section',
      onChange: (v) =>
          setState(() => _selectVal['class_section'] = v?.id),
      displayText: (_, o) => o.name,
      showClearButton: false,
    );
  }

  Widget _staticSectionDropdown() {
    final val = (_selectVal['class_section'] as String?);
    final selected =
    (val != null && _kSectionOptions.contains(val)) ? val : null;
    return Dropdown<String>(
      value: selected,
      items: _kSectionOptions,
      hintText: 'Select Section',
      onChange: (v) =>
          setState(() => _selectVal['class_section'] = v),
      displayText: (_, o) => o,
      showClearButton: false,
    );
  }

  Widget _transportDropdown() {
    const items = [
      {'label': 'Self Pickup', 'value': 'self_pickup'},
      {'label': 'School Transport', 'value': 'school_transport'},
    ];
    final val = (_selectVal['transport_mode'] as String?);
    final selected = items.any((i) => i['value'] == val)
        ? items.firstWhere((i) => i['value'] == val)
        : null;
    return Dropdown<Map<String, String>>(
      value: selected,
      items: items,
      hintText: 'Select Mode',
      onChange: (v) =>
          setState(() => _selectVal['transport_mode'] = v?['value']),
      displayText: (_, o) => o['label']!,
      showClearButton: false,
    );
  }

  Widget _loadingTile(String text) => Container(
    padding:
    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    decoration: BoxDecoration(
      border: Border.all(color: AppTheme.backBtnBgColor),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
    ),
    child: Text(
      text,
      style: MyStyles.regularText(
          size: 14, color: AppTheme.graySubTitleColor),
    ),
  );

  Widget _dateField(String name, String hint) => AppTextField(
    controller: _ctrlFor(name),
    hintText: 'DD.MM.YYYY',
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.\-/]')),
      LengthLimitingTextInputFormatter(10),
      _DotDateFormatter(),
    ],
  );

  Widget _photoField(String name, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      GestureDetector(
        onTap: () => _showImagePicker(name),
        child: Container(
          width: double.infinity,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.backBtnBgColor),
          ),
          child: _files[name] != null
              ? Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _files[name]!,
                  width: double.infinity,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _files[name] = null),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black54,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          )
              : _existingImageUrl(name) != null
              ? Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _existingImageUrl(name)!,
                  width: double.infinity,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      _photoPlaceholder(),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(
                    Icons.edit,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          )
              : _photoPlaceholder(),
        ),
      ),
    ],
  );

  String? _existingImageUrl(String fieldName) {
    final s = widget.editStudent;
    if (s == null) return null;
    switch (fieldName) {
      case 'student_photo':
        return s.profilePhotoUrl;
      case 'student_signature':
        return s.signatureUrl?.toString();
      case 'father_photo':
        return s.fatherPhotoUrl;
      case 'father_signature':
        return s.fatherSignatureUrl?.toString();
      case 'mother_photo':
        return s.motherPhotoUrl;
      case 'mother_signature':
        return s.motherSignatureUrl?.toString();
      default:
        return null;
    }
  }

  Widget _photoPlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const Icon(Icons.camera_alt, color: Colors.grey, size: 22),
      const SizedBox(height: 4),
      Text(
        'Add Photo',
        style: MyStyles.regularText(size: 11, color: Colors.grey),
      ),
    ],
  );

  Widget _buildField(StudentFormField f, StudentFormDataModel? data) {
    switch (f.type) {
      case 'select':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            _dynamicSelectField(f.name, data),
          ],
        );
      case 'date':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            _dateField(f.name, 'DD/MM/YYYY'),
          ],
        );
      case 'file':
        return _photoField(f.name, f.label);
      case 'textarea':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '${f.label}...',
              mxLine: 4,
              inputFormatters: [LengthLimitingTextInputFormatter(100)],
            ),
          ],
        );
      case 'digits':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '${f.label}...',
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              mxLine: 1,
            ),
          ],
        );
      case 'phone':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '${f.label}...',
              keyboardType: TextInputType.number,
              inputFormatters: [
                LengthLimitingTextInputFormatter(10),
                FilteringTextInputFormatter.digitsOnly,
              ],
              mxLine: 1,
            ),
          ],
        );
      case 'email':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '${f.label}...',
              keyboardType: TextInputType.emailAddress,
              mxLine: 1,
            ),
          ],
        );
      case 'password':
        if (f.name == 'password_confirmation') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(f.label, required: f.required),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _ctrlFor('password'),
                builder: (_, passwordVal, __) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _ctrlFor('password_confirmation'),
                    builder: (_, confirmVal, __) {
                      final passwordText = passwordVal.text;
                      final confirmText = confirmVal.text;
                      final mismatch = confirmText.isNotEmpty &&
                          passwordText.isNotEmpty &&
                          confirmText != passwordText;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppTextField(
                            controller: _ctrlFor(f.name),
                            hintText: '••••••',
                            obscureText: true,
                          ),
                          if (mismatch)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Passwords do not match',
                                style: MyStyles.regularText(
                                  size: 11,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '••••••',
              obscureText: true,
            ),
          ],
        );
      default:
        if (f.name == 'date_of_birth' || f.name == 'dob') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(f.label, required: f.required),
              _dateField(f.name, 'DD.MM.YYYY'),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(f.label, required: f.required),
            AppTextField(
              controller: _ctrlFor(f.name),
              hintText: '${f.label}...',
              mxLine: 1,
              textCapitalization: TextCapitalization.words,
            ),
          ],
        );
    }
  }

  Widget _dynamicSelectField(String name, StudentFormDataModel? data) {
    switch (name) {
      case 'session':
        return _sessionDropdown(data?.sessions ?? []);
      case 'class':
        return _classDropdown(data?.classes ?? []);
      case 'house':
        return _houseDropdown(data?.houses ?? []);
      case 'gender':
        return _stringDropdown(name, _kGenderOptions);
      case 'transport_mode':
        return _transportDropdown();
      case 'blood_group':
        return _stringDropdown(name, _kBloodGroupOptions);
      case 'is_rte_student':
        return _stringDropdown(name, _kRteOptions);
      case 'class_section':
        final selectedClassId = _toInt(_selectVal['class']);
        if (selectedClassId == null) {
          return _loadingTile('Select a class first');
        }
        final selectedClass = data?.classes.firstWhere(
              (c) => c.id == selectedClassId,
          orElse: () =>
              ClassOption(id: -1, name: '', nameWithPrefix: ''),
        );

        var sections = selectedClass?.sections ?? [];
        if (sections.isEmpty &&
            (selectedClass?.sectionsIds.isNotEmpty ?? false)) {
          sections = selectedClass!.sectionsIds
              .map((id) => SectionOption(id: id, name: 'Section $id'))
              .toList();
        }
        if (sections.isEmpty) {
          return _staticSectionDropdown();
        }
        return _sectionDropdown(sections);
      default:
        return _stringDropdown(name, ['-Select-']);
    }
  }

  Widget _twoColGrid(
      List<StudentFormField> fields,
      StudentFormDataModel? data,
      ) {
    final rows = <Widget>[];
    int i = 0;
    while (i < fields.length) {
      final f = fields[i];
      if (f.type == 'textarea') {
        rows.add(_buildField(f, data));
        rows.add(const SizedBox(height: 12));
        i++;
      } else {
        final hasNext =
            i + 1 < fields.length && fields[i + 1].type != 'textarea';
        final next = hasNext ? fields[i + 1] : null;
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildField(f, data)),
              if (next != null) ...[
                const SizedBox(width: 12),
                Expanded(child: _buildField(next, data)),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        );
        rows.add(const SizedBox(height: 12));
        i += next != null ? 2 : 1;
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }

  Widget _sectionCard(
      {required String title, required Widget child}) =>
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.backBtnBgColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Text(
                title,
                style: MyStyles.boldText(
                    size: 15, color: AppTheme.black_Color),
              ),
            ),
            const Divider(height: 1),
            Padding(
                padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      );

  Widget _otherStudentTab() {
    return BlocProvider(
      create: (_) => StudentsCubit()
        ..fetchExtraStudents(schoolId: widget.schoolId),
      child: _extraStudentList(),
    );
  }

  Widget _extraStudentList() {
    return BlocBuilder<StudentsCubit, StudentsState>(
      builder: (context, state) {
        if (state.extraLoading) {
          return const ShimmerList(expanded: false);
        }
        if (state.extraStudentsList.isEmpty) {
          return Center(
            child:
            Image.asset('assets/images/no_data.png', height: 200),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.extraStudentsList.length,
          itemBuilder: (context, index) {
            final student = state.extraStudentsList[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: (student.profilePhotoUrl != null &&
                        student.profilePhotoUrl!.isNotEmpty)
                        ? Image.network(
                      student.profilePhotoUrl!,
                      height: 55,
                      width: 55,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _extraPlaceholder(),
                    )
                        : _extraPlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name ?? '',
                          style: MyStyles.boldText(
                              size: 15, color: AppTheme.black_Color),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "${student.datumClass?.nameWithprefix ?? ''} - ${student.section?.name ?? ''}",
                          style: MyStyles.regularText(
                              size: 12, color: AppTheme.btnColor),
                        ),
                        if (student.fatherName != null &&
                            student.fatherName!.isNotEmpty)
                          Text(
                            "Father: ${student.fatherName}",
                            style: MyStyles.regularText(
                                size: 12,
                                color: AppTheme.graySubTitleColor),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'assign') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => StudentAssignClassSheet(
                            schoolId: widget.schoolId,
                            studentUuid: student.uuid ?? '',
                            studentName: student.name ?? '',
                            onAssigned: () {
                              context
                                  .read<StudentsCubit>()
                                  .fetchExtraStudents(
                                schoolId: widget.schoolId,
                              );
                            },
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'assign',
                        child: Row(
                          children: [
                            Icon(Icons.class_,
                                size: 18, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Assign Class'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _extraPlaceholder() => Container(
    height: 55,
    width: 55,
    color: Colors.grey.shade300,
    child: const Icon(Icons.person, color: Colors.grey),
  );

  Widget _mainInfoTab(
      List<StudentFormField> currentFields,
      List<StudentFormField> additionalFields,
      StudentFormDataModel? data,
      ) {
    Widget? _inlineSectionWidget() {
      final selectedClassId = _toInt(_selectVal['class']);
      if (selectedClassId == null) return null;
      final hasClassField =
      currentFields.any((f) => f.name == 'class');
      if (!hasClassField) return null;
      final hasSectionField =
          currentFields.any((f) => f.name == 'class_section') ||
              (data?.classes ?? []).isEmpty;
      if (hasSectionField) return null;

      final selectedClass = data?.classes.firstWhere(
            (c) => c.id == selectedClassId,
        orElse: () =>
            ClassOption(id: -1, name: '', nameWithPrefix: ''),
      );
      var sections = selectedClass?.sections ?? [];
      if (sections.isEmpty &&
          (selectedClass?.sectionsIds.isNotEmpty ?? false)) {
        sections = selectedClass!.sectionsIds
            .map((id) => SectionOption(id: id, name: 'Section $id'))
            .toList();
      }
      if (sections.isEmpty) return null;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Section'),
            _sectionDropdown(sections),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _sectionCard(
              title: 'Main Information',
              child: currentFields.isEmpty
                  ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No fields configured. Please configure student form fields first.',
                    style: MyStyles.regularText(
                      size: 13,
                      color: AppTheme.graySubTitleColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _twoColGrid(currentFields, data),
                  Builder(builder: (_) {
                    final sectionWidget =
                    _inlineSectionWidget();
                    if (sectionWidget == null)
                      return const SizedBox.shrink();
                    return sectionWidget;
                  }),
                ],
              ),
            ),
            if (additionalFields.isNotEmpty)
              _additionalCollapsible(additionalFields, data),
          ],
        ),
      ),
    );
  }

  bool _additionalExpanded = false;

  Widget _additionalCollapsible(
      List<StudentFormField> fields,
      StudentFormDataModel? data,
      ) {
    const groupOrder = [
      'Personal Details',
      'Parent Details',
      'Address Details',
      'Academic Details',
    ];

    final Map<String, List<StudentFormField>> grouped = {};
    for (final f in fields) {
      String g = f.groupLabel.isNotEmpty ? f.groupLabel : 'Other';
      if (g == 'School') g = 'Academic Details';
      if (g == 'Student') g = 'Personal Details';
      if (g == 'Parent') g = 'Parent Details';
      if (g == 'Address') g = 'Address Details';
      grouped.putIfAbsent(g, () => []).add(f);
    }

    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        final ai = groupOrder.indexOf(a);
        final bi = groupOrder.indexOf(b);
        if (ai == -1 && bi == -1) return a.compareTo(b);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.backBtnBgColor),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(
                    () => _additionalExpanded = !_additionalExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Additional Information',
                      style: MyStyles.boldText(
                        size: 15,
                        color: AppTheme.black_Color,
                      ),
                    ),
                  ),
                  Icon(
                    _additionalExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppTheme.graySubTitleColor,
                  ),
                ],
              ),
            ),
          ),
          if (_additionalExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: sortedKeys
                    .map(
                      (key) => _sectionCard(
                    title: key,
                    child: _twoColGrid(grouped[key]!, data),
                  ),
                )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentFormDataCubit, StudentFormDataState>(
      builder: (context, dataState) {
        return BlocBuilder<StudentFormCubit, StudentFormState>(
          builder: (context, formState) {
            final data = dataState.data;
            final currentFields = formState.fields;
            final additionalFields = formState.availableFields
                .where(
                    (f) => !currentFields.any((c) => c.name == f.name))
                .toList();

            return Scaffold(
              appBar: CommonAppBar(
                title: widget.editStudent != null
                    ? 'Edit Student'
                    : 'Add Student',
                backgroundColor: Colors.transparent,
                showText: true,
              ),
              body: Column(
                children: [
                  Container(
                    margin:
                    const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    decoration: BoxDecoration(
                      color: AppTheme.appBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppTheme.btnColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor:
                      AppTheme.graySubTitleColor,
                      labelStyle: MyStyles.boldText(
                        size: 13,
                        color: Colors.white,
                      ),
                      unselectedLabelStyle: MyStyles.regularText(
                        size: 13,
                        color: AppTheme.graySubTitleColor,
                      ),
                      tabs: const [
                        Tab(text: 'Main Information'),
                        Tab(text: 'Other Student'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: (dataState.loading || formState.loading)
                        ? const AddStudentFormShimmer()
                        : dataState.error != null &&
                        dataState.data == null
                        ? Center(
                      child: Text(
                        dataState.error!,
                        style: MyStyles.regularText(
                          size: 14,
                          color: Colors.red,
                        ),
                      ),
                    )
                        : TabBarView(
                      controller: _tabController,
                      children: [
                        _mainInfoTab(
                          currentFields,
                          additionalFields,
                          data,
                        ),
                        _otherStudentTab(),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _tabController,
                    builder: (context, _) {
                      if (_tabController.index == 1)
                        return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                title: 'Cancel',
                                isLoading: false,
                                color: AppTheme.backBtnBgColor,
                                onTap: () =>
                                    Navigator.pop(context),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: BlocConsumer<AddStudentCubit,
                                  AddStudentState>(
                                listener: (ctx, state) {
                                  if (state.success) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          state.message ??
                                              (widget.editStudent !=
                                                  null
                                                  ? 'Student updated successfully'
                                                  : 'Student added successfully'),
                                        ),
                                        backgroundColor:
                                        Colors.green,
                                      ),
                                    );

                                    StudentDetailsData?
                                    returnStudent =
                                        state.newStudent;

                                    if (returnStudent == null &&
                                        widget.editStudent != null) {
                                      // Manually update the student with form fields
                                      final allFields = {
                                        ..._ctrl.map((k, v) =>
                                            MapEntry(k, v.text)),
                                        ..._selectVal,
                                      };
                                      returnStudent = widget
                                          .editStudent!
                                          .copyWith(
                                        name: allFields[
                                        'student_name']
                                            ?.toString(),
                                        dob: allFields[
                                        'date_of_birth']
                                            ?.toString(),
                                        address:
                                        allFields['address']
                                            ?.toString(),
                                        caste:
                                        allFields['caste']
                                            ?.toString(),
                                        studentNicId: allFields[
                                        'student_nic_id']
                                            ?.toString() ??
                                            allFields['nic_id']
                                                ?.toString(),
                                        uidNo:
                                        allFields['uid_number']
                                            ?.toString(),
                                        fatherName: allFields[
                                        'father_name']
                                            ?.toString(),
                                        fatherPhone: allFields[
                                        'father_phone']
                                            ?.toString(),
                                        motherName: allFields[
                                        'mother_name']
                                            ?.toString(),
                                        landLineNo: allFields[
                                        'landline_contact_number']
                                            ?.toString() ??
                                            allFields[
                                            'landline_number']
                                                ?.toString(),
                                        whatsappPhone: allFields[
                                        'student_whatsapp_number']
                                            ?.toString() ??
                                            allFields[
                                            'student_whatsapp']
                                                ?.toString(),
                                        fatherWphone: allFields[
                                        'father_whatsapp_number']
                                            ?.toString() ??
                                            allFields[
                                            'father_whatsapp']
                                                ?.toString(),
                                        motherPhone: allFields[
                                        'mother_phone']
                                            ?.toString(),
                                        email:
                                        allFields['student_email']
                                            ?.toString(),
                                        phone:
                                        allFields['student_phone']
                                            ?.toString(),
                                        pincode:
                                        allFields['pincode']
                                            ?.toString(),
                                        religion:
                                        allFields['religion']
                                            ?.toString(),
                                      );
                                    }

                                    Navigator.pop(
                                        context, returnStudent);
                                  }
                                  if (state.error != null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      SnackBar(
                                        content:
                                        Text(state.error!),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                builder: (ctx, state) => AppButton(
                                  title: widget.editStudent != null
                                      ? 'Update'
                                      : 'Submit',
                                  isLoading: state.loading,
                                  color: AppTheme.btnColor,
                                  onTap: state.loading
                                      ? () {}
                                      : () {
                                    final allVisibleFields = [
                                      ...currentFields,
                                      if (_additionalExpanded)
                                        ...additionalFields,
                                    ];
                                    final validationError =
                                    _validateForm(
                                        allVisibleFields,
                                        data);
                                    if (validationError !=
                                        null) {
                                      ScaffoldMessenger.of(
                                          context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              validationError),
                                          backgroundColor:
                                          Colors.red,
                                        ),
                                      );
                                      return;
                                    }
                                    final allFields = {
                                      ..._ctrl.map(
                                            (k, v) => MapEntry(
                                            k, v.text),
                                      ),
                                      ..._selectVal,
                                    };
                                    if (widget.editStudent !=
                                        null) {
                                      ctx
                                          .read<
                                          AddStudentCubit>()
                                          .updateStudent(
                                        studentUuid: widget
                                            .editStudent!
                                            .uuid ??
                                            '',
                                        schoolId:
                                        widget.schoolId,
                                        fields: allFields,
                                        files: _files,
                                        formDataModel: data,
                                        allConfiguredFieldNames:
                                        currentFields
                                            .map((e) =>
                                        e.name)
                                            .toList(),
                                        // 🔥 FIXED: existing student pass karo
                                        // Offline update me is student ka data preserve hoga
                                        existingStudent: widget
                                            .editStudent,
                                      );
                                    } else {
                                      ctx
                                          .read<
                                          AddStudentCubit>()
                                          .submit(
                                        schoolId:
                                        widget.schoolId,
                                        fields: allFields,
                                        files: _files,
                                        formDataModel: data,
                                        allConfiguredFieldNames:
                                        currentFields
                                            .map((e) =>
                                        e.name)
                                            .toList(),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.length < oldValue.text.length) {
      return newValue;
    }
    String digits =
    newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > 8) digits = digits.substring(0, 8);

    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) formatted += '.';
      formatted += digits[i];
    }

    return newValue.copyWith(
      text: formatted,
      selection:
      TextSelection.collapsed(offset: formatted.length),
    );
  }
}