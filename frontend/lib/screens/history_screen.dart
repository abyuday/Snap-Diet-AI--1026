import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import 'analytics_screen.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final historyProvider = Provider.of<HistoryProvider>(context);
    final history = historyProvider.history;
    final totalToday = historyProvider.totalToday;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Food Journal',
                  style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text('Your daily nutritional log',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 14)),
              const SizedBox(height: 24),
              // Today summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Today's Total",
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('${totalToday.toInt()} kcal',
                            style: GoogleFonts.outfit(
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                            'Goal: 2000 kcal  •  Remaining: ${(2000 - totalToday).toInt()}',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white12,
                      child: Icon(Icons.local_fire_department_rounded,
                          color: Colors.orangeAccent, size: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildAnalyticsCard(context),
              const SizedBox(height: 20),
              // Daily Macro Progress
              _DailyMacroRow(
                protein: historyProvider.totalProteinToday,
                carbs: historyProvider.totalCarbsToday,
                fat: historyProvider.totalFatToday,
              ),
              const SizedBox(height: 24),
              Text('Recent Scans',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
              const SizedBox(height: 12),
              Expanded(
                child: history.isEmpty
                    ? Center(
                        child: Text('No scans yet. Start by snapping a photo!',
                            style: TextStyle(color: Colors.white38)))
                    : ListView.separated(
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = history[index];
                          return _HistoryTile(item: item);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const AnalyticsScreen())),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.analytics_rounded, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'View Weekly Trends & AI Insights',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry item;
  const _HistoryTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 52,
              height: 52,
              child: (item.imagePath.startsWith('http') || item.imagePath.startsWith('blob:'))
                ? Image.network(item.imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())
                : (item.imagePath.isEmpty 
                    ? _buildPlaceholder() 
                    : kIsWeb 
                      ? _buildPlaceholder() 
                      : Image.network(item.imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPlaceholder())),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(DateFormat('MMM d, h:mm a').format(item.dateTime),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.45), fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${item.calories.toInt()} kcal',
                  style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              const SizedBox(height: 2),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white24, size: 18),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppTheme.primaryColor.withOpacity(0.12),
      child: Center(child: Text(item.emoji, style: const TextStyle(fontSize: 22))),
    );
  }
}

class _DailyMacroRow extends StatelessWidget {
  final double protein, carbs, fat;
  const _DailyMacroRow({required this.protein, required this.carbs, required this.fat});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MicroMacroItem(label: 'Protein', value: protein, color: const Color(0xFF4FA3E0))),
        const SizedBox(width: 8),
        Expanded(child: _MicroMacroItem(label: 'Carbs', value: carbs, color: const Color(0xFFFF9057))),
        const SizedBox(width: 8),
        Expanded(child: _MicroMacroItem(label: 'Fat', value: fat, color: const Color(0xFFFF6B8A))),
      ],
    );
  }
}

class _MicroMacroItem extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MicroMacroItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text('${value.toInt()}g', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
          Text(label, style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}
