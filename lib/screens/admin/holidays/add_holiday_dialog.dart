import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/text_filed.dart';
import 'package:idmitra/models/holidays/HolidayModel.dart';
import 'package:idmitra/providers/holidays/holidays_cubit.dart';
import 'package:idmitra/utils/MyStyles.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class AddHolidayDialog extends StatefulWidget {
  final String schoolId;
  final VoidCallback onAdded;
  final HolidayModel? editHoliday;

  const AddHolidayDialog({
    super.key,
    required this.schoolId,
    required this.onAdded,
    this.editHoliday,
  });

  @override
  State<AddHolidayDialog> createState() => _AddHolidayDialogState();
}

class _AddHolidayDialogState extends State<AddHolidayDialog> {
  int _step = 1;

  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  final Set<DateTime> _selectedDates = {};

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _type = 'school';
  bool _saving = false;

  bool get _isEditMode => widget.editHoliday != null;

  static const _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  @override
  void initState() {
    super.initState();
    final h = widget.editHoliday;
    if (h != null) {
      _nameCtrl.text = h.name ?? '';
      _descCtrl.text = h.description ?? '';
      _type = h.type ?? 'school';
      for (final dt in h.dateTimes) {
        _selectedDates.add(DateTime(dt.year, dt.month, dt.day));
      }
      if (h.dateTimes.isNotEmpty) {
        _focusedMonth = DateTime(
          h.dateTimes.first.year,
          h.dateTimes.first.month,
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isInRange(DateTime date) {
    if (_rangeStart == null || _rangeEnd == null) return false;
    final s = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
    final e = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;
    return date.isAfter(s.subtract(const Duration(days: 1))) &&
        date.isBefore(e.add(const Duration(days: 1)));
  }

  bool _isRangeStart(DateTime date) =>
      _rangeStart != null && _isSameDay(date, _rangeStart!);

  bool _isRangeEnd(DateTime date) =>
      _rangeEnd != null && _isSameDay(date, _rangeEnd!);

  bool _isSelected(DateTime date) =>
      _selectedDates.any((d) => _isSameDay(d, date));

  void _onDayTap(DateTime date) {
    setState(() {
      if (_rangeStart != null && _rangeEnd == null) {
        // Range mode active — this tap sets the end date
        _rangeEnd = date;
        final s = _rangeStart!.isBefore(_rangeEnd!) ? _rangeStart! : _rangeEnd!;
        final e = _rangeStart!.isBefore(_rangeEnd!) ? _rangeEnd! : _rangeStart!;
        DateTime cur = s;
        while (!cur.isAfter(e)) {
          _selectedDates.add(DateTime(cur.year, cur.month, cur.day));
          cur = cur.add(const Duration(days: 1));
        }
        _rangeStart = null;
        _rangeEnd = null;
      } else {
        final norm = DateTime(date.year, date.month, date.day);
        if (_selectedDates.any((d) => _isSameDay(d, norm))) {
          _selectedDates.removeWhere((d) => _isSameDay(d, norm));
        } else {
          _selectedDates.add(norm);
        }
      }
    });
  }

  void _onDayDoubleTap(DateTime date) {
    setState(() {
      _rangeStart = DateTime(date.year, date.month, date.day);
      _rangeEnd = null;
    });
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  String _dayName(DateTime d) => _dayNames[d.weekday % 7];

  String _toApiDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter holiday name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final sortedDates = _selectedDates.toList()..sort();
    final dateStrings = sortedDates.map(_toApiDate).toList();

    String? error;
    if (_isEditMode) {
      error = await context.read<HolidaysCubit>().updateHoliday(
        schoolId: widget.schoolId,
        holidayId: widget.editHoliday!.id!,
        name: name,
        dates: dateStrings,
        type: _type,
        description: _descCtrl.text.trim(),
      );
    } else {
      error = await context.read<HolidaysCubit>().addHoliday(
        schoolId: widget.schoolId,
        name: name,
        dates: dateStrings,
        type: _type,
        description: _descCtrl.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              (_isEditMode
                  ? 'Holiday updated successfully'
                  : 'Holiday added successfully'),
        ),
        backgroundColor: error == null ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
    if (error == null) widget.onAdded();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          _stepIndicator(),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: _step == 1 ? _step1Body() : _step2Body(),
            ),
          ),
          const Divider(height: 1),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.btnColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.calendar_month,
              color: AppTheme.btnColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditMode ? 'Edit Holiday' : 'Select Holiday Dates',
            style: MyStyles.boldTxt(AppTheme.black_Color, 16),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          _stepChip(1, 'Select Dates', _step >= 1),
          Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _step == 2 ? AppTheme.btnColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _stepChip(2, 'Holiday Info', _step == 2),
        ],
      ),
    );
  }

