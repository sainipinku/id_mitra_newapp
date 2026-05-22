import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/orders/orders_state.dart';
import 'package:idmitra/providers/staff_list/staff_list_cubit.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class AssignClassesSheet extends StatefulWidget {
  final String schoolId;
  final String staffUuid;
  final String staffName;
  final StaffListCubit cubit;

  const AssignClassesSheet({
    super.key,
    required this.schoolId,
    required this.staffUuid,
    required this.staffName,
    required this.cubit,
  });

  @override
  State<AssignClassesSheet> createState() => _AssignClassesSheetState();
}

class _AssignClassesSheetState extends State<AssignClassesSheet> {
  bool _adding = false;
  List<Map<String, dynamic>> _assignedClasses = [];
  bool _loadingAssigned = true;

  // Selected item: classId_sectionId key (same as FilterBottomSheet)
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _fetchAssigned();
  }

  Future<void> _fetchAssigned() async {
    setState(() => _loadingAssigned = true);
    final result = await widget.cubit.fetchAssignedClasses(
      schoolId: widget.schoolId,
      uuid: widget.staffUuid,
    );
    setState(() {
      _assignedClasses = result;
      _loadingAssigned = false;
    });
  }

  Future<void> _addClass() async {
    if (_selectedKey == null) return;

    final parts = _selectedKey!.split('_');
    final classId = int.tryParse(parts[0]) ?? 0;
    final sectionId = parts.length > 1 ? int.tryParse(parts[1]) : null;
    final sectionIds = sectionId != null ? [sectionId] : <int>[];

    setState(() => _adding = true);

    final success = await widget.cubit.assignClass(
      schoolId: widget.schoolId,
      uuid: widget.staffUuid,
      classId: classId,
      sectionIds: sectionIds,
    );

    setState(() => _adding = false);

    if (success && mounted) {
      setState(() => _selectedKey = null);
      await _fetchAssigned();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Class assigned successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to assign class'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _removeClass(Map<String, dynamic> cls) async {
    final assignedUuid = cls['assigned_uuid']?.toString() ?? '';
    if (assignedUuid.isEmpty) return;

    final success = await widget.cubit.removeAssignedClass(
      schoolId: widget.schoolId,
      assignedClassUuid: assignedUuid,
    );

    if (success) {
      await _fetchAssigned();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove class'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static const _classOrder = [
    'pre nursery', 'prenursery', 'pre-nursery',
    'nursery',
    'prep', 'pre prep', 'preprep', 'pre-prep',
    'lkg', 'l.k.g', 'lower kg', 'lower kindergarten', 'l kg',
    'ukg', 'u.k.g', 'upper kg', 'upper kindergarten', 'u kg',
    'kg', 'k.g', 'kindergarten',
    '1', 'i', 'class 1', 'grade 1',
    '2', 'ii', 'class 2', 'grade 2',
    '3', 'iii', 'class 3', 'grade 3',
    '4', 'iv', 'class 4', 'grade 4',
    '5', 'v', 'class 5', 'grade 5',
    '6', 'vi', 'class 6', 'grade 6',
    '7', 'vii', 'class 7', 'grade 7',
    '8', 'viii', 'class 8', 'grade 8',
    '9', 'ix', 'class 9', 'grade 9',
    '10', 'x', 'class 10', 'grade 10',
    '11', 'xi', 'class 11', 'grade 11',
    '12', 'xii', 'class 12', 'grade 12',
  ];

  static int _sortIndex(String name) {
    final lower = name.trim().toLowerCase();
    for (int i = 0; i < _classOrder.length; i++) {
      if (lower == _classOrder[i]) return i;
    }
    for (int i = 0; i < _classOrder.length; i++) {
      if (lower.startsWith(_classOrder[i])) return i;
    }
    return 999;
  }

  List<OrderClass> _sorted(List<OrderClass> classes) {
    final list = [...classes];
    list.sort((a, b) {
      final aName = a.nameWithprefix ?? a.name;
      final bName = b.nameWithprefix ?? b.name;
      final ai = _sortIndex(aName);
      final bi = _sortIndex(bName);
      if (ai != bi) return ai.compareTo(bi);
      return aName.toLowerCase().compareTo(bName.toLowerCase());
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OrdersCubit, OrdersState>(
      builder: (context, orderState) {
        final classes = _sorted(orderState.availableClasses);

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assign Classes',
                            style: MyStyles.boldText(
                                size: 16, color: AppTheme.black_Color)),
                        Text(widget.staffName,
                            style: MyStyles.regularText(
                                size: 13,
                                color: AppTheme.graySubTitleColor)),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const Divider(),
                const SizedBox(height: 8),

                Text('Select Class',
                    style: MyStyles.mediumText(
                        size: 13, color: AppTheme.graySubTitleColor)),
                const SizedBox(height: 8),

                // Class list — same style as FilterBottomSheet
                orderState.classesLoading
                    ? Column(
                        children: List.generate(
                          5,
                          (i) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: shimmerBox(height: 44, radius: 8),
                          ),
                        ),
                      )
                    : classes.isEmpty
                        ? Text('No classes available',
                            style: MyStyles.regularText(
                                size: 13,
                                color: AppTheme.graySubTitleColor))
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.30,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: classes.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: AppTheme.LineColor),
                              itemBuilder: (_, index) {
                                final cls = classes[index];
                                final clsName =
                                    cls.nameWithprefix ?? cls.name;
                                final displayName =
                                    cls.sectionName.isNotEmpty
                                        ? '$clsName (${cls.sectionName})'
                                        : clsName;
                                final clsKey =
                                    '${cls.classId}_${cls.sectionId ?? ''}';
                                final isSelected = _selectedKey == clsKey;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedKey =
                                          isSelected ? null : clsKey;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 12),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: MyStyles.regularText(
                                              size: 14,
                                              color: isSelected
                                                  ? AppTheme.btnColor
                                                  : AppTheme.black_Color,
                                            ),
                                          ),
                                        ),
                                        Icon(
                                          isSelected
                                              ? Icons.radio_button_checked
                                              : Icons.radio_button_off,
                                          size: 20,
                                          color: isSelected
                                              ? AppTheme.btnColor
                                              : AppTheme.graySubTitleColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),

                const SizedBox(height: 16),

                // Add button
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        title: 'Assign',
                        height: 48,
                        isLoading: _adding,
                        color: _selectedKey != null
                            ? AppTheme.btnColor
                            : AppTheme.graySubTitleColor,
                        onTap: _selectedKey != null ? _addClass : () {},
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Assigned classes table
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.backBtnBgColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.appBackgroundColor,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(10)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text('Class',
                                    style: MyStyles.boldText(
                                        size: 13,
                                        color: AppTheme.black_Color))),
                            Expanded(
                                child: Text('Sections',
                                    style: MyStyles.boldText(
                                        size: 13,
                                        color: AppTheme.black_Color))),
                            Text('Action',
                                style: MyStyles.boldText(
                                    size: 13, color: AppTheme.black_Color)),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      if (_loadingAssigned)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: List.generate(
                              3,
                              (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                        child: shimmerBox(
                                            height: 14, radius: 6)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: shimmerBox(
                                            height: 14, radius: 6)),
                                    const SizedBox(width: 12),
                                    shimmerBox(
                                        width: 24, height: 24, radius: 12),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      else if (_assignedClasses.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'No assigned classes found.',
                              style: MyStyles.regularText(
                                  size: 13, color: Colors.red.shade300),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _assignedClasses.length,
                          separatorBuilder: (_, __) => Divider(
                              height: 1, color: AppTheme.backBtnBgColor),
                          itemBuilder: (_, i) {
                            final cls = _assignedClasses[i];
                            final className =
                                cls['name']?.toString() ?? '';
                            final sections =
                                cls['sections'] as List? ?? [];
                            final sectionNames = sections
                                .map((s) => s is Map
                                    ? (s['name'] ?? '').toString()
                                    : s.toString())
                                .where((s) => s.isNotEmpty)
                                .join(', ');

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(className,
                                        style: MyStyles.regularText(
                                            size: 14,
                                            color: AppTheme.black_Color)),
                                  ),
                                  Expanded(
                                    child: Text(
                                        sectionNames.isEmpty
                                            ? '-'
                                            : sectionNames,
                                        style: MyStyles.regularText(
                                            size: 13,
                                            color:
                                                AppTheme.graySubTitleColor)),
                                  ),
                                  GestureDetector(
                                    onTap: () => _removeClass(cls),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
