import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/providers/orders/orders_cubit.dart';
import 'package:idmitra/providers/orders/orders_state.dart';

class FilterBottomSheet extends StatefulWidget {
  final String schoolId;
  const FilterBottomSheet({super.key, required this.schoolId});

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  final Set<String> _selectedClassIds = {};
  final Map<String, String> _selectedClassNames = {};
  String? selectedGender;

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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Filters",
                  style: MyStyles.boldText(size: 16, color: AppTheme.black_Color),
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

            if (_selectedClassNames.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _selectedClassNames.entries.map((entry) {
                  return Chip(
                    label: Text(
                      entry.value,
                      style: MyStyles.regularText(size: 13, color: AppTheme.btnColor),
                    ),
                    backgroundColor: AppTheme.btnColor.withOpacity(0.1),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() {
                      _selectedClassIds.remove(entry.key);
                      _selectedClassNames.remove(entry.key);
                    }),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            Text(
              "Select Class",
              style: MyStyles.mediumText(size: 13, color: AppTheme.graySubTitleColor),
            ),
            const SizedBox(height: 8),

            BlocBuilder<OrdersCubit, OrdersState>(
              buildWhen: (p, c) =>
              p.availableClasses != c.availableClasses ||
                  p.classesLoading != c.classesLoading,
              builder: (context, state) {
                if (state.classesLoading) {
                  return Column(
                    children: List.generate(
                      5,
                          (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: shimmerBox(height: 44, radius: 8),
                      ),
                    ),
                  );
                }
                if (state.availableClasses.isEmpty) {
                  return Text(
                    "No classes available",
                    style: MyStyles.regularText(size: 13, color: AppTheme.graySubTitleColor),
                  );
                }
                final classes = _sorted(state.availableClasses);
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.35,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: classes.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppTheme.LineColor),
                    itemBuilder: (context, index) {
                      final cls = classes[index];
                      final clsId = cls.classId.toString();
                      final clsName = cls.nameWithprefix ?? cls.name;
                      final clsKey = "${cls.classId}_${cls.sectionIds}";
                      final isSelected = _selectedClassIds.contains(clsKey);
                      return InkWell(


                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedClassIds.remove(clsKey);
                              _selectedClassNames.remove(clsKey);
                            } else {
                              _selectedClassIds.add(clsKey);
                              _selectedClassNames[clsKey] = cls.nameWithprefix ?? cls.name;
                            }
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
                                  clsName,
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
                                    ? Icons.check_box
                                    : Icons.check_box_outline_blank,
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
                );
              },
            ),

            const SizedBox(height: 20),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedClassIds.clear();
                        _selectedClassNames.clear();
                        selectedGender = null;
                      });
                    },
                    child: const Text("Reset"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.btnColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final List<String> classIds = []; // keep string flow
                      final List<int> sectionIds = [];  // array

                      for (var key in _selectedClassIds) {
                        final parts = key.split('_');

                        if (parts.length == 2) {
                          classIds.add(parts[0]); // class as string
                          sectionIds.add(int.tryParse(parts[1]) ?? 0);
                        }
                      }

                      Navigator.pop(context, {
                        "class": classIds.isEmpty ? null : classIds.join(','), // ✅ same as before
                        "section": sectionIds.isEmpty ? null : sectionIds,     // ✅ array
                        "gender": selectedGender,
                      });
                      print("section list---------$sectionIds");
                    },
                    child: const Text(
                      "Apply Filter",
                      style: TextStyle(color: Colors.white),
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
}
