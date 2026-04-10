import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/ar_capture_service.dart';
import 'analysis_screen.dart';

/// AR-guided capture screen — records camera pose data alongside each photo.
/// Works on web (DeviceOrientation API) and mobile (IMU sensors).
class ArCaptureScreen extends StatefulWidget {
  const ArCaptureScreen({super.key});

  @override
  State<ArCaptureScreen> createState() => _ArCaptureScreenState();
}

class _ArCaptureScreenState extends State<ArCaptureScreen>
    with TickerProviderStateMixin {
  final _picker = ImagePicker();
  final _arService = ArCaptureService();

  final List<XFile> _images = [];
  final List<CameraPoseData> _poses = [];
  final Map<int, Uint8List> _thumbnails = {};

  late final AnimationController _orbitController;
  late final AnimationController _pulseController;
  late final Animation<double> _orbitAnim;
  late final Animation<double> _pulseAnim;

  static const int _targetShots = 4;
  static const int _minShots = 2;

  static const List<_ShotGuide> _guides = [
    _ShotGuide('Shot 1', 'Top-down view', Icons.arrow_circle_down_rounded, Color(0xFF4ADE80)),
    _ShotGuide('Shot 2', '45° side angle', Icons.rotate_left_rounded, Color(0xFF60A5FA)),
    _ShotGuide('Shot 3', 'Opposite side', Icons.rotate_right_rounded, Color(0xFFE879F9)),
    _ShotGuide('Shot 4', 'Close-up detail', Icons.zoom_in_rounded, Color(0xFFFBBF24)),
  ];

  @override
  void initState() {
    super.initState();
    _arService.start();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _orbitAnim = Tween<double>(begin: 0, end: 1).animate(_orbitController);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _arService.stop();
    _orbitController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_images.length >= _targetShots) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    final pose = _arService.snapshot(_images.length);
    final bytes = await image.readAsBytes();

    setState(() {
      _images.add(image);
      _poses.add(pose);
      _thumbnails[_images.length - 1] = bytes;
    });
  }

  void _analyze() {
    if (_images.length < _minShots) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => AnalysisScreen(
          imageFiles: _images,
          poseData: _poses.map((p) => p.toJson()).toList(),
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  double get _diversityScore => computePoseDiversity(_poses);

  @override
  Widget build(BuildContext context) {
    final int count = _images.length;
    final bool canAnalyze = count >= _minShots;
    final bool done = count >= _targetShots;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text('AR Capture',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        )),
                  ),
                  // AR Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.view_in_ar_rounded,
                            color: Colors.white, size: 13),
                        const SizedBox(width: 4),
                        Text('AR Mode',
                            style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Orbit guidance animation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AnimatedBuilder(
                animation: _orbitAnim,
                builder: (_, __) => _OrbitWidget(
                  progress: _orbitAnim.value,
                  capturedCount: count,
                  total: _targetShots,
                  pulse: _pulseAnim.value,
                  diversityScore: _diversityScore,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Shot checklist
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: List.generate(_targetShots, (i) {
                  final guide = _guides[i];
                  final captured = i < count;
                  final isNext = i == count;
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: captured
                            ? guide.color.withOpacity(0.15)
                            : isNext
                                ? Colors.white.withOpacity(0.06)
                                : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: captured
                              ? guide.color.withOpacity(0.5)
                              : isNext
                                  ? Colors.white.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            captured ? Icons.check_circle_rounded : guide.icon,
                            color: captured ? guide.color : isNext ? Colors.white54 : Colors.white24,
                            size: 20,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            captured ? '✓' : '${i + 1}',
                            style: TextStyle(
                              color: captured ? guide.color : Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),

            // Current instruction
            if (!done)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _guides[count].color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _guides[count].color.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(_guides[count].icon, color: _guides[count].color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_guides[count].title,
                                style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14)),
                            Text(_guides[count].subtitle,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Thumbnails strip
            if (_thumbnails.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _thumbnails.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_thumbnails[i]!,
                          width: 72, height: 72, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  // Capture button
                  if (!done)
                    Expanded(
                      child: ScaleTransition(
                        scale: _pulseAnim,
                        child: ElevatedButton.icon(
                          onPressed: _capture,
                          icon: const Icon(Icons.camera_alt_rounded, size: 20),
                          label: Text('Capture ${count + 1} of $_targetShots',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 6,
                            shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ),
                  if (!done && canAnalyze) const SizedBox(width: 12),
                  // Analyze button
                  if (canAnalyze)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _analyze,
                        icon: const Icon(Icons.document_scanner_rounded, size: 20),
                        label: Text(
                          done ? 'Analyze (AR)' : 'Analyze $count Photos',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 6,
                          shadowColor: const Color(0xFF6366F1).withOpacity(0.4),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShotGuide {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const _ShotGuide(this.title, this.subtitle, this.icon, this.color);
}

/// Animated orbit ring showing capture guidance.
class _OrbitWidget extends StatelessWidget {
  final double progress;
  final int capturedCount;
  final int total;
  final double pulse;
  final double diversityScore;

  const _OrbitWidget({
    required this.progress,
    required this.capturedCount,
    required this.total,
    required this.pulse,
    required this.diversityScore,
  });

  @override
  Widget build(BuildContext context) {
    final double fillAngle = (capturedCount / total) * 2 * 3.14159;
    Color qualityColor = diversityScore > 0.4
        ? const Color(0xFF4ADE80)
        : diversityScore > 0.2
            ? const Color(0xFFFBBF24)
            : Colors.white38;

    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer orbit ring
          Transform.rotate(
            angle: progress * 2 * 3.14159,
            child: CustomPaint(
              size: const Size(150, 150),
              painter: _OrbitPainter(fillAngle: fillAngle),
            ),
          ),
          // Center food icon
          Transform.scale(
            scale: pulse,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.25),
                    AppTheme.primaryColor.withOpacity(0.05),
                  ],
                ),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.restaurant_rounded,
                      color: AppTheme.primaryColor, size: 28),
                  Text('$capturedCount/$total',
                      style: TextStyle(
                          color: AppTheme.primaryColor.withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          // Diversity badge
          if (capturedCount >= 2)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: qualityColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: qualityColor.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.insights_rounded, color: qualityColor, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      diversityScore > 0.4
                          ? 'Pose diversity: Good'
                          : diversityScore > 0.2
                              ? 'Pose diversity: Fair'
                              : 'Move around food',
                      style: TextStyle(
                          color: qualityColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double fillAngle;
  const _OrbitPainter({required this.fillAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background ring
    canvas.drawArc(
      rect, 0, 2 * 3.14159, false,
      Paint()
        ..color = Colors.white.withOpacity(0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Progress ring
    if (fillAngle > 0) {
      canvas.drawArc(
        rect, -3.14159 / 2, fillAngle, false,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF4ADE80), Color(0xFF6366F1)],
          ).createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }

    // Orbiting dot
    final dotAngle = -3.14159 / 2 + fillAngle;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    canvas.drawCircle(
      Offset(dotX, dotY), 5,
      Paint()..color = AppTheme.primaryColor,
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.fillAngle != fillAngle;
}
