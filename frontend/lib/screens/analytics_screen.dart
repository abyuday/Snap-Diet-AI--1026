import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import '../services/user_provider.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);
    final trend = historyProvider.weeklyCalorieTrend;
    final goal = userProvider.calorieGoal.toDouble();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Weekly Insights', 
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildChartCard(trend, goal),
            const SizedBox(height: 32),
            _buildMacroDistribution(historyProvider),
            const SizedBox(height: 32),
            _buildAIInsights(historyProvider, userProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(List<double> trend, double goal) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calorie Trend', 
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Last 7 days vs Goal', 
            style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.5))),
          const Expanded(child: SizedBox(height: 20)),
          Expanded(
            flex: 8,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Goal Line
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), goal)),
                    isCurved: false,
                    color: Colors.white10,
                    dashArray: [5, 5],
                    dotData: FlDotData(show: false),
                  ),
                  // Actual Trend
                  LineChartBarData(
                    spots: List.generate(7, (i) => FlSpot(i.toDouble(), trend[i])),
                    isCurved: true,
                    color: AppTheme.primaryColor,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: AppTheme.primaryColor,
                        strokeWidth: 3,
                        strokeColor: AppTheme.backgroundColor,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(0.3),
                          AppTheme.primaryColor.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroDistribution(HistoryProvider history) {
    // Simplified: average for the week
    double p = 0, c = 0, f = 0;
    for (var entry in history.history) {
      if (entry.dateTime.isAfter(DateTime.now().subtract(const Duration(days: 7)))) {
        p += entry.protein;
        c += entry.carbs;
        f += entry.fat;
      }
    }
    double total = p + c + f;
    if (total == 0) total = 1;

    return Row(
      children: [
        Expanded(
          flex: 4,
          child: SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(value: p, title: '', color: const Color(0xFF4FA3E0), radius: 20),
                  PieChartSectionData(value: c, title: '', color: const Color(0xFFFF9057), radius: 20),
                  PieChartSectionData(value: f, title: '', color: const Color(0xFFFF6B8A), radius: 20),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Macro Split', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              _macroLegend('Protein', (p/total*100).toInt(), const Color(0xFF4FA3E0)),
              _macroLegend('Carbs', (c/total*100).toInt(), const Color(0xFFFF9057)),
              _macroLegend('Fat', (f/total*100).toInt(), const Color(0xFFFF6B8A)),
            ],
          ),
        )
      ],
    );
  }

  Widget _macroLegend(String label, int percent, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text('$percent%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildAIInsights(HistoryProvider history, UserProvider user) {
    // Heuristic based insights
    String insightText = "Great job! You are staying consistent with your scans.";
    String title = "On Track";
    IconData icon = Icons.star_rounded;
    Color color = AppTheme.primaryColor;

    final trend = history.weeklyCalorieTrend;
    int overLimitDays = trend.where((cal) => cal > user.calorieGoal + 200).length;
    
    if (overLimitDays >= 3) {
      title = "Calorie Spike";
      insightText = "You've exceeded your calorie goal 3 times this week. Try incorporating more protein-rich Indian meals like Paneer or Dal to stay full longer.";
      icon = Icons.trending_up_rounded;
      color = Colors.orangeAccent;
    } else if (history.history.isEmpty) {
      insightText = "Log your first meal to get personalized AI insights and trend analysis!";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(insightText, style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 14)),
        ],
      ),
    );
  }
}
