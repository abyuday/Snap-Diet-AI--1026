import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import 'analysis_screen.dart';
import 'ar_capture_screen.dart';

/// Angle guide info for each capture slot
class _AngleGuide {
  final String title;
  final String subtitle;
  final IconData icon;
  const _AngleGuide(this.title, this.subtitle, this.icon);
}

const List<_AngleGuide> _guides = [
  _AngleGuide('Top View', 'Directly above the food', Icons.arrow_downward_rounded),
  _AngleGuide('Side View', '45° angle from the side', Icons.rotate_90_degrees_cw_rounded),
  _AngleGuide('Close-up', 'Zoom into the food details', Icons.zoom_in_rounded),
  _AngleGuide('Another Angle', 'Any other perspective', Icons.crop_rotate_rounded),
];

class MultiCaptureScreen extends StatefulWidget {
  /// Pre-loaded images (e.g. from gallery multi-pick)
  final List<XFile>? initialImages;

  const MultiCaptureScreen({super.key, this.initialImages});

  @override
  State<MultiCaptureScreen> createState() => _MultiCaptureScreenState();
}

class _MultiCaptureScreenState extends State<MultiCaptureScreen>
    with TickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final Map<int, Uint8List> _thumbnails = {};
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  static const int _maxImages = 4;
  static const int _minImages = 2;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Load pre-selected images if any
    if (widget.initialImages != null) {
      for (final img in widget.initialImages!) {
        if (_images.length < _maxImages) {
          _images.add(img);
          _loadThumbnail(_images.length - 1, img);
        }
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadThumbnail(int index, XFile file) async {
    final bytes = await file.readAsBytes();
    if (mounted) {
      setState(() => _thumbnails[index] = bytes);
    }
  }

  Future<void> _captureImage(int slotIndex) async {
    final source = await _showSourcePicker();
    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 90,
    );
    if (image != null && mounted) {
      setState(() {
        if (slotIndex < _images.length) {
          // Replace existing
          _images[slotIndex] = image;
        } else {
          // Add new
          _images.add(image);
        }
      });
      _loadThumbnail(slotIndex, image);
    }
  }

  Future<ImageSource?> _showSourcePicker() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose Source',
              style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: AppTheme.primaryColor,
                    onTap: () => Navigator.pop(ctx, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SourceOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: const Color(0xFF4FA3E0),
                    onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
      // Rebuild thumbnail map
      final newThumbs = <int, Uint8List>{};
      _thumbnails.forEach((k, v) {
        if (k < index) {
          newThumbs[k] = v;
        } else if (k > index) {
          newThumbs[k - 1] = v;
        }
      });
      _thumbnails.clear();
      _thumbnails.addAll(newThumbs);
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
    final bool canAnalyze = _images.length >= _minImages;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Capture Food',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // AR Mode button
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ArCaptureScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
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
                              color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'AR Mode',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: canAnalyze
                          ? AppTheme.primaryColor.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: canAnalyze
                            ? AppTheme.primaryColor.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Text(
                      '${_images.length}/$_maxImages',
                      style: TextStyle(
                        color: canAnalyze ? AppTheme.primaryColor : Colors.white54,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Info banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.primaryColor.withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.info_outline_rounded,
                          color: AppTheme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Multiple angles = better accuracy',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Take ${_minImages}–$_maxImages photos from different angles for precise portion & weight estimation.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Image grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _maxImages,
                  itemBuilder: (context, index) {
                    final hasImage = index < _images.length;
                    final guide = _guides[index];

                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: hasImage
                          ? _FilledSlot(
                              key: ValueKey('filled_$index'),
                              bytes: _thumbnails[index],
                              guide: guide,
                              onRemove: () => _removeImage(index),
                              onReplace: () => _captureImage(index),
                            )
                          : _EmptySlot(
                              key: ValueKey('empty_$index'),
                              guide: guide,
                              isNext: index == _images.length,
                              pulseAnim: _pulseAnim,
                              onTap: index == _images.length
                                  ? () => _captureImage(index)
                                  : null,
                            ),
                    );
                  },
                ),
              ),
            ),

            // Bottom action area
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  if (!canAnalyze)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Add at least $_minImages photos to continue',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: canAnalyze ? _startAnalysis : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAnalyze
                            ? AppTheme.primaryColor
                            : Colors.white.withOpacity(0.06),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withOpacity(0.06),
                        disabledForegroundColor: Colors.white30,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: canAnalyze ? 6 : 0,
                        shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            canAnalyze
                                ? Icons.document_scanner_rounded
                                : Icons.camera_alt_outlined,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            canAnalyze
                                ? 'Analyze ${_images.length} Photos'
                                : 'Add More Photos',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// A filled image slot with thumbnail, label, and remove/replace actions
class _FilledSlot extends StatelessWidget {
  final Uint8List? bytes;
  final _AngleGuide guide;
  final VoidCallback onRemove;
  final VoidCallback onReplace;

  const _FilledSlot({
    super.key,
    required this.bytes,
    required this.guide,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onReplace,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.4), width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image
              if (bytes != null)
                Image.memory(bytes!, fit: BoxFit.cover)
              else
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),

              // Bottom gradient + label
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(guide.icon, color: AppTheme.primaryColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          guide.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Check badge
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                ),
              ),

              // Remove button
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.white70, size: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty slot waiting for an image
class _EmptySlot extends StatelessWidget {
  final _AngleGuide guide;
  final bool isNext;
  final Animation<double> pulseAnim;
  final VoidCallback? onTap;

  const _EmptySlot({
    super.key,
    required this.guide,
    required this.isNext,
    required this.pulseAnim,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget content = GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isNext
              ? AppTheme.primaryColor.withOpacity(0.06)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isNext
                ? AppTheme.primaryColor.withOpacity(0.35)
                : Colors.white.withOpacity(0.08),
            width: isNext ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isNext
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNext ? Icons.add_a_photo_rounded : guide.icon,
                color: isNext ? AppTheme.primaryColor : Colors.white30,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              guide.title,
              style: TextStyle(
                color: isNext ? Colors.white : Colors.white38,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                guide.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isNext ? Colors.white.withOpacity(0.45) : Colors.white24,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Pulse animation only on the "next" slot
    if (isNext) {
      return AnimatedBuilder(
        animation: pulseAnim,
        builder: (context, child) => Transform.scale(
          scale: pulseAnim.value,
          child: child,
        ),
        child: content,
      );
    }

    return content;
  }
}

/// Bottom sheet source picker option
class _SourceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SourceOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
