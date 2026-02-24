import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/history_service.dart';
import '../models/scan_result_model.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  MobileScannerController? _controller;
  bool _torchEnabled = false;
  bool _isScanning = true;
  String? _lastScannedValue;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (!_isScanning) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    final value = barcode!.rawValue!;
    if (value == _lastScannedValue) return;

    setState(() {
      _isScanning = false;
      _lastScannedValue = value;
    });

    HapticFeedback.mediumImpact();
    await HistoryService.addScan(ScanResultModel(
      value: value,
      type: _detectType(value),
      timestamp: DateTime.now(),
    ));

    if (mounted) {
      _showResultSheet(value);
    }
  }

  String _detectType(String value) {
    if (value.startsWith('http') || value.startsWith('www')) return 'URL';
    if (value.startsWith('tel:')) return 'Phone';
    if (value.startsWith('mailto:')) return 'Email';
    if (value.startsWith('WIFI:')) return 'WiFi';
    return 'Text';
  }

  bool _isUrl(String value) =>
      value.startsWith('http') || value.startsWith('www.');

  void _showResultSheet(String value) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ResultSheet(
        value: value,
        type: _detectType(value),
        isUrl: _isUrl(value),
        onClose: () {
          Navigator.pop(ctx);
          setState(() => _isScanning = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera feed
          MobileScanner(
            controller: _controller!,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout
          CustomPaint(
            painter: _ScanOverlayPainter(),
            child: const SizedBox.expand(),
          ),

          // Header
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text(
                    'QR Studio',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Spacer(),
                  // Torch toggle
                  GestureDetector(
                    onTap: () {
                      setState(() => _torchEnabled = !_torchEnabled);
                      _controller?.toggleTorch();
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _torchEnabled
                            ? const Color(0xFF00F5C4).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _torchEnabled
                              ? const Color(0xFF00F5C4).withValues(alpha: 0.5)
                              : Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _torchEnabled
                            ? Icons.flashlight_on_rounded
                            : Icons.flashlight_off_rounded,
                        color: _torchEnabled
                            ? const Color(0xFF00F5C4)
                            : Colors.white,
                        size: 22,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.3),
                ],
              ).animate().fadeIn(duration: 600.ms),
            ),
          ),

          // Scan line animation
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanLineController,
              builder: (_, __) {
                final scanAreaSize = MediaQuery.of(context).size.width * 0.7;
                final centerY = MediaQuery.of(context).size.height / 2;
                final top = centerY - scanAreaSize / 2;
                final lineY = top + scanAreaSize * _scanLineController.value;

                return CustomPaint(
                  painter: _ScanLinePainter(lineY),
                );
              },
            ),
          ),

          // Instruction text
          Positioned(
            bottom: 160,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Text(
                  'Point camera at a QR code',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Results will appear automatically',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 500.ms, duration: 600.ms),
          ),
        ],
      ),
    );
  }
}

// ── Overlay Painter ──────────────────────────────────────────────────────────

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.width * 0.7;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2 - 30;

    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.65);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(scanRect, const Radius.circular(20))),
      ),
      overlay,
    );

    // Corner brackets
    const cornerLength = 28.0;
    const cornerThickness = 3.5;
    const cornerRadius = 4.0;
    final paint = Paint()
      ..color = const Color(0xFF00F5C4)
      ..strokeWidth = cornerThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      // Top-left
      [
        Offset(left + cornerRadius, top),
        Offset(left + cornerLength, top),
        Offset(left, top + cornerRadius),
        Offset(left, top + cornerLength),
      ],
      // Top-right
      [
        Offset(left + scanSize - cornerLength, top),
        Offset(left + scanSize - cornerRadius, top),
        Offset(left + scanSize, top + cornerRadius),
        Offset(left + scanSize, top + cornerLength),
      ],
      // Bottom-left
      [
        Offset(left, top + scanSize - cornerLength),
        Offset(left, top + scanSize - cornerRadius),
        Offset(left + cornerRadius, top + scanSize),
        Offset(left + cornerLength, top + scanSize),
      ],
      // Bottom-right
      [
        Offset(left + scanSize, top + scanSize - cornerLength),
        Offset(left + scanSize, top + scanSize - cornerRadius),
        Offset(left + scanSize - cornerRadius, top + scanSize),
        Offset(left + scanSize - cornerLength, top + scanSize),
      ],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], paint);
      canvas.drawLine(corner[2], corner[3], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Scan Line Painter ────────────────────────────────────────────────────────

class _ScanLinePainter extends CustomPainter {
  final double lineY;
  _ScanLinePainter(this.lineY);

  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.width * 0.7;
    final left = (size.width - scanSize) / 2;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF00F5C4).withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(left, lineY, scanSize, 2))
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, lineY), Offset(left + scanSize, lineY), paint);
  }

  @override
  bool shouldRepaint(_ScanLinePainter oldDelegate) =>
      oldDelegate.lineY != lineY;
}

// ── Result Bottom Sheet ──────────────────────────────────────────────────────

class _ResultSheet extends StatelessWidget {
  final String value;
  final String type;
  final bool isUrl;
  final VoidCallback onClose;

  const _ResultSheet({
    required this.value,
    required this.type,
    required this.isUrl,
    required this.onClose,
  });

  IconData _typeIcon() {
    switch (type) {
      case 'URL':
        return Icons.link_rounded;
      case 'Phone':
        return Icons.phone_rounded;
      case 'Email':
        return Icons.email_rounded;
      case 'WiFi':
        return Icons.wifi_rounded;
      default:
        return Icons.text_fields_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF00F5C4).withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F5C4).withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Type badge + icon
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5C4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00F5C4).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(),
                          size: 14, color: const Color(0xFF00F5C4)),
                      const SizedBox(width: 6),
                      Text(
                        type,
                        style: GoogleFonts.spaceGrotesk(
                          color: const Color(0xFF00F5C4),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'Scanned!',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Value
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                value,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        _snackBar('Copied to clipboard!'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_rounded,
                    label: 'Share',
                    onTap: () => Share.share(value),
                  ),
                ),
                if (isUrl) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.open_in_browser_rounded,
                      label: 'Open',
                      isPrimary: true,
                      onTap: () async {
                        final uri = Uri.parse(value.startsWith('http')
                            ? value
                            : 'https://$value');
                        if (await canLaunchUrl(uri)) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Scan again
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Scan Again',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }

  SnackBar _snackBar(String message) => SnackBar(
        content: Text(message,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500)),
        backgroundColor: const Color(0xFF00F5C4).withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      );
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isPrimary
              ? const Color(0xFF00F5C4)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.black : Colors.white,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: isPrimary ? Colors.black : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
