import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/UserLocal.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/staff/StaffDetailModel.dart';
import 'package:idmitra/models/staff/StaffListModel.dart';
import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';
import 'package:idmitra/providers/staff_form/staff_form_cubit.dart';
import 'package:idmitra/providers/add_staff/add_staff_cubit.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:idmitra/utils/common_widgets/drop_down/drop_down.dart';

class AddStaffFormPage extends StatefulWidget {
  final StaffDetailModel? editStaff;
  final String schoolId;
  const AddStaffFormPage({super.key, this.editStaff, this.schoolId = ''});

  @override
  State<AddStaffFormPage> createState() => _AddStaffFormPageState();
}

class _AddStaffFormPageState extends State<AddStaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final StaffFormCubit _staffFormCubit;
  late final AddStaffCubit _addStaffCubit;
  String _schoolId = '';
  StreamSubscription<StaffFormState>? _formFieldsSub;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String?> _selectValues = {};

  final Map<String, bool> _obscureMap = {};

  @override
  void initState() {
    super.initState();
    _staffFormCubit = StaffFormCubit();
    _addStaffCubit = AddStaffCubit();
    _initSchoolAndLoad();
  }

  bool _prefilled = false;

  Future<void> _initSchoolAndLoad() async {
    String id = widget.schoolId;
    String name = '';
    if (id.isEmpty) {
      final school = await UserLocal.getSchool();
      id = school['schoolId'] ?? '';
      name = school['schoolName'] ?? '';
    }

    if (id.isNotEmpty) {
      _schoolId = id;

      _formFieldsSub = _staffFormCubit.stream.listen((state) {
        if (!state.loading && state.fields.isNotEmpty && !_prefilled) {
          _prefilled = true;
          for (final c in _controllers.values) c.dispose();
          _controllers.clear();
          _selectValues.clear();
          _prefillDynamicFields(state.roles);
          _formFieldsSub?.cancel();
        }
      });
      await _staffFormCubit.loadFields(id, schoolName: name);

      final currentState = _staffFormCubit.state;
      if (!currentState.loading && currentState.fields.isNotEmpty && !_prefilled) {
        _prefilled = true;
        for (final c in _controllers.values) c.dispose();
        _controllers.clear();
        _selectValues.clear();
        _prefillDynamicFields(currentState.roles);
        _formFieldsSub?.cancel();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('School ID not found. Please select a school first.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    final e = widget.editStaff;
    if (e != null && e.roleId != null) {
      _selectValues['role'] = e.roleId.toString();
    }
  }

  void _prefillDynamicFields(List<StaffRole> roles) {
    final e = widget.editStaff;
    if (e == null) return;

    final Map<String, String> staffFieldMap = {
      'name': e.name,
      'email': e.email,
      'phone': e.phone,
      'designation': e.designation,
      'department': e.department,
      'login_id': e.loginId ?? '',
      'employee_id': e.employeeId ?? '',
      'address': e.address ?? '',
      'date_of_birth': e.dob ?? '',
      'dob': e.dob ?? '',
      'father_name': e.fatherName ?? '',
      'mother_name': e.motherName ?? '',
      'husband_name': e.husbandName ?? '',
      'whatsapp': e.whatsappPhone ?? '',
      'whatsapp_phone': e.whatsappPhone ?? '',
      'pincode': e.pincode ?? '',
      'national_code': e.nationalCode ?? '',
      'date_of_joining': e.dateOfJoining ?? '',
      'gender': e.gender ?? '',
      'blood_group': e.bloodGroup ?? '',
    };

    bool changed = false;
    for (final entry in staffFieldMap.entries) {
      if (entry.value.isNotEmpty) {
        _ctrl(entry.key).text = entry.value;
        changed = true;
      }
    }

    if (roles.isNotEmpty && _selectValues['role'] == null) {
      StaffRole? matchedRole;
      if (e.roleId != null) {
        try {
          matchedRole = roles.firstWhere((r) => r.id == e.roleId);
        } catch (_) {}
      }
      if (matchedRole == null && e.roleName.isNotEmpty) {
        try {
          matchedRole = roles.firstWhere(
                (r) => r.name.toLowerCase() == e.roleName.toLowerCase(),
          );
        } catch (_) {}
      }
      if (matchedRole != null) {
        _selectValues['role'] = matchedRole.id.toString();
        changed = true;
      }
    }

    if (changed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _formFieldsSub?.cancel();
    _staffFormCubit.close();
    _addStaffCubit.close();
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  TextEditingController _ctrl(String name) =>
      _controllers.putIfAbsent(name, () => TextEditingController());

  Widget _label(String text, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 4),
    child: RichText(
      text: TextSpan(
        text: text,
        style: MyStyles.mediumText(size: 13, color: AppTheme.black_Color),
        children: required
            ? [TextSpan(text: ' *', style: MyStyles.mediumText(size: 13, color: Colors.red))]
            : [],
      ),
    ),
  );

  Widget _sectionCard({required String title, required Widget child}) => Container(
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
          child: Text(title, style: MyStyles.boldText(size: 15, color: AppTheme.black_Color)),
        ),
        const Divider(height: 1),
        Padding(padding: const EdgeInsets.all(16), child: child),
      ],
    ),
  );

  Widget _twoCol(Widget left, Widget right) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );

  Widget _dateField(TextEditingController ctrl) => AppTextField(
    controller: ctrl,
    hintText: 'DD.MM.YYYY',
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'[\d.\-/]')),
      LengthLimitingTextInputFormatter(10),
      _DotDateFormatter(),
    ],
  );

  Widget _buildFullShimmer() {
    Widget shimmerField() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shimmerBox(height: 12, width: 90),
        const SizedBox(height: 8),
        shimmerBox(height: 48, radius: 10),
      ],
    );

    Widget shimmerRow() => Row(
      children: [
        Expanded(child: shimmerField()),
        const SizedBox(width: 12),
        Expanded(child: shimmerField()),
      ],
    );

    Widget shimmerSection(String title, int rowCount) => Container(
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
            child: shimmerBox(height: 14, width: 120),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(
                rowCount,
                    (i) => Padding(
                  padding: EdgeInsets.only(bottom: i < rowCount - 1 ? 14 : 0),
                  child: shimmerRow(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        shimmerSection('Main Information', 4),
      ],
    );
  }

  bool _isObscure(String key) => _obscureMap[key] ?? true;

  Widget _visibilityToggle(String key) => IconButton(
    icon: Icon(
      _isObscure(key) ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      size: 20,
      color: AppTheme.graySubTitleColor,
    ),
    onPressed: () => setState(() => _obscureMap[key] = !_isObscure(key)),
  );

  Widget _buildDynamicField(StudentFormField field, List<StaffRole> roles) {
    final isPasswordField =
        field.type == 'password' || field.name.toLowerCase().contains('password');

    if (isPasswordField) {
      final isConfirm = field.name.toLowerCase().contains('confirm') ||
          field.name == 'password_confirmation';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          AppTextField(
            controller: _ctrl(field.name),
            hintText: '••••••••',
            obscureText: _isObscure(field.name),
            suffixIcon: _visibilityToggle(field.name),
            validator: field.required
                ? (v) {
              if (v == null || v.trim().isEmpty) return '${field.label} is required';
              if (isConfirm) {
                final pwCtrl = _controllers.entries
                    .firstWhere(
                      (e) =>
                  e.key.toLowerCase().contains('password') &&
                      !e.key.toLowerCase().contains('confirm') &&
                      e.key != 'password_confirmation',
                  orElse: () => MapEntry('', TextEditingController()),
                )
                    .value;
                if (v != pwCtrl.text) return 'Passwords do not match';
              }
              return null;
            }
                : null,
          ),
        ],
      );
    }

    // ── Textarea ─────────────────────────────────────────────────────────────
    if (field.type == 'textarea') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          AppTextField(
            controller: _ctrl(field.name),
            hintText: '${field.label}...',
            mxLine: 4,
            validator: field.required
                ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
                : null,
          ),
        ],
      );
    }

    if (field.type == 'select') {
      if (field.name == 'role') {
        if (roles.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(field.label, required: field.required),
              AppTextField(
                controller: _ctrl(field.name),
                hintText: '${field.label}...',
                mxLine: 1,
                validator: field.required
                    ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
                    : null,
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label(field.label, required: field.required),
            Dropdown<StaffRole>(
              value: () {
                if (_selectValues['role'] == null) return null;
                try {
                  return roles.firstWhere((r) => r.id.toString() == _selectValues['role']);
                } catch (_) {
                  return null;
                }
              }(),
              items: roles,
              hintText: '-Select Role-',
              onChange: (r) => setState(() => _selectValues['role'] = r?.id.toString()),
              displayText: (_, r) => r.name,
              showClearButton: false,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          AppTextField(
            controller: _ctrl(field.name),
            hintText: '${field.label}...',
            mxLine: 1,
            validator: field.required
                ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
                : null,
          ),
        ],
      );
    }

    if (field.type == 'date') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          _dateField(_ctrl(field.name)),
        ],
      );
    }

    if (field.type == 'phone') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          AppTextField(
            controller: _ctrl(field.name),
            hintText: '${field.label}...',
            keyboardType: TextInputType.number,
            inputFormatters: [
              LengthLimitingTextInputFormatter(10),
              FilteringTextInputFormatter.digitsOnly,
            ],
            mxLine: 1,
            validator: field.required
                ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
                : null,
          ),
        ],
      );
    }

    if (field.type == 'email') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label, required: field.required),
          AppTextField(
            controller: _ctrl(field.name),
            hintText: '${field.label}...',
            keyboardType: TextInputType.emailAddress,
            mxLine: 1,
            validator: field.required
                ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
                : null,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(field.label, required: field.required),
        AppTextField(
          controller: _ctrl(field.name),
          hintText: '${field.label}...',
          mxLine: 1,
          validator: field.required
              ? (v) => (v == null || v.trim().isEmpty) ? '${field.label} is required' : null
              : null,
        ),
      ],
    );
  }

  Widget _twoColGrid(List<StudentFormField> fields, List<StaffRole> roles) {
    final groupOrder = <String>[];
    final groups = <String, List<StudentFormField>>{};
    for (final f in fields) {
      final key = f.groupLabel.isNotEmpty ? f.groupLabel : 'Details';
      if (!groups.containsKey(key)) groupOrder.add(key);
      groups.putIfAbsent(key, () => []).add(f);
    }

    final sections = <Widget>[];
    final hasMultipleGroups = groupOrder.length > 1;

    for (final groupLabel in groupOrder) {
      final groupFields = groups[groupLabel]!;

      if (hasMultipleGroups && sections.isNotEmpty) {
        sections.add(const SizedBox(height: 4));
        sections.add(const Divider());
        sections.add(const SizedBox(height: 4));
      }
      if (hasMultipleGroups) {
        sections.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(groupLabel,
              style: MyStyles.boldText(size: 13, color: AppTheme.graySubTitleColor)),
        ));
      }

      int i = 0;
      while (i < groupFields.length) {
        final f = groupFields[i];
        if (f.type == 'textarea') {
          sections.add(_buildDynamicField(f, roles));
          sections.add(const SizedBox(height: 12));
          i++;
        } else {
          final hasNext =
              i + 1 < groupFields.length && groupFields[i + 1].type != 'textarea';
          final next = hasNext ? groupFields[i + 1] : null;
          sections.add(Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildDynamicField(f, roles)),
              if (next != null) ...[
                const SizedBox(width: 12),
                Expanded(child: _buildDynamicField(next, roles)),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ));
          sections.add(const SizedBox(height: 12));
          i += next != null ? 2 : 1;
        }
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: sections);
  }



  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _staffFormCubit),
        BlocProvider.value(value: _addStaffCubit),
      ],
      child: BlocListener<AddStaffCubit, AddStaffState>(
        listener: (context, state) {
          if (state.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message ??
                    (widget.editStaff != null
                        ? 'Staff updated successfully'
                        : 'Staff added successfully')),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, state.updatedStaff ?? state.newStaff ?? true);
          } else if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
            );
          }
        },
        child: _buildScaffold(context),
      ),
    );
  }

  Widget _buildScaffold(BuildContext ctx) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: widget.editStaff != null ? 'Edit Staff' : 'Add Staff',
        backgroundColor: Colors.white,
        showText: true,
      ),
      body: BlocBuilder<StaffFormCubit, StaffFormState>(
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: state.loading
                      ? _buildFullShimmer()
                      : state.error != null
                      ? Center(
                      child: Text(state.error!,
                          style: MyStyles.regularText(
                              size: 13, color: Colors.red)))
                      : Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _sectionCard(
                          title: 'Main Information',
                          child: state.fields.isNotEmpty
                              ? _twoColGrid(state.fields, state.roles)
                              : Text(
                            'No fields configured.',
                            style: MyStyles.regularText(
                                size: 12,
                                color: AppTheme.graySubTitleColor),
                          ),
                        ),


                      ],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        title: 'Cancel',
                        color: AppTheme.backBtnBgColor,
                        onTap: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: BlocBuilder<AddStaffCubit, AddStaffState>(
                        builder: (context, addState) =>
                            BlocBuilder<StaffFormCubit, StaffFormState>(
                              builder: (context, formState) => AppButton(
                                title: widget.editStaff != null ? 'Update' : 'Add',
                                color: AppTheme.btnColor,
                                isLoading: addState.loading,
                                onTap: () {
                                  if (addState.loading) return;
                                  if (formState.fields.isEmpty) {
                                    _submitForm(context);
                                  } else {
                                    if (_formKey.currentState?.validate() ?? false) {
                                      _submitForm(context);
                                    }
                                  }
                                },
                              ),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _submitForm(BuildContext context) {
    if (_schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('School ID not found. Cannot add staff.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    String? roleId = _selectValues['role'];
    if (roleId == null || roleId.isEmpty) {
      final roles = _staffFormCubit.state.roles;
      final e = widget.editStaff;
      if (e != null) {
        if (e.roleId != null) roleId = e.roleId.toString();
        if ((roleId == null || roleId.isEmpty) && e.roleName.isNotEmpty && roles.isNotEmpty) {
          try {
            final matched = roles.firstWhere(
                  (r) => r.name.toLowerCase() == e.roleName.toLowerCase(),
            );
            roleId = matched.id.toString();
          } catch (_) {}
        }
      }
      if ((roleId == null || roleId.isEmpty) && roles.length == 1) {
        roleId = roles.first.id.toString();
      }
    }

    final hasStaffDetailsFields = _staffFormCubit.state.fields.isNotEmpty;
    if (hasStaffDetailsFields && (roleId == null || roleId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a role'), backgroundColor: Colors.red),
      );
      return;
    }

    final fields = <String, dynamic>{};

    for (final entry in _controllers.entries) {
      if (entry.key == 'role') continue;
      fields[entry.key] = entry.value.text;
    }
    if (roleId != null && roleId.isNotEmpty) {
      fields['role'] = roleId;
    }
    for (final entry in _selectValues.entries) {
      if (entry.key == 'role') continue;
      if (entry.value != null) fields[entry.key] = entry.value;
    }

    if (widget.editStaff != null) {
      _addStaffCubit.update(
        schoolId: _schoolId,
        uuid: widget.editStaff!.uuid,
        fields: fields,
        emergencyContacts: const [],
        roleId: roleId,
      );
    } else {
      _addStaffCubit.submit(
        schoolId: _schoolId,
        fields: fields,
        emergencyContacts: const [],
      );
    }
  }
}

class _DotDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    if (newValue.text.length < oldValue.text.length) return newValue;
    String digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 8) digits = digits.substring(0, 8);
    String formatted = '';
    for (int i = 0; i < digits.length; i++) {
      if (i == 2 || i == 4) formatted += '.';
      formatted += digits[i];
    }
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
