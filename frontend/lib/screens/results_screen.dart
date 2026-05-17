import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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

class _ResultsScreenState extends State<ResultsScreen> {
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadBytes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final isFailed = widget.result.foodName == "Unable to confidently identify food" || 
                       widget.result.foodName == "No Food Detected" || 
                       widget.result.foodName == "Analysis Failed";
      if (isFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Low confidence: Could not identify food.'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Scan completed successfully'),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<void> _loadBytes() async {
    if (widget.imageFile == null) return;
    final bytes = await widget.imageFile!.readAsBytes();
    if (mounted) {
      setState(() => _imageBytes = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: CustomScrollView(
            slivers: [
          SliverAppBar(
            backgroundColor: const Color(0xFF0D1117),
            expandedHeight: 280,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Results', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                ),
                child: Builder(
                  builder: (context) {
                    final conf = widget.result.rawData?['confidence'] as double? ?? 0.95;
                    final confPct = (conf * 100).toInt();
                    return Text('$confPct% Match', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12));
                  }
                ),
              )
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Container(color: const Color(0xFF161B22)),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -24, 0),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1117),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainCard(),
                    const SizedBox(height: 32),
                    Text('Micronutrients', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 16),
                    _buildMicronutrientList(),
                    const SizedBox(height: 40),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    ),
  ),
    );
  }

  Widget _buildMainCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.result.foodName, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('${widget.result.estimatedWeightGrams.toStringAsFixed(0)}g serving', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(widget.result.calories.toInt().toString(), style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryColor, height: 1.0)),
                  Text('kcal', style: TextStyle(color: AppTheme.primaryColor.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                ],
              )
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularMacro('Protein', widget.result.protein, 100, const Color(0xFFFF6B6B)),
              _buildCircularMacro('Carbs', widget.result.carbs, 200, const Color(0xFF5C7CFA)),
              _buildCircularMacro('Fat', widget.result.fat, 80, const Color(0xFFFFB74D)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCircularMacro(String label, double value, double goal, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 60, height: 60,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: (value / goal).clamp(0.0, 1.0),
                backgroundColor: color.withOpacity(0.15),
                color: color,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Text('${value.toInt()}g', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              )
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMicronutrientList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildMicroRow('Fiber', '${widget.result.fiberG}g', 'Good', const Color(0xFF1EDD88)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Sugar', '${widget.result.sugarG}g', 'Low', const Color(0xFF1EDD88)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Sodium', '${widget.result.sodiumMg}mg', 'High', const Color(0xFFFF6B6B)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Potassium', '${widget.result.potassiumMg}mg', 'Good', const Color(0xFF1EDD88)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Vitamin A', '${widget.result.vitaminAMcg}mcg', 'Fair', const Color(0xFF5C7CFA)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Vitamin C', '${widget.result.vitaminCMg}mg', 'Fair', const Color(0xFF5C7CFA)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Calcium', '${widget.result.calciumMg}mg', 'Fair', const Color(0xFF5C7CFA)),
          Divider(color: Colors.white.withOpacity(0.05), height: 1),
          _buildMicroRow('Iron', '${widget.result.ironMg}mg', 'Fair', const Color(0xFF5C7CFA)),
        ],
      ),
    );
  }

  Widget _buildMicroRow(String name, String value, String badge, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Text(name, style: const TextStyle(color: Colors.white70, fontSize: 15)),
          const Spacer(),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isFailed = widget.result.foodName == "Unable to confidently identify food" || widget.result.foodName == "No Food Detected" || widget.result.foodName == "Analysis Failed";
    
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: isFailed ? () {
              // Retake photo
              Navigator.pop(context);
            } : () {
              final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
              historyProvider.addEntry(widget.result, widget.imageFile?.path ?? '');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ Saved to History'),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isFailed ? AppTheme.accentRed : AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(isFailed ? 'Retake Photo' : 'Save to History', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0D1117))),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: () {
              // Action for Ask AI (could route to chat)
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.15), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('Ask AI about this meal', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
        )
      ],
    );
  }
}
