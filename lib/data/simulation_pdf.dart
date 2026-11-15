import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'simulation_report.dart';

typedef SaveSimulationReport = Future<bool> Function(SimulationReport report);

Future<bool> saveSimulationReport(SimulationReport report) async {
  final bytes = await SimulationPdf.create(report);
  final location = await FilePicker.saveFile(
    fileName: report.fileName,
    bytes: bytes,
    mimeType: 'application/pdf',
    dialogTitle: 'Guardar informe de Smart-Cycle',
  );
  return location != null;
}

abstract final class SimulationPdf {
  static final _blue = PdfColor.fromHex('#1769D2');
  static final _green = PdfColor.fromHex('#16815E');
  static final _ink = PdfColor.fromHex('#15364B');
  static final _muted = PdfColor.fromHex('#5C7182');
  static final _soft = PdfColor.fromHex('#E7F6EE');

  static Future<Uint8List> create(SimulationReport report) async {
    final regular = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    final bold = await rootBundle.load('assets/fonts/NotoSans-Bold.ttf');
    final doc = pw.Document(
      title: 'Smart-Cycle · Informe de parcelas',
      author: 'TerraCrop',
    );
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regular),
      bold: pw.Font.ttf(bold),
    );
    final date = report.createdAt;
    String two(int value) => value.toString().padLeft(2, '0');
    final dateLabel =
        '${two(date.day)}/${two(date.month)}/${date.year} · ${two(date.hour)}:${two(date.minute)}';
    for (final parcel in report.parcels) {
      final input = parcel.scenario.input;
      final result = parcel.result;
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: theme,
          header: (_) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TerraCrop',
                  style: pw.TextStyle(
                    color: _green,
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  'SMART-CYCLE',
                  style: pw.TextStyle(
                    color: _blue,
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    dateLabel,
                    style: pw.TextStyle(color: _muted, fontSize: 8),
                  ),
                ),
                pw.Text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(color: _muted, fontSize: 8),
                ),
              ],
            ),
          ),
          build: (_) => [
            pw.Text(
              parcel.scenario.source.name,
              style: pw.TextStyle(
                color: _ink,
                fontSize: 21,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${parcel.scenario.source.crop} · ${parcel.dataLabel}',
              style: pw.TextStyle(color: _muted, fontSize: 10),
            ),
            pw.SizedBox(height: 15),
            pw.Text(
              'Eventos: ${parcel.eventsLabel}',
              style: pw.TextStyle(color: _ink, fontSize: 10),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              '${input.days} días simulados · Intensidad ${(input.intensity * 100).round()}% · Cosecha prevista en ${input.daysToHarvest} días',
              style: pw.TextStyle(color: _muted, fontSize: 9),
            ),
            pw.SizedBox(height: 15),
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: _metric(
                      'Condición simulada',
                      '${result.finalHealth.round()}/100',
                    ),
                  ),
                  pw.Expanded(
                    child: _metric(
                      'Merma simulada',
                      '${result.finalLossPercent.toStringAsFixed(1)}%',
                    ),
                  ),
                  pw.Expanded(
                    child: _metric(
                      'Humedad final simulada',
                      '${result.points.last.moisture.round()}/100',
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 13),
            pw.Text(
              parcel.harvestAdvice,
              style: pw.TextStyle(color: _ink, fontSize: 10, lineSpacing: 3),
            ),
            _heading('Qué hacer en esta parcela'),
            if (parcel.currentCare.isEmpty)
              _paragraph(
                parcel.needsSoilData
                    ? 'Completa el análisis de suelo para precisar los aportes de agua y nutrientes.'
                    : 'Mantén el monitoreo de humedad y nutrientes.',
              ),
            for (final action in parcel.currentCare)
              _action(action.title, action.instruction),
            if (parcel.needsSoilData && parcel.currentCare.isNotEmpty)
              _paragraph(
                'Completa el análisis de suelo para afinar estos cuidados.',
              ),
            if (parcel.scenarioCare.isNotEmpty)
              _heading('Si ocurre el escenario'),
            for (final action in parcel.scenarioCare)
              _action(action.title, action.action),
            _heading('Evolución simulada'),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: _blue),
              cellStyle: pw.TextStyle(fontSize: 8, color: _ink),
              cellPadding: const pw.EdgeInsets.all(7),
              border: null,
              oddRowDecoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5FAF8'),
              ),
              headers: [
                'Día',
                'Condición /100',
                'Humedad /100',
                'Merma simulada',
              ],
              data: [
                for (final point in result.points.where(
                  (p) =>
                      p.day == 0 ||
                      p.day == input.daysToHarvest ||
                      p.day == input.days,
                ))
                  [
                    '${point.day}',
                    '${point.health.round()}',
                    '${point.moisture.round()}',
                    '${point.lossPercent.toStringAsFixed(1)}%',
                  ],
              ],
            ),
            pw.SizedBox(height: 14),
            _paragraph(SimulationReport.notice),
          ],
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _metric(String title, String value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title, style: pw.TextStyle(color: _muted, fontSize: 8)),
      pw.SizedBox(height: 4),
      pw.Text(
        value,
        style: pw.TextStyle(
          color: _blue,
          fontSize: 20,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    ],
  );
  static pw.Widget _heading(String title) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 11, bottom: 6),
    child: pw.Text(
      title,
      style: pw.TextStyle(
        color: _green,
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
      ),
    ),
  );
  static pw.Widget _paragraph(String text) => pw.Text(
    text,
    style: pw.TextStyle(color: _muted, fontSize: 9, lineSpacing: 3),
  );
  static pw.Widget _action(String title, String action) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            color: _ink,
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          action,
          style: pw.TextStyle(color: _ink, fontSize: 8.5, lineSpacing: 1.5),
        ),
      ],
    ),
  );
}
