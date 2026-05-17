import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/theme_provider.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'multi_capture_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomeScreen(),
    DashboardScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  void onTap(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg     = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final navBg  = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final navBorder = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final accent = isDark ? AppTheme.primaryColor  : AppTheme.primaryDark;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      extendBody: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
        ),
      ),

      // ── Floating Camera Button ────────────────────────────────────────
      floatingActionButton: _CameraFab(accent: accent),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom Nav ────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBg,
          border: Border(top: BorderSide(color: navBorder, width: 0.8)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    _NavItem(icon: Icons.home_rounded,      label: 'Home',      index: 0, selected: _selectedIndex, accent: accent, muted: textMuted, onTap: onTap),
                    _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard', index: 1, selected: _selectedIndex, accent: accent, muted: textMuted, onTap: onTap),
                    const Expanded(child: SizedBox()), // gap for FAB
                    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat', index: 2, selected: _selectedIndex, accent: accent, muted: textMuted, onTap: onTap),
                    _NavItem(icon: Icons.person_outline_rounded, label: 'Profile', index: 3, selected: _selectedIndex, accent: accent, muted: textMuted, onTap: onTap),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Camera FAB ─────────────────────────────────────────────────────────────
class _CameraFab extends StatelessWidget {
  final Color accent;
  const _CameraFab({required this.accent});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context, MaterialPageRoute(builder: (_) => const MultiCaptureScreen()),
      ),
      child: Container(
        width: 62, height: 62,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.45),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ── Nav Item ────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, selected;
  final Color accent, muted;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon, required this.label, required this.index,
    required this.selected, required this.accent, required this.muted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selected;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? accent : muted, size: 24),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: isSelected ? accent : muted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? 18 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
