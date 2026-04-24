import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';
import 'scanner_screen.dart';
import 'dashboard_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    HomeScreen(),
    DashboardScreen(),
    ChatScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // Allows FAB to sit over the body nicely
      body: _pages[_selectedIndex],
      floatingActionButton: _buildScanFab(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildScanFab(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 30), // Offset slightly to sit in Notch
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ScannerScreen()),
        ),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white10, width: 2),
          ),
          child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: AppTheme.surfaceColor,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              index: 0,
              selectedIndex: _selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.dashboard_rounded,
              label: 'Daily',
              index: 1,
              selectedIndex: _selectedIndex,
              onTap: onTap,
            ),
            const SizedBox(width: 50), // Gap for FAB
            _NavItem(
              icon: Icons.chat_bubble_rounded,
              label: 'AI Chat',
              index: 2,
              selectedIndex: _selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.history_rounded,
              label: 'History',
              index: 3,
              selectedIndex: _selectedIndex,
              onTap: onTap,
            ),
            _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              index: 4,
              selectedIndex: _selectedIndex,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }

  void onTap(int index) => setState(() => _selectedIndex = index);
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index, selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool selected = index == selectedIndex;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? AppTheme.primaryColor : Colors.white24,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: selected ? AppTheme.primaryColor : Colors.white24,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
