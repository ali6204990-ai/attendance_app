import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class TransferHistoryExportService {
  static Future<pw.Font> _loadArabicFont() async {
    final fontData = await rootBundle.load('assets/fonts/arial.ttf');
    return pw.Font.ttf(fontData);
  }

  static String _formatDate(dynamic value) {
    if (value == null) return 'غير محدد';

    try {
      final date = DateTime.parse(value.toString()).toLocal();

      String two(int number) => number.toString().padLeft(2, '0');

      return '${date.year}/${two(date.month)}/${two(date.day)}'
          ' - ${two(date.hour)}:${two(date.minute)}';
    } catch (_) {
      return 'غير محدد';
    }
  }

  static Map<String, dynamic> _transferRow(
    Map<String, dynamic> transfer,
    Map<String, Map<String, dynamic>> employees,
    Map<int, String> offices,
  ) {
    final employee =
        employees[transfer['employee_id']?.toString()] ?? {};

    final fromId =
        int.tryParse(transfer['from_office_id']?.toString() ?? '') ?? -1;

    final toId =
        int.tryParse(transfer['to_office_id']?.toString() ?? '') ?? -1;

    return {
      'number': employee['employee_number']?.toString() ?? '',
      'name': employee['full_name']?.toString() ?? 'موظف غير معروف',
      'from': offices[fromId] ?? 'غير معروف',
      'to': offices[toId] ?? 'غير معروف',
      'date': _formatDate(transfer['transferred_at']),
      'reason': transfer['reason']?.toString() ?? '',
    };
  }

  static Future<void> exportPdf({
    required List<Map<String, dynamic>> transfers,
    required Map<String, Map<String, dynamic>> employees,
    required Map<int, String> offices,
  }) async {
    final font = await _loadArabicFont();
    final pdf = pw.Document();

    final rows = transfers
        .map((transfer) => _transferRow(transfer, employees, offices))
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: font),
        build: (context) => [
          pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    'سجل تنقلات الموظفين',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Text(
                  'إجمالي عمليات النقل: ${rows.length}',
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.SizedBox(height: 15),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey600),
                  defaultVerticalAlignment:
                      pw.TableCellVerticalAlignment.middle,
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.5),
                    1: const pw.FlexColumnWidth(2.5),
                    2: const pw.FlexColumnWidth(2),
                    3: const pw.FlexColumnWidth(2),
                    4: const pw.FlexColumnWidth(2),
                    5: const pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey300,
                      ),
                      children: [
                        'الرقم الوطني',
                        'اسم الموظف',
                        'المكتب السابق',
                        'المكتب الجديد',
                        'تاريخ النقل',
                        'سبب النقل',
                      ].map((title) {
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            title,
                            textAlign: pw.TextAlign.center,
                            textDirection: pw.TextDirection.rtl,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    ...rows.map((row) {
                      final values = [
                        row['number'],
                        row['name'],
                        row['from'],
                        row['to'],
                        row['date'],
                        row['reason'],
                      ];

                      return pw.TableRow(
                        children: values.map((value) {
                          return pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(
                              value.toString().isEmpty
                                  ? '—'
                                  : value.toString(),
                              textAlign: pw.TextAlign.center,
                              textDirection: pw.TextDirection.rtl,
                              style: pw.TextStyle(
                                font: font,
                                fontSize: 8,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Text(
                  'تم إنشاء السجل إلكترونياً',
                  textAlign: pw.TextAlign.center,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(font: font, fontSize: 9),
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
      filename: 'transfer_history.pdf',
    );
  }

  static Future<void> exportExcel({
    required List<Map<String, dynamic>> transfers,
    required Map<String, Map<String, dynamic>> employees,
    required Map<int, String> offices,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['سجل التنقلات'];

    sheet.appendRow([
      TextCellValue('سجل تنقلات الموظفين'),
    ]);

    sheet.appendRow([
      TextCellValue('إجمالي عمليات النقل: ${transfers.length}'),
    ]);

    sheet.appendRow([
      TextCellValue('الرقم الوطني'),
      TextCellValue('اسم الموظف'),
      TextCellValue('المكتب السابق'),
      TextCellValue('المكتب الجديد'),
      TextCellValue('تاريخ النقل'),
      TextCellValue('سبب النقل'),
    ]);

    for (final transfer in transfers) {
      final row = _transferRow(transfer, employees, offices);

      sheet.appendRow([
        TextCellValue(row['number'].toString()),
        TextCellValue(row['name'].toString()),
        TextCellValue(row['from'].toString()),
        TextCellValue(row['to'].toString()),
        TextCellValue(row['date'].toString()),
        TextCellValue(row['reason'].toString()),
      ]);
    }

    final bytes = excel.save();

    if (bytes == null) {
      throw Exception('تعذر إنشاء ملف Excel');
    }

    final directory = await getTemporaryDirectory();

    final file = File(
      '${directory.path}/transfer_history.xlsx',
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
        text: 'سجل تنقلات الموظفين',
      ),
    );
  }
}