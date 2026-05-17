import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/theme_provider.dart';
import '../theme/app_theme.dart';
import 'results_screen.dart';

const Color neonGreen = Color(0xFF00FF88);
const Color darkBg = Color(0xFF0F141A);
const Color cardBg = Color(0xFF1E2631);
const Color emptyCardBg = Color(0xFF161B22);

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _laserAnimation = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  Future<void> _captureBarcode(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image == null || !mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService().processBarcodeImage(image);
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process image. Please try again.'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final surf = isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary;
    final textMuted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Barcode Scan',
                style: GoogleFonts.outfit(
                  color: textPrimary,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Point at any product barcode',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Viewfinder
              _buildViewfinder(surf),
              const SizedBox(height: 24),

              // Scanning Status Card
              _buildScanningStatus(surf, textPrimary, textMuted),
              const SizedBox(height: 24),

              // Divider
              _buildDivider(textMuted),
              const SizedBox(height: 24),

              // Upload Image Button
              _buildUploadButton(surf, textPrimary),
              const SizedBox(height: 24),

              // Recent Scans
              _buildRecentScans(surf, textPrimary, textMuted),
            ],
          ),
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildViewfinder(Color surf) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Simulated Barcode graphic
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(35, (index) {
              final isThick = index % 3 == 0 || index % 5 == 0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: isThick ? 4 : 2,
                height: 80,
                color: Colors.grey.withOpacity(0.4),
              );
            }),
          ),
          
          // Laser line
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              return Positioned(
                top: 240 * _laserAnimation.value,
                left: 32,
                right: 32,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: neonGreen,
                    boxShadow: [
                      BoxShadow(
                        color: neonGreen.withOpacity(0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Neon Green Corners
          Positioned(top: 24, left: 24, child: _buildCorner(0)),
          Positioned(top: 24, right: 24, child: _buildCorner(1)),
          Positioned(bottom: 24, right: 24, child: _buildCorner(2)),
          Positioned(bottom: 24, left: 24, child: _buildCorner(3)),
        ],
      ),
    );
  }

  Widget _buildScanningStatus(Color surf, Color textPrimary, Color textMuted) {
    return GestureDetector(
      onTap: () => _captureBarcode(ImageSource.camera),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: surf.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.2)),
        ),
        child: Column(
          children: [
            if (_isLoading)
              const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3B82F6)),
              )
            else ...[
              Text(
                'Scanning for barcode...',
                style: TextStyle(
                  color: const Color(0xFF3B82F6), // Blue accent text
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Supports EAN-13, UPC-A, QR',
                style: TextStyle(
                  color: textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadButton(Color surf, Color textPrimary) {
    return GestureDetector(
      onTap: () => _captureBarcode(ImageSource.gallery),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: surf.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Center(
          child: Text(
            'Upload Barcode Image',
            style: GoogleFonts.outfit(
              color: textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color textMuted) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '— or —',
            style: TextStyle(
              color: textMuted,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.grey.withOpacity(0.2))),
      ],
    );
  }

  Widget _buildRecentScans(Color surf, Color textPrimary, Color textMuted) {
    final scans = [
      {'name': "Nature's Path Granola", 'kcal': 210},
      {'name': "Amul Greek Yogurt", 'kcal': 140},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surf.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT SCANS',
            style: GoogleFonts.outfit(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ...scans.map((scan) {
            final isLast = scan == scans.last;
            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      scan['name'] as String,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${scan['kcal']} kcal',
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (!isLast) ...[
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.grey.withOpacity(0.1)),
                  const SizedBox(height: 16),
                ]
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCorner(int rotationIndex) {
    return RotatedBox(
      quarterTurns: rotationIndex,
      child: Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: neonGreen, width: 2.5),
            left: BorderSide(color: neonGreen, width: 2.5),
          ),
        ),
      ),
    );
  }
}
