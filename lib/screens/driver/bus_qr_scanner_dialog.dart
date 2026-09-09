import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/qr_pdf_service.dart';
import '../../core/theme/theme.dart';
import '../../models/models.dart';

class BusQrScannerDialog extends StatefulWidget {
  final String? expectedOrgId;

  const BusQrScannerDialog({super.key, this.expectedOrgId});

  @override
  State<BusQrScannerDialog> createState() => _BusQrScannerDialogState();
}

class _BusQrScannerDialogState extends State<BusQrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    final parsed = QrPdfService.parseBusQrPayload(rawValue);

    if (parsed == null) {
      setState(() {
        _errorMessage = 'Invalid QR Code. Please scan a Mavio Bus QR.';
      });
      return;
    }

    // Verify organization match if expectedOrgId provided
    if (widget.expectedOrgId != null &&
        widget.expectedOrgId!.isNotEmpty &&
        parsed['orgId'] != widget.expectedOrgId) {
      setState(() {
        _errorMessage = 'This bus belongs to a different institution.';
      });
      return;
    }

    final vehicle = MavioVehicle(
      id: parsed['vehicleId'] ?? '',
      name: parsed['name'] ?? 'Bus',
      regNumber: parsed['regNumber'] ?? '',
      status: 'OFFLINE',
      orgId: parsed['orgId'] ?? '',
    );

    _isProcessing = true;
    _controller.stop();
    Navigator.of(context).pop(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Stream
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Darkened Overlay with Viewfinder Cutout
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          shape: const CircleBorder(),
                        ),
                      ),
                      const Text(
                        'Scan Bus QR Code',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () async {
                              await _controller.toggleTorch();
                              setState(() {
                                _isTorchOn = !_isTorchOn;
                              });
                            },
                            icon: Icon(
                              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _isTorchOn ? Colors.amber : Colors.white,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              shape: const CircleBorder(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _controller.switchCamera(),
                            icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              shape: const CircleBorder(),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Viewfinder Target Box
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Subtle corner accents
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 3),
                                left: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.white, width: 3),
                                right: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: 10,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white, width: 3),
                                left: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.white, width: 3),
                                right: BorderSide(color: Colors.white, width: 3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Error message or Helper Prompt
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    children: [
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.65),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Text(
                          'Point your camera at the QR code sticker on the bus dashboard.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
