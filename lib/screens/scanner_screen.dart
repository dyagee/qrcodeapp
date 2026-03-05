import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _torchEnabled = false;
  bool _isScanning = true;
  bool _isProcessingImage = false;
  String? _lastScannedValue;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initController();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  /// Pause/resume camera with app lifecycle (background → foreground)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _controller!.stop();
        break;
      case AppLifecycleState.resumed:
        _controller!.start();
        break;
      default:
        break;
    }
  }

  bool _isTabActive = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Detect when this widget is put offstage (tab switch) and stop camera
    final route = ModalRoute.of(context);
    if (route != null) {
      final active = route.isCurrent;
      if (active != _isTabActive) {
        _isTabActive = active;
        if (active) {
          _controller?.start();
        } else {
          _controller?.stop();
        }
      }
    }
  }

  void _initController() {
    _controller?.dispose();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _scanLineController.dispose();
    super.dispose();
  }

  // Camera detect
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
    await _saveAndShow(value);
  }

  // Gallery pick & decode
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isProcessingImage = true);

    try {
      // analyzeImage returns BarcodeCapture? via the controller
      final result = await _controller!.analyzeImage(file.path);

      setState(() => _isProcessingImage = false);

      if (result == null || result.barcodes.isEmpty) {
        _showNoQrFound();
        return;
      }

      final value = result.barcodes.first.rawValue;
      if (value == null || value.isEmpty) {
        _showNoQrFound();
        return;
      }

      HapticFeedback.mediumImpact();
      await _saveAndShow(value, fromGallery: true);
    } catch (e) {
      setState(() => _isProcessingImage = false);
      _showNoQrFound();
    }
  }

  Future<void> _saveAndShow(String value, {bool fromGallery = false}) async {
    await HistoryService.addScan(ScanResultModel(
      value: value,
      type: _detectType(value),
      timestamp: DateTime.now(),
      source: 'scanned',
    ));
    if (mounted) {
      _showResultSheet(value, fromGallery: fromGallery);
    }
  }

  void _showNoQrFound() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(28),
          border:
              Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.image_search_rounded,
                  color: Color(0xFFFF6B6B), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'No QR Code Found',
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The selected image doesn\'t appear to contain a readable QR code. Try a clearer or higher-resolution image.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickFromGallery();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5C4),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.photo_library_rounded,
                              color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          Text('Try Another',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text('Dismiss',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          )),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      )
          .animate()
          .slideY(
              begin: 1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
          .fadeIn(),
    );
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

  void _showResultSheet(String value, {bool fromGallery = false}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ResultSheet(
        value: value,
        type: _detectType(value),
        isUrl: _isUrl(value),
        fromGallery: fromGallery,
        onClose: () {
          Navigator.pop(ctx);
          setState(() {
            _isScanning = true;
            _lastScannedValue = null;
          });
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
                return CustomPaint(painter: _ScanLinePainter(lineY));
              },
            ),
          ),

          // Bottom area: hint + gallery button
          Positioned(
            bottom: 100,
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
                const SizedBox(height: 6),
                Text(
                  'or pick an image from your gallery',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 22),

                // Gallery button
                GestureDetector(
                  onTap: _isProcessingImage ? null : _pickFromGallery,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isProcessingImage
                          ? Colors.white.withValues(alpha: 0.05)
                          : const Color(0xFF00F5C4).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isProcessingImage
                            ? Colors.white.withValues(alpha: 0.1)
                            : const Color(0xFF00F5C4).withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: _isProcessingImage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: const Color(0xFF00F5C4)
                                      .withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Scanning image…',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.photo_library_rounded,
                                  color: Color(0xFF00F5C4), size: 20),
                              const SizedBox(width: 10),
                              Text(
                                'Scan from Gallery',
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF00F5C4),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
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

// Overlay Painter

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.width * 0.7;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2 - 30;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()
          ..addRRect(
              RRect.fromRectAndRadius(scanRect, const Radius.circular(20))),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );

    const cornerLength = 28.0;
    const cornerThickness = 3.5;
    const cornerRadius = 4.0;
    final paint = Paint()
      ..color = const Color(0xFF00F5C4)
      ..strokeWidth = cornerThickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final corners = [
      [
        Offset(left + cornerRadius, top),
        Offset(left + cornerLength, top),
        Offset(left, top + cornerRadius),
        Offset(left, top + cornerLength)
      ],
      [
        Offset(left + scanSize - cornerLength, top),
        Offset(left + scanSize - cornerRadius, top),
        Offset(left + scanSize, top + cornerRadius),
        Offset(left + scanSize, top + cornerLength)
      ],
      [
        Offset(left, top + scanSize - cornerLength),
        Offset(left, top + scanSize - cornerRadius),
        Offset(left + cornerRadius, top + scanSize),
        Offset(left + cornerLength, top + scanSize)
      ],
      [
        Offset(left + scanSize, top + scanSize - cornerLength),
        Offset(left + scanSize, top + scanSize - cornerRadius),
        Offset(left + scanSize - cornerRadius, top + scanSize),
        Offset(left + scanSize - cornerLength, top + scanSize)
      ],
    ];
    for (final c in corners) {
      canvas.drawLine(c[0], c[1], paint);
      canvas.drawLine(c[2], c[3], paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Scan Line Painter

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
  bool shouldRepaint(_ScanLinePainter old) => old.lineY != lineY;
}

// Result Sheet

class _ResultSheet extends StatelessWidget {
  final String value;
  final String type;
  final bool isUrl;
  final bool fromGallery;
  final VoidCallback onClose;

  const _ResultSheet({
    required this.value,
    required this.type,
    required this.isUrl,
    required this.onClose,
    this.fromGallery = false,
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
        border:
            Border.all(color: const Color(0xFF00F5C4).withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F5C4).withValues(alpha: 0.08),
            blurRadius: 40,
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

            // Type badge row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5C4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF00F5C4).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_typeIcon(),
                          size: 14, color: const Color(0xFF00F5C4)),
                      const SizedBox(width: 6),
                      Text(type,
                          style: GoogleFonts.spaceGrotesk(
                            color: const Color(0xFF00F5C4),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Source badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: fromGallery
                        ? const Color(0xFF7B61FF).withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: fromGallery
                          ? const Color(0xFF7B61FF).withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fromGallery
                            ? Icons.photo_library_rounded
                            : Icons.qr_code_scanner_rounded,
                        size: 12,
                        color: fromGallery
                            ? const Color(0xFF7B61FF)
                            : Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        fromGallery ? 'From Gallery' : 'Camera',
                        style: GoogleFonts.spaceGrotesk(
                          color: fromGallery
                              ? const Color(0xFF7B61FF)
                              : Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text('Scanned!',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 12,
                    )),
              ],
            ),

            const SizedBox(height: 16),

            // Value box
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

            // Actions
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context)
                          .showSnackBar(_snackBar('Copied!'));
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

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onClose,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('Scan Again',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontWeight: FontWeight.w600,
                    )),
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

  SnackBar _snackBar(String msg) => SnackBar(
        content: Text(msg,
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
            Icon(icon,
                color: isPrimary ? Colors.black : Colors.white, size: 20),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.spaceGrotesk(
                  color: isPrimary ? Colors.black : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
