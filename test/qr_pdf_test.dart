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

    // Test URL payload
    final urlPayload = QrPdfService.generateBusQrPayload(vehicle: v1, orgId: 'org1');
    expect(urlPayload, startsWith('https://mavio.skillforgetechnology.app/scan'));
    expect(urlPayload, contains('vehicleId=v1'));
    final parsedUrl = QrPdfService.parseBusQrPayload(urlPayload);
    expect(parsedUrl?['vehicleId'], equals('v1'));
    expect(parsedUrl?['orgId'], equals('org1'));
    expect(parsedUrl?['name'], equals('BUS 01'));

    // Test legacy JSON payload backward compatibility
    final legacyJson = '{"app":"mavio","type":"bus_qr","v":1,"orgId":"org1","vehicleId":"v1","name":"BUS 01","regNumber":"TN 01 AB 1234"}';
    final parsedLegacy = QrPdfService.parseBusQrPayload(legacyJson);
    expect(parsedLegacy?['vehicleId'], equals('v1'));
    expect(parsedLegacy?['name'], equals('BUS 01'));

    // Test document generation
    final pdfBytes = await QrPdfService.generateAllBusesPdfDocument(
      vehicles: [v1, v2, v3, v4, v5],
      org: org,
    );
    expect(pdfBytes.isNotEmpty, isTrue);
  });
}
