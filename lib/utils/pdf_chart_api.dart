import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class PdfChartApi {
  static Future<String> generate({
    required String userName,
    required List<Map<String, dynamic>> readings,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Health Report for $userName', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          ),
          pw.TableHelper.fromTextArray(
            headers: ['Measurement', 'Date', 'Time', 'Readings Value (Sys/Dia/Pulse)'],
            data: readings.map((r) => [
              r['measurement'],
              r['date'],
              r['time'],
              r['value'],
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: pw.TextStyle(fontSize: 12),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            border: pw.TableBorder.all(color: PdfColors.grey),
          ),
        ],
      ),
    );

    // Use app's private directory - no permissions required
    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/HealthReports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    
    // Create a user-friendly filename with date and time
    final now = DateTime.now();
    final dateFormat = DateFormat('dd-MM-yyyy_HH:mm');
    final formattedDate = dateFormat.format(now);
    final filePath = '${reportsDir.path}/HealthReport_$formattedDate.pdf';
    
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }

  static Future<String> generateFull({
    required String userName,
    required String userEmail,
    required String userPhone,
    required List<Map<String, dynamic>> medicationData,
    required List<Map<String, dynamic>> bpData,
    required List<Map<String, dynamic>> symptomsData,
    required String logoPath,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    // Load logo image from assets
    final ByteData logoData = await rootBundle.load(logoPath);
    final Uint8List logoBytes = logoData.buffer.asUint8List();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Health Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text('Exported: ${startDate.day.toString().padLeft(2, '0')}/${startDate.month.toString().padLeft(2, '0')}/${startDate.year} - ${endDate.day.toString().padLeft(2, '0')}/${endDate.month.toString().padLeft(2, '0')}/${endDate.year}', style: pw.TextStyle(fontSize: 12)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('User Information', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Name: $userName'),
          pw.Bullet(text: 'Email: $userEmail'),
          pw.Bullet(text: 'Phone: $userPhone'),
          pw.SizedBox(height: 16),
          if (medicationData.isNotEmpty) ...[
            pw.Text('Medication Intake', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: pw.FixedColumnWidth(60), // Name
                1: pw.FixedColumnWidth(40), // Dose
                2: pw.FixedColumnWidth(40), // Type
                3: pw.FixedColumnWidth(50), // Intake Time
                4: pw.FixedColumnWidth(50), // Start Date
                5: pw.FixedColumnWidth(50), // End Date
                6: pw.FixedColumnWidth(40), // Status
                7: pw.FixedColumnWidth(50), // Date Taken
                8: pw.FixedColumnWidth(40), // Time Taken
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Name', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Dose', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Type', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Intake\nTime', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Start\nDate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('End\nDate', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Status', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Date\nTaken', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Time\nTaken', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows
                ...medicationData.map((m) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['name'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['dose'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['type'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['intakeTime'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['startDate'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['endDate'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['status'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['date'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(m['time'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          if (bpData.isNotEmpty) ...[
            pw.Text('Blood Pressure Readings', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: pw.FixedColumnWidth(50), // Date
                1: pw.FixedColumnWidth(35), // Time
                2: pw.FixedColumnWidth(40), // Systolic
                3: pw.FixedColumnWidth(40), // Diastolic
                4: pw.FixedColumnWidth(35), // Pulse
                5: pw.FixedColumnWidth(70), // Category
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Date', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Time', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Systolic', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Diastolic', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Pulse', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Category', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows
                ...bpData.map((b) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['date'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['time'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['systolic'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['diastolic'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['pulse'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(b['category'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
          if (symptomsData.isNotEmpty) ...[
            pw.Text('Symptoms', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: pw.FixedColumnWidth(80), // Symptoms
                1: pw.FixedColumnWidth(40), // Severity
                2: pw.FixedColumnWidth(50), // Label
                3: pw.FixedColumnWidth(50), // Date
                4: pw.FixedColumnWidth(40), // Time
              },
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Symptoms', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Severity', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Label', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Date', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text('Time', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                // Data rows
                ...symptomsData.map((s) => pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(s['symptoms'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(s['severity'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(s['label'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(s['date'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: pw.EdgeInsets.all(4),
                      child: pw.Text(s['time'] ?? '', style: pw.TextStyle(fontSize: 8)),
                    ),
                  ],
                )),
              ],
            ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final reportsDir = Directory('${dir.path}/HealthReports');
    if (!await reportsDir.exists()) {
      await reportsDir.create(recursive: true);
    }
    
    final now = DateTime.now();
    final dateFormat = DateFormat('dd-MM-yyyy_HH:mm');
    final formattedDate = dateFormat.format(now);
    final filePath = '${reportsDir.path}/HealthReport_$formattedDate.pdf';
    
    final file = File(filePath);
    await file.writeAsBytes(await pdf.save());
    return filePath;
  }
} 
