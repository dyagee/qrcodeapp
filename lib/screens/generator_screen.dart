import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _textController = TextEditingController();
  String _qrData = '';
  String _selectedType = 'Text';

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
    {'label': 'WiFi', 'icon': Icons.wifi_rounded, 'hint': 'SSID:Password'},
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
                    color: Colors.white,
                    fontSize: 15,
                  ),
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
                    setState(() => _qrData = _buildQrData(val));
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
                        'Your QR Code',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F5C4)
                                  .withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: 5,
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
                      )
                          .animate()
                          .scale(
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1.0, 1.0),
                            duration: 400.ms,
                            curve: Curves.easeOutBack,
                          )
                          .fadeIn(),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _QrActionBtn(
                            icon: Icons.copy_rounded,
                            label: 'Copy Data',
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _qrData));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied!',
                                      style: GoogleFonts.spaceGrotesk()),
                                  backgroundColor: const Color(0xFF00F5C4)
                                      .withValues(alpha: 0.9),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              );
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
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 60,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
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

class _QrActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QrActionBtn(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF00F5C4)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
