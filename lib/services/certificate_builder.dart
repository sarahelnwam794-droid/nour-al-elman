import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CertificateBuilder {

  static const PdfColor _green = PdfColor.fromInt(0xFF2E6B4A);
  static const PdfColor _gold = PdfColor.fromInt(0xFFC9974B);
  static const PdfColor _blue = PdfColor.fromInt(0xFF3FA9C8);
  static const PdfColor _bg = PdfColor.fromInt(0xFFF6F7F6);
  static const PdfColor _textDark = PdfColor.fromInt(0xFF2E3542);
  static const PdfColor _lineGrey = PdfColor.fromInt(0xFF8A8A8A);

  static const String _fontRegularPath = 'assets/fonts/Almarai/Almarai-Regular.ttf';
  static const String _fontBoldPath = 'assets/fonts/Almarai/Almarai-Bold.ttf';
  static const String _logoPath = 'assets/full_logo.png';

  static Future<Uint8List> build({
    required String studentName,
    required String reason,
    DateTime? date,
  }) async {
    final regularData = await rootBundle.load(_fontRegularPath);
    final arabicRegular = pw.Font.ttf(regularData);

    pw.Font arabicBold;
    try {
      final boldData = await rootBundle.load(_fontBoldPath);
      arabicBold = pw.Font.ttf(boldData);
    } catch (_) {

      arabicBold = arabicRegular;
    }

    final logoBytes = (await rootBundle.load(_logoPath)).buffer.asUint8List();
    final logoImage = pw.MemoryImage(logoBytes);

    final d = date ?? DateTime.now();
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(
        2, '0')}/${d.year}';

    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: arabicRegular, bold: arabicBold),
        build: (context) {
          return pw.Container(
            color: _bg,
            padding: const pw.EdgeInsets.all(14),
            child: pw.Container(
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: _green, width: 1.4),
                  bottom: pw.BorderSide(color: _green, width: 1.4),
                  left: pw.BorderSide(color: _green, width: 1.4),
                  right: pw.BorderSide(color: _green, width: 1.4),
                ),
              ),
              padding: const pw.EdgeInsets.all(5),
              child: pw.Container(
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(color: _green, width: 0.8),
                    bottom: pw.BorderSide(color: _green, width: 0.8),
                    left: pw.BorderSide(color: _green, width: 0.8),
                    right: pw.BorderSide(color: _green, width: 0.8),
                  ),
                ),
                padding:
                const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 26),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Image(logoImage, height: 80),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'شهادة شكر وتقدير',
                      style: pw.TextStyle(
                        font: arabicRegular,
                        fontSize: 36,
                        color: _green,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'يسر حلقات نور الإيمان لتعليم القرآن الكريم منح هذه الشهادة',
                      style: pw.TextStyle(
                        font: arabicRegular,
                        fontSize: 15,
                        color: _textDark,
                      ),
                      textDirection: pw.TextDirection.rtl,
                    ),
                    pw.SizedBox(height: 26),
                    _fieldRow(
                      label: 'إلى /',
                      value: studentName,
                      font: arabicRegular,
                    ),
                    pw.SizedBox(height: 14),
                    _fieldRow(
                      label: 'تقديراً /',
                      value: reason,
                      font: arabicRegular,
                    ),
                    pw.SizedBox(height: 34),
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [

                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                'التوقيع',
                                style: pw.TextStyle(
                                  font: arabicRegular,
                                  fontSize: 13,
                                  color: _textDark,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                              pw.SizedBox(height: 22),
                              pw.Container(
                                width: 110,
                                height: 0.8,
                                color: _lineGrey,
                              ),
                            ],
                          ),
                        ),

                        pw.Container(
                          width: 64,
                          height: 64,
                          decoration: pw.BoxDecoration(
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(color: _gold, width: 5),
                          ),
                          child: pw.Center(
                            child: pw.Container(
                              width: 42,
                              height: 42,
                              decoration: const pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: _blue,
                              ),
                            ),
                          ),
                        ),

                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Text(
                                'التاريخ',
                                style: pw.TextStyle(
                                  font: arabicRegular,
                                  fontSize: 13,
                                  color: _textDark,
                                ),
                                textDirection: pw.TextDirection.rtl,
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                dateStr,
                                style: pw.TextStyle(
                                  font: arabicRegular,
                                  fontSize: 13,
                                  color: _textDark,
                                ),
                              ),
                              pw.SizedBox(height: 6),
                              pw.Container(
                                width: 110,
                                height: 0.8,
                                color: _lineGrey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    return doc.save();
  }

  static pw.Widget _fieldRow({
    required String label,
    required String value,
    required pw.Font font,
  }) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            children: [
              pw.Text(
                value,
                textAlign: pw.TextAlign.center,

                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(font: font, fontSize: 15, color: _textDark),
              ),
              pw.SizedBox(height: 4),
              pw.Container(height: 0.8, color: _lineGrey),
            ],
          ),
        ),
        pw.SizedBox(width: 12),
        pw.Text(
          label,

          textDirection: pw.TextDirection.rtl,
          style: pw.TextStyle(font: font, fontSize: 15, color: _textDark),
        ),
      ],
    );
  }
}
