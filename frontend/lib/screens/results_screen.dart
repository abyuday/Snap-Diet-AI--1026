import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/nutrition_result.dart';
import '../theme/app_theme.dart';
import '../services/history_provider.dart';

class ResultsScreen extends StatefulWidget {
  final NutritionResult result;
  final XFile? imageFile;

  const ResultsScreen({super.key, required this.result, this.imageFile});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<Offset> _slideAnim;
  late Animation<double> _fadeAnim;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _entryController, curve: Curves.easeIn));
    _entryController.forward();
  }

  Future<void> _loadBytes() async {
    if (widget.imageFile == null) return;
    final bytes = await widget.imageFile!.readAsBytes();
    if (mounted) {
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Stack(
        children: [
          // Hero Food Image
          SizedBox(
            height: 320,
            width: double.infinity,
            child: _imageBytes != null 
                ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                : widget.imageFile == null
                    ? Container(color: AppTheme.surfaceColor)
                    : const Center(child: CircularProgressIndicator()),
          ),
          // Dark gradient overlay over the image
          Container(
            height: 320,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.backgroundColor.withOpacity(0.7),
                  AppTheme.backgroundColor,
                ],
              ),
            ),
          ),
          // Back button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
          // Content panel sliding in from below
          SlideTransition(
            position: _slideAnim,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: DraggableScrollableSheet(
                initialChildSize: 0.63,
                minChildSize: 0.63,
                maxChildSize: 0.95,
                builder: (context, scrollController) {
                  return Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              margin: const EdgeInsets.only(bottom: 20),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          // Food title + calories badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.result.foodName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.straighten_rounded, color: Colors.white.withOpacity(0.5), size: 15),
                                        const SizedBox(width: 5),
                                        Text(
                                          widget.result.portionSize,
                                          style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    if (widget.result.estimatedWeightGrams > 0) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.scale_rounded, color: Colors.white.withOpacity(0.5), size: 15),
                                          const SizedBox(width: 5),
                                          Text(
                                            '~${widget.result.estimatedWeightGrams.toStringAsFixed(0)}g',
                                            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  _CalorieBadge(calories: widget.result.calories),
                                  if (widget.result.estimatedWeightGrams > 0) ...[
                                    const SizedBox(height: 8),
                                    _WeightBadge(weightGrams: widget.result.estimatedWeightGrams),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // AR + Volume badges
                          if (widget.result.rawData != null) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (widget.result.rawData!['ar_enhanced'] == true)
                                  _InfoChip(
                                    icon: Icons.view_in_ar_rounded,
                                    label: 'AR Enhanced',
                                    gradient: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                                  ),
                                if (widget.result.rawData!['volume_cm3'] != null)
                                  _InfoChip(
                                    icon: Icons.threed_rotation_rounded,
                                    label: '${(widget.result.rawData!['volume_cm3'] as num).toStringAsFixed(0)} cm³',
                                    gradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                  ),
                                if (widget.result.rawData!['volume_method'] != null)
                                  _InfoChip(
                                    icon: Icons.layers_rounded,
                                    label: widget.result.rawData!['volume_method'] == 'dpt_depth_multi'
                                        ? 'Multi-View Depth'
                                        : widget.result.rawData!['volume_method'] == 'dpt_depth'
                                            ? 'Depth Map'
                                            : 'Heuristic',
                                    gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                                  ),
                                if (widget.result.rawData!['pose_quality'] != null)
                                  _InfoChip(
                                    icon: Icons.insights_rounded,
                                    label: 'Pose: ${widget.result.rawData!['pose_quality']}',
                                    gradient: widget.result.rawData!['pose_quality'] == 'high'
                                        ? const [Color(0xFF4ADE80), Color(0xFF22C55E)]
                                        : const [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 28),
                          // Macro grid
                          Text(
                            'Macronutrients',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _MacroCard(label: 'Protein', value: widget.result.protein, unit: 'g', color: const Color(0xFF4FA3E0), icon: '🥩')),
                              const SizedBox(width: 12),
                              Expanded(child: _MacroCard(label: 'Carbs', value: widget.result.carbs, unit: 'g', color: const Color(0xFFFF9057), icon: '🌾')),
                              const SizedBox(width: 12),
                              Expanded(child: _MacroCard(label: 'Fat', value: widget.result.fat, unit: 'g', color: const Color(0xFFFF6B8A), icon: '🧈')),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Macro bar chart
                          Text(
                            'Distribution',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _AnimatedMacroBar(
                            label: 'Protein',
                            value: widget.result.protein,
                            maxValue: 100,
                            color: const Color(0xFF4FA3E0),
                          ),
                          const SizedBox(height: 10),
                          _AnimatedMacroBar(
                            label: 'Carbs',
                            value: widget.result.carbs,
                            maxValue: 100,
                            color: const Color(0xFFFF9057),
                          ),
                          const SizedBox(height: 10),
                          _AnimatedMacroBar(
                            label: 'Fat',
                            value: widget.result.fat,
                            maxValue: 100,
                            color: const Color(0xFFFF6B8A),
                          ),
                          const SizedBox(height: 28),
                          // Micronutrients Expandable Section
                          Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              iconColor: Colors.white,
                              collapsedIconColor: Colors.white70,
                              title: Text(
                                'Micronutrients',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              children: [
                                const SizedBox(height: 8),
                                _MicroNutrientRow(label: 'Fiber', value: '${widget.result.fiberG} g'),
                                _MicroNutrientRow(label: 'Sugar', value: '${widget.result.sugarG} g'),
                                _MicroNutrientRow(label: 'Sodium', value: '${widget.result.sodiumMg} mg'),
                                _MicroNutrientRow(label: 'Potassium', value: '${widget.result.potassiumMg} mg'),
                                _MicroNutrientRow(label: 'Vitamin A', value: '${widget.result.vitaminAMcg} mcg'),
                                _MicroNutrientRow(label: 'Vitamin C', value: '${widget.result.vitaminCMg} mg'),
                                _MicroNutrientRow(label: 'Calcium', value: '${widget.result.calciumMg} mg'),
                                _MicroNutrientRow(label: 'Iron', value: '${widget.result.ironMg} mg'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                  label: const Text('Retake'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
                                    historyProvider.addEntry(widget.result, widget.imageFile.path);
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('✅ Added to your daily log!'),
                                        backgroundColor: AppTheme.primaryColor,
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                    
                                    // Navigate back to Home/Shell
                                    Future.delayed(const Duration(milliseconds: 500), () {
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }
                                    });
                                  },
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('Add to Log'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalorieBadge extends StatelessWidget {
  final double calories;
  const _CalorieBadge({required this.calories});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor.withOpacity(0.3), AppTheme.primaryColor.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text(
            calories.toInt().toString(),
            style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          Text('kcal', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _WeightBadge extends StatelessWidget {
  final double weightGrams;
  const _WeightBadge({required this.weightGrams});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4FA3E0).withOpacity(0.3),
            const Color(0xFF4FA3E0).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4FA3E0).withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            '~${weightGrams.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4FA3E0),
            ),
          ),
          Text(
            'grams',
            style: TextStyle(
              fontSize: 11,
              color: const Color(0xFF4FA3E0).withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  final String label, unit, icon;
  final double value;
  final Color color;
  const _MacroCard({required this.label, required this.value, required this.unit, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.55))),
        ],
      ),
    );
  }
}

class _AnimatedMacroBar extends StatefulWidget {
  final String label;
  final double value, maxValue;
  final Color color;
  const _AnimatedMacroBar({required this.label, required this.value, required this.maxValue, required this.color});

  @override
  State<_AnimatedMacroBar> createState() => _AnimatedMacroBarState();
}

class _AnimatedMacroBarState extends State<_AnimatedMacroBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _widthAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _widthAnim = Tween<double>(begin: 0, end: (widget.value / widget.maxValue).clamp(0.05, 1.0))
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(widget.label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _widthAnim,
            builder: (context, _) => Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: _widthAnim.value,
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: widget.color.withOpacity(0.5), blurRadius: 8)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${widget.value.toStringAsFixed(1)}g',
          style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MicroNutrientRow extends StatelessWidget {
  final String label, value;
  const _MicroNutrientRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradient[0].withOpacity(0.2), gradient[1].withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradient[0].withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: gradient[0], size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: gradient[0],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
