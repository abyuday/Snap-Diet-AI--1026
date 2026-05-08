import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ar_capture_service.dart';
import 'analysis_screen.dart';

class ArCaptureScreen extends StatefulWidget {
  const ArCaptureScreen({super.key});

  @override
  State<ArCaptureScreen> createState() => _ArCaptureScreenState();
}

class _ArCaptureScreenState extends State<ArCaptureScreen> {
  final _picker = ImagePicker();
  final _arService = ArCaptureService();
  final List<XFile> _images = [];
  final List<CameraPoseData> _poses = [];

  static const List<String> _angles = ['Top', 'Front', 'Left', 'Right'];

  @override
  void initState() {
    super.initState();
    _arService.start();
  }

  @override
  void dispose() {
    _arService.stop();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_images.length >= _angles.length) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (image == null || !mounted) return;

    final pose = _arService.snapshot(_images.length);
    setState(() {
      _images.add(image);
      _poses.add(pose);
    });

    if (_images.length == _angles.length) {
      _analyze();
    }
  }

  void _analyze() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => AnalysisScreen(
          imageFiles: _images,
          poseData: _poses.map((p) => p.toJson()).toList(),
        ),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // Simulated camera viewfinder background
          Container(
            color: const Color(0xFF161B22),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer dashed circle
                  Container(
                    width: 280, height: 280,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2, style: BorderStyle.solid)), // Using solid since dashed isn't native easily
                  ),
                  // Inner target
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.primaryColor, width: 2)),
                    child: const Center(child: Icon(Icons.add, color: AppTheme.primaryColor, size: 24)),
                  )
                ],
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Column(
                  children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      Expanded(child: Text('AR Capture', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center)),
                      const SizedBox(width: 48), // Balance
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Gyro Active Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.screen_rotation, color: AppTheme.primaryColor, size: 16),
                      SizedBox(width: 8),
                      Text('Gyro: Active', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Instruction
                const Text('Tilt device 15° left for next angle', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 32),
                
                // Gyro Slider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      const Text('-45°', style: TextStyle(color: Colors.white54, fontSize: 12)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                            Positioned(
                              left: 80, // Simulated position
                              child: Container(width: 16, height: 16, decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text('+45°', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 48),
                
                // Angle Progress
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D1117),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ANGLE PROGRESS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white54)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(_angles.length, (index) {
                          final isCompleted = index < _images.length;
                          final isActive = index == _images.length;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isCompleted ? AppTheme.primaryColor : (isActive ? AppTheme.primaryColor.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isCompleted ? AppTheme.primaryColor : (isActive ? AppTheme.primaryColor : Colors.white.withOpacity(0.1))),
                            ),
                            child: Text(
                              _angles[index],
                              style: TextStyle(
                                color: isCompleted ? const Color(0xFF0D1117) : (isActive ? AppTheme.primaryColor : Colors.white54),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),
                      Center(
                        child: GestureDetector(
                          onTap: _capture,
                          child: Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                            child: Center(
                              child: Container(
                                width: 56, height: 56,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
