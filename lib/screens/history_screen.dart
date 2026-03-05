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
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  List<ScanResultModel> _history = [];
  bool _loading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> loadHistory() async {
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
    if (mounted) setState(() => _history = []);
  }

  List<ScanResultModel> get _filtered {
    switch (_tabController.index) {
      case 1:
        return _history.where((h) => h.source == 'scanned').toList();
      case 2:
        return _history.where((h) => h.source == 'generated').toList();
      default:
        return _history;
    }
  }

  IconData _typeIcon(ScanResultModel item) {
    switch (item.type) {
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

  Color _typeColor(ScanResultModel item) {
    switch (item.type) {
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
    final filtered = _filtered;

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('History',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          )),
                      Text(
                        '${_filtered.length} item${_filtered.length == 1 ? '' : 's'}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (_history.isNotEmpty)
                    GestureDetector(
                      onTap: _confirmClear,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: Colors.white.withValues(alpha: 0.45),
                            size: 20),
                      ),
                    ),
                ],
              ).animate().fadeIn().slideY(begin: -0.2),
            ),

            const SizedBox(height: 18),

            // Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF13131A),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Expanded(
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicator: BoxDecoration(
                      color: const Color(0xFF00F5C4).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color:
                              const Color(0xFF00F5C4).withValues(alpha: 0.4)),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w500),
                    labelColor: const Color(0xFF00F5C4),
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.4),
                    tabs: [
                      _buildTab('All', _history.length),
                      _buildTab('Scanned',
                          _history.where((h) => h.source == 'scanned').length,
                          icon: Icons.qr_code_scanner_rounded),
                      _buildTab('Generated',
                          _history.where((h) => h.source == 'generated').length,
                          icon: Icons.qr_code_rounded),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: 16),

            // List
            Expanded(
              child: _loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF00F5C4)))
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: const Color(0xFF00F5C4),
                          onRefresh: loadHistory,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final item = filtered[i];
                              return _HistoryCard(
                                item: item,
                                typeIcon: _typeIcon(item),
                                typeColor: _typeColor(item),
                                index: i,
                                onDelete: () async {
                                  final idx = _history.indexOf(item);
                                  if (idx != -1) {
                                    await HistoryService.removeByIndex(
                                        _history.length - 1 - idx);
                                    setState(() => _history.removeAt(idx));
                                  }
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

  Tab _buildTab(String label, int count, {IconData? icon}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
          Text(label),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('$count',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13131A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear History',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('Delete all scan and generated history?',
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white.withValues(alpha: 0.6))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.spaceGrotesk(
                    color: Colors.white.withValues(alpha: 0.5))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearHistory();
            },
            child: Text('Clear All',
                style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFFFF6B6B),
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final isFiltered = _tabController.index != 0;
    final label = _tabController.index == 1 ? 'scanned' : 'generated';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
                color: Color(0xFF13131A), shape: BoxShape.circle),
            child: Icon(
              isFiltered
                  ? (_tabController.index == 1
                      ? Icons.qr_code_scanner_rounded
                      : Icons.qr_code_rounded)
                  : Icons.history_rounded,
              size: 44,
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'No $label codes yet' : 'Nothing here yet',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Items will appear here once you $label a code'
                : 'Tap Scan or Generate below to get started',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ],
      ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.92, 0.92)),
    );
  }
}

// History Card

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
    // final isGenerated = item.source == 'generated';

    return Dismissible(
      key: Key('${item.timestamp.toIso8601String()}_${item.value}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Color(0xFFFF6B6B)),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(typeIcon, color: typeColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.value,
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Row(children: [
                  /// Uncomment if want to show label for scanned or generated
                  // Container(
                  //   padding:
                  //       const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  //   decoration: BoxDecoration(
                  //     color: isGenerated
                  //         ? const Color(0xFF7B61FF).withValues(alpha: 0.15)
                  //         : const Color(0xFF00F5C4).withValues(alpha: 0.12),
                  //     borderRadius: BorderRadius.circular(6),
                  //   ),
                  //   child: Row(mainAxisSize: MainAxisSize.min, children: [
                  //     Icon(
                  //       isGenerated
                  //           ? Icons.qr_code_rounded
                  //           : Icons.qr_code_scanner_rounded,
                  //       size: 9,
                  //       color: isGenerated
                  //           ? const Color(0xFF7B61FF)
                  //           : const Color(0xFF00F5C4),
                  //     ),
                  //     const SizedBox(width: 3),
                  //     Text(
                  //       isGenerated ? 'Generated' : 'Scanned',
                  //       style: GoogleFonts.spaceGrotesk(
                  //         fontSize: 9,
                  //         fontWeight: FontWeight.w700,
                  //         color: isGenerated
                  //             ? const Color(0xFF7B61FF)
                  //             : const Color(0xFF00F5C4),
                  //       ),
                  //     ),
                  //   ]),
                  // ),
                  const SizedBox(width: 6),
                  Text(formatted,
                      style: GoogleFonts.spaceGrotesk(
                        color: Colors.white.withValues(alpha: 0.28),
                        fontSize: 10,
                      )),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(children: [
            _IconBtn(
              icon: Icons.copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: item.value));
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Copied!', style: GoogleFonts.spaceGrotesk()),
                  backgroundColor:
                      const Color(0xFF00F5C4).withValues(alpha: 0.9),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
            const SizedBox(width: 6),
            _IconBtn(
              icon: Icons.share_rounded,
              onTap: () => Share.share(item.value),
            ),
          ]),
        ]),
      )
          .animate(delay: Duration(milliseconds: 40 * index))
          .fadeIn()
          .slideX(begin: 0.06),
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
        child:
            Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.45)),
      ),
    );
  }
}
