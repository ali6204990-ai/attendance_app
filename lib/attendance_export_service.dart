import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class AttendanceExportService {
  static Future<pw.Font> _loadArabicFont() async {
    final fontData =
        await rootBundle.load('assets/fonts/arial.ttf');

    return pw.Font.ttf(fontData);
  }

  static String _formatTime(dynamic value) {
    if (value == null) return '--:--';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  static String _formatDuration(dynamic value) {
    final minutes = int.tryParse(value.toString()) ?? 0;

    if (minutes <= 0) return '—';

    final hours = minutes ~/ 60;
    final remaining = minutes % 60;

    return '$hours ساعة و $remaining دقيقة';
  }

  static String _safeFileName(String value) {
    return value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static int _count(
    List<Map<String, dynamic>> employees,
    bool Function(Map<String, dynamic>) condition,
  ) {
    return employees.where(condition).length;
  }

  static int _totalWorkMinutes(
    List<Map<String, dynamic>> employees,
  ) {
    return employees.fold<int>(
      0,
      (total, employee) {
        return total +
            (int.tryParse(
                  employee['work_minutes'].toString(),
                ) ??
                0);
      },
    );
  }

  static Future<void> exportPdf({
    required List<Map<String, dynamic>> employees,
    required String reportDate,
    required String officeName,
  }) async {
    final font = await _loadArabicFont();
    final pdf = pw.Document();

    final employeeNumbers = employees
        .map((e) => e['employee_number'].toString())
        .toSet();

    final employeeCount = employeeNumbers.length;

    final present = _count(
      employees,
      (e) => e['attendance_time'] != null,
    );

    final absent = _count(
      employees,
      (e) => e['status'] == 'غياب',
    );

    final late = _count(
      employees,
      (e) => e['late'] == true,
    );

    final missingDeparture = _count(
      employees,
      (e) => e['status'] == 'لم يسجل الانصراف',
    );

    final totalMinutes = _totalWorkMinutes(employees);

    final totalHours = totalMinutes ~/ 60;
    final remainingMinutes = totalMinutes % 60;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        maxPages: 100,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: font,
        ),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    'تقرير الحضور والانصراف',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),

                pw.Text(
                  'المكتب: $officeName',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.SizedBox(height: 5),

                pw.Text(
                  'الفترة: $reportDate',
                  style: pw.TextStyle(font: font, fontSize: 12),
                ),
                pw.SizedBox(height: 15),

                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(5),
                  ),
                  child: pw.Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _summaryText(
                        'عدد الموظفين',
                        employeeCount,
                        font,
                      ),
                      _summaryText(
                        'أيام الحضور',
                        present,
                        font,
                      ),
                      _summaryText(
                        'أيام الغياب',
                        absent,
                        font,
                      ),
                      _summaryText(
                        'مرات التأخير',
                        late,
                        font,
                      ),
                      _summaryText(
                        'غياب الانصراف',
                        missingDeparture,
                        font,
                      ),
                      pw.Text(
                        'إجمالي ساعات العمل: '
                        '$totalHours ساعة و $remainingMinutes دقيقة',
                        style: pw.TextStyle(
                          font: font,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 15),

                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey600,
                  ),
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(1.2),
                    4: const pw.FlexColumnWidth(1.2),
                    5: const pw.FlexColumnWidth(1.8),
                    6: const pw.FlexColumnWidth(1.8),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        'الرقم الوظيفي',
                        'اسم الموظف',
                        'التاريخ',
                        'الحضور',
                        'الانصراف',
                        'الحالة',
                        'مدة العمل',
                      ].map((title) {
                        return _pdfCell(
                          title,
                          font,
                          bold: true,
                        );
                      }).toList(),
                    ),

                    ...employees.map((employee) {
                      final values = [
                        employee['employee_number']?.toString() ?? '',
                        employee['full_name']?.toString() ?? '',
                        employee['work_date']?.toString() ?? '',
                        _formatTime(employee['attendance_time']),
                        _formatTime(employee['departure_time']),
                        employee['status']?.toString() ?? '',
                        _formatDuration(employee['work_minutes']),
                      ];

                      return pw.TableRow(
                        children: values.map((value) {
                          return _pdfCell(value, font);
                        }).toList(),
                      );
                    }),
                  ],
                ),

                pw.SizedBox(height: 20),

                pw.Center(
                  child: pw.Text(
                    'تم إنشاء التقرير إلكترونياً',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bytes = await pdf.save();

    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'attendance_${_safeFileName(reportDate)}.pdf',
    );
  }

  static pw.Widget _summaryText(
    String title,
    int value,
    pw.Font font,
  ) {
    return pw.Text(
      '$title: $value',
      style: pw.TextStyle(
        font: font,
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
      ),
    );
  }

  static pw.Widget _pdfCell(
    String value,
    pw.Font font, {
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        textDirection: pw.TextDirection.rtl,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          fontWeight:
              bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static Future<void> exportExcel({
    required List<Map<String, dynamic>> employees,
    required String reportDate,
    required String officeName,
  }) async {
    final excel = Excel.createExcel();

    final sheet = excel['تقرير الحضور'];

    final employeeNumbers = employees
        .map((e) => e['employee_number'].toString())
        .toSet();

    final employeeCount = employeeNumbers.length;

    final present = _count(
      employees,
      (e) => e['attendance_time'] != null,
    );

    final absent = _count(
      employees,
      (e) => e['status'] == 'غياب',
    );

    final late = _count(
      employees,
      (e) => e['late'] == true,
    );

    final missingDeparture = _count(
      employees,
      (e) => e['status'] == 'لم يسجل الانصراف',
    );

    final totalMinutes = _totalWorkMinutes(employees);

    sheet.appendRow([
      TextCellValue('تقرير الحضور والانصراف'),
    ]);

    sheet.appendRow([
      TextCellValue('المكتب: $officeName'),
    ]);

    sheet.appendRow([
      TextCellValue('الفترة: $reportDate'),
    ]);

    sheet.appendRow([
      TextCellValue('عدد الموظفين: $employeeCount'),
      TextCellValue('أيام الحضور: $present'),
      TextCellValue('أيام الغياب: $absent'),
      TextCellValue('مرات التأخير: $late'),
      TextCellValue('غياب الانصراف: $missingDeparture'),
      TextCellValue('إجمالي ساعات العمل: ${totalMinutes ~/ 60}'),
    ]);

    sheet.appendRow([
      TextCellValue('الرقم الوظيفي'),
      TextCellValue('اسم الموظف'),
      TextCellValue('التاريخ'),
      TextCellValue('وقت الحضور'),
      TextCellValue('وقت الانصراف'),
      TextCellValue('الحالة'),
      TextCellValue('مدة العمل بالدقائق'),
      TextCellValue('مدة العمل'),
      TextCellValue('متأخر'),
    ]);

    for (final employee in employees) {
      sheet.appendRow([
        TextCellValue(
          employee['employee_number']?.toString() ?? '',
        ),
        TextCellValue(
          employee['full_name']?.toString() ?? '',
        ),
        TextCellValue(
          employee['work_date']?.toString() ?? '',
        ),
        TextCellValue(
          _formatTime(employee['attendance_time']),
        ),
        TextCellValue(
          _formatTime(employee['departure_time']),
        ),
        TextCellValue(
          employee['status']?.toString() ?? '',
        ),
        IntCellValue(
          int.tryParse(
                employee['work_minutes'].toString(),
              ) ??
              0,
        ),
        TextCellValue(
          _formatDuration(employee['work_minutes']),
        ),
        TextCellValue(
          employee['late'] == true ? 'نعم' : 'لا',
        ),
      ]);
    }

    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('تعذر إنشاء ملف Excel');
    }

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/attendance_'
      '${_safeFileName(reportDate)}.xlsx',
    );

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: 'تقرير الحضور والانصراف - $reportDate',
      ),
    );
  }
}