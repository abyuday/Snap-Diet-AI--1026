import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class RecipeScreen extends StatelessWidget {
  final List<dynamic> recipes;
  final String summary;

  const RecipeScreen({
    super.key,
    required this.recipes,
    this.summary = '',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Recipe Suggestions',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          if (summary.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Text(
                summary,
                style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
              ),
            ),
          ],
          ...recipes.map((r) => _RecipeCard(recipe: r as Map<String, dynamic>)),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _RecipeCard extends StatefulWidget {
  final Map<String, dynamic> recipe;
  const _RecipeCard({required this.recipe});

  @override
  State<_RecipeCard> createState() => __RecipeCardState();
}

class __RecipeCardState extends State<_RecipeCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final cal = (r['calories'] as num?)?.toInt() ?? 0;
    final prot = (r['protein'] as num?)?.toInt() ?? 0;
    final carbs = (r['carbs'] as num?)?.toInt() ?? 0;
    final fat = (r['fat'] as num?)?.toInt() ?? 0;
    final ingredients = (r['ingredients'] as List<dynamic>?) ?? [];
    final steps = (r['steps'] as List<dynamic>?) ?? [];

    return AnimatedSize(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r['emoji'] ?? '🍽️', style: const TextStyle(fontSize: 36)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r['name'] ?? 'Recipe',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r['description'] ?? '',
                          style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
                          maxLines: _expanded ? null : 2,
                          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 10),
                        // Time chips
                        Wrap(
                          spacing: 8,
                          children: [
                            if (r['prep_time'] != null)
                              _Chip(Icons.timer_outlined, r['prep_time'], Colors.blue),
                            if (r['cook_time'] != null)
                              _Chip(Icons.local_fire_department_outlined, r['cook_time'], Colors.orange),
                            if (r['servings'] != null)
                              _Chip(Icons.people_outline, '${r['servings']} servings', Colors.purple),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Macro strip
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _MacroStat('Calories', '$cal kcal', AppTheme.primaryColor),
                  _vDivider(),
                  _MacroStat('Protein', '${prot}g', const Color(0xFF4FA3E0)),
                  _vDivider(),
                  _MacroStat('Carbs', '${carbs}g', const Color(0xFFFF9057)),
                  _vDivider(),
                  _MacroStat('Fat', '${fat}g', const Color(0xFFFF6B8A)),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Expand toggle
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      _expanded ? 'Hide details' : 'Show ingredients & steps',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            if (_expanded) ...[
              const Divider(color: Colors.white10, height: 1),

              // Ingredients
              if (ingredients.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'Ingredients',
                    style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                  ),
                ),
                ...ingredients.map((ing) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(color: AppTheme.primaryColor, fontSize: 14)),
                      Expanded(
                        child: Text(
                          ing.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
              ],

              // Steps
              if (steps.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text(
                    'How to Make',
                    style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                  ),
                ),
                ...steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.only(right: 12, top: 1),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${e.key + 1}',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.value.toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _vDivider() =>
      Container(height: 28, width: 1, color: Colors.white10);
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Chip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MacroStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}
