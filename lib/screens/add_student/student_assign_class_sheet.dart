import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/api_mamanger/config.dart';
import 'package:idmitra/api_mamanger/secure_storage.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/db_helper.dart';
import 'package:idmitra/providers/students/students_cubit.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';
import 'package:sqflite/sqflite.dart';

class StudentAssignClassSheet extends StatefulWidget {
  final String schoolId;
  final String studentUuid;
  final String studentName;
  final VoidCallback? onAssigned;

  const StudentAssignClassSheet({
    super.key,
    required this.schoolId,
    required this.studentUuid,
    required this.studentName,
    this.onAssigned,
  });

  @override
  State<StudentAssignClassSheet> createState() =>
      _StudentAssignClassSheetState();
}

class _StudentAssignClassSheetState extends State<StudentAssignClassSheet> {
  List<_ClassRow> _availableClasses = [];
  bool _loading = true;
  bool _adding = false;

  _ClassRow? _selectedClass;

  // same sort order as FilterBottomSheet
  static const _classOrder = [
    'pre nursery', 'prenursery', 'pre-nursery',
    'nursery', 'nur',
    'prep', 'pre prep', 'preprep', 'pre-prep', 'pre',
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

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    // 1. Try loading from Local DB first
    final localData = await _loadFromLocal();
    if (localData != null) {
      _processData(localData);
      setState(() => _loading = false);
    }

    // 2. Sync from API
    try {
      final token = await UserSecureStorage.fetchToken();
      final url =
          '${Config.baseUrl}auth/school/${widget.schoolId}/students/form-data';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final data = json['data'] ?? json;

        // Save to Local DB
        await _saveToLocal(data);

        // Process and Update UI
        _processData(data);
      }
    } catch (e) {
      debugPrint('fetchData error: $e');
    }
    setState(() => _loading = false);
  }

  void _processData(Map<String, dynamic> data) {
    final List rawClasses = data['classes'] ?? [];
    final List<_ClassRow> classes = [];

    for (final item in rawClasses) {
      final int classId = item['id'] ?? 0;
      final String className = item['name_withprefix']?.toString() ??
          item['name']?.toString() ??
          '';
      final List sections = item['sections'] ?? [];

      if (sections.isNotEmpty) {
        for (final sec in sections) {
          final sectionId = sec['id'] as int? ?? 0;
          final sectionName =
              sec['name']?.toString().replaceAll('.', '').trim() ?? '';
          final displayName = '$className (Section $sectionName)';
          classes.add(_ClassRow(
            classId: classId,
            sectionId: sectionId,
            displayName: displayName,
          ));
        }
      } else {
        classes.add(_ClassRow(
          classId: classId,
          sectionId: null,
          displayName: className,
        ));
      }
    }

    classes.sort((a, b) {
      final ai = _sortIndex(a.displayName);
      final bi = _sortIndex(b.displayName);
      if (ai != bi) return ai.compareTo(bi);
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });

    setState(() {
      _availableClasses = classes;
    });
  }

  Future<void> _saveToLocal(Map<String, dynamic> data) async {
    try {
      final db = await DBHelper.db;
      await db.insert(
        'school_form_data',
        {
          'school_id': widget.schoolId,
          'classes_json': jsonEncode(data['classes'] ?? []),
          'sessions_json': jsonEncode(data['sessions'] ?? []),
          'houses_json': jsonEncode(data['houses'] ?? []),
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('saveToLocal error: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadFromLocal() async {
    try {
      final db = await DBHelper.db;
      final rows = await db.query(
        'school_form_data',
        where: 'school_id = ?',
        whereArgs: [widget.schoolId],
        limit: 1,
      );
      if (rows.isEmpty) return null;

      final row = rows.first;
      return {
        'classes': jsonDecode(row['classes_json'] as String? ?? '[]'),
        'sessions': jsonDecode(row['sessions_json'] as String? ?? '[]'),
        'houses': jsonDecode(row['houses_json'] as String? ?? '[]'),
      };
    } catch (e) {
      debugPrint('loadFromLocal error: $e');
      return null;
    }
  }

  Future<void> _assign() async {
    if (_selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a class'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() => _adding = true);
    try {
      final success = await context.read<StudentsCubit>().assignClass(
            studentUuid: widget.studentUuid,
            schoolId: widget.schoolId,
            classId: _selectedClass!.classId,
            sectionId: _selectedClass!.sectionId,
          );

      if (!mounted) return;

      if (success) {
        final rootContext = Navigator.of(context, rootNavigator: true).context;
        Navigator.pop(context, true);
        widget.onAssigned?.call();
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(
            content: Text('Student assigned successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to assign class'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('assign error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Something went wrong'),
              backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _adding = false);
  }

  @override
  Widget build(BuildContext context) {
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Assign Class',
                      style: MyStyles.boldText(
                          size: 16, color: AppTheme.black_Color)),
                  Text(widget.studentName,
                      style: MyStyles.regularText(
                          size: 13, color: AppTheme.graySubTitleColor)),
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
          const Divider(height: 24),

          // ── Class list (same style as FilterBottomSheet) ─────────────
          Text('Select Class',
              style: MyStyles.mediumText(
                  size: 13, color: AppTheme.graySubTitleColor)),
          const SizedBox(height: 8),

          if (_loading)
            Column(
              children: List.generate(
                4,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: shimmerBox(height: 44, radius: 8),
                ),
              ),
            )
          else if (_availableClasses.isEmpty)
            Text('No classes available',
                style: MyStyles.regularText(
                    size: 13, color: AppTheme.graySubTitleColor))
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.30,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _availableClasses.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: AppTheme.LineColor),
                itemBuilder: (context, index) {
                  final cls = _availableClasses[index];
                  final isSelected = _selectedClass == cls;
                  return InkWell(
                    onTap: () => setState(() => _selectedClass = cls),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cls.displayName,
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

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              title: 'Assign',
              isLoading: _adding,
              color: AppTheme.btnColor,
              onTap: _assign,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow {
  final int classId;
  final int? sectionId;
  final String displayName;

  const _ClassRow({
    required this.classId,
    required this.sectionId,
    required this.displayName,
  });
}
