import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';
import '../services/theme_provider.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final historyProvider = context.watch<HistoryProvider>();
    final history = historyProvider.history;

    final isDark   = context.watch<ThemeProvider>().isDark;
    final bg       = isDark ? AppTheme.darkBg       : AppTheme.lightBg;
    final surf     = isDark ? AppTheme.darkSurface  : AppTheme.lightSurface;
    final border   = isDark ? AppTheme.darkBorder   : AppTheme.lightBorder;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted   = isDark ? AppTheme.darkTextMuted   : AppTheme.lightTextMuted;
    final accent = isDark ? AppTheme.primaryColor : AppTheme.primaryDark;

    // Filter by search query
    final filteredHistory = history.where((item) {
      return item.foodName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Group by Today vs Yesterday (simplified for UI demonstration)
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    final yesterdayStr = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));

    final List<HistoryEntry> todayItems = [];
    final List<HistoryEntry> yesterdayItems = [];
    final List<HistoryEntry> olderItems = [];

    for (var item in filteredHistory) {
      final dateStr = DateFormat('yyyy-MM-dd').format(item.dateTime);
      if (dateStr == todayStr) {
        todayItems.add(item);
      } else if (dateStr == yesterdayStr) {
        yesterdayItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    double calcCals(List<HistoryEntry> items) => items.fold(0.0, (sum, i) => sum + i.calories);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('History', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24, color: textPrimary)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text('Today', style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: surf,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: TextField(
                    style: TextStyle(color: textPrimary),
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: textMuted, size: 20),
                      hintText: 'Search history...',
                      hintStyle: TextStyle(color: textMuted, fontSize: 15),
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                    ),
                ),
              ),
            ),
            
            // List
            Expanded(
              child: filteredHistory.isEmpty
                  ? Center(child: Text('No data yet — start logging meals', style: TextStyle(color: textMuted)))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        if (todayItems.isNotEmpty) ...[
                          _buildGroupHeader('TODAY', calcCals(todayItems), textMuted),
                          ...todayItems.map((e) => _buildHistoryRow(e, surf, textPrimary, textMuted, accent)),
                          const SizedBox(height: 24),
                        ],
                        if (yesterdayItems.isNotEmpty) ...[
                          _buildGroupHeader('YESTERDAY', calcCals(yesterdayItems), textMuted),
                          ...yesterdayItems.map((e) => _buildHistoryRow(e, surf, textPrimary, textMuted, accent)),
                          const SizedBox(height: 24),
                        ],
                        if (olderItems.isNotEmpty) ...[
                          _buildGroupHeader('OLDER', calcCals(olderItems), textMuted),
                          ...olderItems.map((e) => _buildHistoryRow(e, surf, textPrimary, textMuted, accent)),
                        ]
                      ],
                    ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildGroupHeader(String title, double cals, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        '$title • ${cals.toInt()} KCAL',
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textMuted),
      ),
    );
  }

  Widget _buildHistoryRow(HistoryEntry item, Color surf, Color textPrimary, Color textMuted, Color accent) {
    // Generate mock macros if they are mostly 0, just to match the mockup style
    // The mockup shows "12P 28C 18F"
    int p = item.protein.toInt();
    int c = item.carbs.toInt();
    int f = item.fat.toInt();
    
    // Assign a default meal type
    String mealType = 'Snack';
    if (item.dateTime.hour < 11) mealType = 'Breakfast';
    else if (item.dateTime.hour < 15) mealType = 'Lunch';
    else if (item.dateTime.hour > 18) mealType = 'Dinner';

    final timeStr = DateFormat('h:mm a').format(item.dateTime);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: surf, // slightly lighter than bg
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(item.emoji.isNotEmpty ? item.emoji : '🍽️', style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.foodName, style: GoogleFonts.outfit(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$timeStr • $mealType • ${p}P ${c}C ${f}F', style: TextStyle(color: textMuted, fontSize: 12)),
              ],
            ),
          ),
          // Calories
          Text(item.calories.toInt().toString(), style: GoogleFonts.outfit(color: accent, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
