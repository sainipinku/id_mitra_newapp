import 'package:flutter/material.dart';
import 'package:idmitra/components/app_theme.dart';
import 'package:idmitra/components/my_font_weight.dart';
import 'package:idmitra/utils/common_widgets/app_button.dart';

class DownloadChecklistDialog extends StatefulWidget {
  const DownloadChecklistDialog({super.key});

  @override
  State<DownloadChecklistDialog> createState() => _DownloadChecklistDialogState();
}

class _DownloadChecklistDialogState extends State<DownloadChecklistDialog> {
  // Field selections
  bool _session = true;
  bool _schoolName = true;
  bool _studentName = true;
  bool _fatherName = true;
  bool _class = true;
  bool _fatherPhone = true;
  bool _address = true;
  bool _photo = true;
  bool _photoUrl = true;

  String? _printListType;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 16 : 40,
        vertical: 24,
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: isSmallScreen ? screenWidth - 32 : 700,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Download Checklist',
                      style: MyStyles.boldText(size: 20, color: AppTheme.black_Color),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close, color: Colors.red.shade400, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Data You Want to Display in Correction List',
                      style: MyStyles.mediumText(size: 15, color: AppTheme.graySubTitleColor),
                    ),
                    const SizedBox(height: 20),
                    // Checkboxes in column for better visibility
                    _buildCheckboxItem('Session', _session, (v) => setState(() => _session = v!)),
                    _buildCheckboxItem('School Name', _schoolName, (v) => setState(() => _schoolName = v!)),
                    _buildCheckboxItem('Student Name', _studentName, (v) => setState(() => _studentName = v!)),
                    _buildCheckboxItem('Father Name', _fatherName, (v) => setState(() => _fatherName = v!)),
                    _buildCheckboxItem('Class', _class, (v) => setState(() => _class = v!)),
                    _buildCheckboxItem('Father Phone', _fatherPhone, (v) => setState(() => _fatherPhone = v!)),
                    _buildCheckboxItem('Address', _address, (v) => setState(() => _address = v!)),
                    _buildCheckboxItem('Photo', _photo, (v) => setState(() => _photo = v!)),
                    _buildCheckboxItem('Photo URL', _photoUrl, (v) => setState(() => _photoUrl = v!)),
                    const SizedBox(height: 24),
                    // Print List Type
                    Text(
                      'Print List Type *',
                      style: MyStyles.boldText(size: 15, color: AppTheme.black_Color),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.backBtnBgColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _printListType,
                          isExpanded: true,
                          hint: Text(
                            '-Select Print Type-',
                            style: MyStyles.regularText(size: 15, color: AppTheme.graySubTitleColor),
                          ),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.graySubTitleColor, size: 24),
                          items: [
                            DropdownMenuItem(
                              value: 'class_wise',
                              child: Text('Class Wise', style: MyStyles.regularText(size: 15, color: AppTheme.black_Color)),
                            ),
                            DropdownMenuItem(
                              value: 'section_wise',
                              child: Text('Section Wise', style: MyStyles.regularText(size: 15, color: AppTheme.black_Color)),
                            ),
                          ],
                          onChanged: (v) => setState(() => _printListType = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      title: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      color: AppTheme.cancelTextColor,
                      height: 50,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      title: 'Confirm',
                      onTap: _printListType == null ? () {} : () => _onConfirm(),
                      color: _printListType == null 
                          ? AppTheme.btnColor.withOpacity(0.5) 
                          : AppTheme.btnColor,
                      height: 50,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxItem(String label, bool value, ValueChanged<bool?> onChanged) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: value ? AppTheme.btnColor.withOpacity(0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? AppTheme.btnColor : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: value ? AppTheme.btnColor : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: MyStyles.mediumText(
                  size: 15,
                  color: AppTheme.black_Color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onConfirm() {
    final selectedFields = <String, bool>{
      'session': _session,
      'school_name': _schoolName,
      'student_name': _studentName,
      'father_name': _fatherName,
      'class': _class,
      'father_phone': _fatherPhone,
      'address': _address,
      'photo': _photo,
      'photo_url': _photoUrl,
    };

    Navigator.pop(context, {
      'fields': selectedFields,
      'print_type': _printListType,
    });
  }
}
