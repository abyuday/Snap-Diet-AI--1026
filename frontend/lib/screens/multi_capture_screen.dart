import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'ar_capture_screen.dart';

const Color neonGreen = Color(0xFF00FF88);
const Color darkBg = Color(0xFF0F141A);
const Color cardBg = Color(0xFF1E2631);
const Color emptyCardBg = Color(0xFF161B22);

class MultiCaptureScreen extends StatefulWidget {
  final List<XFile>? initialImages;

  const MultiCaptureScreen({super.key, this.initialImages});

  @override
  State<MultiCaptureScreen> createState() => _MultiCaptureScreenState();
}

class _MultiCaptureScreenState extends State<MultiCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final Map<int, Uint8List> _thumbnails = {};

  static const int _maxImages = 6;
  static const int _minImages = 1;

  @override
  void initState() {
    super.initState();
    if (widget.initialImages != null) {
      for (final img in widget.initialImages!) {
        if (_images.length < _maxImages) {
          _images.add(img);
          _loadThumbnail(_images.length - 1, img);
        }
      }
    }
  }

  Future<void> _loadThumbnail(int index, XFile file) async {
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _thumbnails[index] = bytes);
    }
  }

  Future<void> _captureImage() async {
    if (_images.length >= _maxImages) return;
    
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    
    if (image != null && mounted) {
      setState(() {
        _images.add(image);
      });
      _loadThumbnail(_images.length - 1, image);
    }
  }

  void _clearAll() {
    setState(() {
      _images.clear();
      _thumbnails.clear();
    });
  }

  void _startAnalysis() {
    if (_images.length < _minImages) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AnalysisScreen(imageFiles: _images),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_in_ar_rounded, color: neonGreen),
            onPressed: () => Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const ArCaptureScreen())),
            tooltip: 'AR Mode',
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            if (isWide) {
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 24),
                              Expanded(child: _buildCameraPreview()),
                              const SizedBox(height: 24),
                              _buildBottomActions(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildCapturesHeader(),
                              const SizedBox(height: 16),
                              Expanded(child: _buildGrid()),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Mobile layout
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  Expanded(flex: 4, child: _buildCameraPreview()),
                  const SizedBox(height: 24),
                  _buildCapturesHeader(),
                  const SizedBox(height: 16),
                  Expanded(flex: 5, child: _buildGrid()),
                  const SizedBox(height: 24),
                  _buildBottomActions(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Snap Food',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture 1–6 angles for best accuracy',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: neonGreen.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${_images.length}/$_maxImages',
            style: GoogleFonts.outfit(
              color: neonGreen,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPreview() {
    return GestureDetector(
      onTap: _images.length < _maxImages ? _captureImage : null,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Current viewfinder content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reticle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: neonGreen.withOpacity(0.6), width: 2),
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: neonGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Point at your food',
                  style: TextStyle(
                    color: neonGreen,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            
            // Neon Green Corners
            Positioned(top: 24, left: 24, child: _buildCorner(0)),
            Positioned(top: 24, right: 24, child: _buildCorner(1)),
            Positioned(bottom: 24, right: 24, child: _buildCorner(2)),
            Positioned(bottom: 24, left: 24, child: _buildCorner(3)),

            // Bottom Badges
            Positioned(
              bottom: 24,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAngleBadge('Top', true),
                  const SizedBox(width: 8),
                  _buildAngleBadge('Side', false),
                  const SizedBox(width: 8),
                  _buildAngleBadge('45°', false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAngleBadge(String text, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: darkBg.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isSelected ? neonGreen : Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCapturesHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'CAPTURES',
          style: GoogleFonts.outfit(
            color: Colors.white54,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
          ),
        ),
        GestureDetector(
          onTap: _images.isNotEmpty ? _clearAll : null,
          child: Text(
            'Clear all',
            style: TextStyle(
              color: _images.isNotEmpty ? neonGreen : Colors.white30,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: _maxImages,
      itemBuilder: (context, index) {
        final hasImage = index < _images.length;
        
        return Container(
          decoration: BoxDecoration(
            color: hasImage ? cardBg : emptyCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasImage ? neonGreen : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: hasImage
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_thumbnails[index] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14.5),
                        child: Image.memory(
                          _thumbnails[index]!,
                          fit: BoxFit.cover,
                          color: Colors.black.withOpacity(0.4), // Darken to match design
                          colorBlendMode: BlendMode.darken,
                        ),
                      ),
                    const Center(
                      child: Icon(
                        Icons.check,
                        color: neonGreen,
                        size: 28,
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.white.withOpacity(0.15),
                    size: 24,
                  ),
                ),
        );
      },
    );
  }

  Widget _buildBottomActions() {
    final canAnalyze = _images.length >= _minImages;

    return Row(
      children: [
        // Capture button
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: _images.length < _maxImages ? _captureImage : null,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Colors.white.withOpacity(0.7),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capture',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Analyze button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: canAnalyze ? _startAnalysis : null,
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: canAnalyze ? neonGreen : cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Analyze →',
                  style: GoogleFonts.outfit(
                    color: canAnalyze ? Colors.black : Colors.white30,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
