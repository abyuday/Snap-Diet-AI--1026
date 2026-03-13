import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  final List<Widget> _pages = const [
    HomeScreen(),
    ChatScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_selectedIndex), child: _pages[_selectedIndex]),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 16, left: 24, right: 24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_rounded, label: 'Home', index: 0, selectedIndex: _selectedIndex, onTap: _onTap),
          _NavItem(icon: Icons.chat_bubble_rounded, label: 'AI Chat', index: 1, selectedIndex: _selectedIndex, onTap: _onTap),
          _NavItem(icon: Icons.history_rounded, label: 'History', index: 2, selectedIndex: _selectedIndex, onTap: _onTap),
          _NavItem(icon: Icons.person_rounded, label: 'Profile', index: 3, selectedIndex: _selectedIndex, onTap: _onTap),
        ],
      ),
    );
  }

  void _onTap(int index) => setState(() => _selectedIndex = index);
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primaryColor : Colors.white38, size: 22),
            if (selected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
