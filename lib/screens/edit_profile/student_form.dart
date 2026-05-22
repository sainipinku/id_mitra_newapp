import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/models/schools/SchoolListModel.dart';
import 'package:idmitra/models/student_form/StudentFormFieldsModel.dart';
import 'package:idmitra/providers/staff_form/staff_form_cubit.dart';
import 'package:idmitra/providers/student_form/student_form_cubit.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class _EditableField {
  final String name;
  final String label;
  final String type;
  bool isRequired;
  _EditableField({
    required this.name,
    required this.label,
    required this.type,
    this.isRequired = false,
  });
}

class StudentForm extends StatefulWidget {
  final SchoolDetailsModel schoolDetailsModel;
  const StudentForm({super.key, required this.schoolDetailsModel});

  @override
  State<StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<StudentForm> {
  @override
  void initState() {
    super.initState();

    final currentState = context.read<StudentFormCubit>().state;
    if (currentState.fields.isEmpty && !currentState.loading) {
      final sig = widget.schoolDetailsModel.sig ?? '';
      if (sig.isNotEmpty) {
        context.read<StudentFormCubit>().loadFromModelWithSig(
          fields: widget.schoolDetailsModel.studentFormFields ?? [],
          schoolName: widget.schoolDetailsModel.name ?? '',
          sig: sig,
        );
      } else {
        context.read<StudentFormCubit>().loadFromModel(
          fields: widget.schoolDetailsModel.studentFormFields ?? [],
          schoolName: widget.schoolDetailsModel.name ?? '',
          schoolId: widget.schoolDetailsModel.id?.toString() ?? '',
        );
      }
    }

    final staffState = context.read<StaffFormCubit>().state;
    if (staffState.fields.isEmpty && !staffState.loading) {
      context.read<StaffFormCubit>().loadFields(
        widget.schoolDetailsModel.id?.toString() ?? '',
        schoolName: widget.schoolDetailsModel.name ?? '',
      );
    }
  }


  void _openAddFields(
      StateSetter setSheet,
      List<_EditableField> tempFields,
      List<StudentFormField> apiAvailable,
      ) {
    final List<Map<String, String>> pool = apiAvailable
        .where((f) => !tempFields.any((t) => t.name == f.name))
        .map((f) => {'name': f.name, 'label': f.label, 'type': f.type})
        .toList();

    List<Map<String, String>> filtered = List.from(pool);
    final Set<int> selected = {};
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setAdd) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Multiple Fields',
                            style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Select one or more fields to add to the student registration form',
                            style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setAdd(() {
                    filtered = pool
                        .where((f) => f['label']!.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                    selected.clear();
                  }),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.whiteColor,
                    contentPadding: const EdgeInsets.all(12),
                    hintText: 'Search by field name...',
                    prefixIcon: const Icon(Icons.search),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.backBtnBgColor),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.backBtnBgColor),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    hintStyle: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Fields',
                        style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                    GestureDetector(
                      onTap: () => setAdd(() => selected.length == filtered.length
                          ? selected.clear()
                          : selected.addAll(List.generate(filtered.length, (i) => i))),
                      child: Text('Select All',
                          style: MyStyles.regularText(size: 13, color: AppTheme.btnColor)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text('No more fields available',
                      style: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor)),
                )
                    : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  onReorder: (oldIndex, newIndex) {
                    setAdd(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = filtered.removeAt(oldIndex);
                      filtered.insert(newIndex, item);
                      selected.clear();
                    });
                  },
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    final checked = selected.contains(i);
                    return GestureDetector(
                      key: ValueKey(f['name']),
                      onTap: () => setAdd(() => checked ? selected.remove(i) : selected.add(i)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.backBtnBgColor),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: checked,
                                activeColor: AppTheme.redBtnBgColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setAdd(
                                        () => v == true ? selected.add(i) : selected.remove(i)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['label']!,
                                      style: MyStyles.boldText(size: 13, color: AppTheme.black_Color)),
                                  Text('Type: ${f['type']}',
                                      style: MyStyles.regularText(
                                          size: 11, color: AppTheme.graySubTitleColor)),
                                ],
                              ),
                            ),
                            const Icon(Icons.drag_indicator, color: Colors.grey, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Text('${selected.length} field(s) selected',
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor)),
                    const Spacer(),
                    SizedBox(
                      width: 150,
                      child: AppButton(
                        title: '+ Add ${selected.length} Fields',
                        isLoading: false,
                        color: selected.isEmpty ? AppTheme.backBtnBgColor : AppTheme.btnColor,
                        height: 42,
                        onTap: selected.isEmpty
                            ? () {}
                            : () {
                          setSheet(() {
                            for (final i in selected) {
                              final f = filtered[i];
                              tempFields.add(_EditableField(
                                name: f['name']!,
                                label: f['label']!,
                                type: f['type']!,
                              ));
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openConfigure(
      List<StudentFormField> currentFields,
      String schoolName,
      List<StudentFormField> availableFields,
      ) {
    final List<_EditableField> tempFields = currentFields
        .map((f) => _EditableField(
      name: f.name,
      label: f.label,
      type: f.type,
      isRequired: f.required,
    ))
        .toList();

    final cubit = context.read<StudentFormCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: BlocListener<StudentFormCubit, StudentFormState>(
          listener: (listenerCtx, state) {
            if (state.successMessage != null) {
              navigator.pop();
              messenger.showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ));
              cubit.clearMessages();
            }
            if (state.error != null && !state.loading && !state.saving) {
              messenger.showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ));
              cubit.clearMessages();
            }
          },
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final reqCount = tempFields.where((f) => f.isRequired).length;
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Configure Student Form Fields',
                                    style: MyStyles.boldText(size: 16, color: AppTheme.black_Color)),
                                const SizedBox(height: 4),
                                Text('$schoolName • ${tempFields.length} fields ($reqCount required)',
                                    style: MyStyles.regularText(
                                        size: 12, color: AppTheme.graySubTitleColor)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Drag and drop to reorder fields',
                                style: MyStyles.regularText(
                                    size: 12, color: AppTheme.graySubTitleColor)),
                          ),
                          SizedBox(
                            width: 120,
                            child: AppButton(
                              title: 'Add Field',
                              isLoading: false,
                              color: AppTheme.btnColor,
                              height: 36,
                              onTap: () => _openAddFields(setSheet, tempFields, availableFields),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: tempFields.isEmpty
                          ? Center(
                        child: Text('No fields added yet',
                            style: MyStyles.regularText(
                                size: 14, color: AppTheme.graySubTitleColor)),
                      )
                          : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tempFields.length,
                        onReorder: (oldIndex, newIndex) {
                          setSheet(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = tempFields.removeAt(oldIndex);
                            tempFields.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (_, i) {
                          final f = tempFields[i];
                          return Container(
                            key: ValueKey(f.name),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.backBtnBgColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.drag_indicator,
                                        color: Colors.grey, size: 20),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(f.label,
                                          style: MyStyles.boldText(
                                              size: 13, color: AppTheme.black_Color),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    _typeBadge(f.type),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            value: f.isRequired,
                                            activeColor: AppTheme.redBtnBgColor,
                                            materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (v) =>
                                                setSheet(() => f.isRequired = v ?? false),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('Required',
                                            style: MyStyles.regularText(
                                                size: 12,
                                                color: f.isRequired
                                                    ? AppTheme.redBtnBgColor
                                                    : AppTheme.graySubTitleColor)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => setSheet(() => tempFields.removeAt(i)),
                                      child: const Icon(Icons.delete_outline,
                                          color: Colors.grey, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppTheme.backBtnBgColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              title: 'Cancel',
                              isLoading: false,
                              color: AppTheme.backBtnBgColor,
                              height: 42,
                              onTap: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BlocBuilder<StudentFormCubit, StudentFormState>(
                              builder: (_, state) => AppButton(
                                title: state.saving ? 'Saving...' : 'Save Configure',
                                isLoading: state.saving,
                                color: AppTheme.btnColor,
                                height: 42,
                                onTap: state.saving
                                    ? () {}
                                    : () {
                                  final updated = tempFields
                                      .asMap()
                                      .entries
                                      .map((e) => StudentFormField(
                                    name: e.value.name,
                                    label: e.value.label,
                                    group: '',
                                    groupLabel: '',
                                    type: e.value.type,
                                    required: e.value.isRequired,
                                    order: e.key + 1,
                                  ))
                                      .toList();
                                  cubit.updateStudentFormFields(updated);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  void _openStaffAddFields(
      StateSetter setSheet,
      List<_EditableField> tempFields,
      List<StudentFormField> apiAvailable,
      ) {
    final List<Map<String, String>> pool = apiAvailable
        .where((f) => !tempFields.any((t) => t.name == f.name))
        .map((f) => {'name': f.name, 'label': f.label, 'type': f.type})
        .toList();

    List<Map<String, String>> filtered = List.from(pool);
    final Set<int> selected = {};
    final searchCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setAdd) => SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add Multiple Fields',
                              style: MyStyles.boldText(size: 16, color: AppTheme.black_Color)),
                          const SizedBox(height: 4),
                          Text(
                            'Select one or more fields to add to the staff registration form',
                            style: MyStyles.regularText(
                                size: 12, color: AppTheme.graySubTitleColor),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setAdd(() {
                    filtered = pool
                        .where((f) => f['label']!.toLowerCase().contains(v.toLowerCase()))
                        .toList();
                    selected.clear();
                  }),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.whiteColor,
                    contentPadding: const EdgeInsets.all(12),
                    hintText: 'Search by field name...',
                    prefixIcon: const Icon(Icons.search),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.backBtnBgColor),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppTheme.backBtnBgColor),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    hintStyle: MyStyles.regularText(size: 14, color: AppTheme.graySubTitleColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Select Fields',
                        style: MyStyles.regularText(size: 13, color: AppTheme.black_Color)),
                    GestureDetector(
                      onTap: () => setAdd(() => selected.length == filtered.length
                          ? selected.clear()
                          : selected.addAll(List.generate(filtered.length, (i) => i))),
                      child: Text('Select All',
                          style: MyStyles.regularText(size: 13, color: AppTheme.btnColor)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                  child: Text('No more fields available',
                      style: MyStyles.regularText(
                          size: 14, color: AppTheme.graySubTitleColor)),
                )
                    : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  onReorder: (oldIndex, newIndex) {
                    setAdd(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = filtered.removeAt(oldIndex);
                      filtered.insert(newIndex, item);
                      selected.clear();
                    });
                  },
                  itemBuilder: (_, i) {
                    final f = filtered[i];
                    final checked = selected.contains(i);
                    return GestureDetector(
                      key: ValueKey(f['name']),
                      onTap: () =>
                          setAdd(() => checked ? selected.remove(i) : selected.add(i)),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.backBtnBgColor),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                value: checked,
                                activeColor: AppTheme.redBtnBgColor,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (v) => setAdd(
                                        () => v == true ? selected.add(i) : selected.remove(i)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(f['label']!,
                                      style: MyStyles.boldText(
                                          size: 13, color: AppTheme.black_Color)),
                                  Text('Type: ${f['type']}',
                                      style: MyStyles.regularText(
                                          size: 11, color: AppTheme.graySubTitleColor)),
                                ],
                              ),
                            ),
                            const Icon(Icons.drag_indicator, color: Colors.grey, size: 18),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
                child: Row(
                  children: [
                    Text('${selected.length} field(s) selected',
                        style: MyStyles.regularText(size: 12, color: AppTheme.graySubTitleColor)),
                    const Spacer(),
                    SizedBox(
                      width: 150,
                      child: AppButton(
                        title: '+ Add ${selected.length} Fields',
                        isLoading: false,
                        color: selected.isEmpty ? AppTheme.backBtnBgColor : AppTheme.btnColor,
                        height: 42,
                        onTap: selected.isEmpty
                            ? () {}
                            : () {
                          setSheet(() {
                            for (final i in selected) {
                              final f = filtered[i];
                              tempFields.add(_EditableField(
                                name: f['name']!,
                                label: f['label']!,
                                type: f['type']!,
                              ));
                            }
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _openStaffConfigure(
      List<StudentFormField> currentFields,
      String schoolName,
      List<StudentFormField> availableFields,
      ) {
    final List<_EditableField> tempFields = currentFields
        .map((f) => _EditableField(
      name: f.name,
      label: f.label,
      type: f.type,
      isRequired: f.required,
    ))
        .toList();

    final staffCubit = context.read<StaffFormCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.whiteColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => BlocProvider.value(
        value: staffCubit,
        child: BlocListener<StaffFormCubit, StaffFormState>(
          listener: (listenerCtx, state) {
            if (state.successMessage != null) {
              navigator.pop();
              messenger.showSnackBar(SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ));
              staffCubit.clearMessages();
            }
            if (state.error != null && !state.loading && !state.saving) {
              messenger.showSnackBar(SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ));
              staffCubit.clearMessages();
            }
          },
          child: StatefulBuilder(
            builder: (ctx, setSheet) {
              final reqCount = tempFields.where((f) => f.isRequired).length;
              return SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Configure Staff Form Fields',
                                    style: MyStyles.boldText(size: 16, color: AppTheme.black_Color)),
                                const SizedBox(height: 4),
                                Text('$schoolName • ${tempFields.length} fields ($reqCount required)',
                                    style: MyStyles.regularText(
                                        size: 12, color: AppTheme.graySubTitleColor)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(ctx),
                            child: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('Drag and drop to reorder fields',
                                style: MyStyles.regularText(
                                    size: 12, color: AppTheme.graySubTitleColor)),
                          ),
                          SizedBox(
                            width: 120,
                            child: AppButton(
                              title: 'Add Field',
                              isLoading: false,
                              color: AppTheme.btnColor,
                              height: 36,
                              onTap: () =>
                                  _openStaffAddFields(setSheet, tempFields, availableFields),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: tempFields.isEmpty
                          ? Center(
                        child: Text('No fields added yet',
                            style: MyStyles.regularText(
                                size: 14, color: AppTheme.graySubTitleColor)),
                      )
                          : ReorderableListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: tempFields.length,
                        onReorder: (oldIndex, newIndex) {
                          setSheet(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = tempFields.removeAt(oldIndex);
                            tempFields.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (_, i) {
                          final f = tempFields[i];
                          return Container(
                            key: ValueKey(f.name),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.backBtnBgColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.drag_indicator,
                                        color: Colors.grey, size: 20),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(f.label,
                                          style: MyStyles.boldText(
                                              size: 13, color: AppTheme.black_Color),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    const SizedBox(width: 6),
                                    _typeBadge(f.type),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: Checkbox(
                                            value: f.isRequired,
                                            activeColor: AppTheme.redBtnBgColor,
                                            materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                            onChanged: (v) =>
                                                setSheet(() => f.isRequired = v ?? false),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text('Required',
                                            style: MyStyles.regularText(
                                                size: 12,
                                                color: f.isRequired
                                                    ? AppTheme.redBtnBgColor
                                                    : AppTheme.graySubTitleColor)),
                                      ],
                                    ),
                                    GestureDetector(
                                      onTap: () => setSheet(() => tempFields.removeAt(i)),
                                      child: const Icon(Icons.delete_outline,
                                          color: Colors.grey, size: 20),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: AppTheme.backBtnBgColor)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              title: 'Cancel',
                              isLoading: false,
                              color: AppTheme.backBtnBgColor,
                              height: 42,
                              onTap: () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: BlocBuilder<StaffFormCubit, StaffFormState>(
                              builder: (_, state) => AppButton(
                                title: state.saving ? 'Saving...' : 'Save Configure',
                                isLoading: state.saving,
                                color: AppTheme.btnColor,
                                height: 42,
                                onTap: state.saving
                                    ? () {}
                                    : () {
                                  final updated = tempFields
                                      .asMap()
                                      .entries
                                      .map((e) => StudentFormField(
                                    name: e.value.name,
                                    label: e.value.label,
                                    group: '',
                                    groupLabel: '',
                                    type: e.value.type,
                                    required: e.value.isRequired,
                                    order: e.key + 1,
                                  ))
                                      .toList();
                                  staffCubit.updateStaffFormFields(updated);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }


  Widget _typeBadge(String type) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AppTheme.appBackgroundColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.backBtnBgColor),
    ),
    child: Text(
      type,
      style: MyStyles.regularText(size: 10, color: AppTheme.graySubTitleColor),
    ),
  );


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CommonAppBar(
        title: 'Student Form Fields',
        backgroundColor: Colors.transparent,
        showText: true,
      ),
      body: BlocBuilder<StudentFormCubit, StudentFormState>(
        builder: (context, state) {
          if (state.loading) {
            return const StudentFormShimmer();
          }

          if (state.error != null && state.fields.isEmpty) {
            return Center(
              child: Text(state.error!,
                  style: MyStyles.regularText(size: 14, color: Colors.red)),
            );
          }

          final fields = state.fields;
          final schoolName = state.schoolName.isNotEmpty
              ? state.schoolName
              : widget.schoolDetailsModel.name ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Student Form Fields',
                              style: MyStyles.boldText(size: 16, color: AppTheme.black_Color)),
                          const SizedBox(height: 4),
                          Text('Configure which fields show on the Add Student form',
                              style: MyStyles.regularText(
                                  size: 12, color: AppTheme.graySubTitleColor)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 110,
                      child: AppButton(
                        title: 'Configure',
                        isLoading: false,
                        color: AppTheme.btnColor,
                        height: 40,
                        onTap: () => _openConfigure(fields, schoolName, state.availableFields),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current Fields (${fields.length})',
                          style: MyStyles.boldText(size: 14, color: AppTheme.black_Color)),
                      const SizedBox(height: 12),
                      fields.isEmpty
                          ? Text('No fields configured',
                          style: MyStyles.regularText(
                              size: 13, color: AppTheme.graySubTitleColor))
                          : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: fields
                            .map((f) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.appBackgroundColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.backBtnBgColor),
                          ),
                          child: Text(
                            f.required ? '${f.label} *' : f.label,
                            style: MyStyles.regularText(
                                size: 12, color: AppTheme.black_Color),
                          ),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                BlocBuilder<StaffFormCubit, StaffFormState>(
                  builder: (context, staffState) {
                    if (staffState.loading) {
                      return const ShimmerForm(fieldCount: 6);
                    }

                    if (staffState.error != null && staffState.fields.isEmpty) {
                      return Center(
                        child: Column(
                          children: [
                            Text(staffState.error!,
                                style: MyStyles.regularText(size: 14, color: Colors.red)),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => context.read<StaffFormCubit>().loadFields(
                                widget.schoolDetailsModel.id?.toString() ?? '',
                                schoolName: widget.schoolDetailsModel.name ?? '',
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final staffFields = staffState.fields;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Staff Form Fields',
                                      style: MyStyles.boldText(
                                          size: 16, color: AppTheme.black_Color)),
                                  const SizedBox(height: 4),
                                  Text('Configure which fields show on the Add Staff form',
                                      style: MyStyles.regularText(
                                          size: 12, color: AppTheme.graySubTitleColor)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 110,
                              child: AppButton(
                                title: 'Configure',
                                isLoading: false,
                                color: AppTheme.btnColor,
                                height: 40,
                                onTap: () => _openStaffConfigure(
                                  staffFields,
                                  schoolName,
                                  staffState.availableFields,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.05), blurRadius: 8),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Fields (${staffFields.length})',
                                  style:
                                  MyStyles.boldText(size: 14, color: AppTheme.black_Color)),
                              const SizedBox(height: 12),
                              staffFields.isEmpty
                                  ? Text('No fields configured',
                                  style: MyStyles.regularText(
                                      size: 13, color: AppTheme.graySubTitleColor))
                                  : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: staffFields
                                    .map((f) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.appBackgroundColor,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: AppTheme.backBtnBgColor),
                                  ),
                                  child: Text(
                                    f.required ? '${f.label} *' : f.label,
                                    style: MyStyles.regularText(
                                        size: 12, color: AppTheme.black_Color),
                                  ),
                                ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}