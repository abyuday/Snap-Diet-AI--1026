import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import '../services/user_provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final user = context.watch<UserProvider>();

    // Daily goals — from UserProvider or defaults
    final double calGoal = user.calorieGoal.toDouble().clamp(1, 9999);
    const double protGoal = 150;
    const double carbGoal = 250;
    const double fatGoal = 60;

    final double calEaten = history.totalToday;
    final double protEaten = history.totalProteinToday;
    final double carbEaten = history.totalCarbsToday;
    final double fatEaten = history.totalFatToday;

    final todayEntries = history.history
        .where((e) {
          final now = DateTime.now();
          return e.dateTime.year == now.year &&
              e.dateTime.month == now.month &&
              e.dateTime.day == now.day;
        })
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Today\'s Dashboard',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            _buildDateHeader(),
            const SizedBox(height: 20),

            // Main calorie ring
            _buildCalorieRing(calEaten, calGoal),
            const SizedBox(height: 20),

            // Macro goal cards
            _buildMacroCards(protEaten, protGoal, carbEaten, carbGoal, fatEaten, fatGoal),
            const SizedBox(height: 24),

            // Macro distribution bar
            _buildDistributionBar(protEaten, carbEaten, fatEaten),
            const SizedBox(height: 24),

            // Smart tip
            _buildSmartTip(calEaten, calGoal, protEaten, protGoal),
            const SizedBox(height: 24),

            // Today's meals list
            _buildTodayMeals(todayEntries),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader() {
    final now = DateTime.now();
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dayName = days[now.weekday - 1];
    final formatted = '$dayName, ${now.day} ${months[now.month - 1]} ${now.year}';

    return Text(
      formatted,
      style: TextStyle(color: Colors.white54, fontSize: 13, letterSpacing: 0.4),
    );
  }

  Widget _buildCalorieRing(double eaten, double goal) {
    final progress = (eaten / goal).clamp(0.0, 1.0);
    final remaining = (goal - eaten).clamp(0.0, goal);
    final isOver = eaten > goal;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Calorie Budget',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOver
                      ? Colors.redAccent.withOpacity(0.15)
                      : AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isOver ? 'Over Goal' : '${remaining.toInt()} left',
                  style: TextStyle(
                    color: isOver ? Colors.redAccent : AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              // Ring chart
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 0,
                        centerSpaceRadius: 50,
                        sections: [
                          PieChartSectionData(
                            value: progress,
                            color: isOver ? Colors.redAccent : AppTheme.primaryColor,
                            radius: 18,
                            title: '',
                          ),
                          PieChartSectionData(
                            value: 1.0 - progress,
                            color: Colors.white10,
                            radius: 14,
                            title: '',
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          eaten.toInt().toString(),
                          style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                        Text(
                          'kcal',
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Breakdown stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statRow('Goal', '${goal.toInt()} kcal', Colors.white38),
                    const SizedBox(height: 12),
                    _statRow('Eaten', '${eaten.toInt()} kcal', AppTheme.primaryColor),
                    const SizedBox(height: 12),
                    _statRow(
                      isOver ? 'Over by' : 'Remaining',
                      '${remaining.toInt()} kcal',
                      isOver ? Colors.redAccent : Colors.greenAccent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 13)),
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }

  Widget _buildMacroCards(
      double pEaten, double pGoal,
      double cEaten, double cGoal,
      double fEaten, double fGoal) {
    return Row(
      children: [
        Expanded(
          child: _MacroCard(
            label: 'Protein',
            eaten: pEaten,
            goal: pGoal,
            unit: 'g',
            color: const Color(0xFF4FA3E0),
            icon: Icons.fitness_center_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroCard(
            label: 'Carbs',
            eaten: cEaten,
            goal: cGoal,
            unit: 'g',
            color: const Color(0xFFFF9057),
            icon: Icons.grain_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroCard(
            label: 'Fat',
            eaten: fEaten,
            goal: fGoal,
            unit: 'g',
            color: const Color(0xFFFF6B8A),
            icon: Icons.water_drop_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildDistributionBar(double protein, double carbs, double fat) {
    final total = (protein + carbs + fat).clamp(1.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Macro Distribution (Today)',
              style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Flexible(
                    flex: (protein / total * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFF4FA3E0)),
                  ),
                  Flexible(
                    flex: (carbs / total * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFFFF9057)),
                  ),
                  Flexible(
                    flex: (fat / total * 100).round().clamp(0, 100),
                    child: Container(color: const Color(0xFFFF6B8A)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _barLegend('Protein', (protein / total * 100).round(), const Color(0xFF4FA3E0)),
              _barLegend('Carbs', (carbs / total * 100).round(), const Color(0xFFFF9057)),
              _barLegend('Fat', (fat / total * 100).round(), const Color(0xFFFF6B8A)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _barLegend(String label, int pct, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label $pct%', style: TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildSmartTip(double calEaten, double calGoal, double protEaten, double protGoal) {
    String emoji = '💡';
    String message;
    Color borderColor = AppTheme.primaryColor.withOpacity(0.3);

    if (calEaten == 0) {
      message = 'You haven\'t logged any meals today. Start by scanning a food barcode or searching manually!';
    } else if (calEaten > calGoal * 1.1) {
      emoji = '⚠️';
      message = 'You\'ve exceeded your calorie goal today. Consider lighter snacks or a walk to balance it out.';
      borderColor = Colors.redAccent.withOpacity(0.4);
    } else if (protEaten < protGoal * 0.5 && calEaten > calGoal * 0.6) {
      emoji = '🥩';
      message = 'Protein intake is low relative to your calories. Add a high-protein meal like eggs, paneer, or chicken.';
      borderColor = Colors.orangeAccent.withOpacity(0.4);
    } else if (calEaten < calGoal * 0.4) {
      emoji = '🍱';
      message = 'You\'re well under your calorie goal. Make sure you\'re eating enough to fuel your body!';
    } else {
      emoji = '✅';
      message = 'You\'re on track today! Keep logging your meals to stay consistent.';
      borderColor = Colors.greenAccent.withOpacity(0.3);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Tip',
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 4),
                Text(message,
                    style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayMeals(List<HistoryEntry> entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Meals',
          style: GoogleFonts.outfit(
              fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              children: [
                Text('🍽️', style: TextStyle(fontSize: 40)),
                SizedBox(height: 12),
                Text('No meals logged yet today',
                    style: TextStyle(color: Colors.white54, fontSize: 14)),
              ],
            ),
          )
        else
          ...entries.map((e) => _MealTile(entry: e)),
      ],
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label;
  final double eaten;
  final double goal;
  final String unit;
  final Color color;
  final IconData icon;

  const _MacroCard({
    required this.label,
    required this.eaten,
    required this.goal,
    required this.unit,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (eaten / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            '${eaten.toInt()}$unit',
            style: GoogleFonts.outfit(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Text(
            '/ ${goal.toInt()}$unit',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              color: color,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final HistoryEntry entry;
  const _MealTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Text(entry.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.foodName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'P ${entry.protein.toStringAsFixed(1)}g  •  C ${entry.carbs.toStringAsFixed(1)}g  •  F ${entry.fat.toStringAsFixed(1)}g',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.calories.toInt()}',
                style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
              Text('kcal', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
