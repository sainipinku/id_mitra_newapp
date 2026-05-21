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

    // Map keys to labels
    final Map<String, String> columnMap = {
      for (var col in allColumns) col.key: col.label
    };

    final headers = selectedColumnKeys.map((key) => columnMap[key] ?? key).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(schoolName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('Correction Checklist - ${listType.replaceAll('_', ' ').toUpperCase()}', 
                    style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 10),
              ],
            ),
          ),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headers: ['S.No', ...headers],
            data: List.generate(students.length, (index) {
              final student = students[index].student;
              final row = <String>[];
              row.add((index + 1).toString());

              for (var key in selectedColumnKeys) {
                row.add(_getStudentFieldValue(student, key));
              }
              return row;
            }),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String _getStudentFieldValue(CorrectionStudentData? student, String key) {
    if (student == null) return '-';
    
    switch (key) {
      case 'name': return student.name ?? '-';
      case 'email': return student.email ?? '-';
      case 'phone': return student.phone ?? '-';
      case 'reg_no': return student.regNo ?? '-';
      case 'roll_no': return student.rollNo ?? '-';
      case 'admission_no': return student.admissionNo ?? '-';
      case 'dob': return student.dob ?? '-';
      case 'father_name': return student.fatherName ?? '-';
      case 'mother_name': return student.motherName ?? '-';
      case 'address': return student.address ?? '-';
      case 'class': return student.studentClass?.nameWithPrefix ?? '-';
      case 'section': return student.section?.name ?? '-';
      default:
        // Fallback for any other fields that might be in the model but not explicitly handled
        return '-';
    }
  }
}
