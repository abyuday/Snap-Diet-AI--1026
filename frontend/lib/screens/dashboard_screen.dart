import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import '../services/user_provider.dart';
import '../services/theme_provider.dart';
import 'multi_capture_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark   = context.watch<ThemeProvider>().isDark;
    final history  = context.watch<HistoryProvider>();
    final user     = context.watch<UserProvider>();
    final accent   = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;
    final bg       = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final surf     = isDark ? AppTheme.darkSurface   : AppTheme.lightSurface;
    final surf2    = isDark ? AppTheme.darkSurface2  : AppTheme.lightSurface2;
    final border   = isDark ? AppTheme.darkBorder    : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;
    final shadowColor = isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.04);

    final calGoal  = user.calorieGoal.toDouble().clamp(1.0, 9999.0).toDouble();
    final protGoal = user.proteinGoal.toDouble().clamp(1.0, 999.0).toDouble();
    final carbGoal = user.carbsGoal.toDouble().clamp(1.0, 999.0).toDouble();
    final fatGoal  = user.fatGoal.toDouble().clamp(1.0, 999.0).toDouble();

    final calEaten  = history.totalSelectedDate;
    final protEaten = history.totalProteinSelectedDate;
    final carbEaten = history.totalCarbsSelectedDate;
    final fatEaten  = history.totalFatSelectedDate;

    final now = DateTime.now();
    final sel = history.selectedDate;
    final isToday = sel.year == now.year && sel.month == now.month && sel.day == now.day;

    final days = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${days[sel.weekday-1]}, ${sel.day} ${months[sel.month-1]} · ${sel.year}';

    final selectedEntries = history.selectedDateEntries;

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
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dashboard', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text(dateStr, style: GoogleFonts.outfit(fontSize: 13, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.calendar_month_rounded, color: accent),
                    onPressed: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: sel,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: isDark 
                                ? ColorScheme.dark(primary: accent, onPrimary: Colors.white, onSurface: textPrimary)
                                : ColorScheme.light(primary: accent, onPrimary: Colors.white, onSurface: textPrimary),
                              dialogBackgroundColor: surf,
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        history.setSelectedDate(picked);
                      }
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday ? accent.withOpacity(0.15) : surf2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isToday ? accent.withOpacity(0.5) : border),
                    ),
                    child: Text(isToday ? 'Today' : 'Past', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: isToday ? accent : textMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SizedBox(height: 20),

              // Calendar Strip
              _buildCalendarStrip(context, history, surf, border, accent, textPrimary, textMuted),
              const SizedBox(height: 24),

              // Smart AI Insight Card
              _buildSmartInsightCard(user, calEaten, calGoal, protEaten, protGoal, surf, border, textPrimary, textMuted, shadowColor),
              const SizedBox(height: 20),

              // Daily Calories card
              _buildCalorieCard(calEaten, calGoal, accent, surf, border, textPrimary, textMuted, shadowColor),
              const SizedBox(height: 16),

              // Macros Today
              _buildMacrosCard(protEaten, protGoal, carbEaten, carbGoal, fatEaten, fatGoal, accent, surf, border, textPrimary, textMuted, shadowColor),
              const SizedBox(height: 16),

              // Water Intake
              _buildWaterCard(user, accent, surf, border, textPrimary, textMuted, shadowColor),
              const SizedBox(height: 16),

              // Meal timeline
              _buildMealTimeline(context, selectedEntries, accent, surf, surf2, border, textPrimary, textMuted),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  void _logWater(UserProvider user, int amount) {
    user.addWater(amount);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('💧 Added $amount ml of water'),
        backgroundColor: const Color(0xFF4FA3E0),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildSmartInsightCard(UserProvider user, double calEaten, double calGoal, double protEaten, double protGoal,
      Color surf, Color border, Color textPrimary, Color textMuted, Color shadowColor) {
    String insightText = "You're on track with your goals today! Keep it up.";
    IconData insightIcon = Icons.stars_rounded;
    Color insightColor = AppTheme.primaryColor;

    if (calEaten > calGoal && calGoal > 0) {
      insightText = "You've exceeded your daily calorie target. Consider lighter meals.";
      insightColor = AppTheme.accentRed;
      insightIcon = Icons.warning_rounded;
    } else if (user.currentWater >= user.waterGoal && user.waterGoal > 0) {
      insightText = "Hydration goal completed! Excellent work today.";
      insightColor = const Color(0xFF4FA3E0);
      insightIcon = Icons.water_drop;
    } else if (protEaten < protGoal * 0.5 && calEaten > calGoal * 0.5) {
      insightText = "Protein intake is below target. Add more lean meats or legumes.";
      insightColor = const Color(0xFFFFB74D);
      insightIcon = Icons.bolt_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: insightColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(insightIcon, color: insightColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI INSIGHT', style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(
                  insightText,
                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip(BuildContext context, HistoryProvider history, Color surf, Color border, Color accent, Color textPrimary, Color textMuted) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Generate last 30 days
    final List<DateTime> dates = List.generate(30, (index) => today.subtract(Duration(days: 29 - index)));

    return SizedBox(
      height: 75,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        controller: ScrollController(initialScrollOffset: 30 * 64.0), // Start near the end (today)
        itemBuilder: (context, index) {
          final date = dates[index];
          final sel = history.selectedDate;
          final isSelected = date.year == sel.year && date.month == sel.month && date.day == sel.day;
          final daysShort = ['M','T','W','T','F','S','S'];

          return GestureDetector(
            onTap: () => history.setSelectedDate(date),
            child: Container(
              width: 54,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? accent : surf,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? accent : border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    daysShort[date.weekday - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalorieCard(double eaten, double goal, Color accent, Color surf,
      Color border, Color textPrimary, Color textMuted, Color shadowColor) {
    final progress   = (eaten / goal).clamp(0.0, 1.0).toDouble();
    final remaining  = (goal - eaten).clamp(0.0, goal).toDouble();
    final isOver     = eaten > goal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('DAILY CALORIES', style: TextStyle(fontSize: 11, letterSpacing: 1, color: textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(
            children: [
              // Animated Ring
              SizedBox(
                width: 100, height: 100,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (context, animValue, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            startDegreeOffset: -90,
                            sectionsSpace: 0,
                            centerSpaceRadius: 38,
                            sections: [
                              PieChartSectionData(
                                value: animValue,
                                color: isOver ? AppTheme.accentRed : const Color(0xFF10B981), // Green for good, Red for over
                                radius: 12,
                                title: '',
                              ),
                              PieChartSectionData(
                                value: 1.0 - animValue,
                                color: accent.withOpacity(0.1),
                                radius: 10,
                                title: '',
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '${(animValue * 100).toInt()}%',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isOver ? AppTheme.accentRed : textPrimary),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
                      ),
                      child: Text(
                        '${eaten.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                        key: ValueKey<int>(eaten.toInt()),
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: textPrimary, height: 1.1),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                      child: Text(
                        'of ${goal.toInt()} kcal · ${isOver ? "EXCEEDED!" : "${remaining.toInt()} left"}',
                        key: ValueKey<String>('${goal.toInt()}_$remaining'),
                        style: TextStyle(
                          fontSize: 13,
                          color: isOver ? AppTheme.accentRed : textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // AI Insight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child: Text(
                      isOver 
                        ? 'You have exceeded your calorie goal for today by ${(eaten - goal).toInt()} kcal.'
                        : remaining > goal * 0.5 
                          ? 'Plenty of calories left! Plan a nutritious meal.'
                          : remaining > goal * 0.1
                            ? 'You are on track! Keep it up.'
                            : 'Almost at your limit. Choose your next snack wisely!',
                      key: ValueKey<String>('${isOver}_${remaining > goal * 0.5}_${remaining > goal * 0.1}'),
                      style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWaterCard(UserProvider user, Color accent, Color surf, Color border, Color textPrimary, Color textMuted, Color shadowColor) {
    final int eaten = user.currentWater;
    final int goal = user.waterGoal;
    final double progress = (eaten / goal.clamp(1, 99999)).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('WATER INTAKE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: textMuted, fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () => user.resetWater(),
                child: Text('Reset', style: TextStyle(fontSize: 12, color: accent, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.water_drop_rounded, color: Color(0xFF4FA3E0), size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1.0).animate(animation), child: child),
                          ),
                          child: Text(
                            '$eaten ml',
                            key: ValueKey<int>(eaten),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
                          ),
                        ),
                        Text('Goal: $goal ml', style: TextStyle(fontSize: 13, color: textMuted, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: value,
                          backgroundColor: const Color(0xFF4FA3E0).withOpacity(0.12),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FA3E0)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _logWater(user, 250),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FA3E0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4FA3E0).withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('+250 ml', style: TextStyle(color: Color(0xFF4FA3E0), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _logWater(user, 500),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4FA3E0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF4FA3E0).withOpacity(0.3)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('+500 ml', style: TextStyle(color: Color(0xFF4FA3E0), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(
      double pEaten, double pGoal,
      double cEaten, double cGoal,
      double fEaten, double fGoal,
      Color accent, Color surf, Color border, Color textPrimary, Color textMuted, Color shadowColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MACROS TODAY', style: TextStyle(fontSize: 11, letterSpacing: 1, color: textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          _macroBar('Protein', pEaten, pGoal, const Color(0xFFFF6B6B), textPrimary, textMuted),
          const SizedBox(height: 14),
          _macroBar('Carbs',   cEaten, cGoal, const Color(0xFF4FA3E0), textPrimary, textMuted),
          const SizedBox(height: 14),
          _macroBar('Fat',     fEaten, fGoal, const Color(0xFFFFB74D), textPrimary, textMuted),
        ],
      ),
    );
  }

  Widget _macroBar(String label, double eaten, double goal, Color color,
      Color textPrimary, Color textMuted) {
    final progress = (eaten / goal.clamp(1.0, 999.0).toDouble()).clamp(0.0, 1.0).toDouble();
    final isOver = eaten > goal;
    final displayColor = isOver ? AppTheme.accentRed : color;
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(label, style: TextStyle(color: textMuted, fontSize: 13)),
        ),
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: displayColor.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(displayColor),
                minHeight: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
            child: Text(
              '${eaten.toInt()}g / ${goal.toInt()}g',
              key: ValueKey<int>(eaten.toInt()),
              textAlign: TextAlign.end,
              style: TextStyle(color: displayColor, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealTimeline(BuildContext context, List<HistoryEntry> entries, Color accent, Color surf,
      Color surf2, Color border, Color textPrimary, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MEAL TIMELINE', style: TextStyle(fontSize: 11, letterSpacing: 1, color: textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
            child: Column(
              children: [
                Text('🍽️', style: const TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                Text('No meals logged yet', style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Start by scanning your first meal', style: TextStyle(color: textMuted, fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MultiCaptureScreen())),
                  icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                  label: const Text('Log a Meal'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          ...entries.map((e) {
            final t = '${e.dateTime.hour.toString().padLeft(2,'0')}:${e.dateTime.minute.toString().padLeft(2,'0')}';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time + dot
                  Column(
                    children: [
                      SizedBox(width: 42, child: Text(t, style: TextStyle(color: textMuted, fontSize: 12))),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 3), decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: surf, borderRadius: BorderRadius.circular(14), border: Border.all(color: border)),
                      child: Row(
                        children: [
                          Text(e.emoji, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(e.foodName, style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14), overflow: TextOverflow.ellipsis),
                                Text('${e.calories.toInt()} kcal', style: TextStyle(color: textMuted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('${e.calories.toInt()}', style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}