  Widget _stepChip(int num, String label, bool active) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: active ? AppTheme.btnColor : Colors.grey.shade300,
          child: Text(
            '$num',
            style: TextStyle(
              color: active ? Colors.white : Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? AppTheme.btnColor : Colors.grey,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _step1Body() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final wide = constraints.maxWidth > 500;
          final calendar = _calendarWidget();
          final selectedList = _selectedDatesList();
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: calendar),
                const SizedBox(width: 16),
                SizedBox(width: 220, child: selectedList),
              ],
            );
          }
          return Column(
            children: [calendar, const SizedBox(height: 16), selectedList],
          );
        },
      ),
    );
  }

  Widget _calendarWidget() {
    final today = DateTime.now();
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    ).day;
    final startWeekday = firstDay.weekday % 7;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month - 1,
                  );
                }),
                child: const Icon(Icons.arrow_back, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                  style: MyStyles.boldTxt(AppTheme.black_Color, 15),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                  );
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.btnColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Today',
                    style: MyStyles.mediumTxt(AppTheme.btnColor, 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month + 1,
                  );
                }),
                child: const Icon(Icons.arrow_forward, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_rangeStart != null && _rangeEnd == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppTheme.btnColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.touch_app, size: 14, color: AppTheme.btnColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'From ${_rangeStart!.day} ${_monthNames[_rangeStart!.month - 1]} — tap end date',
                      style: MyStyles.regularTxt(AppTheme.btnColor, 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: _dayNames
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: MyStyles.mediumTxt(
                          AppTheme.graySubTitleColor,
                          11,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
            ),
            itemCount: startWeekday + daysInMonth,
            itemBuilder: (ctx, index) {
              if (index < startWeekday) return const SizedBox();
              final day = index - startWeekday + 1;
              final date = DateTime(
                _focusedMonth.year,
                _focusedMonth.month,
                day,
              );
              final isToday = _isSameDay(date, today);
              final isSelected = _isSelected(date);
              final inRange = _isInRange(date);
              final isStart = _isRangeStart(date);
              final isEnd = _rangeEnd != null && _isRangeEnd(date);

              Color bgColor = Colors.transparent;
              Color textColor = AppTheme.black_Color;
              BorderRadius radius = BorderRadius.circular(8);

              if (isSelected) {
                bgColor = AppTheme.btnColor;
                textColor = Colors.white;
              } else if (inRange) {
                bgColor = AppTheme.btnColor.withOpacity(0.15);
                textColor = AppTheme.btnColor;
                // Flat on sides for range middle
                radius = BorderRadius.zero;
                if (isStart) {
                  radius = const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  );
                } else if (isEnd) {
                  radius = const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  );
                }
              } else if (isStart) {
                bgColor = AppTheme.btnColor;
                textColor = Colors.white;
                radius = const BorderRadius.horizontal(
                  left: Radius.circular(8),
                );
              } else if (isToday) {
                bgColor = AppTheme.btnColor.withOpacity(0.1);
                textColor = AppTheme.btnColor;
              }

              return GestureDetector(
                onTap: () => _onDayTap(date),
                onDoubleTap: () => _onDayDoubleTap(date),
                child: Container(
                  margin: EdgeInsets.symmetric(
                    vertical: 2,
                    horizontal: inRange && !isStart && !isEnd ? 0 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: radius,
                    border: isToday && !isSelected && !inRange
                        ? Border.all(color: AppTheme.btnColor, width: 1)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected || isToday || inRange
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _selectedDatesList() {
    final sorted = _selectedDates.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Selected Dates (${sorted.length})',
              style: MyStyles.boldTxt(AppTheme.black_Color, 14),
            ),
            const Spacer(),
            if (sorted.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() {
                  _selectedDates.clear();
                  _rangeStart = null;
                  _rangeEnd = null;
                }),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list_off,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Clear All',
                      style: MyStyles.mediumTxt(Colors.red.shade400, 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (sorted.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                'Single tap = select date\nDouble tap = start range, then tap end date',
                style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 12),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...sorted.map(
            (d) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.btnColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.btnColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.btnColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${d.day}',
                          style: MyStyles.boldTxt(AppTheme.btnColor, 13),
                        ),
                        Text(
                          _monthNames[d.month - 1].substring(0, 3),
                          style: MyStyles.regularTxt(AppTheme.btnColor, 10),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(d),
                          style: MyStyles.mediumTxt(AppTheme.black_Color, 13),
                        ),
                        Text(
                          _dayName(d),
                          style: MyStyles.regularTxt(
                            AppTheme.graySubTitleColor,
                            11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDates.remove(d)),
                    child: Icon(
                      Icons.delete,
                      color: Colors.red.shade400,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget HolidayListShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              shimmerBox(width: 44, height: 44, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shimmerBox(height: 14, width: double.infinity),
                    const SizedBox(height: 8),
                    shimmerBox(height: 12, width: 150),
                    const SizedBox(height: 8),
                    shimmerBox(height: 12, width: 100),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _step2Body() {
    if (_saving)
      return Padding(
        padding: const EdgeInsets.all(16),
        child: HolidayListShimmer(),
      );

    final sorted = _selectedDates.toList()..sort();
    final year = sorted.isNotEmpty ? sorted.first.year : DateTime.now().year;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today, size: 18, color: AppTheme.black_Color),
              const SizedBox(width: 8),
              Text(
                'Holiday Details',
                style: MyStyles.boldTxt(AppTheme.black_Color, 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Selected Dates',
                      style: MyStyles.mediumTxt(AppTheme.black_Color, 13),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _step = 1),
                      child: Row(
                        children: [
                          Icon(
                            Icons.arrow_back,
                            size: 14,
                            color: AppTheme.btnColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Change Dates',
                            style: MyStyles.mediumTxt(AppTheme.btnColor, 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: sorted
                      .map(
                        (d) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.btnColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${d.day} ${_monthNames[d.month - 1]} ${d.year}',
                            style: MyStyles.mediumTxt(AppTheme.btnColor, 12),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 6),
                Text(
                  'Total: ${sorted.length} date(s) selected',
                  style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        text: 'Holiday Name ',
                        style: MyStyles.mediumTxt(AppTheme.black_Color, 13),
                        children: const [
                          TextSpan(
                            text: '*',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: _nameCtrl,
                      hintText: 'e.g. School Sports Day...',
                      textCapitalization: TextCapitalization.words,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Year',
                      style: MyStyles.mediumTxt(AppTheme.black_Color, 13),
                    ),
                    const SizedBox(height: 6),
                    AppTextField(
                      controller: TextEditingController(text: '$year'),
                      hintText: '$year',
                      enabled: false,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-detected',
                      style: MyStyles.regularTxt(
                        AppTheme.graySubTitleColor,
                        11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Description
          Text(
            'Description (Optional)',
            style: MyStyles.mediumTxt(AppTheme.black_Color, 13),
          ),
          const SizedBox(height: 6),
          AppTextField(
            controller: _descCtrl,
            hintText: 'Add description about this holiday...',
            mxLine: 4,
          ),
          const SizedBox(height: 4),
          Text(
            'Optional: Add notes or details about this holiday',
            style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 11),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_step == 1) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: AppButton(
                title: 'Cancel',
                color: Colors.pink.shade400,
                height: 48,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AppButton(
                title: _selectedDates.isEmpty
                    ? 'Holiday Info'
                    : 'Holiday Info (${_selectedDates.length})',
                color: AppTheme.btnColor,
                height: 48,
                onTap: _selectedDates.isEmpty
                    ? () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one date'),
                          backgroundColor: Colors.orange,
                        ),
                      )
                    : () => setState(() => _step = 2),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Expanded(
          //   child: AppButton(
          //     title: 'Back',
          //     color: Colors.grey.shade400,
          //     height: 48,
          //     onTap: () => setState(() => _step = 1),
          //   ),
          // ),
          const SizedBox(width: 8),
          Expanded(
            child: AppButton(
              title: 'Cancel',
              color: Colors.pink.shade400,
              height: 48,
              onTap: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: AppButton(
              title: _isEditMode
                  ? 'Update Holiday (${_selectedDates.length})'
                  : 'Add Holiday (${_selectedDates.length})',
              color: AppTheme.btnColor,
              height: 48,
              isLoading: _saving,
              onTap: _save,
            ),
          ),
        ],
      ),
    );
  }
}
