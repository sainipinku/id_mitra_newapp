import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:idmitra/models/correction/CorrectionListModel.dart';
import 'package:idmitra/providers/correction/correction_state.dart';

class PdfHelper {
  static Future<Uint8List> generateCorrectionChecklist({
    required String schoolName,
    required List<CorrectionStudentItem> students,
    required List<String> selectedColumnKeys,
    required List<DownloadColumn> allColumns,
    required String listType,
  }) async {
    final pdf = pw.Document();

    final Map<String, String> columnMap = {
      for (var col in allColumns) col.key: col.label
    };

    // Group students by class name
    final Map<String, List<CorrectionStudentItem>> byClass = {};
    for (final item in students) {
      final className =
          item.student?.studentClass?.nameWithPrefix ?? 'No Class';
      byClass.putIfAbsent(className, () => []).add(item);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          final widgets = <pw.Widget>[];
          bool firstGroup = true;

          for (final entry in byClass.entries) {
            final className = entry.key;
            final classStudents = entry.value;

            // Separate each class group with a new page (except the first)
            if (!firstGroup) {
              widgets.add(pw.NewPage());
            }
            firstGroup = false;

            // Class section header — "[School Name] (ClassName)"
            widgets.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Text(
                  '$schoolName ($className)',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            );

            // Student cards for this class
            for (final item in classStudents) {
              final student = item.student;
              final name = student?.name ?? '';
              final initials = name
                  .split(' ')
                  .where((w) => w.isNotEmpty)
                  .take(2)
                  .map((w) => w[0].toUpperCase())
                  .join();

              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  decoration: pw.BoxDecoration(
                    border:
                        pw.Border.all(color: PdfColors.grey400, width: 0.5),
                  ),
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Initials box
                      pw.Container(
                        width: 36,
                        height: 36,
                        color: PdfColors.grey300,
                        alignment: pw.Alignment.center,
                        child: pw.Text(
                          initials.isNotEmpty ? initials : '?',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      // Student detail rows
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            for (final key in selectedColumnKeys)
                              pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 2),
                                child: pw.Text(
                                  '${columnMap[key] ?? key} : ${_getStudentFieldValue(student, key)}',
                                  style: const pw.TextStyle(fontSize: 9),
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
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static String _getStudentFieldValue(CorrectionStudentData? student, String key) {
    if (student == null) return '-';
    switch (key) {
      case 'name':
      case 'student_name':
        return student.name ?? '-';
      case 'email':
        return student.email ?? '-';
      case 'phone':
        return student.phone ?? '-';
      case 'father_phone':
        return student.fatherPhone ?? '-';
      case 'mother_phone':
        return student.motherPhone ?? '-';
      case 'reg_no':
        return student.regNo ?? '-';
      case 'roll_no':
        return student.rollNo ?? '-';
      case 'admission_no':
        return student.admissionNo ?? '-';
      case 'dob':
        return student.dob ?? '-';
      case 'father_name':
        return student.fatherName ?? '-';
      case 'mother_name':
        return student.motherName ?? '-';
      case 'address':
        return student.address ?? '-';
      case 'class':
        return student.studentClass?.nameWithPrefix ?? '-';
      case 'section':
      case 'class_section':
        return student.section?.name ?? '-';
      default:
        return '-';
    }
  }
}
