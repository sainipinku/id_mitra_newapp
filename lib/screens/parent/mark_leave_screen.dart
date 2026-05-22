import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/utils/MyStyles.dart';

const _kLeaveStudents = ['Aarav Sharma', 'Priya Sharma'];

class MarkLeaveScreen extends StatefulWidget {
  const MarkLeaveScreen({super.key});

  @override
  State<MarkLeaveScreen> createState() => _MarkLeaveScreenState();
}

class _MarkLeaveScreenState extends State<MarkLeaveScreen> {
  String _selectedStudent = _kLeaveStudents[0];
  DateTime? _fromDate;
  DateTime? _toDate;
  String _selectedReason = 'Medical';
  final _noteController = TextEditingController();
  bool _submitted = false;

  final _reasons = ['Medical', 'Family Function', 'Travel', 'Other'];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppTheme.btnColor),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) _toDate = picked;
      } else {
        _toDate = picked;
      }
    });
  }

  int get _leaveDays {
    if (_fromDate == null || _toDate == null) return 0;
    return _toDate!.difference(_fromDate!).inDays + 1;
  }

  void _submit() {
    if (_fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select leave dates')),
      );
      return;
    }
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.appBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppTheme.black_Color,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Mark Leave',
            style: MyStyles.boldTxt(AppTheme.black_Color, 17)),
        centerTitle: false,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.btnColor, const Color(0xFF0077B6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_busy_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Leave Application',
                          style: MyStyles.boldTxt(Colors.white, 15)),
                      Text('Submit leave request for your child',
                          style: MyStyles.regularTxt(
                              Colors.white.withOpacity(0.8), 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Select Student
          _sectionLabel('Select Student'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 6)
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedStudent,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.btnColor),
                style: MyStyles.mediumTxt(AppTheme.black_Color, 14),
                onChanged: (v) => setState(() => _selectedStudent = v!),
                items: _kLeaveStudents
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Date Range
          _sectionLabel('Leave Duration'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _datePicker('From', _fromDate, () => _pickDate(isFrom: true))),
              const SizedBox(width: 12),
              Expanded(child: _datePicker('To', _toDate, () => _pickDate(isFrom: false))),
            ],
          ),
          if (_leaveDays > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppTheme.btnColor),
                const SizedBox(width: 6),
                Text(
                  '$_leaveDays day${_leaveDays > 1 ? 's' : ''} of leave',
                  style: MyStyles.mediumTxt(AppTheme.btnColor, 12),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Reason
          _sectionLabel('Reason'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.map((r) {
              final selected = _selectedReason == r;
              return GestureDetector(
                onTap: () => setState(() => _selectedReason = r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.btnColor
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? AppTheme.btnColor
                          : Colors.grey.shade300,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: AppTheme.btnColor.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Text(
                    r,
                    style: MyStyles.mediumTxt(
                        selected ? Colors.white : AppTheme.graySubTitleColor,
                        13),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Additional Note (Optional)'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.04), blurRadius: 6)
              ],
            ),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              style: MyStyles.regularTxt(AppTheme.black_Color, 13),
              decoration: InputDecoration(
                hintText: 'Write a note for the teacher...',
                hintStyle:
                    MyStyles.regularTxt(AppTheme.graySubTitleColor, 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.btnColor,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Submit Leave Request',
                  style: MyStyles.boldTxt(Colors.white, 15)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _datePicker(String label, DateTime? date, VoidCallback onTap) {
    final formatted = date == null
        ? 'Select Date'
        : '${date.day} ${_monthName(date.month)} ${date.year}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: date != null ? AppTheme.btnColor : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6)
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16,
                color: date != null
                    ? AppTheme.btnColor
                    : AppTheme.graySubTitleColor),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: MyStyles.regularTxt(
                          AppTheme.graySubTitleColor, 10)),
                  Text(formatted,
                      style: MyStyles.mediumTxt(
                          date != null
                              ? AppTheme.black_Color
                              : AppTheme.graySubTitleColor,
                          12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: MyStyles.semiBoldTxt(AppTheme.black_Color, 13));

  String _monthName(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade600, size: 56),
            ),
            const SizedBox(height: 20),
            Text('Leave Submitted!',
                style: MyStyles.boldTxt(AppTheme.black_Color, 20)),
            const SizedBox(height: 8),
            Text(
              'Your leave request for $_selectedStudent has been sent to the school. You will be notified once it is approved.',
              style: MyStyles.regularTxt(AppTheme.graySubTitleColor, 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.btnColor,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Back to Dashboard',
                    style: MyStyles.boldTxt(Colors.white, 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
