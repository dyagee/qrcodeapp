import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../services/history_service.dart';
import '../models/scan_result_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanResultModel> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await HistoryService.getHistory();
    if (mounted) {
      setState(() {
        _history = history.reversed.toList();
        _loading = false;
      });
    }
  }

  Future<void> _clearHistory() async {
    await HistoryService.clearHistory();
    setState(() => _history = []);
  }

  IconData _typeIcon(String type) {
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

  Color _typeColor(String type) {
    switch (type) {
      case 'URL':
        return const Color(0xFF7B61FF);
      case 'Phone':
        return const Color(0xFF00D4AA);
      case 'Email':
        return const Color(0xFFFF6B6B);
      case 'WiFi':
        return const Color(0xFFFFB547);
      default:
        return const Color(0xFF00F5C4);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'History',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        '${_history.length} scan${_history.length == 1 ? '' : 's'}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF13131A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                              'Clear History',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            content: Text(
                              'Are you sure you want to delete all scan history?',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Cancel',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: Colors.white
                                            .withValues(alpha: 0.5))),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _clearHistory();
                                },
                                child: Text('Clear',
                                    style: GoogleFonts.spaceGrotesk(
                                        color: const Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ).animate().fadeIn().slideY(begin: -0.2),
            ),

            const SizedBox(height: 20),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF00F5C4)))
                  : _history.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: const Color(0xFF00F5C4),
                          onRefresh: _loadHistory,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: _history.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = _history[i];
                              return _HistoryCard(
                                item: item,
                                typeIcon: _typeIcon(item.type),
                                typeColor: _typeColor(item.type),
                                index: i,
                                onDelete: () {
                                  setState(() => _history.removeAt(i));
                                  HistoryService.removeAt(_history.length - i);
                                },
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: Color(0xFF13131A),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No scans yet',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan a QR code to see it here',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final ScanResultModel item;
  final IconData typeIcon;
  final Color typeColor;
  final int index;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.item,
    required this.typeIcon,
    required this.typeColor,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp);

    return Dismissible(
      key: Key(item.timestamp.toIso8601String()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatted,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                _IconBtn(
                  icon: Icons.copy_rounded,
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: item.value));
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('Copied!', style: GoogleFonts.spaceGrotesk()),
                        backgroundColor:
                            const Color(0xFF00F5C4).withValues(alpha: 0.9),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),
                _IconBtn(
                  icon: Icons.share_rounded,
                  onTap: () => Share.share(item.value),
                ),
              ],
            ),
          ],
        ),
      )
          .animate(delay: Duration(milliseconds: 50 * index))
          .fadeIn()
          .slideX(begin: 0.1),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.5)),
      ),
    );
  }
}
