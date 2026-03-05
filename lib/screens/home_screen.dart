import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'scanner_screen.dart';
import 'generator_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // History is the default tab
  int _currentIndex = 2;

  final List<GlobalKey<NavigatorState>> _navKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  // call loadHistory() on the HistoryScreen instance directly
  final _historyKey = GlobalKey<HistoryScreenState>();

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const ScannerScreen();
      case 1:
        return const GeneratorScreen();
      case 2:
        return HistoryScreen(key: _historyKey);
      default:
        return HistoryScreen(key: _historyKey);
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) {
      _navKeys[index].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    // Reload history every time the History tab becomes active
    if (index == 2) {
      _historyKey.currentState?.loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final nav = _navKeys[_currentIndex].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, -0.8),
                  radius: 1.2,
                  colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0F)],
                ),
              ),
            ),
            // Accent glow
            Positioned(
              top: -80,
              right: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF7B61FF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // Tab bodies — Offstage keeps inactive tabs out of render pipeline
            for (int i = 0; i < 3; i++)
              Offstage(
                offstage: _currentIndex != i,
                child: Navigator(
                  key: _navKeys[i],
                  onGenerateRoute: (_) => MaterialPageRoute(
                    builder: (_) => _buildTab(i),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}

// ── Bottom Nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        border: Border(
          top:
              BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, -5)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                  index: 0,
                  icon: Icons.qr_code_scanner_rounded,
                  label: 'Scan',
                  currentIndex: currentIndex,
                  onTap: onTap),
              _NavItem(
                  index: 1,
                  icon: Icons.qr_code_rounded,
                  label: 'Generate',
                  currentIndex: currentIndex,
                  onTap: onTap),
              _NavItem(
                  index: 2,
                  icon: Icons.history_rounded,
                  label: 'History',
                  currentIndex: currentIndex,
                  onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final String label;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.index,
    required this.icon,
    required this.label,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00F5C4).withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey(isSelected),
                color: isSelected
                    ? const Color(0xFF00F5C4)
                    : Colors.white.withValues(alpha: 0.4),
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? const Color(0xFF00F5C4)
                    : Colors.white.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
