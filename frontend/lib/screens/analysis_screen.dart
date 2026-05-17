import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../models/nutrition_result.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final XFile? imageFile;
  final List<XFile>? imageFiles;
  final List<Map<String, dynamic>>? poseData;

  const AnalysisScreen({super.key, this.imageFile, this.imageFiles, this.poseData})
      : assert(imageFile != null || imageFiles != null, 'Either imageFile or imageFiles must be provided');

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _hasError = false;
  String? _errorMessage;
  late final List<XFile> _allImages;
  
  int _progress = 0;
  int _stepIndex = 0;
  Timer? _simTimer;

  @override
  void initState() {
    super.initState();
    _allImages = widget.imageFiles != null && widget.imageFiles!.isNotEmpty ? widget.imageFiles! : [widget.imageFile!];
    
    _startSimulatedProgress();
    _startAnalysis();
  }

  void _startSimulatedProgress() {
    _simTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;
      setState(() {
        if (_progress < 30) {
          _progress += 10;
          _stepIndex = 0; // Image preprocessing
        } else if (_progress < 70) {
          _progress += 8;
          _stepIndex = 1; // Food recognition
        } else if (_progress < 95) {
          _progress += 2;
          _stepIndex = 2; // Portion & macro estimation
        }
      });
    });
  }

  Future<void> _startAnalysis() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final NutritionResult result;
      final poses = widget.poseData;

      if (poses != null && poses.isNotEmpty) {
        result = await apiService.analyzeWithPoseData(_allImages, poses);
      } else if (_allImages.length > 1) {
        result = await apiService.analyzeMultipleImages(_allImages);
      } else {
        result = await apiService.analyzeImage(_allImages.first);
      }

      if (mounted) {
        _simTimer?.cancel();
        setState(() {
          _progress = 100;
          _stepIndex = 3; // Done
        });
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ResultsScreen(result: result, imageFile: _allImages.first),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _simTimer?.cancel();
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠️ Network/API Error: Could not complete analysis.'),
            backgroundColor: const Color(0xFFFF6B6B), // AppTheme.accentRed
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: _hasError ? _buildErrorState() : _buildAnalyzingState(),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyzingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(),
        Center(
          child: SizedBox(
            width: 200, height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: _progress / 100,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  color: AppTheme.primaryColor,
                  strokeWidth: 8,
                  strokeCap: StrokeCap.round,
                ),
                Center(
                  child: Text('$_progress%', style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Analyzing...', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        const Text('Please wait while AI processes your image', style: TextStyle(color: Colors.white54, fontSize: 14)),
        
        const SizedBox(height: 48),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PROCESSING STEPS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white54)),
              const SizedBox(height: 20),
              _buildStepRow('Image preprocessing', 0),
              const SizedBox(height: 16),
              _buildStepRow('Food recognition', 1),
              const SizedBox(height: 16),
              _buildStepRow('Portion estimation', 2),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF9D84FF), size: 16),
              const SizedBox(width: 8),
              Text('Vision Model Active', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStepRow(String title, int stepIndex) {
    final isCompleted = _stepIndex > stepIndex;
    final isActive = _stepIndex == stepIndex;
    
    return Row(
      children: [
        if (isCompleted)
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
            child: const Icon(Icons.check, color: Color(0xFF0D1117), size: 14),
          )
        else if (isActive)
          const SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
          )
        else
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)),
          ),
        const SizedBox(width: 16),
        Text(title, style: TextStyle(
          color: isCompleted || isActive ? Colors.white : Colors.white54,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          fontSize: 15
        )),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 80, color: Color(0xFFFF6B6B)),
            const SizedBox(height: 24),
            Text('Analysis Failed', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Unknown error occurred', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF161B22), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Padding(padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12), child: Text('Go Back', style: TextStyle(color: Colors.white))),
            ),
          ],
        ),
      ),
    );
  }
}
