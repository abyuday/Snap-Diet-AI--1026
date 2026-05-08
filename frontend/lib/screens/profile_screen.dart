import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/user_provider.dart';
import '../services/history_provider.dart';
import '../services/theme_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark   = context.watch<ThemeProvider>().isDark;
    final user     = context.watch<UserProvider>();
    final history  = context.watch<HistoryProvider>();
    final accent   = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    final bg       = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final surf     = isDark ? AppTheme.darkSurface   : AppTheme.lightSurface;
    final surf2    = isDark ? AppTheme.darkSurface2  : AppTheme.lightSurface2;
    final border   = isDark ? AppTheme.darkBorder    : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U';
    final goalLabel = user.goal == 'weight_loss' ? 'Weight Loss'
        : user.goal == 'muscle_gain' ? 'Muscle Gain' : 'Maintenance';
    final actLabel = user.activityLevel == 'low' ? 'Low Activity'
        : user.activityLevel == 'high' ? 'High Activity' : 'Active';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
          child: Column(
            children: [
              // ── Avatar ────────────────────────────────────────────────
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Center(
                  child: Text(initial, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 14),
              Text(user.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
              const SizedBox(height: 4),
              Text('$goalLabel · $actLabel', style: GoogleFonts.outfit(fontSize: 13, color: textMuted)),
              const SizedBox(height: 14),

              // Badges
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _badge('🔥 ${history.currentStreak}-day streak', accent),
                  const SizedBox(width: 10),
                  _badge('📸 ${history.history.length} scans', accent),
                ],
              ),
              const SizedBox(height: 28),

              // ── Personal Info ─────────────────────────────────────────
              _sectionCard(
                title: 'PERSONAL INFO',
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted,
                children: [
                  _infoRow('Age',            user.age > 0 ? '${user.age} years' : '—',         textPrimary, textMuted),
                  _divider(border),
                  _infoRow('Height',         user.heightCm > 0 ? '${user.heightCm.toInt()} cm' : '—', textPrimary, textMuted),
                  _divider(border),
                  _infoRow('Current Weight', user.weightKg > 0 ? '${user.weightKg.toStringAsFixed(1)} kg' : '—', textPrimary, textMuted),
                  _divider(border),
                  _infoRow('Target Weight',  user.targetWeightKg > 0 ? '${user.targetWeightKg.toStringAsFixed(1)} kg' : '—', accent, textMuted),
                ],
              ),
              const SizedBox(height: 16),

              // ── Daily Goals ───────────────────────────────────────────
              _sectionCard(
                title: 'DAILY GOALS',
                surf: surf, border: border, textPrimary: textPrimary, textMuted: textMuted,
                children: [
                  _goalRow('Calorie Goal', history.totalToday.toInt(), user.calorieGoal, '${user.calorieGoal} kcal', const Color(0xFF4FA3E0), textPrimary, textMuted),
                  const SizedBox(height: 16),
                  _goalRow('Protein Goal', history.totalProteinToday.toInt(), user.proteinGoal, '${user.proteinGoal}g', const Color(0xFFFF6B6B), textPrimary, textMuted),
                  const SizedBox(height: 16),
                  _goalRow('Water Goal', user.currentWater, user.waterGoal, '${(user.waterGoal / 1000).toStringAsFixed(1)} L', const Color(0xFF4FA3E0), textPrimary, textMuted),
                ],
              ),
              const SizedBox(height: 16),

              // ── Edit Profile button ───────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _showEditDialog(context, user, accent, surf, border, textPrimary, textMuted),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Edit Profile', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: textPrimary)),
                ),
              ),
              const SizedBox(height: 12),

              // ── Theme toggle ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.read<ThemeProvider>().toggle(),
                  icon: Icon(isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round, size: 18, color: accent),
                  label: Text(isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: accent)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: accent.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Logout ────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, user),
                  icon: const Icon(Icons.logout_rounded, size: 18, color: AppTheme.accentRed),
                  label: Text('Sign Out', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.accentRed)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppTheme.accentRed.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionCard({
    required String title,
    required Color surf, required Color border,
    required Color textPrimary, required Color textMuted,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 11, letterSpacing: 1, color: textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textMuted, fontSize: 14)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _divider(Color border) => Divider(color: border, height: 1);

  Widget _goalRow(String label, int current, int goal, String goalLabel,
      Color color, Color textPrimary, Color textMuted) {
    final progress = (current / goal.clamp(1, 999999).toDouble()).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: textMuted, fontSize: 13)),
            Text(goalLabel, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  void _confirmLogout(BuildContext context, UserProvider user) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () { Navigator.pop(context); user.logout(); },
            child: const Text('Sign Out', style: TextStyle(color: AppTheme.accentRed)),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, UserProvider user, Color accent,
      Color surf, Color border, Color textPrimary, Color textMuted) {
    final nameCtrl = TextEditingController(text: user.name);
    final calCtrl = TextEditingController(text: user.calorieGoal.toString());
    final protCtrl = TextEditingController(text: user.proteinGoal.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: surf,
        title: Text('Edit Profile', style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Calorie Goal (kcal)',
                labelStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: protCtrl,
              keyboardType: TextInputType.number,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: 'Protein Goal (g)',
                labelStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: border)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              user.updateProfile(nameCtrl.text, user.rank);
              user.updateGoals(
                calories: int.tryParse(calCtrl.text) ?? user.calorieGoal,
                protein: int.tryParse(protCtrl.text) ?? user.proteinGoal,
              );
              Navigator.pop(context);
            },
            child: Text('Save', style: TextStyle(color: accent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
