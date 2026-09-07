import 'package:flutter_test/flutter_test.dart';
import 'package:mavio/core/services/qr_pdf_service.dart';
import 'package:mavio/models/models.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

void main() {
  test('Test QrPdfService generate single and batch', () async {
    final v1 = MavioVehicle(
      id: 'v1',
      orgId: 'org1',
      name: 'BUS 01',
      regNumber: 'TN 01 AB 1234',
      status: 'active',
    );
    final v2 = MavioVehicle(
      id: 'v2',
      orgId: 'org1',
      name: 'BUS 02',
      regNumber: 'TN 01 AB 5678',
      status: 'active',
    );
    final v3 = MavioVehicle(
      id: 'v3',
      orgId: 'org1',
      name: 'BUS 03',
      regNumber: 'TN 01 AB 9999',
      status: 'active',
    );
    final v4 = MavioVehicle(
      id: 'v4',
      orgId: 'org1',
      name: 'BUS 04',
      regNumber: 'TN 01 AB 0000',
      status: 'active',
    );
    final v5 = MavioVehicle(
      id: 'v5',
      orgId: 'org1',
      name: 'BUS 05',
      regNumber: 'TN 01 AB 1111',
      status: 'active',
    );
    final org = MavioOrganization(
      id: 'org1',
      name: 'Alpha College of Engg',
      code: 'ALPHA',
      createdAt: DateTime.now().toIso8601String(),
    );

    // Test payload
    final payload = QrPdfService.generateBusQrPayload(vehicle: v1, orgId: 'org1');
    expect(payload, contains('BUS 01'));
    final parsed = QrPdfService.parseBusQrPayload(payload);
    expect(parsed?['vehicleId'], equals('v1'));

    // Test document generation
    final pdfBytes = await QrPdfService.generateAllBusesPdfDocument(
      vehicles: [v1, v2, v3, v4, v5],
      org: org,
    );
    expect(pdfBytes.isNotEmpty, isTrue);
  });
}
