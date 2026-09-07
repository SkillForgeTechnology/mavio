import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';

class QrPdfService {
  /// Base landing URL for universal QR scanning (redirects to Play Store on web/external scanners)
  static const String scanBaseUrl = 'https://mavio.skillforgetechnology.app/scan';

  /// Generates a standardized Universal Link payload string for a vehicle's QR code.
  /// When scanned outside the app, it opens the web landing page and redirects to Google Play.
  /// When scanned inside the MAVIO Driver App, it instantly activates driver shift mode.
  static String generateBusQrPayload({
    required MavioVehicle vehicle,
    required String orgId,
  }) {
    final uri = Uri.parse(scanBaseUrl).replace(
      queryParameters: {
        'app': 'mavio',
        'type': 'bus_qr',
        'v': '1',
        'orgId': orgId,
        'vehicleId': vehicle.id,
        'name': vehicle.name,
        'regNumber': vehicle.regNumber,
      },
    );
    return uri.toString();
  }

  /// Parses and validates a scanned QR payload string (supports both Universal URL & JSON formats)
  static Map<String, dynamic>? parseBusQrPayload(String rawData) {
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) return null;

    // 1. Check if payload is a Universal URL (https://mavio.../scan?...)
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      try {
        final uri = Uri.parse(trimmed);
        final params = uri.queryParameters;
        if (params['app'] == 'mavio' &&
            params['type'] == 'bus_qr' &&
            params.containsKey('vehicleId') &&
            params.containsKey('orgId')) {
          return {
            'app': 'mavio',
            'type': 'bus_qr',
            'v': int.tryParse(params['v'] ?? '1') ?? 1,
            'orgId': params['orgId'] ?? '',
            'vehicleId': params['vehicleId'] ?? '',
            'name': params['name'] ?? '',
            'regNumber': params['regNumber'] ?? '',
          };
        }
      } catch (_) {}
    }

    // 2. Fallback check for legacy JSON payload
    try {
      final decoded = jsonDecode(trimmed);
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
                      barcode: pw.Barcode.qrCode(),
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

  /// Helper to build a single vehicle cut-out sticker badge for batch printing
  static pw.Widget _buildBatchBadge({
    required MavioVehicle vehicle,
    required String orgId,
    required MavioOrganization? org,
  }) {
    final qrPayload = generateBusQrPayload(
      vehicle: vehicle,
      orgId: orgId,
    );

    return pw.Container(
      margin: const pw.EdgeInsets.all(6),
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(
          color: PdfColors.orange600,
          width: 1.5,
          style: pw.BorderStyle.dashed,
        ),
        borderRadius: const pw.BorderRadius.all(
          pw.Radius.circular(12),
        ),
      ),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'MAVIO',
                style: pw.TextStyle(
                  color: PdfColors.orange700,
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (org != null && org.name.isNotEmpty) ...[
                pw.Text(
                  ' | ${org.name.length > 20 ? org.name.substring(0, 20) : org.name}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            vehicle.name.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 3,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(
                pw.Radius.circular(6),
              ),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
            ),
            child: pw.Text(
              vehicle.regNumber.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
            ),
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: qrPayload,
              width: 185,
              height: 185,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'SCAN VIA DRIVER APP TO START TRIP',
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.orange800,
            ),
          ),
        ],
      ),
    );
  }

  /// Generates the raw PDF Document bytes for batch QR printing
  static Future<Uint8List> generateAllBusesPdfDocument({
    required List<MavioVehicle> vehicles,
    required MavioOrganization? org,
  }) async {
    final pdf = pw.Document();
    final orgId = org?.id ?? (vehicles.isNotEmpty ? vehicles.first.orgId ?? '' : '');

    // Split into chunks of 4 cards per A4 page (2 columns x 2 rows)
    const chunkSize = 4;
    for (var i = 0; i < vehicles.length; i += chunkSize) {
      final chunk = vehicles.sublist(
        i,
        i + chunkSize > vehicles.length ? vehicles.length : i + chunkSize,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange700,
                          ),
                        ),
                        if (org != null && org.name.isNotEmpty) ...[
                          pw.Text(
                            ' - ${org.name}',
                            style: pw.TextStyle(
                              fontSize: 12,
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
                        fontSize: 9.5,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Divider(color: PdfColors.grey300, thickness: 0.8),
                pw.SizedBox(height: 6),

                // Row 1 (Item 0 and Item 1)
                pw.Row(
                  children: [
                    pw.Expanded(
                      child: _buildBatchBadge(
                        vehicle: chunk[0],
                        orgId: orgId,
                        org: org,
                      ),
                    ),
                    pw.Expanded(
                      child: chunk.length > 1
                          ? _buildBatchBadge(
                              vehicle: chunk[1],
                              orgId: orgId,
                              org: org,
                            )
                          : pw.SizedBox(),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Row 2 (Item 2 and Item 3)
                if (chunk.length > 2)
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildBatchBadge(
                          vehicle: chunk[2],
                          orgId: orgId,
                          org: org,
                        ),
                      ),
                      pw.Expanded(
                        child: chunk.length > 3
                            ? _buildBatchBadge(
                                vehicle: chunk[3],
                                orgId: orgId,
                                org: org,
                              )
                            : pw.SizedBox(),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Prints or exports a multi-bus batch printable sticker sheet
  static Future<void> printAllBusesQrSheet({
    required List<MavioVehicle> vehicles,
    required MavioOrganization? org,
  }) async {
    if (vehicles.isEmpty) return;

    final bytes = await generateAllBusesPdfDocument(
      vehicles: vehicles,
      org: org,
    );

    final safeOrgName = org?.name.replaceAll(' ', '_') ?? 'Badges';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'Mavio_Fleet_QR_$safeOrgName.pdf',
    );
  }
}
