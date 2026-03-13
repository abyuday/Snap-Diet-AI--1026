import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/history_provider.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  late AnimationController _pulseController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              AnalysisScreen(imageFile: image),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.6),
            radius: 0.9,
            colors: [
              AppTheme.primaryColor.withOpacity(0.15),
              AppTheme.backgroundColor,
              AppTheme.backgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                _buildTopBar(),
                const SizedBox(height: 32),
                _buildHeroSection(),
                const SizedBox(height: 32),
                _buildChatCard(context),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildSearchButton(context),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Switch to Chat Tab (Index 1 in MainShell)
        // We look for the Scaffold that contains the MainShell's state if possible,
        // or just let the user use the bottom nav.
        // For now, this is a visual enticement.
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Need diet advice?",
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    "Ask me anything about your Indian food goals!",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hello 👋', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
            const Text('AI Dietitian', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ],
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.notifications_none_rounded, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildHeroSection() {
    return Column(
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_pulseAnim, _floatAnim]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: Transform.scale(
                scale: _pulseAnim.value,
                child: child,
              ),
            );
          },
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.3),
                  AppTheme.primaryColor.withOpacity(0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              size: 80,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Snap & Know\nYour Nutrition',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Take a photo of any food and get instant\naccurate nutritional insights powered by AI.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final scanCount = historyProvider.history.length;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('🍎', 'Scans', '$scanCount'),
          _buildDivider(),
          _buildStatItem('🔥', 'Foods', '500+'),
          _buildDivider(),
          _buildStatItem('⚡', 'Accuracy', '97%'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 40, color: Colors.white.withOpacity(0.08));
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _ScanButton(
          label: 'Take a Photo',
          icon: Icons.camera_alt_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF56C27B), Color(0xFF2E7D32)],
          ),
          onTap: () => _pickImage(ImageSource.camera),
        ),
        const SizedBox(height: 14),
        _ScanButton(
          label: 'Choose from Gallery',
          icon: Icons.photo_library_rounded,
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.08),
              Colors.white.withOpacity(0.04),
            ],
          ),
          onTap: () => _pickImage(ImageSource.gallery),
          outlined: true,
        ),
      ],
    );
  }

  Widget _buildSearchButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_rounded,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'OR LOG MANUALLY',
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool outlined;

  const _ScanButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.outlined = false,
  });

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(20),
            border: widget.outlined
                ? Border.all(color: Colors.white.withOpacity(0.15))
                : null,
            boxShadow: widget.outlined ? [] : [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 22, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
