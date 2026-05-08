import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final user = context.watch<UserProvider>();
    final isDark = context.watch<ThemeProvider>().isDark;

    final bg       = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final surf     = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final border   = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    
    final trend = history.weeklyCalorieTrend;
    final safeTrend = trend.length == 7 ? trend : List.filled(7, 0.0);
    
    final goal = user.calorieGoal.toDouble();
    double sum = 0;
    int count = 0;
    for (var c in safeTrend) {
      if (c > 0) {
        sum += c;
        count++;
      }
    }
    final avg = count > 0 ? (sum / count).toInt() : 0;
    
    final macros = history.getMacrosForPeriod(7);
    final p = macros['protein'] ?? 0;
    final c = macros['carbs'] ?? 0;
    final f = macros['fat'] ?? 0;
    final totalM = p + c + f;
    
    final pPct = totalM > 0 ? (p / totalM) : 0.0;
    final cPct = totalM > 0 ? (c / totalM) : 0.0;
    final fPct = totalM > 0 ? (f / totalM) : 0.0;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analytics', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 28, color: textPrimary)),
            Text('Weekly Overview', style: GoogleFonts.outfit(fontSize: 14, color: textMuted)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('This Week', style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildCalorieTrendCard(safeTrend, avg, goal.toInt(), surf, border, textPrimary, textMuted, accent),
            const SizedBox(height: 16),
            _buildMacroDistributionCard(pPct, cPct, fPct, surf, border, textPrimary, textMuted),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildBestDayCard(safeTrend, surf, border, textPrimary, textMuted, accent)),
                const SizedBox(width: 16),
                Expanded(child: _buildStreakCard(history.currentStreak, surf, border, textPrimary, textMuted, accent)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCalorieTrendCard(List<double> trend, int avg, int goal, Color surf, Color border, Color textPrimary, Color textMuted, Color accent) {
    final todayIndex = DateTime.now().weekday - 1; // 0=Mon, 6=Sun
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CALORIE TREND', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted)),
          const SizedBox(height: 24),
          
          // Bar Chart area
          SizedBox(
            height: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final isToday = i == todayIndex;
                final val = trend[i];
                final heightFactor = (val / (goal * 1.2)).clamp(0.01, 1.0);
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      width: 36,
                      height: 110 * heightFactor,
                      decoration: BoxDecoration(
                        color: isToday ? accent : textMuted.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: isToday ? [
                          BoxShadow(color: accent.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
                        ] : [],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(days[i], style: TextStyle(
                      color: isToday ? accent : textMuted,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12
                    )),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Avg: ${avg > 0 ? avg : 0} kcal', style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              Text('Goal: $goal kcal', style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMacroDistributionCard(double pPct, double cPct, double fPct, Color surf, Color border, Color textPrimary, Color textMuted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MACRO DISTRIBUTION', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted)),
          const SizedBox(height: 20),
          
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: (pPct * 100).toInt(), child: Container(color: const Color(0xFFFF6B6B))),
                  const SizedBox(width: 4),
                  Expanded(flex: (cPct * 100).toInt(), child: Container(color: const Color(0xFF5C7CFA))),
                  const SizedBox(width: 4),
                  Expanded(flex: (fPct * 100).toInt(), child: Container(color: const Color(0xFFFFB74D))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _macroLegend('Protein', pPct, const Color(0xFFFF6B6B), textPrimary),
              _macroLegend('Carbs', cPct, const Color(0xFF5C7CFA), textPrimary),
              _macroLegend('Fat', fPct, const Color(0xFFFFB74D), textPrimary),
            ],
          )
        ],
      ),
    );
  }

  Widget _macroLegend(String label, double pct, Color color, Color textPrimary) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text('$label ${(pct * 100).toInt()}%', style: TextStyle(color: textPrimary, fontSize: 13)),
      ],
    );
  }

  Widget _buildBestDayCard(List<double> safeTrend, Color surf, Color border, Color textPrimary, Color textMuted, Color accent) {
    double maxCal = 0;
    int maxIdx = -1;
    for (int i = 0; i < safeTrend.length; i++) {
      if (safeTrend[i] > maxCal) {
        maxCal = safeTrend[i];
        maxIdx = i;
      }
    }
    
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final bestDayStr = maxIdx == -1 || maxCal == 0 ? 'None' : days[maxIdx];
  
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('BEST DAY', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted)),
          const SizedBox(height: 12),
          Text(bestDayStr, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: accent)),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak, Color surf, Color border, Color textPrimary, Color textMuted, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STREAK', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$streak', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: const Color(0xFF9D84FF))),
              const SizedBox(width: 4),
              Text('days', style: TextStyle(fontSize: 14, color: textMuted)),
            ],
          )
        ],
      ),
    );
  }
}
