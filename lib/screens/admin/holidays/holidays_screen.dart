import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:idmitra/Widgets/CommonAppBar.dart';
import 'package:idmitra/Widgets/shimmer_loader.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/models/holidays/HolidayModel.dart';
import 'package:idmitra/providers/holidays/holidays_cubit.dart';
import 'package:idmitra/providers/holidays/holidays_state.dart';
import 'package:idmitra/screens/admin/holidays/add_holiday_dialog.dart';
import 'package:idmitra/utils/MyStyles.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class HolidaysScreen extends StatelessWidget {
  final String schoolId;
  const HolidaysScreen({super.key, required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HolidaysCubit()..fetchHolidays(schoolId: schoolId),
      child: _HolidaysView(schoolId: schoolId),
    );
  }
}

class _HolidaysView extends StatefulWidget {
  final String schoolId;
  const _HolidaysView({required this.schoolId});

  @override
  State<_HolidaysView> createState() => _HolidaysViewState();
}

class _HolidaysViewState extends State<_HolidaysView> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isTableView = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  int _selectedYear = DateTime.now().year;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onYearChanged(int year) {
    setState(() => _selectedYear = year);
    context.read<HolidaysCubit>().fetchHolidays(
      schoolId: widget.schoolId,
      year: year,
      search: _searchQuery,
    );
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);
    context.read<HolidaysCubit>().fetchHolidays(
      schoolId: widget.schoolId,
      year: _selectedYear,
      search: value,
    );
  }

  List<HolidayModel> _monthHolidays(List<HolidayModel> all) {
    return all.where((h) {
      final dt = h.dateTime;
      return dt != null &&
          dt.month == _focusedMonth.month &&
          dt.year == _focusedMonth.year;
    }).toList();
  }

  void _refresh() {
    context.read<HolidaysCubit>().fetchHolidays(
      schoolId: widget.schoolId,
      year: _selectedYear,
      search: _searchQuery,
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, HolidayModel h) async {
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                'Are you sure you want to\ndelete this holiday?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      title: "Yes, I'm sure",
                      color: Colors.red,
                      onTap: () async {
                        Navigator.pop(ctx);
                        final error = await ctx
                            .read<HolidaysCubit>()
                            .deleteHoliday(
                          schoolId: widget.schoolId,
                          holidayId: h.id!,
                        );
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text(
                                error ?? 'Holiday deleted successfully',
                              ),
                              backgroundColor:
                              error == null ? Colors.green : Colors.red,
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
                      onTap: () => Navigator.pop(ctx),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: CommonAppBar(
        title: 'Holidays Management',
        showBackButton: true,
        showDivider: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                _searchBar(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _yearDropdown(),
                    const Spacer(),
                    _tableViewButton(),
                    const SizedBox(width: 8),
                    _addButton(),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<HolidaysCubit, HolidaysState>(
              builder: (context, state) {
                if (state.loading) {
                  return _isTableView
                      ? HolidayListShimmer()
                      : _calendarShimmer();
                }
                if (state.error != null) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          state.error!,
                          style: MyStyles.regularTxt(Colors.red, 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refresh,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.btnColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return _isTableView
                    ? _tableView(context, state.holidays)
                    : _calendarView(state.holidays);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      controller: _searchCtrl,
      style: MyStyles.regularTxt(AppTheme.black_Color, 14),
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(12),
        hintText: 'Search holiday name...',
        prefixIcon: const Icon(Icons.search),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.backBtnBgColor),
          borderRadius: BorderRadius.circular(15),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.backBtnBgColor),
          borderRadius: BorderRadius.circular(15),
        ),
        hintStyle: MyStyles.regularTxt(AppTheme.graySubTitleColor, 14),
      ),
    );
  }

  Widget _yearDropdown() {
    final years = [2024, 2025, 2026, 2027, 2028, 2029, 2030];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.backBtnBgColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedYear,
          style: MyStyles.regularTxt(AppTheme.black_Color, 13),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          items: years
              .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
              .toList(),
          onChanged: (v) {
            if (v != null) _onYearChanged(v);
          },
        ),
      ),
    );
  }

  Widget _tableViewButton() {
    return GestureDetector(
      onTap: () => setState(() => _isTableView = !_isTableView),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isTableView ? AppTheme.btnColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isTableView ? AppTheme.btnColor : AppTheme.backBtnBgColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 16,
              color: _isTableView ? Colors.white : AppTheme.black_Color,
            ),
            const SizedBox(width: 4),
            Text(
              'Table',
              style: MyStyles.mediumTxt(
                _isTableView ? Colors.white : AppTheme.black_Color,
                12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton() {
    return GestureDetector(
      onTap: () => _showAddHolidaySheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.btnColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 16, color: Colors.white),
            const SizedBox(width: 4),
            Text('Add', style: MyStyles.mediumTxt(Colors.white, 12)),
          ],
        ),
      ),
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

  Widget _calendarShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    shimmerBox(width: 32, height: 32, radius: 8),
                    const SizedBox(width: 10),
                    shimmerBox(width: 120, height: 16),
                    const Spacer(),
                    shimmerBox(width: 60, height: 28, radius: 8),
                    const SizedBox(width: 10),
                    shimmerBox(width: 32, height: 32, radius: 8),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    7,
                        (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: shimmerBox(height: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.95,
                  ),
                  itemCount: 35,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.all(2),
                    child: shimmerBox(height: double.infinity, radius: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                shimmerBox(width: 140, height: 16),
                const SizedBox(height: 12),
                ...List.generate(
                  3,
                      (_) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        shimmerBox(width: 10, height: 10, radius: 5),
                        const SizedBox(width: 8),
                        Expanded(child: shimmerBox(height: 12)),
                        const SizedBox(width: 8),
                        shimmerBox(width: 60, height: 12),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 20),
                Row(
                  children: List.generate(
                    4,
                        (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        child: shimmerBox(height: 48, radius: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _calendarView(List<HolidayModel> holidays) {
    final monthList = _monthHolidays(holidays);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05), blurRadius: 6),
              ],
            ),
            child: Column(
              children: [
                _calendarHeader(),
                const SizedBox(height: 12),
                _calendarGrid(holidays),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _monthSummaryPanel(holidays, monthList),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _calendarHeader() {
    final monthName = _monthNames[_focusedMonth.month - 1];
    return Row(
      children: [
        GestureDetector(
          onTap: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month - 1);
          }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_left, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$monthName ${_focusedMonth.year}',
            style: MyStyles.boldTxt(AppTheme.black_Color, 16),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() {
            _focusedMonth =
                DateTime(DateTime.now().year, DateTime.now().month);
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.btnColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today, size: 13, color: Colors.white),
                const SizedBox(width: 4),
                Text('Today', style: MyStyles.mediumTxt(Colors.white, 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () => setState(() {
            _focusedMonth =
                DateTime(_focusedMonth.year, _focusedMonth.month + 1);
          }),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_right, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _calendarGrid(List<HolidayModel> holidays) {
    final today = DateTime.now();
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;

    final Map<int, HolidayModel> holidayMap = {};
    for (final h in _monthHolidays(holidays)) {
      for (final dt in h.dateTimes) {
        if (dt.month == _focusedMonth.month &&
            dt.year == _focusedMonth.year) {
          holidayMap[dt.day] = h;
        }
      }
    }

    return Column(
      children: [
        Row(
          children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
              .map(
                (d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style:
                  MyStyles.mediumTxt(AppTheme.graySubTitleColor, 12),
                ),
              ),
            ),
          )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.95,
          ),
          itemCount: startWeekday + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startWeekday) return const SizedBox();
            final day = index - startWeekday + 1;
            final date =
            DateTime(_focusedMonth.year, _focusedMonth.month, day);
            final isToday = date.year == today.year &&
                date.month == today.month &&
                date.day == today.day;
            final holiday = holidayMap[day];

            return Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isToday
                    ? AppTheme.btnColor.withOpacity(0.08)
                    : holiday != null
                    ? _typeColor(holiday.type ?? '').withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isToday
                    ? Border.all(color: AppTheme.btnColor, width: 1.5)
                    : Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: MyStyles.mediumTxt(
                      isToday
                          ? AppTheme.btnColor
                          : holiday != null
                          ? _typeColor(holiday.type ?? '')
                          : AppTheme.black_Color,
                      13,
                    ),
                  ),
                  if (holiday != null) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Text(
                        holiday.name ?? '',
                        style: TextStyle(
                          fontSize: 8,
                          color: _typeColor(holiday.type ?? ''),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _monthSummaryPanel(
      List<HolidayModel> all,
      List<HolidayModel> monthList,
      ) {
    final monthName = _monthNames[_focusedMonth.month - 1];
    final total = all.length;
    final superAdmin = all.where((h) => h.type == 'super_admin').length;
    final hidden = all.where((h) => h.type == 'hidden').length;
    final school = all.where((h) => h.type == 'school').length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_month, color: AppTheme.btnColor, size: 18),
              const SizedBox(width: 8),
              Text(
                '$monthName Holidays',
                style: MyStyles.boldTxt(AppTheme.black_Color, 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (monthList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    Text(
                      'No holidays this month',
                      style:
                      MyStyles.regularTxt(AppTheme.graySubTitleColor, 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: monthList.map((h) {
                final dt = h.dateTime;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _typeColor(h.type ?? ''),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          h.name ?? '',
                          style:
                          MyStyles.regularTxt(AppTheme.black_Color, 13),
                        ),
                      ),
                      if (dt != null)
                        Text(
                          '${dt.day} ${_monthNames[dt.month - 1].substring(0, 3)}',
                          style: MyStyles.regularTxt(
                              AppTheme.graySubTitleColor, 12),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const Divider(height: 20),
          Row(
            children: [
              _statChip('Total', '$total', AppTheme.black_Color),
              const SizedBox(width: 8),
              _statChip('Super Admin', '$superAdmin', AppTheme.btnColor),
              const SizedBox(width: 8),
              _statChip('Hidden', '$hidden', Colors.red),
              const SizedBox(width: 8),
              _statChip('School', '$school', Colors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value, style: MyStyles.boldTxt(color, 16)),
            const SizedBox(height: 2),
            Text(
              label,
              style:
              MyStyles.regularTxt(AppTheme.graySubTitleColor, 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableView(BuildContext ctx, List<HolidayModel> holidays) {
    if (holidays.isEmpty) {
      return Center(
        child: Image.asset('assets/images/no_data.png', height: 200),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: holidays.length,
      itemBuilder: (context, index) {
        final h = holidays[index];
        final dts = h.dateTimes;
        final firstDt = dts.isNotEmpty ? dts.first : null;
        final lastDt = dts.length > 1 ? dts.last : null;
        final dayCount = dts.length;
        final typeColor = _typeColor(h.type ?? '');

        return GestureDetector(
          onTap: () => _showEditDialog(ctx, h),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 58,
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.08),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                    child: firstDt != null
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _monthNames[firstDt.month - 1]
                              .substring(0, 3)
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: typeColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${firstDt.day}',
                          style: TextStyle(
                            fontSize: 22,
                            color: typeColor,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        if (dayCount > 1)
                          Text(
                            '+${dayCount - 1}',
                            style: TextStyle(
                              fontSize: 9,
                              color: typeColor.withOpacity(0.7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    )
                        : const SizedBox(),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  h.name ?? '',
                                  style: MyStyles.boldTxt(
                                      AppTheme.black_Color, 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: typeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _typeLabel(h.type ?? ''),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: typeColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    Icons.more_vert,
                                    size: 16,
                                    color: Colors.grey.shade400,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _confirmDelete(ctx, h);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete,
                                              size: 16, color: Colors.red),
                                          SizedBox(width: 8),
                                          Text('Delete',
                                              style:
                                              TextStyle(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 5),

                          if (firstDt != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 11,
                                  color: AppTheme.graySubTitleColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    lastDt != null
                                        ? '${_weekdayShort(firstDt)}, ${_monthNames[firstDt.month - 1].substring(0, 3)} ${firstDt.day} – ${_weekdayShort(lastDt)}, ${_monthNames[lastDt.month - 1].substring(0, 3)} ${lastDt.day}, ${lastDt.year}'
                                        : '${_weekdayShort(firstDt)}, ${_monthNames[firstDt.month - 1].substring(0, 3)} ${firstDt.day}, ${firstDt.year}',
                                    style: MyStyles.regularTxt(
                                        AppTheme.graySubTitleColor, 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),

                          const SizedBox(height: 5),

                          Row(
                            children: [
                              Text(
                                '${h.year ?? firstDt?.year ?? ''}',
                                style: MyStyles.regularTxt(
                                    AppTheme.graySubTitleColor, 11),
                              ),
                              if (dayCount > 1) ...[
                                Text(
                                  '  ·  ',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                                Text(
                                  '$dayCount days',
                                  style: MyStyles.regularTxt(
                                      AppTheme.graySubTitleColor, 11),
                                ),
                              ],
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w600,
                                  ),
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
            ),
          ),
        );
      },
    );
  }

  String _weekdayShort(DateTime d) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[d.weekday - 1];
  }

  void _showAddHolidaySheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<HolidaysCubit>(),
        child: AddHolidayDialog(
            schoolId: widget.schoolId, onAdded: _refresh),
      ),
    );
  }

  void _showEditDialog(BuildContext context, HolidayModel holiday) {
    showDialog(
      context: context,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<HolidaysCubit>(),
        child: AddHolidayDialog(
          schoolId: widget.schoolId,
          onAdded: _refresh,
          editHoliday: holiday,
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'super_admin':
        return AppTheme.btnColor;
      case 'hidden':
        return Colors.red;
      case 'school':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'super_admin':
        return 'Super Admin';
      case 'hidden':
        return 'Hidden';
      case 'school':
        return 'School';
      default:
        return type;
    }
  }

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
}

class _AddHolidaySheet extends StatefulWidget {
  final String schoolId;
  final VoidCallback? onAdded;
  const _AddHolidaySheet({required this.schoolId, this.onAdded});

  @override
  State<_AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends State<_AddHolidaySheet> {
  final _nameCtrl = TextEditingController();
  DateTime? _selectedDate;
  String _type = 'school';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

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
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    final cubit = context.read<HolidaysCubit>();
    final error = await cubit.addHoliday(
      schoolId: widget.schoolId,
      name: name,
      type: _type,
      dates: [dateStr],
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Holiday added successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
      widget.onAdded?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Add Holiday',
            style: MyStyles.boldTxt(AppTheme.black_Color, 18),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: MyStyles.regularTxt(AppTheme.black_Color, 14),
            decoration: InputDecoration(
              hintText: 'Holiday name',
              hintStyle:
              MyStyles.regularTxt(AppTheme.graySubTitleColor, 14),
              filled: true,
              fillColor: AppTheme.appBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime(2028),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.appBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 18, color: AppTheme.btnColor),
                  const SizedBox(width: 10),
                  Text(
                    _selectedDate == null
                        ? 'Select date'
                        : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                    style: MyStyles.regularTxt(
                      _selectedDate == null
                          ? AppTheme.graySubTitleColor
                          : AppTheme.black_Color,
                      14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.appBackgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _type,
                isExpanded: true,
                style: MyStyles.regularTxt(AppTheme.black_Color, 14),
                items: const [
                  DropdownMenuItem(value: 'school', child: Text('School')),
                  DropdownMenuItem(
                      value: 'super_admin', child: Text('Super Admin')),
                  DropdownMenuItem(value: 'hidden', child: Text('Hidden')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.btnColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Text(
                'Save Holiday',
                style: MyStyles.mediumTxt(Colors.white, 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}