import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/history_provider.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';
import '../theme/app_theme.dart';
import 'multi_capture_screen.dart';
import 'search_screen.dart';
import 'chat_screen.dart';
import 'voice_log_screen.dart';
import 'history_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final user    = context.watch<UserProvider>();
    final history = context.watch<HistoryProvider>();
    final accent  = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    final bg      = isDark ? AppTheme.darkBg      : AppTheme.lightBg;
    final surf    = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final surf2   = isDark ? AppTheme.darkSurface2 : AppTheme.lightSurface2;
    final border  = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;

    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final greetEmoji = hour < 12 ? '🌅' : hour < 17 ? '☀️' : '🌙';

    // Stats
    final totalScans = history.history.length;
    final calToday   = history.totalToday;
    final calGoal    = user.calorieGoal.toDouble();
    
    final shadowColor = isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // ── Top bar ──────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$greeting $greetEmoji',
                          style: GoogleFonts.outfit(
                            fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Let's track your nutrition today",
                          style: GoogleFonts.outfit(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  // Avatar / Profile Initial
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // ── AI Dietitian hero card ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: accent.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.sentiment_satisfied_alt_rounded, color: accent, size: 36),
                    ),
                    const SizedBox(height: 14),
                    Text('Snap DietAI', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                    const SizedBox(height: 2),
                    Text('Powered by Vision AI', style: GoogleFonts.outfit(fontSize: 13, color: textMuted)),
                    const SizedBox(height: 20),
                    // Stats row
                    Row(
                      children: [
                        Expanded(child: _statChip('TOTAL SCANS', '$totalScans', '+${history.history.where((e) {
                          final now = DateTime.now();
                          return e.dateTime.year == now.year && e.dateTime.month == now.month && e.dateTime.day == now.day;
                        }).length} today', accent, surf2, border, textPrimary, textMuted, shadowColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _statChip('CALORIES TODAY', '${calToday.toInt()}', 'of ${calGoal.toInt()} kcal', accent, surf2, border, textPrimary, textMuted, shadowColor)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Quick Actions ─────────────────────────────────────────
              Text('QUICK ACTIONS', style: GoogleFonts.outfit(fontSize: 11, letterSpacing: 1.2, color: textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _QuickActionTile(
                icon: Icons.camera_alt_outlined, iconColor: accent,
                title: 'Scan Food', subtitle: 'Multi-capture with AI analysis',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiCaptureScreen())),
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.qr_code_scanner_rounded, iconColor: const Color(0xFF10B981),
                title: 'Barcode Scanner', subtitle: 'Scan packaged food barcodes',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen())),
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.mic_rounded, iconColor: const Color(0xFFFF9800),
                title: 'Voice Log', subtitle: 'Speak your meal to AI',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VoiceLogScreen())),
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.grid_view_rounded, iconColor: const Color(0xFF8B5CF6),
                title: 'Manual Log', subtitle: 'Search and add food',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
              const SizedBox(height: 10),
              _QuickActionTile(
                icon: Icons.history_rounded, iconColor: const Color(0xFF4FA3E0),
                title: 'View History', subtitle: 'See all past logged meals',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
              const SizedBox(height: 20),

              // ── AI Tip card ───────────────────────────────────────────
              _AiTipCard(
                calToday: calToday, calGoal: calGoal,
                protToday: history.totalProteinToday,
                protGoal: user.proteinGoal.toDouble(),
                accent: accent, surf: surf, border: border,
                textPrimary: textPrimary, textMuted: textMuted, shadowColor: shadowColor,
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, String sub, Color accent,
      Color surf2, Color border, Color textPrimary, Color textMuted, Color shadowColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: surf2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 9, letterSpacing: 0.8, color: accent, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
            ),
            child: Text(value, key: ValueKey(value), style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: accent)),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(sub, style: GoogleFonts.outfit(fontSize: 10, color: accent)),
          ),
        ],
      ),
    );
  }
}

// ── Quick Action Tile ────────────────────────────────────────────────────────
class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;
  final Color surf, border, textPrimary, textMuted, shadowColor;

  const _QuickActionTile({
    required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.onTap, required this.surf, required this.border,
    required this.textPrimary, required this.textMuted, required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textPrimary)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 12, color: textMuted)),
                ],
              ),
            ),
              Icon(Icons.chevron_right_rounded, color: textMuted, size: 20),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

// ── AI Tip Card ──────────────────────────────────────────────────────────────
class _AiTipCard extends StatelessWidget {
  final double calToday, calGoal, protToday, protGoal;
  final Color accent, surf, border, textPrimary, textMuted, shadowColor;

  const _AiTipCard({
    required this.calToday, required this.calGoal,
    required this.protToday, required this.protGoal,
    required this.accent, required this.surf, required this.border,
    required this.textPrimary, required this.textMuted, required this.shadowColor,
  });

  String _buildTip() {
    if (calToday == 0) return 'Start logging your meals to get personalised tips!';
    final calPct = calToday / calGoal;
    final protPct = protToday / (protGoal == 0 ? 120 : protGoal);
    if (protPct < 0.5) return 'Your protein intake is ${((1 - protPct) * 100).toInt()}% below target this week. Consider adding Greek yogurt or eggs to breakfast for a quick boost.';
    if (calPct > 0.9) return "You're close to your calorie goal! Try a light dinner like grilled veggies or salad.";
    return 'Great job tracking today! Keep consistent logging for accurate weekly insights.';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.access_time_rounded, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Tip of the Day', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: accent)),
                const SizedBox(height: 5),
                Text(_buildTip(), style: GoogleFonts.outfit(fontSize: 13, color: textMuted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
