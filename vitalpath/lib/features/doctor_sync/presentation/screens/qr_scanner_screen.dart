import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pinput/pinput.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/haptic_service.dart';

/// QR code scanner + 6-digit sync code entry for doctor-patient pairing (SRS §3.2).
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  MobileScannerController? _scannerController;
  bool _useManualCode = false;
  bool _isProcessing = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleQrCode(String code) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    await ref.read(hapticServiceProvider).success();

    // Parse QR payload — expected format: "vitalpath://sync/{doctorId}/{code}"
    if (code.startsWith('vitalpath://sync/')) {
      final parts = code.split('/');
      if (parts.length >= 4) {
        final doctorId = parts[3];
        final syncCode = parts.length > 4 ? parts[4] : '';
        await _initiateSync(doctorId: doctorId, syncCode: syncCode);
      }
    } else {
      // Treat as plain 6-digit code
      await _initiateSync(syncCode: code);
    }

    setState(() => _isProcessing = false);
  }

  Future<void> _initiateSync({String? doctorId, required String syncCode}) async {
    // TODO: Call Supabase to complete doctor-patient pairing
    // 1. Validate sync code against server
    // 2. Create DoctorConnection record
    // 3. Subscribe to doctor's prescriptions via Realtime

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully connected with your doctor!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Sync with Doctor'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _useManualCode = !_useManualCode),
            icon: Icon(_useManualCode
                ? Icons.qr_code_scanner_rounded
                : Icons.keyboard_rounded),
            color: Colors.white,
          ),
        ],
      ),
      body: _useManualCode ? _ManualCodeEntry(
        controller: _codeController,
        onSubmit: (code) => _handleQrCode(code),
      ) : Stack(
        children: [
          MobileScanner(
            controller: _scannerController!,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQrCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),

          // Scanning frame overlay
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primaryLight, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  'Point at your doctor\'s QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() => _useManualCode = true),
                  child: const Text(
                    'Enter 6-digit code instead',
                    style: TextStyle(color: AppColors.primaryLight),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primaryLight),
            ),
        ],
      ),
    );
  }
}

class _ManualCodeEntry extends StatelessWidget {
  final TextEditingController controller;
  final void Function(String) onSubmit;

  const _ManualCodeEntry({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_rounded, size: 56, color: AppColors.primary),
            const SizedBox(height: 24),
            const Text(
              'Enter Sync Code',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the 6-digit code your doctor provided',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            Pinput(
              controller: controller,
              length: 6,
              autofocus: true,
              onCompleted: onSubmit,
              defaultPinTheme: PinTheme(
                width: 50,
                height: 54,
                textStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
