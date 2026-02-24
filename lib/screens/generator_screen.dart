import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'dart:io';
import '../services/history_service.dart';
import '../models/scan_result_model.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _textController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = '';
  String _selectedType = 'Text';
  bool _savedToHistory = false;

  final List<Map<String, dynamic>> _types = [
    {
      'label': 'Text',
      'icon': Icons.text_fields_rounded,
      'hint': 'Enter any text...'
    },
    {'label': 'URL', 'icon': Icons.link_rounded, 'hint': 'https://example.com'},
    {
      'label': 'Email',
      'icon': Icons.email_rounded,
      'hint': 'email@example.com'
    },
    {'label': 'Phone', 'icon': Icons.phone_rounded, 'hint': '+1 234 567 8900'},
    {
      'label': 'WiFi',
      'icon': Icons.wifi_rounded,
      'hint': 'NetworkName:Password'
    },
  ];

  String _buildQrData(String input) {
    switch (_selectedType) {
      case 'Email':
        return 'mailto:$input';
      case 'Phone':
        return 'tel:$input';
      case 'WiFi':
        final parts = input.split(':');
        if (parts.length >= 2) {
          return 'WIFI:T:WPA;S:${parts[0]};P:${parts.sublist(1).join(':')};H:false;;';
        }
        return input;
      default:
        return input;
    }
  }

  /// Capture the QR widget as PNG bytes
  Future<Uint8List?> _captureQr() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  Future<void> _saveToGallery() async {
    final bytes = await _captureQr();
    if (bytes == null) {
      _showSnack('Failed to capture QR code', isError: true);
      return;
    }
    try {
      // Write to a temp file then hand it to gal
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Gal.putImage(file.path, album: 'QR App');
      _showSnack('QR code saved to gallery!');
    } catch (e) {
      _showSnack('Could not save to gallery', isError: true);
    }
  }

  Future<void> _shareQr() async {
    final bytes = await _captureQr();
    if (bytes == null) {
      _showSnack('Failed to capture QR code', isError: true);
      return;
    }
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/qr_studio.png');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: 'QR Code generated with QR Studio',
    );
  }

  Future<void> _saveToHistory() async {
    if (_qrData.isEmpty || _savedToHistory) return;
    await HistoryService.addScan(ScanResultModel(
      value: _textController.text.trim(),
      type: _selectedType,
      timestamp: DateTime.now(),
      source: 'generated',
    ));
    setState(() => _savedToHistory = true);
    _showSnack('Saved to history');
  }

  void _showSaveShareSheet() {
    // Auto-save to history when user opens the sheet
    _saveToHistory();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SaveShareSheet(
        onSave: () async {
          Navigator.pop(ctx);
          await _saveToGallery();
        },
        onShare: () async {
          Navigator.pop(ctx);
          await _shareQr();
        },
        onCopy: () {
          Navigator.pop(ctx);
          Clipboard.setData(ClipboardData(text: _textController.text.trim()));
          _showSnack('Copied to clipboard');
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg,
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w500)),
        backgroundColor: isError
            ? const Color(0xFFFF6B6B).withValues(alpha: 0.9)
            : const Color(0xFF00F5C4).withValues(alpha: 0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Generate',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ).animate().fadeIn().slideY(begin: -0.2),
              Text(
                'Create your custom QR code',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 28),

              // Type selector
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final type = _types[i];
                    final isSelected = _selectedType == type['label'];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedType = type['label'];
                          _textController.clear();
                          _qrData = '';
                          _savedToHistory = false;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF00F5C4)
                              : const Color(0xFF13131A),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              type['icon'] as IconData,
                              size: 16,
                              color: isSelected
                                  ? Colors.black
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              type['label'] as String,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.black
                                    : Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // Input field
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _textController,
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.white, fontSize: 15),
                  maxLines: 3,
                  minLines: 3,
                  decoration: InputDecoration(
                    hintText: _types.firstWhere(
                        (t) => t['label'] == _selectedType)['hint'] as String,
                    hintStyle: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.25),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _qrData =
                          val.trim().isEmpty ? '' : _buildQrData(val.trim());
                      _savedToHistory = false;
                    });
                  },
                ),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              // QR Preview
              if (_qrData.isNotEmpty) ...[
                Center(
                  child: Column(
                    children: [
                      Text(
                        'YOUR QR CODE',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.35),
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Repaint boundary wraps only the QR widget for capture
                      RepaintBoundary(
                        key: _qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F5C4)
                                    .withValues(alpha: 0.25),
                                blurRadius: 48,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF0A0A0F),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF0A0A0F),
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(),

                      const SizedBox(height: 28),

                      // ── Save / Share / Copy row ──
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _GenActionBtn(
                            icon: Icons.download_rounded,
                            label: 'Save Image',
                            isPrimary: true,
                            onTap: _showSaveShareSheet,
                          ),
                          const SizedBox(width: 10),
                          _GenActionBtn(
                            icon: Icons.share_rounded,
                            label: 'Share',
                            onTap: _shareQr,
                          ),
                          const SizedBox(width: 10),
                          _GenActionBtn(
                            icon: Icons.copy_rounded,
                            label: 'Copy',
                            onTap: () {
                              Clipboard.setData(ClipboardData(
                                  text: _textController.text.trim()));
                              _showSnack('Copied to clipboard');
                            },
                          ),
                        ],
                      ).animate().fadeIn(delay: 200.ms),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            size: 60,
                            color: Colors.white.withValues(alpha: 0.1)),
                        const SizedBox(height: 12),
                        Text(
                          'Preview appears here',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Save / Share Bottom Sheet ─────────────────────────────────────────────────

class _SaveShareSheet extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onCopy;

  const _SaveShareSheet({
    required this.onSave,
    required this.onShare,
    required this.onCopy,
  });

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
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 22),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F5C4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_rounded,
                      color: Color(0xFF00F5C4), size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QR Code Ready!',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'What would you like to do?',
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Action buttons stacked
            _SheetOption(
              icon: Icons.save_alt_rounded,
              iconColor: const Color(0xFF00F5C4),
              bgColor: const Color(0xFF00F5C4).withValues(alpha: 0.12),
              title: 'Save to Gallery',
              subtitle: 'Save QR image to your photo library',
              onTap: onSave,
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.share_rounded,
              iconColor: const Color(0xFF7B61FF),
              bgColor: const Color(0xFF7B61FF).withValues(alpha: 0.12),
              title: 'Share Image',
              subtitle: 'Send via messages, email, or other apps',
              onTap: onShare,
            ),
            const SizedBox(height: 10),
            _SheetOption(
              icon: Icons.copy_rounded,
              iconColor: const Color(0xFFFFB547),
              bgColor: const Color(0xFFFFB547).withValues(alpha: 0.12),
              title: 'Copy Text',
              subtitle: 'Copy the QR content to clipboard',
              onTap: onCopy,
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(begin: 1, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn();
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Compact action button below QR ───────────────────────────────────────────

class _GenActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _GenActionBtn({
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? const Color(0xFF00F5C4) : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? Colors.transparent
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: isPrimary ? Colors.black : const Color(0xFF00F5C4)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: isPrimary ? Colors.black : Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
