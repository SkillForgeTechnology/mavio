import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';

class QrPdfService {
  /// Generates a standardized JSON payload string for a vehicle's QR code
  static String generateBusQrPayload({
    required MavioVehicle vehicle,
    required String orgId,
  }) {
    return jsonEncode({
      'app': 'mavio',
      'type': 'bus_qr',
      'v': 1,
      'orgId': orgId,
      'vehicleId': vehicle.id,
      'name': vehicle.name,
      'regNumber': vehicle.regNumber,
    });
  }

  /// Parses and validates a scanned QR payload string
  static Map<String, dynamic>? parseBusQrPayload(String rawData) {
    try {
      final decoded = jsonDecode(rawData.trim());
      if (decoded is Map<String, dynamic>) {
        if (decoded['app'] == 'mavio' &&
            decoded['type'] == 'bus_qr' &&
            decoded.containsKey('vehicleId') &&
            decoded.containsKey('orgId')) {
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Prints or exports a single formatted printable bus dashboard sticker
  static Future<void> printSingleBusQr({
    required MavioVehicle vehicle,
    required MavioOrganization? org,
  }) async {
    final pdf = pw.Document();
    final qrPayload = generateBusQrPayload(
      vehicle: vehicle,
      orgId: org?.id ?? vehicle.orgId ?? '',
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Center(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.orange700, width: 2),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(16)),
              ),
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Organization & Mavio Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        'MAVIO',
                        style: pw.TextStyle(
                          color: PdfColors.orange700,
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (org != null && org.name.isNotEmpty) ...[
                        pw.Text(
                          '  |  ${org.name}',
                          style: pw.TextStyle(
                            color: PdfColors.grey800,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.grey300, thickness: 1),
                  pw.SizedBox(height: 16),

                  // Vehicle Badge Details
                  pw.Text(
                    vehicle.name.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(8),
                      ),
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(
                      vehicle.regNumber.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 20),

                  // High-contrast Crisp QR Code
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(12),
                      ),
                      border: pw.Border.all(color: PdfColors.grey300),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(
                        errorCorrectLevel: pw.BarcodeQRCorrectionLevel.high,
                      ),
                      data: qrPayload,
                      width: 170,
                      height: 170,
                    ),
                  ),
                  pw.SizedBox(height: 18),

                  // Instructions
                  pw.Text(
                    'SCAN WITH MAVIO DRIVER APP TO ACTIVATE TRIP',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Place this sticker on the vehicle dashboard.',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Mavio_QR_${vehicle.name.replaceAll(' ', '_')}.pdf',
    );
  }

  /// Prints or exports a multi-bus batch printable sticker sheet
  static Future<void> printAllBusesQrSheet({
    required List<MavioVehicle> vehicles,
    required MavioOrganization? org,
  }) async {
    if (vehicles.isEmpty) return;

    final pdf = pw.Document();
    final orgId = org?.id ?? vehicles.first.orgId ?? '';

    // Split into chunks of 4 cards per A4 page (2x2 grid)
    const chunkSize = 4;
    for (var i = 0; i < vehicles.length; i += chunkSize) {
      final chunk = vehicles.sublist(
        i,
        i + chunkSize > vehicles.length ? vehicles.length : i + chunkSize,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              children: [
                // Sheet Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'MAVIO FLEET QR BADGES',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange700,
                          ),
                        ),
                        if (org != null && org.name.isNotEmpty) ...[
                          pw.Text(
                            ' - ${org.name}',
                            style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                    pw.Text(
                      'Page ${(i / chunkSize).floor() + 1} of ${(vehicles.length / chunkSize).ceil()}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Divider(color: PdfColors.grey300),
                pw.SizedBox(height: 12),

                // 2x2 Grid of Cut-out Vehicle Badges
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: chunk.map((v) {
                      final qrPayload = generateBusQrPayload(
                        vehicle: v,
                        orgId: orgId,
                      );

                      return pw.Container(
                        padding: const pw.EdgeInsets.all(12),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          border: pw.Border.all(
                            color: PdfColors.orange600,
                            width: 1.5,
                            style: pw.BorderStyle.dashed,
                          ),
                          borderRadius: const pw.BorderRadius.all(
                            pw.Radius.circular(10),
                          ),
                        ),
                        child: pw.Column(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: pw.CrossAxisAlignment.center,
                          children: [
                            pw.Row(
                              mainAxisAlignment: pw.MainAxisAlignment.center,
                              children: [
                                pw.Text(
                                  'MAVIO',
                                  style: pw.TextStyle(
                                    color: PdfColors.orange700,
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                if (org != null && org.name.isNotEmpty) ...[
                                  pw.Text(
                                    ' | ${org.name.length > 18 ? org.name.substring(0, 18) : org.name}',
                                    style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              v.name.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.black,
                              ),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.grey100,
                                borderRadius: const pw.BorderRadius.all(
                                  pw.Radius.circular(4),
                                ),
                              ),
                              child: pw.Text(
                                v.regNumber.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey800,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(
                                errorCorrectLevel:
                                    pw.BarcodeQRCorrectionLevel.medium,
                              ),
                              data: qrPayload,
                              width: 120,
                              height: 120,
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              'SCAN VIA DRIVER APP TO START TRIP',
                              style: pw.TextStyle(
                                fontSize: 6.5,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.orange800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Mavio_Fleet_QR_${org?.name.replaceAll(' ', '_') ?? 'Badges'}.pdf',
    );
  }
}
